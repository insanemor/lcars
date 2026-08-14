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
#   3. gera settings.nix com defaults derivados da máquina e ABRE NO EDITOR
#      para você revisar (pule com LCARS_EDIT=no);
#   4. aplica o que ficou no settings.nix e gera machines/<host>/ com o
#      hardware-configuration.nix real;
#   5. registra tudo no index do git — flakes só enxergam arquivos rastreados;
#   6. roda `nixos-rebuild switch --flake .#<host>`.
#
# Variáveis reconhecidas no ambiente:
#   LCARS_HOST     nome do host (default: hostname -s)
#   LCARS_REPO     repo (default: github.com/insanemor/lcars)
#   LCARS_BRANCH   branch (default: main)
#   LCARS_DEST     onde clonar (default: ~/lcars do usuário alvo)
#   LCARS_USER     usuário Linux a configurar (default: SUDO_USER, senão $USER)
#   LCARS_PROFILE  "auto" (default), ou o nome de um diretório de profiles/
#                  ("basic" headless, "personal" desktop). "auto" usa basic em VM.
#   LCARS_ACTION   "switch" (default), "boot", "test", "dry-activate", "none"
#   LCARS_EDIT     "no" pula a abertura do editor
#   LCARS_EDITOR   editor a usar (default: o do settings.nix, senão nano/vim/vi)
#   LCARS_FORCE    "yes" reescreve settings.nix e machines/<host> existentes
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
  # machines/<host>/. Atualizar é opt-in e só por fast-forward.
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
blocked=$(git diff --cached --name-only | grep -E '^(settings\.nix|machines/.+/hardware-configuration\.nix)$' || true)
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
# Tudo aqui vira apenas o VALOR INICIAL do settings.nix. Quem manda no fim é
# o que estiver no arquivo depois que você o editar.
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
  BOOTMODE="uefi"
  GRUB_DEVICE=""
else
  BOOTMODE="bios"
  ROOT_SRC="$(findmnt -no SOURCE / 2>/dev/null || true)"
  PK="$(lsblk -no PKNAME "$ROOT_SRC" 2>/dev/null | head -1 || true)"
  GRUB_DEVICE="${PK:+/dev/$PK}"
  [[ -n "$GRUB_DEVICE" ]] \
    || warn "BIOS legado, mas não achei o disco de boot. preencha grubDevice no settings.nix."
fi

case "$PROFILE" in
  auto) if [[ "$IS_VM" == true ]]; then PROFILE="basic"; else PROFILE="personal"; fi ;;
esac
[[ -d "$DEST/profiles/$PROFILE" ]] \
  || die "profile '$PROFILE' não existe em profiles/ (opções: $(cd "$DEST/profiles" && ls -d */ 2>/dev/null | tr -d / | tr '\n' ' '))"

log "detectado: host=$HOST profile=$PROFILE vm=$IS_VM laptop=$IS_LAPTOP boot=$BOOTMODE"

# --- 4. settings.nix --------------------------------------------------
# Este é o único arquivo que o operador precisa editar.
if [[ -f settings.nix && "${LCARS_FORCE:-no}" != "yes" ]]; then
  log "settings.nix já existe — mantendo (LCARS_FORCE=yes para recriar)"
else
  log "gerando settings.nix com os valores detectados"
  run_as_user env \
    LCARS_ROOT="$DEST" \
    LCARS_NONINTERACTIVE=yes \
    LCARS_FORCE="${LCARS_FORCE:-no}" \
    LCARS_USERNAME="$TARGET_USER" \
    LCARS_HOST="$HOST" \
    LCARS_PROFILE="$PROFILE" \
    LCARS_BOOTMODE="$BOOTMODE" \
    LCARS_GRUBDEV="$GRUB_DEVICE" \
    bash ./scripts/bootstrap.sh
fi

# --- 4b. revisão pelo operador ---------------------------------------
# Um pipe `curl | bash` ocupa o stdin, então não há terminal em $0. Mas /dev/tty
# continua apontando para o terminal de controle quando existe um — é dele que
# o editor precisa. Sem terminal (CI, cloud-init), seguimos com os defaults.
if [[ "${LCARS_EDIT:-yes}" == "no" ]]; then
  log "LCARS_EDIT=no — aplicando settings.nix sem revisão"
