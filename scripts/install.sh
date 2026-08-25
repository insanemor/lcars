#!/usr/bin/env bash
#
# lcars — instalador de um comando.
#
#   curl -fsSL https://raw.githubusercontent.com/insanemor/lcars/main/scripts/install.sh | bash
#
# Rodando por esse pipe, o stdin do script É o pipe: qualquer programa que
# tente ler do teclado lê o resto do script, ou desiste. Por isso TODA leitura
# aqui é feita em /dev/tty, explicitamente. Foi o que faltou na #150 (o `read`
# do hostname) e de novo na #157, onde o `$EDITOR` saía na hora com "a entrada
# padrão não é um terminal" e ninguém via.
#
# Regra desta versão: nenhum editor é aberto e nada é adivinhado em silêncio.
# O que a máquina pode responder por si (UEFI/BIOS, disco, VM, notebook) é
# detectado e mostrado; o resto é perguntado.

# -e   qualquer comando que falhe aborta a instalação. Era o que faltava para
#      a falha do nixos-rebuild não terminar em "Instalação concluída" (#157).
# -u   variável não definida é erro, não string vazia.
# -o pipefail  um pipe falha se QUALQUER etapa falhar, não só a última.
set -euo pipefail

REPO_URL="https://github.com/insanemor/lcars.git"
DOTFILES="$HOME/.dotfiles"

# ---------------------------------------------------------------------
# Saída e erro
# ---------------------------------------------------------------------
titulo() {
    printf '\n\033[1m%s\033[0m\n' "$*"
}

info() {
    printf '  %s\n' "$*"
}

# Toda saída deste script que não seja resposta de função vai para o stderr:
# o stdout é o canal por onde as funções de pergunta devolvem o valor lido.
erro() {
    printf '\n\033[1;31mERRO:\033[0m %s\n' "$*" >&2
}

die() {
    erro "$*"
    printf '\nInstalação abortada. Nada foi aplicado ao sistema.\n' >&2
    exit 1
}

# ---------------------------------------------------------------------
# Perguntas — todas leem de /dev/tty, nunca do stdin
# ---------------------------------------------------------------------
# O prompt do `read -p` sai no stderr (comportamento do bash), então ele
# aparece no terminal sem sujar o valor capturado por $(...).

# perguntar <texto> [padrão]
#   Enter aceita o padrão. Vazio sem padrão repete a pergunta: todo campo
#   perguntado aqui é obrigatório.
perguntar() {
    local texto="$1" padrao="${2-}" resposta prompt

    if [ -n "$padrao" ]; then
        prompt="$texto [$padrao]: "
    else
        prompt="$texto: "
    fi

    while :; do
        if ! read -r -p "$prompt" resposta < /dev/tty; then
            die "não consegui ler a resposta (fim de entrada em /dev/tty)."
        fi
        resposta="${resposta:-$padrao}"
        if [ -n "$resposta" ]; then
            printf '%s' "$resposta"
            return
        fi
        printf '  este campo é obrigatório.\n' >&2
    done
}

# confirmar <texto> [s|n]   — o segundo argumento é a resposta do Enter
confirmar() {
    local texto="$1" padrao="${2:-s}" resposta dica

    case "$padrao" in
        s) dica="[S/n]" ;;
        *) dica="[s/N]" ;;
    esac

    while :; do
        if ! read -r -p "$texto $dica: " resposta < /dev/tty; then
            die "não consegui ler a resposta (fim de entrada em /dev/tty)."
        fi
        resposta="${resposta:-$padrao}"
        case "${resposta,,}" in
            s | sim | y | yes) return 0 ;;
            n | nao | não | no) return 1 ;;
            *) printf '  responda s ou n.\n' >&2 ;;
        esac
    done
}

