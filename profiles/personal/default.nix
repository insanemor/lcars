# profile "personal" — estação de trabalho completa.
#
# É o que o instalador escolhe por padrão: desktop KDE Plasma, 1Password com
# CLI e GUI, e o ambiente de linha de comando do dia a dia.
#
# Este arquivo é o painel da máquina: o que não estiver ligado aqui (ou na
# própria máquina) não sobe — vale para os dois lados, system/ e user/.
{ config, lib, ... }:

with lib;

{
  config = mkIf (config.lcars.profile == "personal") {
    # --- sistema (system/) --------------------------------------------
    lcars.system.core.enable     = mkDefault true;
    lcars.system.security.enable = mkDefault true;

    lcars.system.wm.plasma.enable       = mkDefault true;
    lcars.system.app.onePassword.enable = mkDefault true;

    # Áudio é independente do desktop: o Plasma não o liga por trás, é aqui
    # que os dois se encontram. O teclado vale em qualquer máquina; o layout
    # em si vem do default do módulo, ou da máquina, se ela tiver outro.
    lcars.system.hardware.audio.enable    = mkDefault true;
    lcars.system.hardware.keyboard.enable = mkDefault true;

    # Estes pacotes não são do sistema, são do usuário — e qual conjunto
    # faz sentido depende do papel da máquina, então é o profile que decide.
    lcars.system.core.userPackages = mkDefault [
      "ripgrep"
      "fd"
      "bat"
      "eza"
    ];

    # --- ambiente do usuário (user/) ----------------------------------
    # Num desktop, tudo: o prompt, o direnv e o gancho de dotfiles fazem
    # diferença no uso interativo.
    lcars.user.zsh.enable      = mkDefault true;
    lcars.user.starship.enable = mkDefault true;
    lcars.user.git.enable      = mkDefault true;
    lcars.user.direnv.enable   = mkDefault true;
    lcars.user.dotfiles.enable = mkDefault true;
  };
}
