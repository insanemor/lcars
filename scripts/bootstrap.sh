#!/usr/bin/env bash
# =====================================================================
# lcars-public — script de bootstrap
#
# Gera `vars/local.nix` a partir de perguntas interativas, para que um
# repo recém-clonado funcione sem commitar dados específicos do usuário.
#
# Rode uma vez por máquina (ou sempre que quiser alterar as vars):
#   ./scripts/bootstrap.sh
# =====================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="${REPO_ROOT}/vars/example.nix"
TARGET="${REPO_ROOT}/vars/local.nix"

# --- preflight --------------------------------------------------------
if [[ -f "$TARGET" ]]; then
  printf '\n%s já existe.\n' "$TARGET"
  printf '  altere as vars diretamente nele.\n'
  exit 0
fi
if [[ ! -f "$TEMPLATE" ]]; then
  printf 'ERRO: template %s não encontrado. clone o repo completo.\n' "$TEMPLATE"
  exit 1
fi

# --- helpers ----------------------------------------------------------
ask() {
  local label="$1"; local default="$2"; local value
  printf '%s [%s]: ' "$label" "$default" 1>&2
  read -r value
  printf '%s' "${value:-$default}"
}

# --- prompts ----------------------------------------------------------
printf '\n--- lcars public: preenchendo vars/local.nix ---\n\n'

username=$(ask  'usuário'         'ins')
fullName=$(ask  'nome completo'   'Seu Nome')
email=$(ask     'email'           "${username}@example.com")
timezone=$(ask  'fuso horário'    'America/Sao_Paulo')
locale=$(ask    'locale'          'pt_BR.UTF-8')
defaultHostName=$(ask 'hostname padrão' 'lcars-$(hostname -s)')

# --- escrita ----------------------------------------------------------
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

  defaultHostName = "$defaultHostName";

  onePassword = {
    enableCli      = true;
    enableGui      = true;
    enableSshAgent = true;
    polkitOwner    = "$username";
    vault          = "Personal";
  };

  dotfilesFrom1Password = [
    # "./zshrc"
    # "./gitconfig"
  ];

  systemPackages = [];
  userPackages   = [ "zsh" "starship" ];
}
EOF

printf '\nvars/local.nix escrito.\n'
printf '\nPróximos passos:\n'
printf '  1. Edite hosts/<seu-host>/default.nix e hardware-configuration.nix.\n'
printf '  2. Adicione uma entrada em flake.nix dentro de nixosConfigurations.\n'
printf '  3. Rode: sudo nixos-rebuild switch --flake .#<host>\n'
printf '\nVeja docs/adding-a-host.md para detalhes.\n'
