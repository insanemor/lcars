# --------------------------------------------------------------------
# Máquina de template.
#
# Profile, bootloader, locale e tudo mais vêm do `settings.nix` na raiz. O que
# mora aqui é o que só faz sentido para ESTA máquina — as flags de hardware
# abaixo — e os overrides, caso o mesmo repo sirva mais de uma.
#
#   1. cp -r machines/template machines/<nome>
#   2. Na máquina alvo, gere o hardware-configuration.nix:
#        sudo nixos-generate-config --show-hardware-config \
#          > machines/<nome>/hardware-configuration.nix
#   3. Aponte systemSettings.hostname para <nome> no settings.nix
#   4. `git add -f machines/<nome>` — flakes só enxergam arquivos que o git
#      rastreia, e o hardware-configuration.nix está no .gitignore.
#
# `machines/<dir>` vira uma entrada de nixosConfigurations automaticamente, e
# é o nome do diretório que vira networking.hostName. `template` é ignorado
# pela auto-descoberta. O instalador nomeia o diretório com o modelo do
# hardware; na mão, escolha o que quiser.
# --------------------------------------------------------------------
{ config, lib, pkgs, sys, user, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # --- ajustes de hardware ------------------------------------------
  # Ninguém detecta isto por você — nem o instalador. Ligue à mão o que
  # esta máquina for: vm traz virtio e qemu-guest-agent, laptop traz tlp,
  # limite de carga da bateria e suspensão ao fechar a tampa.
  lcars.system.hardware.vm.enable     = false;
  lcars.system.hardware.laptop.enable = false;

  # Áudio e teclado vêm do profile. O layout é o único que costuma variar de
  # máquina para máquina — o default é US internacional, com acentuação:
  #
  #   lcars.system.hardware.keyboard.layout  = "br";
  #   lcars.system.hardware.keyboard.variant = "abnt2";
  #
  # Ele vale nos dois contextos de uma vez, console e sessão gráfica.

  # --- overrides do profile e do settings.nix -----------------------
  # O profile e o settings aplicam tudo com mkDefault, então basta declarar
  # aqui o que você quer diferente NESTA máquina. Vale para os dois lados:
  #
  #   lcars.profile                   = "basic";   # outro preset só aqui
  #
  #   lcars.system.core.bootLoader    = "grub";    # sistema
  #   lcars.system.core.grubDevice    = "/dev/sda";
  #   lcars.system.core.swapFileSize  = 8192;
  #   lcars.system.wm.plasma.enable   = false;
  #   lcars.system.hardware.audio.enable = true;   # som sem desktop
  #   lcars.system.security.sshKeys   = [ "ssh-ed25519 AAAA..." ];
  #
  #   lcars.user.starship.enable      = false;     # ambiente do usuário
  #   lcars.user.dotfiles.enable      = false;
}
