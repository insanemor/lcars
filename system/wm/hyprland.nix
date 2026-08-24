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

    # Agente polkit: quem mostra a caixa pedindo senha quando um programa
    # gráfico precisa de privilégio.
    #
    # Não há serviço aqui, ao contrário do que este arquivo tinha antes da
    # #34: o noctalia traz o dele, ligado por `polkit_agent = true` em
    # user/wm/noctalia-config.toml — hoje o mesmo agente serve niri e
    # Hyprland. Somar `hyprpolkitagent` aqui seria dois agentes disputando o
    # mesmo serviço, a lição da #24.
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

      # hyprpaper NÃO está aqui: o papel de parede é o plugin
      # noctalia/mpvpaper (compositor-agnóstico, já usado com o niri), e
      # lcars.system.theme.wallpaper continua null por padrão — apontar uma
      # imagem ali auto-ligaria o alvo hyprpaper do stylix, que entraria em
      # conflito com o mpvpaper (mesmo raciocínio documentado em
      # machines/Standard-PC-Q35-ICH9-2009/default.nix para o regreet).
    ];
  };
}
