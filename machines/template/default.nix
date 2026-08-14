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
#   4. `git add -f settings.nix machines/<nome>` — flakes só enxergam
#      arquivos que o git rastreia.
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
  lcars.hardware.vm.enable     = false;
  lcars.hardware.laptop.enable = false;

  # --- overrides do settings.nix ------------------------------------
  # Tudo que vem do settings é aplicado com mkDefault, então basta declarar
  # aqui o que você quer diferente NESTA máquina:
  #
  #   lcars.profile          = "basic";        # outro preset só aqui
  #   lcars.core.bootLoader  = "grub";
  #   lcars.core.grubDevice  = "/dev/sda";
  #   lcars.core.swapFileSize = 8192;
  #   lcars.wm.plasma.enable = false;
  #   lcars.security.sshKeys = [ "ssh-ed25519 AAAA..." ];
}
