#!/usr/bin/env bash
# =====================================================================
# lcars — verificação dos arquivos .nix
#
#   ./scripts/check.sh            verifica tudo
#   ./scripts/check.sh --fmt      só formato e anti-padrões (rápido)
#   ./scripts/check.sh --eval     só a avaliação (é o que o nupdate usa)
#   ./scripts/check.sh --fix      corrige formato e anti-padrões no lugar
#
# Usa o `nix` da máquina quando ele existe; senão, um container `nixos/nix`
# com o store num volume Docker. Nos dois casos nada é instalado, e a sua
# árvore de trabalho não é tocada.
#
# O que ele faz, em ordem de custo:
#
#   formato       nixfmt --check             reprova
#   anti-padrões  statix check               reprova
#   avaliação     nix eval                   reprova
#   código morto  deadnix                    informativo
#
# A avaliação é o que pega erro de verdade — nome de option que não existe,
# atributo mal aninhado, módulo que não avalia. Ela para no drvPath: nenhum
# pacote é compilado. Isto é um check de código, não uma prova de que o
# sistema sobe.
#
# Primeira execução baixa o nixpkgs (~250MB no volume); as seguintes levam
# poucos segundos.
# =====================================================================

set -euo pipefail

IMAGE="nixos/nix:latest"
VOLUME="lcars-nix-store"
# Array, não string: a lista precisa se dividir em palavras ao virar
# argumentos do `nix shell`, e aspas em volta de uma string impediriam isso.
TOOLS=(nixpkgs#nixfmt nixpkgs#statix nixpkgs#deadnix)
# nixfmt deprecou receber diretório, então os arquivos vão um a um pelo find.
# As aspas ficam escapadas: isto é expandido só dentro do container.
FIND_NIX="find . -name \"*.nix\" -not -path \"./.git/*\""

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MODE="all"
case "${1:-}" in
  --fmt)  MODE="fmt" ;;
  --fix)  MODE="fix" ;;
  --eval) MODE="eval" ;;
  "")     ;;
  *)      printf 'uso: %s [--fmt|--fix|--eval]\n' "$0" >&2; exit 2 ;;
esac

bold=$'\033[1m'; red=$'\033[1;31m'; green=$'\033[1;32m'
yellow=$'\033[1;33m'; blue=$'\033[1;34m'; off=$'\033[0m'

step() { printf '\n%s══ %s%s\n' "$blue" "$*" "$off"; }
ok()   { printf '%s  ✓ %s%s\n' "$green" "$*" "$off"; }
bad()  { printf '%s  ✗ %s%s\n' "$red" "$*" "$off"; }
note() { printf '%s  · %s%s\n' "$yellow" "$*" "$off"; }

# --- onde rodar --------------------------------------------------------
# Com `nix` na máquina, usamos ele direto: é mais rápido e não precisa de
# container. O Docker existe porque a máquina de desenvolvimento é Garuda, sem
# nix — mas numa NixOS (o alvo deste repo) o nix está ali, e exigir Docker
# tornaria o check inútil justamente onde ele é mais útil.
if command -v nix >/dev/null 2>&1; then
  RUNNER=nix
elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  RUNNER=docker
else
  bad "preciso de 'nix' ou de um Docker funcionando para avaliar os .nix"
  note "nix:    https://nixos.org/download"
  note "docker: o daemon precisa estar de pé e acessível sem sudo"
  exit 1
fi

# --- área de trabalho -------------------------------------------------
# Uma CÓPIA do repo, para não sujar a sua árvore: a avaliação precisa de uma
# máquina em machines/ e de tudo no index do git, e nada disso deve sobrar.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# `git archive HEAD` levaria só o commitado, e o normal é você querer checar o
# que está editando agora. Copiamos a árvore de trabalho, menos o .git.
tar -c -C "$REPO_ROOT" --exclude=.git --exclude=result . | tar -x -C "$WORK"

