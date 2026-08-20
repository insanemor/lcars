#!/usr/bin/env bash
# =====================================================================
# lcars — atualizar e aplicar
#
#   nupdate              sincroniza com o repositório e aplica
#   nupdate --inputs     também atualiza o nixpkgs (build longo)
#   nupdate --preview    mostra o que mudaria (nix store diff-closures) antes
#                        de aplicar --inputs, e pergunta — implica --inputs
#   nupdate --no-check   pula a avaliação e vai direto ao rebuild
#
# O alias `nupdate` está em user/shell/zsh.nix e aponta para cá.
#
# A sequência:
#   0. sincroniza o histórico do atuin, se ele estiver instalado
#   1. sincroniza ~/.dotfiles com o repositório
#   2. (com --inputs) nix flake update
#   3. avalia os .nix — erro de código aparece em segundos, não no meio do build
#   3.5. (com --preview) constrói sem ativar, mostra o diff-closures contra o
#        sistema rodando, e pergunta; "não" reverte o flake.lock e para aqui
#   4. renomeia .hm-bak que colidiriam com a ativação do home-manager (#37)
#   5. nixos-rebuild switch
#   6. autentica o atuin, se ainda não houver sessão — aqui, e não num módulo,
#      porque só este script roda na sua sessão (veja o bloco no fim)
#
# SOBRE CONFLITOS: o repositório sempre vence, mas só quando ele tem
# histórico novo de verdade. Se `origin/main` for ancestral do HEAD local —
# main local igual ou à FRENTE, o caso comum aqui, já que este script nunca dá
# push — a sincronização inteira é pulada: sem stash, sem reset. Uma entrega
# que a skill `entrega` já mergeou em main, e que ainda não foi publicada,
# fica intacta até você decidir subir. Sem esta checagem o reset --hard trata
# esse merge como lixo remoto e o joga pro reflog — foi o que aconteceu na
# #69, com o merge da #67.
#
# Só quando origin TEM histórico novo é que "o repositório sempre vence" entra
# em ação: se você editou um arquivo que também mudou lá, a sua versão é
# descartada — sem perguntar, sem parar. É uma escolha deliberada, para o
# comando poder rodar sem exigir atenção.
#
# Nada é perdido de forma irrecuperável: o que estava fora do commit vai para
# um `git stash` nomeado, e commits locais que forem descartados continuam no
# `git reflog`. Os dois são rede de segurança, não confirmação — o comando
# segue sem esperar você olhar.
#
# machines/<host>/ é preservado sempre. Esse diretório não existe no
# repositório — é a configuração desta máquina, e sincronizar não pode
# levá-lo junto.
# =====================================================================

set -euo pipefail

REPO="${LCARS_REPO_DIR:-$HOME/.dotfiles}"
BRANCH="main"

INPUTS=no
PREVIEW=no
CHECK=yes
for arg in "$@"; do
  case "$arg" in
    --inputs)   INPUTS=yes ;;
    --preview)  PREVIEW=yes; INPUTS=yes ;;
    --no-check) CHECK=no ;;
    -h|--help)  sed -n '2,35p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) printf 'opção desconhecida: %s (use --help)\n' "$arg" >&2; exit 2 ;;
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

# O histórico de comandos sobe antes de mexer no sistema.
#
# Não é resgate de desastre: o banco do atuin fica em ~/.local/share/atuin, fora
# do store, e o rebuild não encosta nele. É só fechar a janela entre o último
# `auto_sync` (de 5 em 5 minutos, e só quando um comando roda) e agora.
#
# Silencioso quando dá certo, e incapaz de parar o script: sem atuin instalado,
# sem login ou sem rede, o `|| true` segue em frente. `set -e` está ligado.
sync_historico() {
  command -v atuin >/dev/null 2>&1 || return 0
  atuin sync >/dev/null 2>&1 || note "atuin sync falhou — seguindo (histórico fica local)"
}

sync_historico

# O alvo do rebuild é o nome do diretório em machines/, e networking.hostName
# recebe esse mesmo nome (flake.nix) — então o hostname da máquina é o alvo.
HOST="$(hostname)"
[[ -d "machines/$HOST" ]] \
  || die "não existe machines/$HOST — confira 'ls machines/' e o hostname desta máquina"

# --- 1. sincronizar ---------------------------------------------------
step "sincronizando $REPO com o repositório"

