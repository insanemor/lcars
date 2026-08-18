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
#   0. sincroniza o histórico do atuin, se ele estiver instalado (fora do -n)
#   1. exporta a configuração do noctalia por cima do arquivo versionado
#   2. valida o TOML — inválido para aqui, antes de qualquer commit
#   3. consulta o remoto e mostra o que mudou aqui e o que ainda não subiu
#   4. espera você confirmar
#   5. commita em main, se houver arquivo alterado
#   6. rebaseia sobre o remoto, se ele estiver à frente, e publica
#
# DUAS COISAS DIFERENTES: ter o que commitar e ter o que publicar. Um commit
# feito à mão deixa a árvore limpa e o remoto desatualizado ao mesmo tempo, e a
# primeira versão olhava só a árvore — saía dizendo que estava tudo publicado
# sem ter consultado o remoto, e o commit ficava para trás (#31). Por isso o
# fetch acontece antes de decidir se há trabalho, e não junto do push.
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
    -h|--help)      sed -n '2,43p' "$0" | sed 's/^# \?//'; exit 0 ;;
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

# O histórico de comandos sobe antes de publicar, pelo mesmo motivo do nupdate:
# fechar a janela entre o último `auto_sync` do atuin e agora. Silencioso, e
# incapaz de parar o script — sem atuin, sem login ou sem rede, segue em frente.
#
# Fora do dry run: `-n` promete não alterar nada, e um sync altera o servidor.
if [[ "$DRY" == no ]] && command -v atuin >/dev/null 2>&1; then
  atuin sync >/dev/null 2>&1 || note "atuin sync falhou — seguindo (histórico fica local)"
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

# O fetch vem ANTES de decidir se há trabalho, e não junto do push.
#
# Ter o que commitar e ter o que publicar são coisas diferentes: um commit feito
# à mão deixa a árvore limpa e o remoto desatualizado ao mesmo tempo. A versão
# anterior olhava só a árvore e saía dizendo "o repositório já reflete esta
# máquina" — afirmação que ela não tinha como fazer, porque nem havia consultado
# o remoto. O commit ficava para trás em silêncio (#31).
#
# Falhar aqui não aborta: sem rede, ou com o SSH ainda por configurar, ainda dá
# para commitar. A conta de pendentes sai da referência em cache, que pode estar
# velha — e é por isso que o aviso diz isso em vez de fingir precisão.
step "consultando origin/$BRANCH"
if git fetch --quiet origin "$BRANCH" 2>/dev/null; then
  ok "atualizado"
else
  note "não consegui falar com o remoto — seguindo com o que está em cache"
fi

pendentes=$(git rev-list --count "origin/$BRANCH..HEAD" 2>/dev/null || echo 0)

if [[ ${#levar[@]} -eq 0 && "$pendentes" -eq 0 ]]; then
  printf '\n'
  ok "nada a fazer — nenhuma alteração aqui, nenhum commit por publicar"
  exit 0
fi

if [[ ${#levar[@]} -eq 0 ]]; then
  printf '\n'
  note "nenhum arquivo alterado, mas há $pendentes commit(s) daqui ainda fora do remoto:"
  git --no-pager log --oneline "origin/$BRANCH..HEAD" | sed 's/^/      /'
else
  printf '\n'
  printf '    %s\n' "${levar[@]}"
  printf '\n'
  # --stat sobre os rastreados; os novos não aparecem no diff e já foram listados
  # acima pelo nome.
  git --no-pager diff --stat -- "${levar[@]}" | sed 's/^/    /' || true
  printf '\n'
  git --no-pager diff -- "${levar[@]}" | sed 's/^/    /' || true

  if [[ "$pendentes" -gt 0 ]]; then
    printf '\n'
    note "e $pendentes commit(s) anterior(es) que também vão junto:"
    git --no-pager log --oneline "origin/$BRANCH..HEAD" | sed 's/^/      /'
  fi
fi

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
    # Nada é desfeito: o que foi exportado continua no disco e os commits que
    # já existiam continuam onde estavam. Cancelar aqui só não publica.
    *) note "cancelado — nada foi commitado nem publicado"; exit 0 ;;
  esac
fi

# --- 5. commitar ------------------------------------------------------
# Só quando há arquivo alterado. Com a árvore limpa e commits pendentes, o
# trabalho já está commitado e só falta publicá-lo — forçar um commit aqui
# criaria um vazio.
if [[ ${#levar[@]} -gt 0 ]]; then
  HOST="$(hostname)"
  [[ -n "$MSG" ]] || MSG="config: ajustes feitos em $HOST"

  step "commitando"

  # `--only` com os caminhos, e não `git commit` seco.
  #
  # Sem isso o commit leva o INDEX INTEIRO, e o index nunca está limpo aqui: o
  # nupdate faz `git add -f machines/$HOST` toda vez (update.sh:121), porque
  # flakes só leem arquivos rastreados. O resultado foi um commit publicando o
  # diretório da máquina — que este mesmo script tinha acabado de listar como
  # "não publicado" (#33). O filtro valia para a tela e não para o git, que é o
  # pior lugar para uma mensagem estar errada.
  #
  # Com `--only`, o que ficou de fora continua staged e intacto.
  git add -- "${levar[@]}"
  git commit -q --only -m "$MSG" -- "${levar[@]}"
  ok "$(git --no-pager log --oneline -1)"
fi

# --- 6. publicar ------------------------------------------------------
step "publicando em origin/$BRANCH"

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
