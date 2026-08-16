# system/theme — a cor de tudo, a partir de um lugar só.
#
# Por que isto não fica em system/wm/: tema é transversal. Um esquema base16
# pinta o Hyprland, a waybar, o rofi, o terminal, os aplicativos GTK e Qt, o
# Plasma e até o console TTY. Amarrá-lo a um ambiente gráfico faria a cor do
# console depender de qual desktop está ligado, o que não faz sentido.
#
# O caminho alternativo, que este módulo evita
# --------------------------------------------
# O repo que serviu de referência (github.com/Sly-Harvey/NixOS, MIT) fia a cor
# à mão em cada programa: 17 paletas .rasi só para o rofi, CSS próprio para a
# barra, e assim por diante — 218 arquivos em desktop/hyprland. Funciona, mas
# cada programa novo é mais um arquivo de cor para manter em sincronia.
#
# O stylix parte de um esquema base16 e deriva o resto. Trocar de esquema é
# uma linha, e nada fica para trás.
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.lcars.system.theme;
in
{
  options.lcars.system.theme = {
    enable = mkEnableOption "tema unificado via stylix — cor, fontes e papel de parede";

    scheme = mkOption {
      type = types.str;
      default = "catppuccin-mocha";
      example = "gruvbox-dark-hard";
      description = ''
        Nome de um esquema base16, entre os que o pacote `base16-schemes`
        traz. Veja a lista com:

          ls ${"$"}{pkgs.base16-schemes}/share/themes/

        Alguns conhecidos: catppuccin-mocha, gruvbox-dark-hard, nord,
        tokyo-night-dark, rose-pine, dracula, solarized-dark.
      '';
    };

    polarity = mkOption {
      type = types.enum [
        "dark"
        "light"
        "either"
      ];
      default = "dark";
      description = ''
        Diz ao stylix se o esquema é claro ou escuro. Programas que têm modo
        claro e escuro separados usam isto para escolher.
      '';
    };

    wallpaper = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Imagem de fundo. `null` deixa o Hyprland pintar uma cor sólida
        derivada do esquema, sem daemon de papel de parede — é o padrão, e o
        que sobrevive numa VM sem aceleração 3D.

        Apontar para uma imagem liga o hyprpaper, que a renderiza.
      '';
    };

    # A forma é separada da cor de propósito: quem gosta da paleta mas não do
    # visual em ilhas não deve ter que escolher entre os dois.
    rice = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Aplica a geometria do rice: barra em ilhas arredondadas, borda de
        janela em gradiente, cantos e blur ajustados. Desligar deixa o visual
        padrão de cada programa, ainda pintado pelo esquema.

        Inspirado em github.com/Sly-Harvey/NixOS (MIT) — de lá vêm as formas;
        as cores continuam saindo do esquema base16 acima.
      '';
    };

    fonts = {
      size = mkOption {
        type = types.int;
        default = 11;
        description = "Corpo da fonte de interface, em pontos.";
      };

      monospace = mkOption {
        type = types.str;
        default = "JetBrainsMono Nerd Font";
        description = ''
          Fonte do terminal e do editor. Uma Nerd Font por padrão porque a
          waybar e o prompt usam ícones que só existem nelas — com uma fonte
          comum, aparecem quadradinhos vazios.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    stylix = {
      enable = true;
      inherit (cfg) polarity;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/${cfg.scheme}.yaml";

      # `null` quando você não aponta uma imagem, e isso é deliberado.
      #
      # O stylix exige `image` OU `base16Scheme`; como o esquema está definido
      # acima, a imagem é opcional. E ela não é neutra: definir `image` faz o
      # stylix auto-habilitar o alvo hyprpaper, que sobe um daemon com pilha
      # OpenGL — o mesmo que segfaultava na VM sem GPU (#26).
      #
      # Sem imagem, o fundo do Hyprland é o `misc.background_color` que o
      # próprio stylix deriva de base00: uma cor sólida, pintada pelo
      # compositor, sem processo nenhum a mais. O Plasma usa o papel de parede
      # padrão dele.
      #
      # Antes daqui havia um gradiente gerado com ImageMagick. Saiu: para duas
      # cores quase idênticas (base00 e base01) a diferença para a cor sólida é
      # imperceptível, e não compensava a dependência de build nem a superfície
      # de falha.
      image = cfg.wallpaper;

      fonts = {
        monospace = {
          package = pkgs.nerd-fonts.jetbrains-mono;
          name = cfg.fonts.monospace;
        };
        sansSerif = {
          package = pkgs.noto-fonts;
          name = "Noto Sans";
        };
        serif = {
          package = pkgs.noto-fonts;
          name = "Noto Serif";
        };
        emoji = {
          package = pkgs.noto-fonts-color-emoji;
          name = "Noto Color Emoji";
        };

        sizes = {
          applications = cfg.fonts.size;
          terminal = cfg.fonts.size;
          desktop = cfg.fonts.size;
          popups = cfg.fonts.size;
        };
      };
    };
  };
}
