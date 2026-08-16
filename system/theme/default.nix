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
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.lcars.system.theme;

  # Papel de parede gerado a partir das cores do próprio esquema.
  #
  # A alternativa seria versionar um .webp de alguns MB — o repo de referência
  # tem 18 deles. Num repositório que se quer forkável e legível em diff, um
  # gradiente derivado da paleta dá um fundo coerente sem acrescentar binário.
  # Para usar uma foto sua, aponte `wallpaper` para o arquivo.
  gradiente =
    pkgs.runCommand "lcars-wallpaper.png"
      { nativeBuildInputs = [ pkgs.imagemagick ]; }
      ''
        magick -size 3840x2160 \
          gradient:'#${config.lib.stylix.colors.base00}-#${config.lib.stylix.colors.base01}' \
          "$out"
      '';
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
      type = types.enum [ "dark" "light" "either" ];
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
        Imagem de fundo. `null` gera um gradiente a partir das cores do
        esquema — sem binário no repositório.
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
      polarity = cfg.polarity;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/${cfg.scheme}.yaml";

      # O stylix exige `image` ou `base16Scheme`; temos os dois, e a imagem
      # serve para o papel de parede, não para derivar a paleta.
      image = if cfg.wallpaper != null then cfg.wallpaper else gradiente;

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