# escolher <texto> <padrão> <opção>...  — menu numerado, devolve a opção
escolher() {
    local texto="$1" padrao="$2"
    shift 2
    local -a opcoes=("$@")
    local i escolha

    printf '\n%s\n' "$texto" >&2
    for i in "${!opcoes[@]}"; do
        printf '  %d) %s\n' "$((i + 1))" "${opcoes[i]}" >&2
    done

    while :; do
        if ! read -r -p "Escolha [1-${#opcoes[@]}, padrão $padrao]: " escolha < /dev/tty; then
            die "não consegui ler a resposta (fim de entrada em /dev/tty)."
        fi
        # Enter devolve o padrão; um nome digitado por extenso também vale.
        if [ -z "$escolha" ]; then
            printf '%s' "$padrao"
            return
        fi
        if [[ "$escolha" =~ ^[0-9]+$ ]] && [ "$escolha" -ge 1 ] && [ "$escolha" -le "${#opcoes[@]}" ]; then
            printf '%s' "${opcoes[$((escolha - 1))]}"
            return
        fi
        for i in "${opcoes[@]}"; do
            if [ "$escolha" = "$i" ]; then
                printf '%s' "$i"
                return
            fi
        done
        printf '  opção inválida.\n' >&2
    done
}

# Reduz um texto ao que `networking.hostName` aceita — [a-zA-Z0-9-] e nada
# mais. Trocar só espaços não basta: uma VM QEMU se apresenta como
# "Standard PC (Q35 + ICH9, 2009)", e parênteses, vírgula e + não são válidos.
# Os dois `tr` viram tudo em hífen e colapsam os repetidos; o `sed` apara as
# pontas.
sanitizar_hostname() {
    printf '%s' "$1" | tr -c 'a-zA-Z0-9-' '-' | tr -s '-' | sed 's/^-//; s/-$//'
}

# ---------------------------------------------------------------------
# Escrita nos arquivos .nix
# ---------------------------------------------------------------------
# Dois arquivos, duas naturezas:
#
#   settings.nix                    quem você é — igual em todas as máquinas
#   machines/<nome>/default.nix     o que ESTA máquina é — boot, VM, notebook
#
# É por isso que o boot não vai para o settings.nix: assim ele nunca diverge
# do repositório, e o `git pull` de quem já instalou não conflita.

# O sed só substitui o que já existe: se o campo for removido do arquivo, ele
# não faz nada e sai com status 0. Foi assim que grubDevice ficou vazio numa VM
# BIOS e o build morreu numa assertion lá adiante, sem pista de onde começou
# (#15). Aqui isso é erro fatal, não aviso: todo campo escrito por este script
# é necessário para o rebuild seguinte.
_escrever_campo() {
    local arquivo="$1" campo="$2" valor="$3" campo_re escapado

    # Os pontos do nome da option são literais, não "qualquer caractere".
    campo_re="${campo//./\\.}"

    if ! grep -qE "^[[:space:]]*${campo_re}[[:space:]]*=" "$arquivo"; then
        die "o campo '$campo' não existe em $(basename "$arquivo") — o arquivo foi editado à mão? acrescente '$campo = $valor;' e rode de novo."
    fi

    # Barra, & e contrabarra têm significado na substituição do sed. Sem isto,
    # um valor como "/dev/sda" faz o sed abortar com "opção desconhecida".
    escapado=$(printf '%s' "$valor" | sed 's/[\/&\\]/\\&/g')
    sed -i "0,/^\([[:space:]]*\)${campo_re}[[:space:]]*=.*/s//\1${campo} = ${escapado};/" "$arquivo"

    # Conferir o resultado, não só a tentativa: é o que separa "o sed rodou" de
    # "o valor está lá".
    if ! grep -qF "${campo} = ${valor};" "$arquivo"; then
        die "não consegui escrever '$campo' em $(basename "$arquivo")."
    fi
}

# String Nix (com aspas) e valor literal (booleano, número) — o Nix distingue,
# e `vm.enable = "true"` não é um erro de digitação que a avaliação perdoe.
set_str() { _escrever_campo "$1" "$2" "\"$3\""; }
set_raw() { _escrever_campo "$1" "$2" "$3"; }

# =====================================================================
# 0. Pré-requisitos
# =====================================================================
if [ ! -r /dev/tty ]; then
    die "este instalador é interativo e precisa de um terminal (/dev/tty ilegível). Rode-o direto no console da máquina."