# --- máquina descartável ----------------------------------------------
# machines/template é ignorado pela auto-descoberta (veja flake.nix), então
# sem isto não há nixosConfiguration nenhum para avaliar.
cp -r "$WORK/machines/template" "$WORK/machines/checkhost"

# O hardware-configuration.nix do template é um placeholder vazio, e o NixOS
# tem uma assertion exigindo raiz declarada: sem isto toda avaliação morre em
# "The 'fileSystems' option does not specify your root file system", que é
# ruído do check e não defeito do repo. Um disco fictício basta — nada aqui é
# montado, só avaliado.
cat > "$WORK/machines/checkhost/hardware-configuration.nix" <<'HWEOF'
# Gerado por scripts/check.sh para a máquina descartável de avaliação.
{ ... }:
{
  fileSystems."/" = {
    device = "/dev/disk/by-label/check-root";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/check-boot";
    fsType = "vfat";
  };
  boot.loader.grub.device = "/dev/sda";
  system.stateVersion = "24.05";
}
HWEOF

# Flakes só leem arquivos rastreados. O repo temporário é descartável, então
# aqui commitar é o caminho mais simples — e o -f passa por cima do .gitignore.
git -C "$WORK" init -q
git -C "$WORK" add -A -f >/dev/null
git -C "$WORK" -c user.email=check@lcars -c user.name=check commit -qm check

# Roda um comando com as ferramentas disponíveis, dentro da cópia do repo.
#
# NIX_CONFIG em vez de --extra-experimental-features: a flag carrega aspas
# simples, que colidiriam com as aspas em que o comando é embutido aqui.
run_tools() {
  if [[ "$RUNNER" == "nix" ]]; then
    ( cd "$WORK" \
      && NIX_CONFIG="experimental-features = nix-command flakes" \
         nix shell "${TOOLS[@]}" -c sh -c "$1" )
  else
    # Um só `docker run` por chamada: subir o container é o que custa, não os
    # comandos. O gitconfig evita "repository path is not owned by current
    # user", já que o container roda como root sobre um diretório seu.
    docker run --rm \
      -v "$VOLUME:/nix" \
      -v "$WORK:/repo" \
      -w /repo \
      -e NIX_CONFIG="experimental-features = nix-command flakes" \
      "$IMAGE" \
      sh -c "printf '[safe]\n\tdirectory = /repo\n' > /root/.gitconfig
             nix shell ${TOOLS[*]} -c sh -c '$1'"
  fi
}

[[ "$RUNNER" == "docker" ]] && docker volume create "$VOLUME" >/dev/null

printf '%slcars — verificando %s arquivos .nix (via %s)%s\n' \
  "$bold" "$(find "$WORK" -name '*.nix' | wc -l)" "$RUNNER" "$off"