elif [[ -e /dev/tty ]] && (exec </dev/tty >/dev/tty 2>&1) 2>/dev/null; then
  EDITOR_CMD="${LCARS_EDITOR:-${EDITOR:-}}"
  if [[ -z "$EDITOR_CMD" ]]; then
    # O editor pedido no próprio settings.nix, se já estiver instalado.
    WANT="$(sed -n 's/^[[:space:]]*editor[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' settings.nix | head -1)"
    for c in "$WANT" nano vim vi; do
      [[ -n "$c" ]] && command -v "$c" >/dev/null 2>&1 && { EDITOR_CMD="$c"; break; }
    done
  fi

  if [[ -n "$EDITOR_CMD" ]]; then
    log "abrindo settings.nix em '$EDITOR_CMD' — salve e feche para continuar"
    run_as_user "$EDITOR_CMD" "$DEST/settings.nix" </dev/tty >/dev/tty 2>&1 \
      || warn "editor saiu com erro; seguindo com o arquivo como está"
  else
    warn "nenhum editor encontrado — seguindo com os valores detectados"
  fi
else
  log "sem terminal disponível — aplicando os valores detectados"
  log "  para revisar antes: rode com LCARS_ACTION=none e edite $DEST/settings.nix"
fi

# --- 5. o que o operador decidiu -------------------------------------
# A partir daqui o settings.nix é a autoridade, não a detecção. Se ele trocou
# o hostname, é em machines/<novo>/ que o hardware-config precisa entrar.
read_setting() {
  sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\"\([^\"]*\)\".*/\1/p" settings.nix | head -1
}

FINAL_HOST="$(read_setting hostname)"
FINAL_PROFILE="$(read_setting profile)"
[[ -n "$FINAL_HOST" ]] || die "não consegui ler 'hostname' de settings.nix."
[[ -n "$FINAL_PROFILE" ]] || die "não consegui ler 'profile' de settings.nix."

[[ -d "$DEST/profiles/$FINAL_PROFILE" ]] \
  || die "settings.nix pede o profile '$FINAL_PROFILE', que não existe em profiles/."

if [[ "$FINAL_HOST" != "$HOST" || "$FINAL_PROFILE" != "$PROFILE" ]]; then
  log "settings.nix editado: host=$FINAL_HOST profile=$FINAL_PROFILE"
fi
HOST="$FINAL_HOST"
PROFILE="$FINAL_PROFILE"

# --- 6. machines/<host>/ ---------------------------------------------
# Só o que é da máquina: hardware detectado e o hardware-config real.
# Profile, bootloader e locale vêm do settings.nix.
if [[ -f "machines/$HOST/default.nix" && "${LCARS_FORCE:-no}" != "yes" ]]; then
  log "machines/$HOST/default.nix já existe — mantendo"
else
  log "gerando machines/$HOST/default.nix"
  $SUDO mkdir -p "machines/$HOST"
  $SUDO tee "machines/$HOST/default.nix" >/dev/null <<EOF
# Gerado por scripts/install.sh — ajuste à vontade, não será sobrescrito
# (a menos que você rode o instalador com LCARS_FORCE=yes).
#
# Profile, bootloader, locale e identidade vêm do settings.nix na raiz.
# Aqui fica só o que é desta máquina.
{ config, lib, pkgs, sys, user, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Detectado na instalação.
  lcars.hardware.vm.enable     = $IS_VM;
  lcars.hardware.laptop.enable = $IS_LAPTOP;

  # O settings.nix é aplicado com mkDefault, então declare aqui o que quiser
  # diferente SÓ nesta máquina:
  #   lcars.profile         = "basic";
  #   lcars.wm.gnome.enable = false;
}
EOF
fi

HW="machines/$HOST/hardware-configuration.nix"
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
    die "nixos-generate-config falhou — não consigo montar machines/$HOST sem o hardware-config."
  fi
fi
$SUDO chown -R "$TARGET_USER" "machines/$HOST" 2>/dev/null || true

# --- 6. tornar visível para o flake ----------------------------------
# Um flake em repo git só lê arquivos rastreados. settings.nix e
# hardware-configuration.nix estão no .gitignore, daí o -f. Isso os põe no
# index, não em um commit — e o hook acima impede o commit acidental.
log "registrando arquivos no index do git"
run_as_user git -C "$DEST" add -f settings.nix "machines/$HOST" >/dev/null

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
log "  máquina:  $HOST  (profile: $PROFILE)"
log "  usuário:  $TARGET_USER (senha inicial: lcars — troque com 'passwd')"
if [[ "$PROFILE" == "personal" ]]; then
  log "  1Password GUI instalado: abra '1password' e ligue o agente SSH em Developer."
fi
