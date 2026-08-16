# hyprland.nix — o hyprland.conf, do lado do usuário.
#
# O compositor é do sistema (system/wm/hyprland.nix); os atalhos, as regras de
# janela e o que abre junto com a sessão são seus, e é isto aqui.
#
# Opt-in por `lcars.user.hyprland.enable`, declarada em user/options.nix e
# ligada no profile. A flag vem do config do NixOS, lida por `osConfig`.
#
# Referência de estrutura e atalhos: github.com/Sly-Harvey/NixOS (MIT).
{ config, osConfig, lib, pkgs, ... }:

let
  rice = osConfig.lcars.system.theme.rice;
  # As cores do esquema, como o stylix as resolveu. Nada de hex aqui: trocar
  # `lcars.system.theme.scheme` muda a borda junto.
  cores = config.lib.stylix.colors;

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
      # Vazia, e é para continuar assim.
      #
      # Barra, notificações e papel de parede sobem por unidades systemd dos
      # próprios módulos (programs.waybar, services.swaync, services.hyprpaper
      # — este último configurado pelo stylix). O systemd reinicia o que cai e
      # responde a `systemctl --user status`; pelo exec-once, falha é silêncio.
      #
      # DUAS REGRAS, aprendidas errando as duas:
      #
      #   1. nunca ponha aqui algo que o módulo não instale — o Hyprland tenta
      #      executar, falha calado, e a tela fica sem pista do motivo (#19);
      #   2. nunca ponha aqui algo que JÁ suba por systemd — a segunda
      #      instância morre porque a primeira detém o socket, e o usuário vê
      #      "erro fatal" de um programa que na verdade está funcionando (#24).
      #
      # Só entra aqui o que não tiver um serviço próprio.
      exec-once = [ ];

      # --- aparência ----------------------------------------------------
      # Só geometria. As CORES vêm do stylix (system/theme/), que tem alvo
      # para hyprland — não há paleta escrita neste arquivo.
      general = {
        gaps_in = 4;
        gaps_out = if rice then 9 else 8;
        border_size = 2;
        layout = "dwindle";
      }
      # Borda em gradiente a 45°, a assinatura visual do rice de referência.
      #
      # mkForce porque o stylix declara `col.active_border` sem mkDefault
      # (modules/hyprland/hm.nix) — sem forçar, as duas definições colidem.
      # Se um dia ele passar a usar mkDefault, este mkForce pode sair.
      // lib.optionalAttrs rice {
        "col.active_border" =
          lib.mkForce "rgb(${cores.base0E}) rgb(${cores.base0C}) 45deg";
      };

      decoration = {
        rounding = if rice then 10 else 8;

        blur = {
          enabled = true;
        }
        // lib.optionalAttrs rice {
          # Valores do repo de referência. Blur é caro: numa VM sem aceleração
          # 3D, subir passes é o primeiro lugar onde a interface engasga.
          size = 6;
          passes = 2;
          ignore_opacity = true;
          new_optimizations = true;
        };

        # Desligada no rice: com borda em gradiente e blur, a sombra vira
        # ruído em volta de cada janela.
        shadow.enabled = !rice;
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

      # --- fundo, sem daemon ---------------------------------------------
      # `misc.background_color` NÃO é declarado aqui: o stylix já o define a
      # partir de base00 (modules/hyprland/hm.nix), no formato rgb() que o
      # Hyprland espera.
      #
      # As duas linhas abaixo, sim. O stylix só liga `disable_hyprland_logo`
      # quando o hyprpaper está habilitado — e nós o desligamos no caso padrão
      # (veja services.hyprpaper mais abaixo). Sem elas, o logo do Hyprland
      # ficaria desenhado por cima da cor de fundo.
      misc = {
        disable_hyprland_logo = true;
        force_default_wallpaper = 0;
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

        # Painel de notificações.
        "${mod}, N, exec, swaync-client -t -sw"
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
  #
  # O rofi NÃO está aqui: quem o instala é user/wm/rofi.nix, via programs.rofi.
  # Pôr nos dois lugares daria duas cópias no PATH, e a do home.packages não
  # teria a configuração.
  home.packages = [ pkgs.kitty ];
}
