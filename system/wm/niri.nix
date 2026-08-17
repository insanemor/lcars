# niri.nix — o compositor, do lado do sistema.
#
# A configuração (atalhos, monitores, regras) NÃO fica aqui: ela é do usuário e
# mora em user/wm/niri.nix, no formato KDL. Esta divisão é do repo — veja o
# CLAUDE.md.
#
# O que o niri é, e por que ele
# -----------------------------
# Tiling scrollable. As janelas formam uma fita horizontal que se estende sem
# limite, e a tela rola por ela — abrir uma janela nova não redivide o espaço
# das outras, como faz o `dwindle` do Hyprland. É uma arquitetura diferente, não
# um modo de layout: nenhuma configuração de Hyprland produz esse
# comportamento, e foi por isso que ele entrou no lugar dele (#34).
#
# O que o módulo do nixpkgs já resolve
# ------------------------------------
# Bastante, e por isso este arquivo é curto. `programs.niri.enable` registra a
# sessão em `displayManager.sessionPackages`, liga o gnome-keyring, e monta os
# portais XDG com a combinação que o upstream recomenda (gnome para screencast
# e captura, gtk para o resto).
#
# O que ele NÃO faz, e nós fazemos aqui: os utilitários de sessão.
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.lcars.system.wm.niri;
in
{
  options.lcars.system.wm.niri = {
    enable = mkEnableOption "niri, compositor Wayland com tiling scrollable";

    useNautilus = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Usa o Nautilus como seletor de arquivos do portal, em vez do diálogo
        do GTK.

        Ligado por padrão, e não é só estética: sem Plasma não há mais Dolphin,
        e este é o gerenciador de arquivos que sobra — o portal o abre em todo
        "salvar como" e "abrir arquivo". Desligar deixa o seletor mais simples
        do GTK, que funciona mas não navega bem.
      '';
    };
  };

  config = mkIf cfg.enable {
    programs.niri = {
      enable = true;
      inherit (cfg) useNautilus;
    };

    # XWayland NÃO vem daqui. O módulo do nixpkgs monta a sessão com
    # `enableXWayland = false`, porque o niri não embute um servidor X: ele usa
    # o xwayland-satellite, um processo à parte que sobe sob demanda.
    #
    # Quem o coloca no PATH é o home-manager, em user/wm/niri.nix
    # (`xwaylandSatellitePackage`, ligado por padrão) — e o niri o inicia
    # sozinho quando um aplicativo X11 aparece. Sem ele, esses aplicativos
    # simplesmente não abrem.

    # Agente polkit: quem mostra a caixa pedindo senha quando um programa
    # gráfico precisa de privilégio.
    #
    # Não há serviço aqui, ao contrário do que havia no Hyprland: o noctalia
    # traz o dele, e é ele que usamos — `polkit_agent = true` no
    # user/wm/noctalia-config.toml. Dois agentes disputando o mesmo serviço é
    # conflito, não redundância, e foi a lição da #24.

    environment.systemPackages = with pkgs; [
      # Sem estes a sessão sobe e não se faz o básico:
      wl-clipboard # copiar e colar
      brightnessctl # brilho da tela
      pamixer # volume
      playerctl # play/pause das teclas de mídia

      # grim e slurp NÃO estão aqui, ao contrário do que havia no Hyprland: o
      # niri tem captura de tela nativa, com seleção de região, janela e monitor
      # (as ações `screenshot`, `screenshot-window` e `screenshot-screen`).
    ];
  };
}
