#!/usr/bin/env bash
# =====================================================================
# lcars — instalador one-shot
#
# Uso (um único comando, numa máquina NixOS já bootada):
#
#   curl -fsSL https://raw.githubusercontent.com/insanemor/lcars/main/scripts/install.sh | sudo bash
#
# O que ele faz, sem pedir nada:
#   1. valida que estamos em NixOS e habilita flakes só para esta execução;
#   2. clona (ou atualiza) o repo;
#   3. gera vars/local.nix com defaults derivados da máquina;
#   4. gera hosts/<host>/ com hardware-configuration.nix real e os módulos
#      lcars que combinam com o hardware detectado (VM / notebook / UEFI);
#   5. registra tudo no index do git — flakes só enxergam arquivos rastreados;
#   6. roda `nixos-rebuild switch --flake .#<host>`.
#
# Variáveis reconhecidas no ambiente:
#   LCARS_HOST     nome do host (default: hostname -s)
#   LCARS_REPO     repo (default: github.com/insanemor/lcars)
#   LCARS_BRANCH   branch (default: main)
#   LCARS_DEST     onde clonar (default: ~/lcars do usuário alvo)
#   LCARS_USER     usuário Linux a configurar (default: SUDO_USER, senão $USER)
#   LCARS_PROFILE  "auto" (default), "desktop", "minimal"
#   LCARS_ACTION   "switch" (default), "boot", "test", "dry-activate", "none"
#   LCARS_FORCE    "yes" reescreve vars/local.nix e hosts/<host> existentes
#   LCARS_UPDATE   "yes" faz fast-forward do repo se ele já existir
#
# O instalador é idempotente: rodar de novo não sobrescreve nada que você já
# tenha editado, a menos que você peça com LCARS_FORCE=yes.
# =====================================================================

set -euo pipefail

REPO="${LCARS_REPO:-github.com/insanemor/lcars}"
BRANCH="${LCARS_BRANCH:-main}"
PROFILE="${LCARS_PROFILE:-auto}"
ACTION="${LCARS_ACTION:-switch}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!! \033[0m%s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx \033[0m%s\n' "$*" >&2; exit 1; }

# --- 1. ambiente ------------------------------------------------------
[[ -e /etc/NIXOS ]] || grep -q '^ID=nixos' /etc/os-release 2>/dev/null \
  || die "este instalador só roda em NixOS."

SUDO=""
if [[ "$(id -u)" -ne 0 ]]; then
  command -v sudo >/dev/null 2>&1 \
    || die "não sou root e sudo não está disponível. rode como root."
  SUDO="sudo"
fi

# Usuário alvo: quem chamou o sudo, não o root.
TARGET_USER="${LCARS_USER:-${SUDO_USER:-${USER:-}}}"
[[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]] && TARGET_USER="$(
  awk -F: '$3 >= 1000 && $3 < 65534 { print $1; exit }' /etc/passwd
)"
[[ -n "$TARGET_USER" ]] || die "não consegui determinar o usuário alvo. use LCARS_USER=<nome>."
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
[[ -n "$TARGET_HOME" ]] || TARGET_HOME="/home/$TARGET_USER"

DEST="${LCARS_DEST:-$TARGET_HOME/lcars}"

# Flakes só para esta execução — não exige que o sistema atual já os tenha.
# nixos-rebuild repassa NIX_CONFIG para os comandos nix que ele invoca.
export NIX_CONFIG="experimental-features = nix-command flakes"

command -v nix >/dev/null || die "nix não encontrado — isto não parece um NixOS funcional."