# Versões anteriores deste script rodavam `sudo nixos-rebuild`, e o Nix como
# root escrevia em .git/objects — deixando objetos com dono root dentro de um
# repositório seu. O sintoma só aparece depois, num fetch que precise escrever:
#
#   error: insufficient permission for adding an object to repository database
#
# Detectamos antes para a mensagem fazer sentido. Não corrigimos sozinhos: um
# `chown -R` recursivo é invasivo demais para um comando que roda sem pedir
# confirmação.
if find .git -maxdepth 3 ! -user "$(id -un)" -print -quit 2>/dev/null | grep -q .; then
  printf '\n'
  die "há arquivos do root dentro de $REPO/.git — o git não consegue escrever.
    Isso é resíduo de versões antigas deste script, que rodavam o rebuild
    como root. Uma vez só, rode:

        sudo chown -R \"\$USER\" $REPO

    e chame o nupdate de novo."
fi

git fetch --quiet origin "$BRANCH"

antes="$(git rev-parse HEAD)"
depois="$(git rev-parse "origin/$BRANCH")"

# Local pode estar igual ou à FRENTE de origin sem que haja conflito nenhum:
# é o estado normal deste repo entre uma entrega mergeada e o próximo push.
# Só vale resetar quando origin de fato trouxe histórico que o local não tem.
if [[ "$antes" == "$depois" ]] || git merge-base --is-ancestor "$depois" "$antes"; then
  precisa_reset=no
else
  precisa_reset=yes
fi

if [[ "$precisa_reset" == yes ]]; then
  # O diretório desta máquina sai do git ANTES de qualquer operação.
  #
  # Fora do git de propósito: ele pode estar commitado localmente, no index,
  # ou só no disco, e o `reset --hard` abaixo o levaria em qualquer um dos
  # casos. Depender de stash aqui seria frágil — se você tiver commitado a
  # configuração da máquina, não há nada para stashear, e o diretório sumiria
  # sem rede.
  guardado="$(mktemp -d)"
  trap 'rm -rf "$guardado"' EXIT
  cp -a "machines/$HOST" "$guardado/"

  if [[ -n "$(git status --porcelain)" ]]; then
    # `-u` inclui os não rastreados: sem ele o stash não os leva e o reset os
    # apagaria sem deixar cópia.
    git stash push -u -q -m "nupdate $(date +%F-%H%M)" || true
    note "edições locais guardadas — recupere com 'git stash list' / 'git stash pop'"
  fi

  # reset --hard, e não merge: é o que "o repositório sempre vence" significa
  # quando origin de fato tem histórico novo. Nunca conflita, nunca para.
  # Commits locais descartados ficam no reflog.
  if ! git merge-base --is-ancestor "$antes" "$depois"; then
    note "havia commits locais nesta máquina — descartados, mas veja 'git reflog'"
  fi
  git reset --hard --quiet "origin/$BRANCH"

  # Devolve o diretório da máquina, e o registra no index: o
  # hardware-configuration.nix está no .gitignore, e um flake em repo git só lê
  # arquivos rastreados.
  rm -rf "machines/$HOST"
  cp -a "$guardado/$HOST" machines/
  git add -f "machines/$HOST" >/dev/null
fi

if [[ "$antes" == "$depois" ]]; then
  ok "já estava atualizado"
elif [[ "$precisa_reset" == no ]]; then
  ok "main local está à frente de origin/$BRANCH — nada publicado para trazer, seguindo com o que já está aqui"
else
  git --no-pager log --oneline "$antes..$depois" 2>/dev/null | sed 's/^/    /' \
    || ok "sincronizado com origin/$BRANCH"
fi

# --- 2. inputs (opcional) --------------------------------------------
if [[ "$INPUTS" == "yes" ]]; then
  step "atualizando os inputs do flake (nixpkgs, home-manager…)"
  note "isto costuma render um build longo"
  nix --extra-experimental-features 'nix-command flakes' flake update
fi

# --- 3. avaliar -------------------------------------------------------
# Barato e vale a pena: erro de option ou de módulo aparece aqui em segundos,
# em vez de derrubar o rebuild depois de meio sistema compilado.
#
# `--eval`, e não o check inteiro: formato e anti-padrões não são motivo para
# recusar um rebuild.
if [[ "$CHECK" == "yes" && -x ./scripts/check.sh ]]; then
  step "avaliando os .nix antes de aplicar"
  if ! ./scripts/check.sh --eval; then
    die "a avaliação falhou — rebuild NÃO executado."
  fi
