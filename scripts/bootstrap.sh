#!/usr/bin/env bash
# =====================================================================
# lcars — gerador do settings.nix
#
# Cria o `settings.nix` a partir do `settings.example.nix`, preenchendo os
# campos com o que dá para descobrir da máquina. Depois é só editar o arquivo.
#
#   ./scripts/bootstrap.sh
#
# Modo não-interativo (usado pelo install.sh): LCARS_NONINTERACTIVE=yes.
# Valores por ambiente, todos opcionais:
#   LCARS_USERNAME LCARS_FULLNAME LCARS_EMAIL LCARS_TZ LCARS_LOCALE
#   LCARS_HOST LCARS_PROFILE LCARS_BOOTMODE LCARS_GRUBDEV LCARS_EDITOR
#
# LCARS_FORCE=yes reescreve um settings.nix existente.
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

TEMPLATE="${REPO_ROOT}/settings.example.nix"
TARGET="${REPO_ROOT}/settings.nix"

# --- preflight --------------------------------------------------------
if [[ ! -f "$TEMPLATE" ]]; then
  printf 'ERRO: %s não encontrado. rode a partir da raiz do repo.\n' "$TEMPLATE" >&2
  exit 1
fi
if [[ -f "$TARGET" && "${LCARS_FORCE:-no}" != "yes" ]]; then
  printf '\n%s já existe — mantendo.\n' "$TARGET"
  printf '  edite-o diretamente, ou rode com LCARS_FORCE=yes para recomeçar.\n'
  exit 0
fi

# --- helpers ----------------------------------------------------------
NONINTERACTIVE="${LCARS_NONINTERACTIVE:-no}"
# Sem stdin de terminal (ex.: `curl ... | bash`) não dá para perguntar.
[[ -t 0 ]] || NONINTERACTIVE=yes

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

if [[ -d /sys/firmware/efi ]]; then default_boot="uefi"; else default_boot="bios"; fi

default_grubdev=""
if [[ "$default_boot" == "bios" ]]; then
  root_src="$(findmnt -no SOURCE / 2>/dev/null || true)"
  pk="$(lsblk -no PKNAME "$root_src" 2>/dev/null | head -1 || true)"
  [[ -n "$pk" ]] && default_grubdev="/dev/$pk"
fi

# VM headless não ganha nada com um ambiente gráfico.
if command -v systemd-detect-virt >/dev/null 2>&1 && systemd-detect-virt --quiet --vm; then
  default_profile="basic"
else
  default_profile="personal"
fi

# --- prompts ----------------------------------------------------------
[[ "$NONINTERACTIVE" == "yes" ]] || printf '\n--- lcars: gerando settings.nix ---\n\n'

username=$(ask  'usuário'        "$default_user"           "${LCARS_USERNAME:-}")
fullName=$(ask  'nome completo'  "$username"               "${LCARS_FULLNAME:-}")
email=$(ask     'email'          "${username}@example.com" "${LCARS_EMAIL:-}")
hostName=$(ask  'hostname'       "$default_host"           "${LCARS_HOST:-}")
profile=$(ask   'profile'        "$default_profile"        "${LCARS_PROFILE:-}")
timezone=$(ask  'fuso horário'   'America/Sao_Paulo'       "${LCARS_TZ:-}")
locale=$(ask    'locale'         'pt_BR.UTF-8'             "${LCARS_LOCALE:-}")
bootMode=$(ask  'boot (uefi/bios)' "$default_boot"         "${LCARS_BOOTMODE:-}")
grubDevice=$(ask 'disco do grub' "$default_grubdev"        "${LCARS_GRUBDEV:-}")
editor=$(ask    'editor'         'vim'                     "${LCARS_EDITOR:-}")

# --- escrita ----------------------------------------------------------
# Partimos do exemplo (que carrega todos os comentários explicativos) e
# trocamos só os valores. Assim o arquivo continua legível para editar.
python3 - "$TEMPLATE" "$TARGET" <<PYEOF
import re, sys
src, dst = sys.argv[1], sys.argv[2]
vals = {
    "hostname": """$hostName""",
    "profile": """$profile""",
    "timezone": """$timezone""",
    "locale": """$locale""",
    "bootMode": """$bootMode""",
    "grubDevice": """$grubDevice""",
    "username": """$username""",
    "fullName": """$fullName""",
    "email": """$email""",
    "editor": """$editor""",
}
s = open(src, encoding="utf-8").read()
for key, val in vals.items():
    # Só a primeira ocorrência de cada chave, e só em linhas de atribuição.
    s, n = re.subn(
        r'^(\s*%s\s*=\s*)"[^"]*"(;)' % re.escape(key),
        lambda m: m.group(1) + '"' + val + '"' + m.group(2),
        s, count=1, flags=re.M,
    )
    if n == 0:
        print("aviso: campo '%s' não encontrado no template" % key, file=sys.stderr)
s = s.replace(
    "# lcars — configuração desta instalação",
    "# lcars — configuração desta instalação\n# Gerado por scripts/bootstrap.sh. Edite à vontade: nada aqui é reescrito.",
    1,
)
open(dst, "w", encoding="utf-8").write(s)
PYEOF

printf '\nsettings.nix escrito (usuário: %s, host: %s, profile: %s).\n' \
  "$username" "$hostName" "$profile"