# --- --fix: reformata e sai -------------------------------------------
if [[ "$MODE" == "fix" ]]; then
  step "reformatando"
  # statix antes do nixfmt: ele reescreve expressões (assignment -> inherit) e
  # deixa a formatação do trecho novo por conta do nixfmt, que roda depois.
  run_tools 'statix fix .' || { bad "statix fix falhou"; exit 1; }
  run_tools "$FIND_NIX -exec nixfmt {} +" || { bad "nixfmt falhou"; exit 1; }
  # Traz de volta só os .nix, um a um: o WORK tem um .git nosso e a máquina
  # descartável, que não podem vazar para o repo.
  changed=0
  while IFS= read -r f; do
    rel="${f#"$WORK"/}"
    [[ "$rel" == machines/checkhost/* ]] && continue
    if ! cmp -s "$f" "$REPO_ROOT/$rel"; then
      cp "$f" "$REPO_ROOT/$rel"; printf '  reformatado: %s\n' "$rel"; changed=1
    fi
  done < <(find "$WORK" -name '*.nix' -not -path '*/.git/*')
  if [[ "$changed" -eq 0 ]]; then
    ok "nada a reformatar"
  else
    note "revise com 'git diff'"
  fi
  exit 0
fi

falhas=0

# --- 1. formato -------------------------------------------------------
# `--eval` pula formato e anti-padrões: quem chama assim quer saber se o código
# avalia, não se está bem-arrumado. É o caso do nupdate, onde reprovar um
# rebuild por causa de indentação seria absurdo.
if [[ "$MODE" != "eval" ]]; then
step "formato (nixfmt)"
if out="$(run_tools "$FIND_NIX -exec nixfmt --check {} + 2>&1" 2>&1)"; then
  ok "formatação consistente"
else
  bad "arquivos fora do padrão:"
  printf '%s\n' "$out" | sed 's/^/    /' | head -30
  note "corrija com: ./scripts/check.sh --fix"
  falhas=$((falhas + 1))
fi

# --- 2. anti-padrões --------------------------------------------------
step "anti-padrões (statix)"
if out="$(run_tools 'statix check . 2>&1' 2>&1)"; then
  ok "nenhum anti-padrão"
else
  bad "apontamentos:"
  # statix cospe ANSI pesado; sem isto a saída fica ilegível num log.
  printf '%s\n' "$out" | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'Warning|╭─\[' \
    | sed 's/^/    /' | head -30
  falhas=$((falhas + 1))
fi

if [[ "$MODE" == "fmt" ]]; then
  printf '\n%s--fmt: parando antes da avaliação%s\n' "$yellow" "$off"
  exit "$((falhas > 0 ? 1 : 0))"
fi
fi  # fim do bloco pulado por --eval

# --- 3. avaliação -----------------------------------------------------
# O que pega erro de verdade. Os dois profiles, porque cada um liga um
# conjunto diferente de módulos e o erro pode estar só num deles.
for profile in basic personal; do
  step "avaliação — profile $profile"
  sed -i "s/^\( *profile *= *\)\"[^\"]*\";/\1\"$profile\";/" "$WORK/settings.nix"
  git -C "$WORK" add -A -f >/dev/null
  git -C "$WORK" -c user.email=check@lcars -c user.name=check commit -qm "$profile" --allow-empty

  if out="$(run_tools "nix eval .#nixosConfigurations.checkhost.config.system.build.toplevel.drvPath 2>&1" 2>&1)"; then
    ok "avalia"
  else
    bad "erro de avaliação:"
    # O Nix põe a causa real no FIM do stack trace: as primeiras linhas
    # 'error:' são só o encadeamento de "while evaluating…". Guardamos a
    # última e imprimimos dali em diante; o resto é caminho de /nix/store.
    printf '%s\n' "$out" | sed 's/\x1b\[[0-9;]*m//g' \
      | awk '/^ *error:/ { ini = NR } { l[NR] = $0 }
             END { for (i = (ini ? ini : 1); i <= NR; i++) print l[i] }' \
      | sed 's/^/    /' | head -20
    falhas=$((falhas + 1))
  fi
done

# --- 4. código morto (informativo) ------------------------------------
if [[ "$MODE" != "eval" ]]; then
# Não reprova: módulos NixOS convencionalmente recebem { config, lib, pkgs,
# ... } mesmo sem usar tudo, e isso é idioma da linguagem, não defeito.
step "código morto (deadnix) — informativo"
if out="$(run_tools 'deadnix --fail . 2>&1' 2>&1)"; then
  ok "nada não usado"
else
  printf '%s\n' "$out" | sed 's/\x1b\[[0-9;]*m//g' | grep -E '╭─\[|Unused' \
    | sed 's/^/    /' | head -20
  note "informativo — não reprova o check"
fi
fi  # fim do bloco pulado por --eval

# --- veredito ---------------------------------------------------------
printf '\n'
if [[ "$falhas" -eq 0 ]]; then
  printf '%s✓ tudo certo%s\n' "$green" "$off"
  exit 0
fi
printf '%s✗ %d etapa(s) reprovada(s)%s\n' "$red" "$falhas" "$off"
exit 1
