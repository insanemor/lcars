#!/usr/bin/env bash
# =====================================================================
# lcars — script de bootstrap
#
# Gera `vars/local.nix` a partir de perguntas interativas, para que um
# repo recém-clonado funcione sem commitar dados específicos do usuário.
#
# Rode uma vez por máquina (ou sempre que quiser alterar as vars):
#   ./scripts/bootstrap.sh
#
# Modo não-interativo (usado pelo install.sh): defina LCARS_NONINTERACTIVE=yes
# e passe os valores por ambiente:
#   LCARS_USERNAME LCARS_FULLNAME LCARS_EMAIL LCARS_TZ LCARS_LOCALE
#   LCARS_HOST LCARS_VAULT
#
# LCARS_FORCE=yes reescreve um vars/local.nix existente.
# =====================================================================

set -euo pipefail

# `nix run .#bootstrap` empacota este script fora da árvore, então $0 não
# aponta para o repo. Nesse caso usamos o diretório de trabalho atual.
if [[ -n "${LCARS_ROOT:-}" ]]; then
  REPO_ROOT="$LCARS_ROOT"
elif [[ -f "$(dirname "${BASH_SOURCE[0]}")/../flake.nix" ]]; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
else
  REPO_ROOT="$PWD"
fi

TEMPLATE="${REPO_ROOT}/vars/example.nix"
TARGET="${REPO_ROOT}/vars/local.nix"

# --- preflight --------------------------------------------------------
if [[ ! -f "$TEMPLATE" ]]; then
  printf 'ERRO: template %s não encontrado. rode a partir da raiz do repo.\n' "$TEMPLATE" >&2
  exit 1
fi
if [[ -f "$TARGET" && "${LCARS_FORCE:-no}" != "yes" ]]; then
  printf '\n%s já existe — mantendo.\n' "$TARGET"
  printf '  altere as vars diretamente nele, ou rode com LCARS_FORCE=yes.\n'
  exit 0
fi

# --- helpers ----------------------------------------------------------
NONINTERACTIVE="${LCARS_NONINTERACTIVE:-no}"
if [[ ! -t 0 ]]; then
  # Sem stdin de terminal (ex.: `curl ... | bash`) não dá para perguntar.
  NONINTERACTIVE=yes
fi

ask() {
  local label="$1" default="$2" override="${3:-}" value
  if [[ -n "$override" ]]; then printf '%s' "$override"; return; fi
  if [[ "$NONINTERACTIVE" == "yes" ]]; then printf '%s' "$default"; return; fi
  printf '%s [%s]: ' "$label" "$default" 1>&2
  read -r value
  printf '%s' "${value:-$default}"
}

# --- defaults derivados da máquina -----------------------------------
# SUDO_USER porque o instalador roda com sudo; aí $USER seria "root".
default_user="${SUDO_USER:-${USER:-ins}}"
[[ "$default_user" == "root" ]] && default_user="ins"
default_host="$(hostname -s 2>/dev/null || echo nixos)"

# --- prompts ----------------------------------------------------------
if [[ "$NONINTERACTIVE" != "yes" ]]; then
  printf '\n--- lcars: preenchendo vars/local.nix ---\n\n'
fi

username=$(ask  'usuário'          "$default_user"            "${LCARS_USERNAME:-}")
fullName=$(ask  'nome completo'    "$username"                "${LCARS_FULLNAME:-}")
email=$(ask     'email'            "${username}@example.com"  "${LCARS_EMAIL:-}")
timezone=$(ask  'fuso horário'     'America/Sao_Paulo'        "${LCARS_TZ:-}")
locale=$(ask    'locale'           'pt_BR.UTF-8'              "${LCARS_LOCALE:-}")
hostName=$(ask  'hostname'         "$default_host"            "${LCARS_HOST:-}")
vault=$(ask     'vault 1Password'  'Personal'                 "${LCARS_VAULT:-}")

# --- escrita ----------------------------------------------------------
mkdir -p "$(dirname "$TARGET")"
cat > "$TARGET" <<EOF
# Gerado automaticamente por scripts/bootstrap.sh — NÃO EDITE À MÃO.
# Este arquivo está no .gitignore. Rode o bootstrap de novo para reescrevê-lo.

{ lib }:

{
  username      = "$username";
  fullName      = "$fullName";
  email         = "$email";
  gpgKey        = null;

  timezone      = "$timezone";
  locale        = "$locale";

  defaultHostName = "$hostName";

  onePassword = {
    enableCli      = true;
    enableGui      = true;
    enableSshAgent = true;
    polkitOwner    = "$username";
    vault          = "$vault";
  };

  dotfilesFrom1Password = [
    # "zshrc"
    # "gitconfig"
  ];

  systemPackages = [];
  userPackages   = [ "zsh" "starship" ];
}
EOF

printf '\nvars/local.nix escrito (usuário: %s, host: %s).\n' "$username" "$hostName"
