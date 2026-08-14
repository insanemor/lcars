#!/usr/bin/env bash

# Automated script to install my dotfiles

# Clone dotfiles
# TODO make ~/.dotfiles path arbitrary and make all other scripts conform to this
# using SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
nix-shell -p git --command "git clone https://github.com/insanemor/lcars.git ~/.dotfiles"

# Passo 1: Ler o nome do modelo do dispositivo
model_name=$(cat /sys/devices/virtual/dmi/id/product_name)
# Passo 2: Substituir espaços por hífens se necessário (opcional)
model_name=${model_name// /-}
# Máquinas sem DMI legível (ARM, algumas VMs) não têm modelo: cai em "nixos"
model_name=${model_name:-nixos}
# Passo 3: Definir o diretório de destino
destination="$HOME/.dotfiles/machines/$model_name"
# Passo 4: Criar a máquina a partir do template (traz o default.nix que o flake importa)
cp -r ~/.dotfiles/machines/template "$destination"
# Generate hardware config for new system
sudo nixos-generate-config --show-hardware-config > "$destination/hardware-configuration.nix"
echo "Configuração de hardware salva em: $destination/hardware-configuration.nix"

# settings.nix vem versionado com o default básico — o script edita esse mesmo
# arquivo, e o editor abaixo te dá a chance de revisar antes do build.

# Check if uefi or bios
if [ -d /sys/firmware/efi/efivars ]; then
    sed -i "0,/bootMode.*=.*\".*\";/s//bootMode = \"uefi\";/" ~/.dotfiles/settings.nix
else
    sed -i "0,/bootMode.*=.*\".*\";/s//bootMode = \"bios\";/" ~/.dotfiles/settings.nix
    grubDevice=$(findmnt / | awk -F' ' '{ print $2 }' | sed 's/\[.*\]//g' | tail -n 1 | lsblk -no pkname | tail -n 1 )
    sed -i "0,/grubDevice.*=.*\".*\";/s//grubDevice = \"\/dev\/$grubDevice\";/" ~/.dotfiles/settings.nix
fi

# Patch settings.nix com o nome da máquina, o usuário e o nome completo
sed -i "0,/hostname.*=.*\".*\";/s//hostname = \"$model_name\";/" ~/.dotfiles/settings.nix
sed -i "0,/username.*=.*\".*\";/s//username = \"$(whoami)\";/" ~/.dotfiles/settings.nix
sed -i "0,/fullName.*=.*\".*\";/s//fullName = \"$(getent passwd $(whoami) | cut -d ':' -f 5 | cut -d ',' -f 1)\";/" ~/.dotfiles/settings.nix

# Open up editor to manually edit settings.nix before install
if [ -z "$EDITOR" ]; then
    EDITOR=nano;
fi
$EDITOR ~/.dotfiles/settings.nix;

# Flakes só enxergam arquivos rastreados pelo git, e o hardware-configuration
# está no .gitignore. `add -f` o põe no index; não é commit.
nix-shell -p git --command "git -C ~/.dotfiles add -f machines/$model_name"

# Rebuild system (o home-manager entra como módulo neste mesmo rebuild)
sudo nixos-rebuild switch --flake ~/.dotfiles#"$model_name";
