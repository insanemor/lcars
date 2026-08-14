# --------------------------------------------------------------------
# Máquina de template.
#
# Com UMA máquina você provavelmente nunca precisa editar este arquivo:
# profile, bootloader, locale e tudo mais vêm do `settings.nix` na raiz.
# O que mora aqui é o que só faz sentido para ESTA máquina — e os overrides,
# caso o mesmo repo sirva mais de uma.
#
#   1. cp -r machines/template machines/<hostname>
#   2. Na máquina alvo, gere o hardware-configuration.nix:
#        sudo nixos-generate-config --show-hardware-config \
#          > machines/<hostname>/hardware-configuration.nix
#   3. Aponte systemSettings.hostname para <hostname> no settings.nix
#   4. `git add -f settings.nix machines/<hostname>` — flakes só enxergam
#      arquivos que o git rastreia.
#
# `machines/<dir>` vira uma entrada de nixosConfigurations automaticamente.
# `template` é ignorado pela auto-descoberta.
# --------------------------------------------------------------------
{ config, lib, pkgs, sys, user, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # --- ajustes de hardware ------------------------------------------
  # Ligados pela detecção do instalador; ajuste se ele errar.
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
  #   lcars.wm.gnome.enable  = false;
  #   lcars.security.sshKeys = [ "ssh-ed25519 AAAA..." ];
}
