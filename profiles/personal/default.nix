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
    lcars.system.core.enable = mkDefault true;
    lcars.system.security.enable = mkDefault true;

    lcars.system.app.onePassword.enable = mkDefault true;

    # O niri é o ambiente gráfico, e é o único: Plasma e Hyprland saíram na
    # #34. Como não há segunda sessão na tela de login, se ele não subir a
    # volta é pelo TTY (Ctrl+Alt+F2), editando este arquivo ou o
    # machines/<host> e rodando `nupdate`.
    lcars.system.wm.niri.enable = mkDefault true;

    # Tema: um esquema base16 pinta o terminal, o shell, GTK, Qt e o console
    # de uma vez. Trocar de esquema é uma linha — lcars.system.theme.scheme.
    # O niri é a exceção: o stylix não tem alvo para ele, e user/wm/niri.nix
    # aplica as mesmas cores à mão.
    lcars.system.theme.enable = mkDefault true;

    # Áudio é independente do desktop: o Plasma não o liga por trás, é aqui
    # que os dois se encontram. O teclado vale em qualquer máquina; o layout
    # em si vem do default do módulo, ou da máquina, se ela tiver outro.
    lcars.system.hardware.audio.enable = mkDefault true;
    lcars.system.hardware.keyboard.enable = mkDefault true;

    # Estes pacotes não são do sistema, são do usuário — e qual conjunto
    # faz sentido depende do papel da máquina, então é o profile que decide.
    lcars.system.core.userPackages = mkDefault [
      "ripgrep"
      "fd"
      "bat"
      "eza"
      "gh"
      "mtr"
    ];

    # --- ambiente do usuário (user/) ----------------------------------
    # Num desktop, tudo: o direnv e o gancho de dotfiles fazem diferença no
    # uso interativo.
    lcars.user.zsh.enable = mkDefault true;
    lcars.user.atuin.enable = mkDefault true;
    lcars.user.fzf.enable = mkDefault true;
    lcars.user.zoxide.enable = mkDefault true;
    lcars.user.git.enable = mkDefault true;
    lcars.user.direnv.enable = mkDefault true;
    lcars.user.dotfiles.enable = mkDefault true;
    lcars.user.kitty.enable = mkDefault true;
    lcars.user.vivaldi.enable = mkDefault true;
    lcars.user.herdr.enable = mkDefault true;
    lcars.user.herdrTelegram.enable = mkDefault true;
    lcars.user.nvim.enable = mkDefault true;
    lcars.user.claudeCode.enable = mkDefault true;
    lcars.user.opencode.enable = mkDefault true;
    lcars.user.crush.enable = mkDefault false;
    lcars.user.niri.enable = mkDefault true;
    lcars.user.noctalia.enable = mkDefault true;
    lcars.user.noctalia.plugins.wallhaven.enable = mkDefault true;
    lcars.user.noctalia.plugins.nixMonitor.enable = mkDefault true;
    lcars.user.noctalia.plugins.niriDisplays.enable = mkDefault true;
    lcars.user.noctalia.plugins.niriAnimations.enable = mkDefault true;
    lcars.user.noctalia.plugins.miniDocker.enable = mkDefault true;
    lcars.user.noctalia.plugins.gitCompanion.enable = mkDefault true;
    lcars.user.noctalia.plugins.driveHealth.enable = mkDefault true;
    lcars.user.noctalia.plugins.aiUsagebar.enable = mkDefault true;
    lcars.user.noctalia.plugins.mpvpaper.enable = mkDefault true;
    lcars.user.noctalia.plugins.notes.enable = mkDefault true;
    lcars.user.yazi.enable = mkDefault true;
    lcars.user.lazygit.enable = mkDefault true;
    lcars.user.onedrive.enable = mkDefault true;
    lcars.user.sudoAskpass.enable = mkDefault true;
    lcars.user.vscode.enable = mkDefault true;
    lcars.user.nautilus.enable = mkDefault true;
  };
}
