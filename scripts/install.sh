#!/usr/bin/env bash
# =====================================================================
# lcars — instalador one-shot
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/insanemor/lcars/main/scripts/install.sh | bash
#
# Variáveis reconhecidas no ambiente:
#   LCARS_HOST  — nome do host a registrar (ex.: minha-vm)
#   LCARS_REPO  — URL do repo (default: github.com/insanemor/lcars)
#   LCARS_BRANCH — branch (default: main)
#   LCARS_NIXOS — "yes" para rodar nixos-rebuild após bootstrap
#
# O script:
#   1. Garante que git esteja disponível (instala via apt/pacman/dnf/apk).
#   2. Detecta se Nix / NixOS estão disponíveis.
#   3. clona o repo em ~/lcars (ou caminho passado).
#   4. roda `nix run .#bootstrap` para preencher vars/local.nix.
#   5. opcionalmente ativa uma config NixOS existente.
# =====================================================================

set -euo pipefail

REPO="${LCARS_REPO:-github.com/insanemor/lcars}"
BRANCH="${LCARS_BRANCH:-main}"
DEST="${LCARS_DEST:-$HOME/lcars}"
HOST="${LCARS_HOST:-}"
ACTIVATE="${LCARS_NIXOS:-no}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!! \033[0m%s\n' "$*"; }
die()  { printf '\033[1;31mxx \033[0m%s\n' "$*" >&2; exit 1; }

# `sudo` pode não existir (NixOS minimal já roda como root).
SUDO=""
if [[ "$(id -u)" -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then SUDO="sudo"
  else die "não sou root e sudo não está disponível. rode como root ou instale sudo."
  fi
fi

# --- garantir git ------------------------------------------------------
if ! command -v git >/dev/null 2>&1; then
  warn "git não encontrado — tentando instalar"
  if   command -v apt-get     >/dev/null 2>&1; then $SUDO apt-get update && $SUDO apt-get install -y git
  elif command -v dnf         >/dev/null 2>&1; then $SUDO dnf install -y git
  elif command -v yum         >/dev/null 2>&1; then $SUDO yum install -y git
  elif command -v pacman      >/dev/null 2>&1; then $SUDO pacman -Sy --noconfirm git
  elif command -v apk         >/dev/null 2>&1; then $SUDO apk add git
  elif command -v zypper      >/dev/null 2>&1; then $SUDO zypper install -y git
  elif command -v xbps-install >/dev/null 2>&1; then $SUDO xbps-install -Sy git
  elif command -v nix         >/dev/null 2>&1; then nix profile install nixpkgs#git
  else die "git ausente e nenhum package manager conhecido encontrado (apt/dnf/yum/pacman/apk/zypper/xbps/nix). instale git manualmente."
  fi
fi
command -v git >/dev/null || die "git ainda indisponível após tentativa de instalação."

if [[ "$REPO" == github.com/* ]] && command -v nix >/dev/null; then
  # caminho via nix flake
  log "nix detectado — usando nix flake metadata"
else
  log "baixando repo $REPO (branch $BRANCH) -> $DEST"
  git clone --depth=1 --branch="$BRANCH" "https://$REPO.git" "$DEST"
  cd "$DEST"
fi

# --- bootstrap interativo (a não ser que LCARS_BATCH=yes) -------------
if [[ "${LCARS_BATCH:-no}" == "yes" ]]; then
  warn "modo batch: pulando perguntas. preencha vars/local.nix depois."
else
  log "rodando bootstrap para preencher vars/local.nix"
  if command -v nix >/dev/null && [[ -f flake.nix ]]; then
    nix run .#bootstrap || warn "bootstrap falhou — abra vars/local.nix à mão"
  else
    bash ./scripts/bootstrap.sh || warn "bootstrap falhou — abra vars/local.nix à mão"
  fi
fi

# --- ativação --------------------------------------------------------
if [[ -n "$HOST" ]] && [[ "$ACTIVATE" == "yes" ]]; then
  if [[ -e /etc/NIXOS ]]; then
    log "ativando NixOS configuration #$HOST"
    $SUDO nixos-rebuild switch --flake ".#$HOST"
  else
    warn "/etc/NIXOS ausente — não estamos em NixOS. pulando rebuild."
  fi
else
  log "ativação automática não solicitada."
  log "passos manuais estão em docs/adding-a-host.md"
fi

log "pronto. configure o host em hosts/<seu-host>/ e adicione em flake.nix."
