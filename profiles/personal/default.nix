# profile "personal" — estação de trabalho completa.
#
# É o que o instalador one-shot escolhe por padrão: desktop KDE Plasma, 1Password
# com CLI e GUI, e as ferramentas de linha de comando do dia a dia.
{ config, lib, ... }:

with lib;

{
  config = mkIf (config.lcars.profile == "personal") {
    lcars.core.enable     = mkDefault true;
    lcars.security.enable = mkDefault true;

    lcars.wm.plasma.enable = mkDefault true;
    lcars.apps.onePassword.enable = mkDefault true;

    # Estes pacotes não são do sistema, são do usuário — e qual conjunto
    # faz sentido depende do papel da máquina, então é o profile que decide.
    lcars.core.userPackages = mkDefault [
      "ripgrep"
      "fd"
      "bat"
      "eza"
    ];
  };
}