fi

# --- 3.5. prévia (opcional) --------------------------------------------
# `nix build` sem `--elevate`/`switch`: só constrói, não ativa nada — é lido,
# não escrito, então não tem o problema de `.git/objects` com dono root que
# o comentário do passo 5 explica.
#
# `diff-closures` compara duas gerações já construídas, pacote por pacote,
# com a diferença de versão e de tamanho. Testado ao vivo antes de entrar
# aqui: com `/run/current-system` (o que está rodando) contra o build novo,
# a saída já é a lista que se quer ver antes de decidir.
#
# Responder não à pergunta reverte só o `flake.lock` — nenhum outro arquivo
# foi tocado até aqui, e o build que ficou no store não atrapalha ninguém,
# só ocupa espaço até o próximo garbage collect.
if [[ "$PREVIEW" == "yes" ]]; then
  step "construindo a nova geração para comparar (sem aplicar ainda)"
  novo="$(nix --extra-experimental-features 'nix-command flakes' build \
    ".#nixosConfigurations.$HOST.config.system.build.toplevel" --no-link --print-out-paths)"

  step "o que mudaria"
  nix --extra-experimental-features 'nix-command flakes' store diff-closures \
    /run/current-system "$novo" || note "diff-closures não achou o que comparar"

  printf '\n'
  resposta=""
  read -r -p "Aplicar essas mudanças? [y/N] " resposta || resposta="n"
  if [[ ! "$resposta" =~ ^[Yy]$ ]]; then
    git checkout -- flake.lock
    note "flake.lock revertido — nada foi aplicado."
    exit 0
  fi
fi

# --- 4. renomear backups do home-manager que colidiriam -------------------
# flake.nix define `backupFileExtension = "hm-bak"`: quando o home-manager
# encontra um arquivo que ele não criou no caminho de um que quer escrever,
# guarda o original como `<nome>.hm-bak` em vez de abortar. O problema
# aparece na SEGUNDA colisão do mesmo arquivo — o home-manager se recusa a
# sobrescrever um `.hm-bak` que já existe, e falha assim:
#
#   Existing file '/home/ins/.config/niri/config.kdl.hm-bak' would be
#   clobbered by backing up '/home/ins/.config/niri/config.kdl'
#
# e nesse ponto o `nixos-rebuild switch` já trocou o sistema — só a ativação
# do usuário falhou. O sintoma aparece longe da causa: atalhos que não
# funcionam, tema que não mudou, sem nenhuma pista de que o culpado é um
# arquivo de backup esquecido (#37).
#
# Renomeia com timestamp em vez de apagar — o ponto de um backup é poder
# olhar depois, e um `.hm-bak` de ontem continua legível ao lado do de hoje.
# `.cache` fica de fora da busca: é a pasta mais pesada de $HOME e o
# home-manager nunca escreve lá.
renomeia_hm_bak() {
  local achou=no f ts novo
  while IFS= read -r -d '' f; do
    achou=yes
    ts="$(date +%F-%H%M%S)"
    novo="${f}.${ts}"
    [[ -e "$novo" ]] && novo="${novo}.$$"
    mv "$f" "$novo"
    note "backup antigo renomeado: $f → $novo"
  done < <(find "$HOME" -path "$HOME/.cache" -prune -o -name '*.hm-bak' -print0 2>/dev/null)
  if [[ "$achou" == yes ]]; then
    note "nomes liberados — a ativação não deve mais recusar o backup"
  fi
}

step "verificando backups antigos do home-manager"
renomeia_hm_bak

# --- 5. aplicar -------------------------------------------------------
# NÃO use `sudo nixos-rebuild`. Um flake git+file:// faz o Nix ler a árvore
# pelo git, e sob sudo quem faz isso é o root — que escreve em .git/objects e
# deixa os objetos com dono dele. Enquanto só há leitura ninguém nota; no
# primeiro `git fetch` que traga objetos novos, o git para com
# "insufficient permission for adding an object to repository database".
#
# `--elevate=sudo` inverte: a avaliação e o build rodam como você, e o root só
# entra na ativação, que não toca no repositório. O nome antigo
# (--use-remote-sudo) ainda funciona e serve de reserva em versões mais velhas.
step "nixos-rebuild switch --flake .#$HOST"
if nixos-rebuild --help 2>&1 | grep -q -- --elevate; then
  nixos-rebuild switch --flake ".#$HOST" --elevate=sudo
