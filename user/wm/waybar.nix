# waybar.nix — a barra.
#
# Aqui está só o LAYOUT: quais módulos, em que ordem, o que cada um mostra. A
# cor não está aqui — vem do stylix (system/theme/), que tem alvo para waybar.
#
# É essa divisão que evita o que acontece no repo de referência
# (github.com/Sly-Harvey/NixOS, MIT): lá cada tema de barra é um CSS próprio,
# e trocar de esquema significa reescrever o CSS.
{ osConfig, lib, ... }:

lib.mkIf osConfig.lcars.user.waybar.enable {
  programs.waybar = {
    enable = true;

    # --- a forma -------------------------------------------------------
    # Três ilhas arredondadas sobre uma barra transparente, com os workspaces
    # como pílulas — a assinatura visual de github.com/Sly-Harvey/NixOS (MIT).
    #
    # Nenhum hexadecimal aqui. `@base00`…`@base0F` são declaradas pelo stylix
    # no CSS que ele gera, e é isso que faz trocar `lcars.system.theme.scheme`
    # repintar a barra junto. No repo de origem essa paleta está fixa em 30
    # linhas de `@define-color`, e mudar de esquema exige reescrevê-las.
    #
    # `mkAfter` porque `programs.waybar.style` é do tipo `lines`: as definições
    # se concatenam, e a nossa precisa vir DEPOIS da do stylix para vencer no
    # cascade.
    style = lib.mkIf osConfig.lcars.system.theme.rice (lib.mkAfter ''
      /* A barra em si some: quem tem fundo são as ilhas. */
      window#waybar {
        background: transparent;
      }

      /* As três ilhas. Laterais com a cor de destaque, centro discreto —
         assim o relógio não compete com o resto. */
      .modules-left,
      .modules-center,
      .modules-right {
        background: @base00;
        border-radius: 11px;
        margin: 4px 0;
        padding: 0 10px;
      }

      .modules-left,
      .modules-right {
        border: 1px solid @base0D;
      }

      .modules-center {
        border: 1px solid @base03;
      }

      tooltip {
        background: @base00;
        border: 1px solid @base0D;
        border-radius: 9px;
      }

      /* Workspaces como pílulas. O stylix os desenha com uma borda embaixo;
         aqui a marcação do ativo é a cor e a largura. */
      #workspaces button {
        border: none;
        border-bottom: none;
        border-radius: 10px;
        padding: 0 6px;
        color: @base04;
        transition: all 0.2s ease;
      }

      #workspaces button:hover {
        background: @base02;
        color: @base05;
      }

      #workspaces button.active {
        color: @base09;
        padding: 0 11px;
      }

      #workspaces button.urgent {
        color: @base08;
      }

      /* Espaço entre os módulos de cada ilha, para não ficarem colados. */
      #clock,
      #battery,
      #network,
      #pulseaudio,
      #tray,
      #window {
        padding: 0 8px;
      }

      /* Aviso de bateria: o único lugar em que a cor grita de propósito. */
      #battery.warning {
        color: @base0A;
      }

      #battery.critical {
        color: @base08;
      }
    '');

    # Ligar pelo systemd, e não pelo exec-once do Hyprland: assim a barra
    # reinicia sozinha se cair, e o `systemctl --user status waybar` diz o que
    # aconteceu. Pelo exec-once, uma falha é silenciosa.
    #
    # Sem declarar o alvo: o default de `systemd.targets` já é
    # `[ config.wayland.systemd.target ]`, que é a sessão gráfica. Declarar à
    # mão não acrescentava nada e ainda usava `target` (string), renomeado para
    # `targets` (lista) — era de onde vinha o aviso de option deprecada.
    systemd.enable = true;

    settings.principal = {
      layer = "top";
      position = "top";
      height = 34;

      modules-left = [ "hyprland/workspaces" "hyprland/window" ];
      modules-center = [ "clock" ];
      modules-right = [ "pulseaudio" "network" "battery" "tray" ];

      "hyprland/workspaces" = {
        format = "{id}";
        on-click = "activate";
        # Mostra só os que existem: numerar 1–10 fixo polui a barra com
        # workspaces vazios.
        all-outputs = true;
      };

      "hyprland/window" = {
        format = "{title}";
        max-length = 60;
        separate-outputs = true;
      };

      clock = {
        format = "{:%H:%M}";
        format-alt = "{:%d/%m/%Y  %H:%M}";
        tooltip-format = "<tt><small>{calendar}</small></tt>";
      };

      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = "󰝟 mudo";
        format-icons.default = [ "󰕿" "󰖀" "󰕾" ];
        on-click = "pamixer -t";
        scroll-step = 5;
      };

      network = {
        format-wifi = "󰖩 {essid}";
        format-ethernet = "󰈀 {ipaddr}";
        format-disconnected = "󰖪 sem rede";
        tooltip-format = "{ifname}: {ipaddr}";
      };

      # Numa máquina sem bateria o módulo simplesmente não aparece, então
      # deixá-lo declarado não atrapalha desktop nem VM.
      battery = {
        format = "{icon} {capacity}%";
        format-charging = "󰂄 {capacity}%";
        format-icons = [ "󰁺" "󰁽" "󰂀" "󰂂" "󰁹" ];
        states = {
          warning = 30;
          critical = 15;
        };
      };

      tray.spacing = 8;
    };
  };
}