fi

if [ -e "$DOTFILES" ]; then
    die "$DOTFILES já existe. Mova ou remova o diretório antes de reinstalar."
fi

# =====================================================================
# 1. Clonar o repositório
# =====================================================================
# `--run`, não `--command`: com `--command` o nix-shell deixa um bash
# INTERATIVO aberto depois de rodar o comando, e esse bash passa a ler do
# stdin — que aqui é o pipe do curl, ou seja, o resto deste próprio script.
# `--run` roda e sai, devolvendo o status de verdade.
titulo "Baixando o repositório em $DOTFILES"
nix-shell -p git --run "git clone --quiet '$REPO_URL' '$DOTFILES'" \
    || die "não consegui clonar $REPO_URL. Sem rede, ou o nix-shell não está disponível?"

# =====================================================================
# 2. Sugestões de nome para esta máquina
# =====================================================================
# O DMI às vezes não tem nada de útil a oferecer: placas que a fabricante não
# preencheu respondem literalmente "System Product Name" (#150), e o slug
# resultante viraria o hostname para sempre sem ninguém notar na hora. Por
# isso as duas sugestões aparecem e a escolha é explícita.
modelo_dmi=$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null || true)
modelo_dmi=$(sanitizar_hostname "$modelo_dmi")
hostname_atual=$(sanitizar_hostname "$(hostname 2>/dev/null || true)")

sugestao="${hostname_atual:-${modelo_dmi:-nixos}}"

titulo "Esta máquina"
info "Este nome vira o diretório em machines/ e o networking.hostName."
info "Não é fácil de trocar depois — quem define o hostname é o nome do diretório."
if [ -n "$hostname_atual" ]; then info "hostname atual ....... $hostname_atual"; fi
if [ -n "$modelo_dmi" ]; then info "modelo do hardware ... $modelo_dmi"; fi

while :; do
    maquina=$(perguntar "Nome desta máquina" "$sugestao")
    limpo=$(sanitizar_hostname "$maquina")
    if [ -z "$limpo" ]; then
        info "nome inválido: sobram só letras, números e hífen."
        continue
    fi
    if [ "$limpo" != "$maquina" ]; then
        info "ajustado para o que networking.hostName aceita: $limpo"
    fi
    if [ "$limpo" = "template" ]; then
        info "'template' é o único nome reservado — a auto-descoberta o ignora."
        continue
    fi
    maquina="$limpo"
    break
done

# =====================================================================
# 3. Quem você é
# =====================================================================
titulo "Você"
info "Vai para o settings.nix, que vale igual em todas as suas máquinas."