# git pode não existir num NixOS minimal. Em vez de mandar o usuário editar
# configuration.nix, reexecutamos este script dentro de um shell efêmero.
if ! command -v git >/dev/null 2>&1; then
  if [[ "${LCARS_GIT_RETRY:-no}" == "yes" ]]; then
    die "git continua indisponível mesmo dentro de 'nix shell'."
  fi
  log "git ausente — reexecutando dentro de 'nix shell nixpkgs#git'"
  SELF="$(mktemp)"; trap 'rm -f "$SELF"' EXIT
  if [[ -f "${BASH_SOURCE[0]}" ]]; then
    cp "${BASH_SOURCE[0]}" "$SELF"
  else
    # Viemos de um pipe (curl | bash): $BASH_SOURCE não é um arquivo. Baixa de novo.
    case "$REPO" in
      github.com/*) RAW="https://raw.githubusercontent.com/${REPO#github.com/}/$BRANCH/scripts/install.sh" ;;
      *) die "git ausente e não sei de onde rebaixar o script para $REPO. instale git e rode de novo." ;;
    esac
    curl -fsSL "$RAW" -o "$SELF" \
      || die "git ausente e não consegui rebaixar o instalador de $RAW."
  fi
  chmod +x "$SELF"
  LCARS_GIT_RETRY=yes exec nix shell nixpkgs#git --command bash "$SELF"
fi

# --- 2. clone ---------------------------------------------------------
# Como root, largamos privilégio para o usuário alvo (senão o repo fica
# root-owned e o usuário não consegue editar nada depois). Quando não somos
# root, já somos ele.
if [[ "$(id -u)" -eq 0 ]]; then
  if command -v runuser >/dev/null 2>&1; then
    run_as_user() { runuser -u "$TARGET_USER" -- "$@"; }
  elif command -v sudo >/dev/null 2>&1; then
    run_as_user() { sudo -u "$TARGET_USER" -- "$@"; }
  else
    die "sou root mas não achei runuser nem sudo para largar privilégio."
  fi
else
  run_as_user() { "$@"; }
fi

if [[ -d "$DEST/.git" ]]; then
  # Nunca damos `reset --hard` aqui: o repo já pode ter edições suas em
  # hosts/<host>/. Atualizar é opt-in e só por fast-forward.
  if [[ "${LCARS_UPDATE:-no}" == "yes" ]]; then
    log "atualizando $DEST (fast-forward)"
    run_as_user git -C "$DEST" fetch origin "$BRANCH"
    run_as_user git -C "$DEST" merge --ff-only "origin/$BRANCH" \
      || warn "fast-forward não foi possível (há trabalho local). seguindo com o que está no disco."
  else
    log "repo já existe em $DEST — usando como está (LCARS_UPDATE=yes para atualizar)"
  fi
else
  log "clonando $REPO ($BRANCH) -> $DEST"
  # Criamos o destino já com o dono certo, em vez de mexer no diretório pai.
  $SUDO mkdir -p "$DEST"
  $SUDO chown "$TARGET_USER" "$DEST"
  case "$REPO" in
    *://*|git@*) URL="$REPO" ;;
    *)           URL="https://$REPO.git" ;;
  esac
  run_as_user git clone --branch="$BRANCH" "$URL" "$DEST"
fi
cd "$DEST"

# O rebuild roda como root sobre um repo que pertence ao usuário. Sem isto, o
# git (e o libgit2 que o Nix usa para ler o flake) aborta com
# "detected dubious ownership in repository".
$SUDO git config --global --add safe.directory "$DEST" 2>/dev/null || true

# Rede de segurança: impede que os arquivos com dados da máquina, que
# precisamos deixar no index para o flake enxergá-los, acabem num commit.
HOOK=".git/hooks/pre-commit"
cat > "$HOOK" <<'HOOKEOF'
#!/usr/bin/env bash
# instalado por scripts/install.sh
blocked=$(git diff --cached --name-only | grep -E '^(vars/local\.nix|hosts/.+/hardware-configuration\.nix)$' || true)
if [[ -n "$blocked" ]]; then
  echo "lcars: estes arquivos têm dados desta máquina e não devem ser commitados:" >&2
  echo "$blocked" | sed 's/^/  /' >&2
  echo "eles precisam ficar no index para o flake enxergá-los — não os remova do index." >&2
  echo "para commitar mesmo assim: git commit --no-verify" >&2
  exit 1
fi
HOOKEOF
chmod +x "$HOOK"
$SUDO chown "$TARGET_USER" "$HOOK" 2>/dev/null || true

# --- 3. detecção de hardware -----------------------------------------
HOST="${LCARS_HOST:-$(hostname -s 2>/dev/null || echo nixos)}"
# hostnames NixOS aceitam só [a-zA-Z0-9-]
HOST="$(printf '%s' "$HOST" | tr -c 'a-zA-Z0-9-' '-' | sed 's/^-*//; s/-*$//')"
[[ -n "$HOST" ]] || HOST="nixos"

IS_VM=false
if command -v systemd-detect-virt >/dev/null && systemd-detect-virt --quiet --vm; then
  IS_VM=true
fi

IS_LAPTOP=false
compgen -G "/sys/class/power_supply/BAT*" >/dev/null && IS_LAPTOP=true

if [[ -d /sys/firmware/efi ]]; then
  BOOTLOADER="systemd-boot"
  GRUB_DEVICE=""
else
  BOOTLOADER="grub"
  ROOT_SRC="$(findmnt -no SOURCE / 2>/dev/null || true)"
  PK="$(lsblk -no PKNAME "$ROOT_SRC" 2>/dev/null | head -1 || true)"
  GRUB_DEVICE="${PK:+/dev/$PK}"
  [[ -n "$GRUB_DEVICE" ]] || die "BIOS legado detectado mas não achei o disco de boot. defina lcars.common.grubDevice à mão em hosts/$HOST/default.nix."
