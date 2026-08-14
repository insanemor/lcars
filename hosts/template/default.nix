# --------------------------------------------------------------------
# Host de template — copie este diretório para adicionar uma nova máquina.
#
# Passos:
#   1. cp -r hosts/template hosts/<hostname>
#   2. Edite default.nix: troque o hostname e ative os módulos.
#   3. Na máquina alvo, rode:
#        nixos-generate-config --show-hardware-config > hardware-configuration.nix
#        cp hardware-configuration.nix hosts/<hostname>/hardware-configuration.nix
#      (ignorado pelo git por padrão — revise antes do commit.)
#   4. Registre o host em flake.nix dentro de nixosConfigurations.
# --------------------------------------------------------------------
{ config, lib, pkgs, vars, ... }:

{
  # Substitua pelo hostname real desta máquina.
  networking.hostName = "<replace-me>";

  boot.loader.systemd-boot.configurationLimit = 5;

  # --- seleção de módulos -------------------------------------------
  lcars.common.enable   = true;
  lcars.vm.enable       = false;
  lcars.laptop.enable   = false;
  lcars.desktop.enable  = true;

  # --- imports ------------------------------------------------------
  imports = [
    ./hardware-configuration.nix
  ];

  # --- documentação das chaves disponíveis --------------------------
  # services.printing.enable = false;
}