usuario_padrao=$(whoami)
while :; do
    usuario=$(perguntar "Nome de usuário" "$usuario_padrao")
    if [[ "$usuario" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        break
    fi
    info "usuário inválido: comece com letra minúscula ou _, sem espaços."
done

# O GECOS de um NixOS recém-instalado costuma vir vazio ou truncado, então ele
# entra só como sugestão — nunca como valor escrito às escondidas.
nome_padrao=$(getent passwd "$usuario" 2>/dev/null | cut -d: -f5 | cut -d, -f1 || true)
nome_completo=$(perguntar "Seu nome completo (git, GPG, tela de login)" "$nome_padrao")

while :; do
    email=$(perguntar "Seu e-mail (autoria dos commits)")
    if [[ "$email" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]; then
        break
    fi
    info "e-mail inválido."
done

# =====================================================================
# 4. Profile
# =====================================================================
# A lista vem dos diretórios de profiles/, não de uma lista fixa aqui: um
# profile novo aparece sozinho no menu.
mapfile -t profiles < <(find "$DOTFILES/profiles" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
[ "${#profiles[@]}" -gt 0 ] || die "nenhum profile encontrado em $DOTFILES/profiles."

profile_padrao=$(sed -n 's/^[[:space:]]*profile[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$DOTFILES/settings.nix" | head -n 1)
profile_padrao="${profile_padrao:-${profiles[0]}}"

profile=$(escolher "Profile desta máquina (preset de flags — dá para trocar depois):" "$profile_padrao" "${profiles[@]}")

# =====================================================================
# 5. O que a máquina responde por si
# =====================================================================
# Nada disto é perguntado: são fatos que a máquina sabe sobre si mesma. Eram a
# razão de o instalador abrir um editor, e a razão de `vm` e `laptop` ficarem
# em false quando o editor não abria (#157).
titulo "Detectando o hardware"

if [ -d /sys/firmware/efi/efivars ]; then
    boot_loader="systemd-boot"
    grub_device=""
    info "firmware ...... UEFI  -> systemd-boot"
else
    boot_loader="grub"
    # O DISCO da raiz, não a partição: /dev/sda, não /dev/sda1.
    #
    # `findmnt -no SOURCE` devolve a partição direto, sem cabeçalho; o sed tira
    # o subvolume que btrfs acrescenta ("[/@]"). O disco sai do `lsblk` com a
    # partição como ARGUMENTO — antes ela ia por pipe, que o lsblk ignora, e
    # ele listava todos os discos do sistema para o `tail -n 1` pegar o último.
    # Numa máquina de um disco só isso acerta por acaso; com dois, instalaria
    # o GRUB no disco errado.
    root_part=$(findmnt -no SOURCE / | sed 's/\[.*\]//')
    root_disk=$(lsblk -no pkname "$root_part" 2>/dev/null | head -n 1 || true)
    [ -n "$root_disk" ] || die "não consegui descobrir o disco de '$root_part' para instalar o GRUB."
    grub_device="/dev/$root_disk"
    info "firmware ...... BIOS legado -> grub em $grub_device"
fi

# systemd-detect-virt --vm: só virtualização de máquina, não container.
if command -v systemd-detect-virt > /dev/null && systemd-detect-virt --vm --quiet; then
    eh_vm="true"
    info "virtualização . $(systemd-detect-virt --vm) -> qemu-guest-agent e virtio"
else
    eh_vm="false"
    info "virtualização . nenhuma (máquina física)"
fi

# Chassi 8-11 e 14 são as formas de portátil no DMI; a bateria é a confirmação
# de quem não preencheu o chassi.
chassi=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || true)
case "$chassi" in
    8 | 9 | 10 | 11 | 14) eh_laptop="true" ;;
    *) eh_laptop="false" ;;
esac
if [ "$eh_laptop" = "false" ] && compgen -G "/sys/class/power_supply/BAT*" > /dev/null; then
    eh_laptop="true"
fi
if [ "$eh_laptop" = "true" ]; then
    info "formato ....... notebook -> tlp, limite de carga, suspender ao fechar"
else
    info "formato ....... desktop"
fi

# =====================================================================
# 6. Resumo e confirmação
# =====================================================================
titulo "Resumo"
cat >&2 <<RESUMO
  machines/$maquina/default.nix
    networking.hostName ................. $maquina
    lcars.system.core.bootLoader ........ $boot_loader${grub_device:+
    lcars.system.core.grubDevice ........ $grub_device}
    lcars.system.hardware.vm.enable ..... $eh_vm
    lcars.system.hardware.laptop.enable . $eh_laptop

  settings.nix
    profile ............................. $profile
    username ............................ $usuario
    fullName ............................ $nome_completo
    email ............................... $email

RESUMO

confirmar "Aplicar isto e rodar o nixos-rebuild?" s \
    || die "cancelado por você."

# O sudo aparece aqui, uma vez, para a senha não surgir no meio do build sem
# contexto. Ele lê do terminal, não do stdin.
titulo "Preciso do sudo para ler o hardware e ativar o sistema"
sudo -v || die "sudo recusado."

# =====================================================================
# 7. Aplicar
# =====================================================================
destino="$DOTFILES/machines/$maquina"
maquina_nix="$destino/default.nix"
settings_nix="$DOTFILES/settings.nix"

# `-T` (--no-target-directory) porque `cp -r origem destino` copia PARA DENTRO
# quando o destino já existe — e aí sai machines/<host>/template/, uma cópia
# inútil que ninguém importa e que depois viaja junto em algum commit (#33).
cp -rT "$DOTFILES/machines/template" "$destino"

# shellcheck disable=SC2024  # o redirecionamento é meu, não do sudo: o arquivo
# nasce com o seu dono, não do root.
sudo nixos-generate-config --show-hardware-config > "$destino/hardware-configuration.nix" \
    || die "nixos-generate-config falhou."

set_str "$maquina_nix" lcars.system.core.bootLoader "$boot_loader"
if [ -n "$grub_device" ]; then
    set_str "$maquina_nix" lcars.system.core.grubDevice "$grub_device"
fi
set_raw "$maquina_nix" lcars.system.hardware.vm.enable "$eh_vm"
set_raw "$maquina_nix" lcars.system.hardware.laptop.enable "$eh_laptop"

set_str "$settings_nix" profile "$profile"
set_str "$settings_nix" username "$usuario"
set_str "$settings_nix" fullName "$nome_completo"
set_str "$settings_nix" email "$email"

# =====================================================================
# 8. Rebuild
# =====================================================================
# Daqui para baixo tudo precisa do git, inclusive o rebuild — e numa máquina
# recém-instalada ele ainda não existe: só chega DEPOIS deste build, por
# system/core. Por isso o bloco inteiro roda dentro do nix-shell.
#
#   add -f          flakes só enxergam arquivos rastreados, e o
#                   hardware-configuration está no .gitignore. Põe no index,
#                   não é commit.
#   --elevate=sudo  NÃO use `sudo nixos-rebuild`: sob sudo é o root que lê a
#                   árvore pelo git, e ele escreve em .git/objects deixando os
#                   objetos com dono dele. O repositório fica travado para
#                   você no primeiro fetch que precise escrever. Com esta flag
#                   a avaliação roda como você e o root só ativa.
#
#                   Isso também dispensa o `safe.directory` que existia aqui:
#                   sem root lendo o repositório, não há "dubious ownership".
#
#                   O nome antigo, --use-remote-sudo, serve de reserva em
#                   versões mais velhas do nixos-rebuild.
#
# O home-manager entra como módulo neste mesmo rebuild — não há passo separado.
#
# A saída NÃO é capturada: o erro do rebuild é a informação mais valiosa desta
# instalação, e escondê-lo foi o defeito da #157.
titulo "Construindo o sistema — a primeira vez demora"

if ! nix-shell -p git --run "
  set -e
  git -C '$DOTFILES' add -f 'machines/$maquina'
  if nixos-rebuild --help 2>&1 | grep -q -- --elevate; then
    nixos-rebuild switch --flake '$DOTFILES#$maquina' --elevate=sudo
  else
    nixos-rebuild switch --flake '$DOTFILES#$maquina' --use-remote-sudo
  fi
"; then
    erro "o nixos-rebuild falhou — o motivo está na saída acima."
    cat >&2 <<FALHOU

O que foi escrito continua no lugar: corrija o que a mensagem apontar e repita
só o build, sem reinstalar nada:

  cd $DOTFILES
  nixos-rebuild switch --flake .#$maquina --elevate=sudo

FALHOU
    exit 1
fi

# =====================================================================
# 9. Fim
# =====================================================================
# O remote fica em HTTPS para sempre — de propósito, e não só na primeira
# instalação. Sem chave nenhuma, é o que permite clonar; com origin apontando
# para o repositório de outra pessoa (curl direto, sem fork), também é o que
# impede que este script dê a quem instala uma falsa capacidade de publicar
# ali. Publicar ficou fora do que este repositório automatiza — quem quiser,
# configura o remote e o agente SSH por conta própria.
cat <<AVISO

===============================================================
 Instalação concluída — o sistema já está ativo nesta geração.

 Reinicie para entrar na sessão gráfica.

 O remote continua em HTTPS — este repositório não publica nada
 sozinho, nem troca isso por você. Se quiser publicar mudanças suas
 (no seu próprio fork), configure o remote e a autenticação manualmente.
===============================================================
AVISO
