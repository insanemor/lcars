# profile "basic" — máquina headless.
#
# Base do sistema, acesso por ssh, nada de gráfico. É o default: uma máquina
# que não declara `lcars.profile` sobe assim.
#
# Este arquivo é o painel da máquina: o que não estiver ligado aqui (ou na
# própria máquina) não sobe — vale para os dois lados, system/ e user/.
{ config, lib, ... }:

with lib;

{
  config = mkIf (config.lcars.profile == "basic") {
    # --- sistema (system/) --------------------------------------------
    lcars.system.core.enable = mkDefault true;
    lcars.system.security.enable = mkDefault true;

    lcars.system.wm.plasma.enable = mkDefault false;
    lcars.system.wm.hyprland.enable = mkDefault false;

    # Sem tema: numa máquina headless, um esquema de cores para GTK e Qt é
    # peso morto. O console usa a paleta padrão do kernel.
    lcars.system.theme.enable = mkDefault false;

    # 1Password é proprietário e puxa a GUI junto; numa máquina headless não
    # ganha nada. Ligue explicitamente se quiser só o CLI aqui.
    lcars.system.app.onePassword.enable = mkDefault false;

    # Teclado sim: mesmo headless, alguém acaba no TTY em algum momento.
    # Áudio não: sem placa de som ou sem ninguém para ouvir, o PipeWire só
    # acrescentaria um daemon.
    lcars.system.hardware.keyboard.enable = mkDefault true;
    lcars.system.hardware.audio.enable = mkDefault false;

    # --- ambiente do usuário (user/) ----------------------------------
    # Só o que serve a quem entra por ssh para trabalhar. Ficam de fora:
    # direnv (não há projetos aqui) e dotfiles (dependem de sessão aberta no
    # 1Password, que numa máquina headless normalmente não existe).
    lcars.user.zsh.enable = mkDefault true;
    lcars.user.git.enable = mkDefault true;

    lcars.user.direnv.enable = mkDefault false;
    lcars.user.dotfiles.enable = mkDefault false;
    lcars.user.hyprland.enable = mkDefault false;
    lcars.user.noctalia.enable = mkDefault false;
  };
}
