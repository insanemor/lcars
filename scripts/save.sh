#!/usr/bin/env bash
# =====================================================================
# lcars — salvar o que você ajustou nesta máquina e publicar
#
#   nsave                    exporta, mostra o diff, pergunta, commita e publica
#   nsave -m "mensagem"      define a mensagem do commit
#   nsave -n                 mostra tudo que faria, sem alterar nada
#   nsave -y                 não pergunta (para quando você já sabe o que vem)
#   nsave --no-export        não roda o export do noctalia
#
# O alias `nsave` está em user/shell/zsh.nix e aponta para cá.
#
# É o `nupdate` ao contrário. Aquele puxa do repositório e aplica; este pega o
# que você mudou aqui e devolve.
#
# A sequência:
#   1. exporta a configuração do noctalia por cima do arquivo versionado
#   2. valida o TOML — inválido para aqui, antes de qualquer commit
#   3. mostra o que mudou e espera você confirmar
#   4. commita em main
#   5. rebaseia sobre o remoto, se ele estiver à frente, e publica
#
# POR QUE ELE EXISTE: sem ele, publicar um ajuste do noctalia é lembrar de
# quatro comandos na ordem certa, e a ordem errada custa o trabalho. O
# `nupdate` faz `git reset --hard origin/main` e só preserva machines/<host>;
# rodá-lo antes de commitar apaga o TOML exportado.
#
# machines/ NÃO é publicado. É o único lugar que descreve hardware, e cada
# máquina tem o seu — mandá-lo junto num comando que roda sem atenção faria
# uma máquina sobrescrever a configuração da outra. Se você mexeu lá, o script
# avisa e segue sem levar.
#
# CONFLITO NÃO É ADIVINHADO. Se o rebase parar, o script desfaz o rebase e sai
# explicando. Ao contrário do `nupdate`, aqui não há lado que "sempre vence":
# lá o repositório é a verdade, aqui os dois lados são trabalho seu.
# =====================================================================

set -euo pipefail

REPO="${LCARS_REPO_DIR:-$HOME/.dotfiles}"
BRANCH="main"
TOML="user/wm/noctalia-config.toml"

MSG=""
DRY=no
ASSUME=no
EXPORT=yes
while [[ $# -gt 0 ]]; do
  case "$1" in
    -m) MSG="${2:-}"; [[ -n "$MSG" ]] || { printf -- '-m precisa de uma mensagem\n' >&2; exit 2; }; shift 2 ;;
    -n|--dry-run)   DRY=yes; shift ;;
    -y|--yes)       ASSUME=yes; shift ;;
    --no-export)    EXPORT=no; shift ;;
    -h|--help)      sed -n '2,36p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) printf 'opção desconhecida: %s (use --help)\n' "$1" >&2; exit 2 ;;
  esac
done

red=$'\033[1;31m'; green=$'\033[1;32m'
yellow=$'\033[1;33m'; blue=$'\033[1;34m'; off=$'\033[0m'
step() { printf '\n%s==> %s%s\n' "$blue" "$*" "$off"; }
ok()   { printf '%s    %s%s\n' "$green" "$*" "$off"; }
die()  { printf '%s!!  %s%s\n' "$red" "$*" "$off" >&2; exit 1; }
note() { printf '%s    %s%s\n' "$yellow" "$*" "$off"; }

[[ -d "$REPO/.git" ]] || die "não achei um repositório git em $REPO"
cd "$REPO"

atual="$(git rev-parse --abbrev-ref HEAD)"
[[ "$atual" == "$BRANCH" ]] \
  || die "você está na branch '$atual', e este comando publica em '$BRANCH'.
    Ou volte para $BRANCH, ou publique essa branch à mão."

# Mesmo diagnóstico do nupdate: versões antigas rodavam `sudo nixos-rebuild`, o
# Nix escrevia em .git/objects como root, e o git só reclama depois — no
# primeiro fetch que precise gravar.
if find .git -maxdepth 3 ! -user "$(id -un)" -print -quit 2>/dev/null | grep -q .; then
  printf '\n'
  die "há arquivos do root dentro de $REPO/.git — o git não consegue escrever.
    Uma vez só, rode:

        sudo chown -R \"\$USER\" $REPO

    e chame o nsave de novo."
fi

