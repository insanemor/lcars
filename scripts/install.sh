#!/usr/bin/env bash

# Automated script to install my dotfiles

# Clone dotfiles
# TODO make ~/.dotfiles path arbitrary and make all other scripts conform to this
# using SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
nix-shell -p git --command "git clone https://github.com/insanemor/lcars.git ~/.dotfiles"

# Passo 1: Ler o nome do modelo do dispositivo
model_name=$(cat /sys/devices/virtual/dmi/id/product_name)
# Passo 2: Reduzir ao que um hostname aceita — [a-zA-Z0-9-] e nada mais.
# Trocar só espaços não basta: uma VM QEMU se apresenta como
# "Standard PC (Q35 + ICH9, 2009)", e parênteses, vírgula e + não são válidos
# em networking.hostName. Os dois `tr` viram tudo em hífen e colapsam os
# repetidos; o `sed` apara os das pontas.
model_name=$(printf '%s' "$model_name" | tr -c 'a-zA-Z0-9-' '-' | tr -s '-' | sed 's/^-//; s/-$//')
# Máquinas sem DMI legível (ARM, algumas VMs) não têm modelo: cai em "nixos"
model_name=${model_name:-nixos}
# Passo 3: Definir o diretório de destino
destination="$HOME/.dotfiles/machines/$model_name"
# Passo 4: Criar a máquina a partir do template (traz o default.nix que o flake importa)
cp -r ~/.dotfiles/machines/template "$destination"
# Generate hardware config for new system
# O redirecionamento é feito por você, não pelo sudo — e é o que queremos: o
# arquivo nasce com o seu dono, não do root. (SC2024)
# shellcheck disable=SC2024
sudo nixos-generate-config --show-hardware-config > "$destination/hardware-configuration.nix"
echo "Configuração de hardware salva em: $destination/hardware-configuration.nix"

# settings.nix vem versionado com o default básico — o script edita esse mesmo
# arquivo, e o editor abaixo te dá a chance de revisar antes do build.

# Escreve um campo do settings.nix, e AVISA se não achou a linha.
#
# O sed só substitui o que já existe: se o campo tiver sido removido do
# settings.nix, ele não faz nada e sai com status 0. Foi assim que grubDevice
# ficou vazio numa VM BIOS e o build morreu numa assertion lá adiante, sem
# nenhuma pista de onde tinha começado.
settings="$HOME/.dotfiles/settings.nix"
set_field() {
    local campo="$1" valor="$2" escapado

    if ! grep -qE "^[[:space:]]*${campo}[[:space:]]*=" "$settings"; then
        echo "AVISO: campo '$campo' não existe em settings.nix — não foi preenchido." >&2
        echo "       acrescente '$campo = \"$valor\";' à mão antes do rebuild." >&2
        return
    fi

    # Barra, & e contrabarra têm significado na substituição do sed. Sem isto,
    # um valor como "/dev/sda" faz o sed abortar com "opção desconhecida".
    escapado=$(printf '%s' "$valor" | sed 's/[\/&\\]/\\&/g')
    sed -i "0,/^\([[:space:]]*\)${campo}[[:space:]]*=.*/s//\1${campo} = \"${escapado}\";/" "$settings"

    # Conferir o resultado, não só a tentativa: é o que separa "o sed rodou" de
    # "o valor está lá". Qualquer forma de falha cai aqui.
    if ! grep -qF "${campo} = \"${valor}\";" "$settings"; then
        echo "AVISO: não consegui escrever '$campo' em settings.nix." >&2
        echo "       ajuste '$campo = \"$valor\";' à mão antes do rebuild." >&2
    fi
}

# Check if uefi or bios
if [ -d /sys/firmware/efi/efivars ]; then
    set_field bootMode uefi
else
    set_field bootMode bios
    # O DISCO da raiz, não a partição: /dev/sda, não /dev/sda1.
    #
    # `findmnt -no SOURCE` devolve a partição direto, sem cabeçalho; o sed tira
    # o subvolume que btrfs acrescenta ("[/@]"). O disco sai do `lsblk` com a
    # partição como ARGUMENTO — antes ela ia por pipe, que o lsblk ignora, e
    # ele listava todos os discos do sistema para o `tail -n 1` pegar o último.
    # Numa máquina de um disco só isso acerta por acaso; com dois, instalaria
    # o GRUB no disco errado.
    root_part=$(findmnt -no SOURCE / | sed 's/\[.*\]//')
    root_disk=$(lsblk -no pkname "$root_part" 2>/dev/null | head -n 1)
    if [ -n "$root_disk" ]; then
        set_field grubDevice "/dev/$root_disk"
    else
        echo "AVISO: não consegui descobrir o disco de '$root_part'." >&2
        echo "       preencha grubDevice no settings.nix antes do rebuild." >&2
    fi
fi

# Patch settings.nix com o nome da máquina, o usuário e o nome completo
set_field hostname "$model_name"
set_field username "$(whoami)"
set_field fullName "$(getent passwd "$(whoami)" | cut -d ':' -f 5 | cut -d ',' -f 1)"

# Open up editor to manually edit settings.nix before install
if [ -z "$EDITOR" ]; then
    EDITOR=nano;
fi
$EDITOR ~/.dotfiles/settings.nix;

# Daqui para baixo tudo precisa do git, inclusive o rebuild — e numa máquina
# recém-instalada ele ainda não existe: só chega DEPOIS deste build, por
# system/core. Por isso o bloco inteiro roda dentro do nix-shell.
#
#   add -f       flakes só enxergam arquivos rastreados, e o
#                hardware-configuration está no .gitignore. Põe no index,
#                não é commit.
#   safe.directory  o rebuild roda como root sobre um repo que é seu, e o git
#                aborta nessa situação com "detected dubious ownership".
#   env PATH     o sudo zera o PATH, então o git do nix-shell não chegaria ao
#                root sem isto. Sem ele o build morre com
#                'executing "git": No such file or directory'.
#
# O home-manager entra como módulo neste mesmo rebuild — não há passo separado.
nix-shell -p git --command "
  git -C $HOME/.dotfiles add -f machines/$model_name
  sudo env PATH=\"\$PATH\" git config --global --add safe.directory $HOME/.dotfiles
  sudo env PATH=\"\$PATH\" nixos-rebuild switch --flake $HOME/.dotfiles#$model_name
"