else
  nixos-rebuild switch --flake ".#$HOST" --use-remote-sudo
fi

# --- 6. atuin: autenticar, se ainda não estiver -----------------------
# POR QUE ISTO ESTÁ AQUI, E NÃO NUM MÓDULO
# ----------------------------------------
# Porque este script roda no SEU terminal, e a ativação do home-manager não.
#
# O login do atuin morou em `home.activation.atuinLogin` da #48 à #57, e nunca
# funcionou: aquilo roda na unit `home-manager-<user>.service`, que não tem a
# sua sessão gráfica — nem as variáveis, nem o socket, nem alguém para
# autorizar o popup que o 1Password mostra ao liberar o CLI. O journal só dizia
# "sem login no 1Password", com o `op` presente e funcionando no terminal ao
# lado. Não era configuração: era o contexto do processo.
#
# Aqui é diferente. Quem chamou o nupdate foi você, com sessão aberta e o
# 1Password destravado — o popup aparece e você clica. Uma vez por máquina; nas
# vezes seguintes, `atuin status` responde e este bloco não faz nada.
#
# Nada abaixo pode mudar o resultado do nupdate. O sistema já foi construído e
# ativado; um login que não deu certo não invalida um rebuild que deu.
autentica_atuin() {
  command -v atuin >/dev/null 2>&1 || return 0
  atuin status >/dev/null 2>&1 && return 0   # já logado nesta máquina

  # O `op` do wrapper primeiro — é o setgid do grupo `onepassword-cli`, o único
  # que o aplicativo aceita. Mesma ordem de user/shell/atuin.nix (#56).
  local op="" candidato
  for candidato in /run/wrappers/bin/op "$(command -v op 2>/dev/null || true)"; do
    if [[ -n "$candidato" && -x "$candidato" ]]; then
      op="$candidato"
      break
    fi
  done
  if [[ -z "$op" ]]; then
    note "atuin sem login, e o 'op' não foi encontrado — histórico fica local"
    return 0
  fi

  # O vault sai do settings.nix, para não haver um segundo lugar onde o nome
  # possa divergir — foi assim que a #50 aconteceu.
  local vault
  vault="$(grep -oP 'vault = "\K[^"]+' settings.nix 2>/dev/null || true)"
  if [[ -z "$vault" ]]; then
    note "não achei o vault em settings.nix — pulando o login do atuin"
    return 0
  fi

  step "autenticando o atuin (o 1Password pode pedir autorização)"

  # O stderr do `op` é guardado: é ele quem sabe o que houve. A mensagem
  # genérica de "não consegui ler" já mandou conferir o lugar errado uma vez
  # (#50), e não vai mandar de novo.
  local tmp erro=""
  tmp="$(mktemp -d)"
  local u p k
  u="$("$op" read "op://$vault/atuin/username" 2>>"$tmp/erro" || true)"
  p="$("$op" read "op://$vault/atuin/password" 2>>"$tmp/erro" || true)"
  k="$("$op" read "op://$vault/atuin/key" 2>>"$tmp/erro" || true)"
  [[ -s "$tmp/erro" ]] && erro="$(head -1 "$tmp/erro")"
  rm -rf "$tmp"

  if [[ -z "$u" || -z "$p" || -z "$k" ]]; then
    note "não consegui ler op://$vault/atuin — histórico fica local"
    [[ -n "$erro" ]] && note "  op disse: $erro"
    return 0
  fi

  # A senha vai no argv porque `atuin login` não a lê de outro jeito — nem
  # stdin, nem variável de ambiente (conferido no --help da 18.18.1). Fica
  # visível no `ps` desta máquina enquanto o comando roda, por volta de um
  # segundo, uma vez por máquina.
  if atuin login -u "$u" -p "$p" -k "$k" >/dev/null 2>&1; then
    ok "atuin autenticado — o histórico desta máquina passa a sincronizar"
    atuin sync >/dev/null 2>&1 || true
  else
    note "'atuin login' falhou (senha, chave ou servidor) — histórico fica local"
  fi
}

autentica_atuin

printf '\n'
ok "pronto — $HOST atualizada"