# --- 1. exportar ------------------------------------------------------
# `merged` exporta a sua configuração, sem os defaults embutidos do noctalia
# (isso é o `full`). Por isso o arquivo versionado fica pequeno e o diff
# legível.
if [[ "$EXPORT" == "yes" ]]; then
  step "exportando a configuração do noctalia"
  if ! command -v noctalia >/dev/null 2>&1; then
    note "noctalia não está no PATH — seguindo sem exportar"
  else
    # Para um arquivo temporário: `noctalia … > $TOML` truncaria o arquivo
    # versionado antes de o comando rodar, e um export que falha deixaria você
    # sem a configuração e sem o original.
    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' EXIT
    if ! noctalia config export merged > "$tmp" 2>/dev/null; then
      note "o export falhou (o noctalia está rodando?) — seguindo com o arquivo atual"
    elif [[ ! -s "$tmp" ]]; then
      note "o export veio vazio — seguindo com o arquivo atual"
    else
      # --- 2. validar ---------------------------------------------------
      # Antes de tocar no arquivo versionado. Um TOML quebrado que chegasse ao
      # repositório derrubaria o rebuild de todas as outras máquinas.
      if ! noctalia config validate "$tmp" >/dev/null 2>&1; then
        printf '\n'
        noctalia config validate "$tmp" 2>&1 | sed 's/^/    /' || true
        die "o TOML exportado não passou na validação — nada foi alterado."
      fi
      cp "$tmp" "$TOML"
      ok "$TOML atualizado"
    fi
  fi
fi

# --- 3. o que vai (e o que não vai) ----------------------------------
step "o que vai para o repositório"

# `-z` e o laço abaixo, em vez de parsear a saída normal: nome de arquivo com
# espaço quebraria qualquer split por linha, e o git escapa aspas na saída
# legível.
mapfile -d '' -t todos < <(git status --porcelain -z -uall | \
  while IFS= read -r -d '' registro; do
    caminho="${registro:3}"
    # Renomeado vem como "R  novo\0antigo\0" — o segundo campo é lido e
    # descartado aqui, senão o laço o trataria como um arquivo à parte.
    [[ "${registro:0:1}" == "R" ]] && IFS= read -r -d '' _antigo
    printf '%s\0' "$caminho"
  done)

levar=(); ficar=()
for f in "${todos[@]}"; do
  case "$f" in
    machines/*) ficar+=("$f") ;;
    *)          levar+=("$f") ;;
  esac
done

if [[ ${#ficar[@]} -gt 0 ]]; then
  note "não publicados (machines/ é desta máquina):"
  printf '      %s\n' "${ficar[@]}"
fi

if [[ ${#levar[@]} -eq 0 ]]; then
  printf '\n'
  ok "nada para publicar — o repositório já reflete esta máquina"
  exit 0
fi

printf '\n'
printf '    %s\n' "${levar[@]}"
printf '\n'
# --stat sobre os rastreados; os novos não aparecem no diff e já foram listados
# acima pelo nome.
git --no-pager diff --stat -- "${levar[@]}" | sed 's/^/    /' || true
printf '\n'
git --no-pager diff -- "${levar[@]}" | sed 's/^/    /' || true

# --- 4. confirmar -----------------------------------------------------
if [[ "$DRY" == "yes" ]]; then
  printf '\n'
  ok "dry run — nada foi commitado nem publicado"
  exit 0
fi

if [[ "$ASSUME" != "yes" ]]; then
  [[ -t 0 ]] || die "sem terminal para perguntar — use -y se é isso que você quer"
  printf '\n'
  read -r -p "publicar em $BRANCH? [s/N] " resposta
  case "$resposta" in
    s|S|sim|SIM) ;;
    *) note "cancelado — o que você exportou continua no disco"; exit 0 ;;
  esac
fi

# --- 5. commitar ------------------------------------------------------
HOST="$(hostname)"
[[ -n "$MSG" ]] || MSG="config: ajustes feitos em $HOST"

step "commitando"
git add -- "${levar[@]}"
git commit -q -m "$MSG"
ok "$(git --no-pager log --oneline -1)"

# --- 6. publicar ------------------------------------------------------
step "publicando em origin/$BRANCH"
git fetch --quiet origin "$BRANCH"

if ! git merge-base --is-ancestor "origin/$BRANCH" HEAD; then
  note "o remoto está à frente — rebaseando o seu commit por cima"
  # A saída vai para uma variável em vez da tela: em caso de conflito o git
  # imprime hints sobre `--continue` e `--abort`, e nós já abortamos — deixá-las
  # aparecer mandaria o usuário fazer o que não é mais possível. Do que ele
  # imprime, só as linhas de CONFLICT interessam: são a lista de arquivos.
  if ! rebase_saida="$(git rebase "origin/$BRANCH" 2>&1)"; then
    git rebase --abort >/dev/null 2>&1 || true
    printf '\n'
    printf '%s\n' "$rebase_saida" | grep '^CONFLICT' | sed 's/^/    /' || true
    die "o rebase encontrou conflito, e foi desfeito — o seu commit está
    intacto, aqui, sem nada pela metade.

    Um arquivo mudou dos dois lados e escolher por você seria chute. Resolva
    à mão:

        cd $REPO
        git rebase origin/$BRANCH     # edite os conflitos, git add, git rebase --continue
        git push origin $BRANCH"
  fi
fi

git push --quiet origin "$BRANCH"

printf '\n'
ok "publicado — origin/$BRANCH em $(git rev-parse --short HEAD)"