fi

case "$PROFILE" in
  desktop) WANT_DESKTOP=true ;;
  minimal) WANT_DESKTOP=false ;;
  auto)    WANT_DESKTOP=true ;;
  *)       die "LCARS_PROFILE inválido: $PROFILE (use auto, desktop ou minimal)" ;;
esac

log "host=$HOST  vm=$IS_VM  laptop=$IS_LAPTOP  boot=$BOOTLOADER  desktop=$WANT_DESKTOP"

# --- 4. vars/local.nix ------------------------------------------------
if [[ -f vars/local.nix && "${LCARS_FORCE:-no}" != "yes" ]]; then
  log "vars/local.nix já existe — mantendo"
else
  log "gerando vars/local.nix"
  run_as_user env \
    LCARS_ROOT="$DEST" \
    LCARS_NONINTERACTIVE=yes \
    LCARS_FORCE="${LCARS_FORCE:-no}" \
    LCARS_USERNAME="$TARGET_USER" \
    LCARS_HOST="$HOST" \
    bash ./scripts/bootstrap.sh
fi

# --- 5. hosts/<host>/ -------------------------------------------------
if [[ -d "hosts/$HOST" && "${LCARS_FORCE:-no}" != "yes" ]]; then
  log "hosts/$HOST já existe — mantendo"
else
  log "gerando hosts/$HOST/default.nix"
  $SUDO mkdir -p "hosts/$HOST"
  $SUDO tee "hosts/$HOST/default.nix" >/dev/null <<EOF
# Gerado por scripts/install.sh — ajuste à vontade, não será sobrescrito
# (a menos que você rode o instalador com LCARS_FORCE=yes).
{ config, lib, pkgs, vars, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  lcars.common.enable  = true;
  lcars.vm.enable      = $IS_VM;
  lcars.laptop.enable  = $IS_LAPTOP;
  lcars.desktop.enable = $WANT_DESKTOP;

  lcars.common.bootLoader = "$BOOTLOADER";$(
    if [[ -n "$GRUB_DEVICE" ]]; then printf '\n  lcars.common.grubDevice = "%s";' "$GRUB_DEVICE"; fi
  )

  # O sshd deste flake só aceita chave. Adicione as suas aqui:
  # lcars.common.sshKeys = [ "ssh-ed25519 AAAA..." ];
}
EOF
fi

HW="hosts/$HOST/hardware-configuration.nix"
if [[ -f "$HW" && "${LCARS_FORCE:-no}" != "yes" ]]; then
  log "$HW já existe — mantendo"
else
  log "gerando $HW"
  # Gera para um temporário antes de mover: se nixos-generate-config falhar,
  # não ficamos com um hardware-configuration.nix truncado no lugar do bom.
  HW_TMP="$(mktemp)"
  if $SUDO nixos-generate-config --show-hardware-config > "$HW_TMP" && [[ -s "$HW_TMP" ]]; then
    $SUDO cp "$HW_TMP" "$HW"
    rm -f "$HW_TMP"
  else
    rm -f "$HW_TMP"
    die "nixos-generate-config falhou — não consigo montar hosts/$HOST sem o hardware-config."
  fi
fi
$SUDO chown -R "$TARGET_USER" "hosts/$HOST" 2>/dev/null || true

# --- 6. tornar visível para o flake ----------------------------------
# Um flake em repo git só lê arquivos rastreados. vars/local.nix e
# hardware-configuration.nix estão no .gitignore, daí o -f. Isso os põe no
# index, não em um commit — e o hook acima impede o commit acidental.
log "registrando arquivos no index do git"
run_as_user git -C "$DEST" add -f vars/local.nix "hosts/$HOST" >/dev/null

# --- 7. build ---------------------------------------------------------
if [[ "$ACTION" == "none" ]]; then
  log "LCARS_ACTION=none — parando antes do rebuild."
  log "quando quiser: sudo nixos-rebuild switch --flake $DEST#$HOST"
  exit 0
fi

log "nixos-rebuild $ACTION --flake .#$HOST  (a primeira build é longa)"
$SUDO env NIX_CONFIG="$NIX_CONFIG" nixos-rebuild "$ACTION" --flake ".#$HOST"

log "pronto."
log "  repo:     $DEST"
log "  host:     $HOST"
log "  usuário:  $TARGET_USER (senha inicial: lcars — troque com 'passwd')"
if [[ "$WANT_DESKTOP" == true ]]; then
  log "  1Password GUI instalado: abra '1password' e ligue o agente SSH em Developer."
fi
