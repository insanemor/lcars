# hyprland.nix — o compositor, do lado do sistema.
#
# A configuração em si (atalhos, monitores, regras de janela) NÃO fica aqui:
# ela é do usuário e mora em user/wm/hyprland.nix. Esta divisão é do repo
# (veja CLAUDE.md) e o Hyprland encaixa nela bem — o compositor é do sistema,
# o hyprland.conf é seu.
#
# O que o Hyprland precisa e não traz junto
# -----------------------------------------
# Ao contrário do Plasma, que vem com tudo, o Hyprland é só o compositor. Sem
# os utilitários abaixo a sessão sobe e você não consegue copiar e colar, mudar
# o volume nem o brilho da tela. Não são conforto — são o mínimo para a sessão
# ser utilizável.
#
# Referência de estrutura: github.com/Sly-Harvey/NixOS (MIT).
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.lcars.system.wm.hyprland;
in
{
  options.lcars.system.wm.hyprland = {
    enable = mkEnableOption "Hyprland, compositor Wayland com tiling";

    xwayland = mkOption {
      type = types.bool;
      default = true;
      description = ''
        XWayland, para os aplicativos que ainda não falam Wayland. Desligar
        deixa parte do software gráfico sem rodar; só faça isso sabendo o que
        deixa de funcionar.
      '';
    };
  };

  config = mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
      xwayland.enable = cfg.xwayland;
    };

    # O módulo acima já registra a sessão em services.displayManager.sessionPackages,
    # então o Hyprland aparece sozinho na tela de login. Quem decide qual sessão
    # vem pré-selecionada é system/wm/default.nix.

    # Portais XDG: é por eles que um aplicativo pede "abra um seletor de
    # arquivos" ou "compartilhe minha tela". O portal do Hyprland cuida do
    # screencast; o do GTK, dos diálogos de arquivo — sem ele, um "salvar como"
    # de aplicativo GTK não abre nada.
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };

    # Agente polkit: é quem mostra a caixa pedindo senha quando um programa
    # gráfico precisa de privilégio. O Plasma traz o dele embutido; no Hyprland,
    # sem isto, essas ações falham em silêncio.
    systemd.user.services.hyprpolkitagent = {
      description = "Agente de autenticação polkit do Hyprland";
      wantedBy = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
        Restart = "on-failure";
        RestartSec = 1;
      };
    };

    environment.systemPackages = with pkgs; [
      # Sem estes a sessão sobe e não se faz o básico:
      wl-clipboard # copiar e colar
      brightnessctl # brilho da tela
      pamixer # volume
      playerctl # play/pause das teclas de mídia

      # Ferramentas do próprio Hyprland, para o que um desktop faz o tempo todo:
      hyprpicker # conta-gotas de cor
      grim # captura de tela
      slurp # seleção de região, usada com o grim
      hyprpaper # papel de parede
    ];
  };
}
