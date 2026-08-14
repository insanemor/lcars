# --------------------------------------------------------------------
# Host de template — copie este diretório para adicionar uma nova máquina.
#
# Passos:
#   1. cp -r hosts/template hosts/<hostname>
#   2. Edite este arquivo e ative os módulos que a máquina precisa.
#   3. Na máquina alvo, gere o hardware-configuration.nix:
#        sudo nixos-generate-config --show-hardware-config \
#          > hosts/<hostname>/hardware-configuration.nix
#   4. `git add -f hosts/<hostname>` — flakes só enxergam arquivos que o git
#      rastreia, e hardware-configuration.nix está no .gitignore.
#
# Não é preciso registrar nada no flake.nix: hosts/<dir> vira uma entrada de
# nixosConfigurations automaticamente, e networking.hostName recebe o nome do
# diretório. `template` e `common` são ignorados pela auto-descoberta.
# --------------------------------------------------------------------
{ config, lib, pkgs, vars, ... }:

{
  # --- imports ------------------------------------------------------
  imports = [
    ./hardware-configuration.nix
  ];

  # --- seleção de módulos -------------------------------------------
  lcars.common.enable   = true;
  lcars.vm.enable       = false;
  lcars.laptop.enable   = false;
  lcars.desktop.enable  = true;

  # --- boot ---------------------------------------------------------
  # "systemd-boot" exige UEFI. Em BIOS legado troque para "grub" e aponte
  # lcars.common.grubDevice para o disco de boot.
  lcars.common.bootLoader = "systemd-boot";
  # lcars.common.grubDevice = "/dev/sda";

  # Descomente se o hardware-configuration.nix não trouxer swap nenhum.
  # lcars.common.swapFileSize = 8192;

  # Suas chaves públicas SSH — o sshd deste flake só aceita chave.
  # lcars.common.sshKeys = [ "ssh-ed25519 AAAA..." ];
}
