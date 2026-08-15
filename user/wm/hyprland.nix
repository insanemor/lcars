# hyprland.nix — o hyprland.conf, do lado do usuário.
#
# O compositor é do sistema (system/wm/hyprland.nix); os atalhos, as regras de
# janela e o que abre junto com a sessão são seus, e é isto aqui.
#
# Opt-in por `lcars.user.hyprland.enable`, declarada em user/options.nix e
# ligada no profile. A flag vem do config do NixOS, lida por `osConfig`.
#
# Referência de estrutura e atalhos: github.com/Sly-Harvey/NixOS (MIT).
{ osConfig, lib, pkgs, ... }:

let
  # SUPER é a tecla Windows. Escolha do Hyprland e dos rices em geral: não
  # colide com atalho de aplicativo, ao contrário de Alt ou Ctrl.
  mod = "SUPER";

  terminal = "kitty";
  launcher = "rofi -show drun";
in
lib.mkIf osConfig.lcars.user.hyprland.enable {
  wayland.windowManager.hyprland = {
    enable = true;

    # null porque quem instala é o módulo NixOS (programs.hyprland). A
    # documentação do home-manager pede exatamente isto: "Set this to null if
    # you use the NixOS module to install Hyprland." Sem isso, duas cópias do
    # compositor seriam gerenciadas em paralelo.
    package = null;
    portalPackage = null;

    settings = {
      # --- monitores ---------------------------------------------------
      # "preferred" usa a resolução que o monitor anuncia, "auto" posiciona,
      # e "1" é a escala. Serve para qualquer tela sem você medir nada — numa
      # VM inclusive. Para vários monitores, declare um por linha na máquina.
      monitor = ",preferred,auto,1";

      # --- o que sobe junto com a sessão --------------------------------
      # Sem papel de parede o fundo fica preto; sem a barra e as notificações,
      # a sessão parece travada porque nada dá retorno visual. As duas últimas
      # só têm efeito depois da camada 3, quando forem configuradas.
      exec-once = [
        "hyprpaper"
        "waybar"
        "swaync"
      ];

      # --- aparência ----------------------------------------------------
      # Valores sóbrios de propósito: o tema de verdade vem na camada 2, via
      # stylix, e sobrescreve as cores daqui.
      general = {
        gaps_in = 4;
        gaps_out = 8;
        border_size = 2;
        layout = "dwindle";
      };

      decoration = {
        rounding = 8;
        blur.enabled = true;
      };

      # Animações ligadas, mas curtas: numa VM sem aceleração 3D, animação
      # longa vira arrasto perceptível.
      animations = {
        enabled = true;
        animation = [
          "windows, 1, 3, default"
          "fade, 1, 3, default"
          "workspaces, 1, 3, default"
        ];
      };

      input = {
        # Vem do mesmo lugar que o console e o SDDM: um layout só para a
        # máquina inteira, definido em system/hardware/keyboard.nix.
        kb_layout = osConfig.lcars.system.hardware.keyboard.layout;
        kb_variant = osConfig.lcars.system.hardware.keyboard.variant;
        follow_mouse = 1;
        touchpad.natural_scroll = true;
      };

      # --- atalhos ------------------------------------------------------
      # O mínimo para a sessão não ser uma tela onde não se faz nada: abrir
      # terminal, abrir programa, fechar janela e sair.
      bind = [
        "${mod}, Return, exec, ${terminal}"
        "${mod}, D, exec, ${launcher}"
        "${mod}, Q, killactive,"
        "${mod} SHIFT, E, exit,"
        "${mod}, V, togglefloating,"
        "${mod}, F, fullscreen,"

        # Foco entre janelas, com as setas e com hjkl.
        "${mod}, left, movefocus, l"
        "${mod}, right, movefocus, r"
        "${mod}, up, movefocus, u"
        "${mod}, down, movefocus, d"
        "${mod}, H, movefocus, l"
        "${mod}, L, movefocus, r"
        "${mod}, K, movefocus, u"
        "${mod}, J, movefocus, d"

        # Captura de tela: seleciona uma região e joga na área de transferência.
        ''${mod} SHIFT, S, exec, grim -g "$(slurp)" - | wl-copy''
      ]
      # Workspaces 1–9: SUPER troca, SUPER+SHIFT leva a janela junto.
      ++ builtins.concatLists (builtins.genList
        (i:
          let n = toString (i + 1);
          in [
            "${mod}, ${n}, workspace, ${n}"
            "${mod} SHIFT, ${n}, movetoworkspace, ${n}"
          ])
        9);

      # Teclas de mídia e brilho. `bindel` repete enquanto segurada, que é o
      # que se espera de volume e brilho; `bindl` funciona com a tela travada.
      bindel = [
        ", XF86AudioRaiseVolume, exec, pamixer -i 5"
        ", XF86AudioLowerVolume, exec, pamixer -d 5"
        ", XF86MonBrightnessUp, exec, brightnessctl set +5%"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];

      bindl = [
        ", XF86AudioMute, exec, pamixer -t"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"
      ];

      # Arrastar e redimensionar com o mouse, segurando SUPER.
      bindm = [
        "${mod}, mouse:272, movewindow"
        "${mod}, mouse:273, resizewindow"
      ];
    };
  };

  # O terminal não vem com o Hyprland, e sem ele não há como se recuperar de
  # nada dentro da sessão.
  home.packages = with pkgs; [
    kitty
    # `rofi`, não `rofi-wayland`: os dois foram fundidos no nixpkgs, e o nome
    # antigo agora aborta a avaliação com um throw.
    rofi
  ];
}
