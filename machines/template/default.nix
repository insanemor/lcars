# --------------------------------------------------------------------
# Máquina de template — copie este diretório para adicionar uma nova.
#
#   1. cp -r machines/template machines/<hostname>
#   2. Escolha o profile e ajuste o que for específico desta máquina.
#   3. Na máquina alvo, gere o hardware-configuration.nix:
#        sudo nixos-generate-config --show-hardware-config \
#          > machines/<hostname>/hardware-configuration.nix
#   4. `git add -f machines/<hostname>` — flakes só enxergam arquivos que o git
#      rastreia, e hardware-configuration.nix está no .gitignore.
#
# Não é preciso registrar nada no flake.nix: machines/<dir> vira uma entrada de
# nixosConfigurations automaticamente, e networking.hostName recebe o nome do
# diretório. `template` é ignorado pela auto-descoberta.
# --------------------------------------------------------------------
{ config, lib, pkgs, vars, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # --- o que esta máquina é -----------------------------------------
  # "basic" = headless; "personal" = desktop completo. Veja profiles/.
  lcars.profile = "personal";

  # --- ajustes de hardware ------------------------------------------
  lcars.hardware.vm.enable     = false;
  lcars.hardware.laptop.enable = false;

  # "systemd-boot" exige UEFI. Em BIOS legado troque para "grub" e aponte
  # lcars.core.grubDevice para o disco de boot.
  lcars.core.bootLoader = "systemd-boot";
  # lcars.core.grubDevice = "/dev/sda";

  # Descomente se o hardware-configuration.nix não trouxer swap nenhum.
  # lcars.core.swapFileSize = 8192;

  # --- overrides do profile -----------------------------------------
  # O profile define as flags com mkDefault, então basta declarar aqui a que
  # você quer diferente:
  # lcars.wm.gnome.enable = false;

  # Suas chaves públicas SSH — o sshd só aceita chave.
  # lcars.security.sshKeys = [ "ssh-ed25519 AAAA..." ];
}
