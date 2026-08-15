# --------------------------------------------------------------------
# Máquina de template.
#
# Este arquivo descreve O QUE ESTA MÁQUINA É. Tudo que vale igual em todas as
# suas máquinas — usuário, locale, profile, 1Password — está no settings.nix
# da raiz, e não aqui. A divisão existe para o settings.nix nunca divergir
# entre clones: sem ela, todo `git pull` daria conflito.
#
#   1. cp -r machines/template machines/<nome>
#   2. Na máquina alvo, gere o hardware-configuration.nix:
#        sudo nixos-generate-config --show-hardware-config \
#          > machines/<nome>/hardware-configuration.nix
#   3. Ajuste as linhas abaixo para o que esta máquina é
#   4. `git add -f machines/<nome>` — flakes só enxergam arquivos que o git
#      rastreia, e o hardware-configuration.nix está no .gitignore.
#
# `machines/<dir>` vira uma entrada de nixosConfigurations automaticamente, e
# é o nome do diretório que vira networking.hostName — não há campo de hostname
# em lugar nenhum. `template` é ignorado pela auto-descoberta. O instalador
# nomeia o diretório com o modelo do hardware; na mão, escolha o que quiser.
# --------------------------------------------------------------------
{ config, lib, pkgs, sys, user, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # --- boot -----------------------------------------------------------
  # Depende de a máquina ter bootado em UEFI ou em BIOS legado, algo que o
  # nixos-generate-config não decide por você. O instalador detecta e preenche;
  # na mão, confira com `[ -d /sys/firmware/efi ] && echo uefi || echo bios`.
  #
  #   "systemd-boot"  UEFI — usa bootMountPath, normalmente /boot
  #   "grub"          BIOS legado — exige grubDevice preenchido
  lcars.system.core.bootLoader = "systemd-boot";

  # Só com bootLoader = "grub". O DISCO, não a partição: "/dev/sda", não
  # "/dev/sda1". Descubra com:
  #   lsblk -no pkname "$(findmnt -no SOURCE /)"
  lcars.system.core.grubDevice = "";

  # --- ajustes de hardware --------------------------------------------
  # Ninguém detecta isto por você. Ligue à mão o que esta máquina for: vm traz
  # virtio e qemu-guest-agent, laptop traz tlp, limite de carga da bateria e
  # suspensão ao fechar a tampa.
  lcars.system.hardware.vm.enable = false;
  lcars.system.hardware.laptop.enable = false;

  # As linhas acima existem descomentadas de propósito: o instalador as
  # reescreve com `sed`, que só substitui linha já presente. Apagá-las faria
  # ele falhar em silêncio — foi o que aconteceu na #15.

  # --- outros ajustes desta máquina -----------------------------------
  # O profile e o settings.nix aplicam tudo com mkDefault, então basta declarar
  # aqui o que você quer diferente NESTA máquina:
  #
  #   lcars.profile                          = "basic";   # outro preset só aqui
  #   lcars.system.core.bootMountPath        = "/efi";    # se a ESP não é /boot
  #   lcars.system.core.swapFileSize         = 8192;
  #   lcars.system.wm.plasma.enable          = false;
  #   lcars.system.hardware.audio.enable     = true;      # som sem desktop
  #   lcars.system.hardware.keyboard.layout  = "br";      # teclado ABNT2
  #   lcars.system.hardware.keyboard.variant = "abnt2";
  #   lcars.system.security.sshKeys          = [ "ssh-ed25519 AAAA..." ];
  #
  #   lcars.user.starship.enable             = false;     # ambiente do usuário
  #   lcars.user.dotfiles.enable             = false;
}
