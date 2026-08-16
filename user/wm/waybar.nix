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

    # Ligar pelo systemd, e não pelo exec-once do Hyprland: assim a barra
    # reinicia sozinha se cair, e o `systemctl --user status waybar` diz o que
    # aconteceu. Pelo exec-once, uma falha é silenciosa.
    systemd = {
      enable = true;
      target = "graphical-session.target";
    };

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
