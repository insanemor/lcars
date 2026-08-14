# hardware-configuration.nix — PLACEHOLDER.
#
# Este arquivo precisa ser uma expressão Nix válida (um módulo), senão o flake
# nem chega a avaliar. Substitua-o pelo real, gerado na máquina alvo:
#
#   sudo nixos-generate-config --show-hardware-config \
#     > hosts/<host>/hardware-configuration.nix
#
# É ele quem declara fileSystems, swapDevices e boot.initrd — nada disso é
# definido pelos módulos lcars.
#
# Está no .gitignore por padrão (pode conter números de série). Como flakes só
# leem arquivos rastreados pelo git, adicione-o com `git add -f` depois de
# revisar.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ ];
}
