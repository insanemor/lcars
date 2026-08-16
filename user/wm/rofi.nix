# rofi.nix — o lançador.
#
# Só GEOMETRIA: largura, número de linhas, cantos, tamanho do ícone. A cor vem
# do stylix (system/theme/), que tem alvo para rofi.
#
# Cuidado ao mexer aqui
# ---------------------
# `programs.rofi.theme` é um attrset com merge RASO. O stylix declara a paleta
# inteira dentro da chave `"*"` — se este arquivo também definir `"*"`, uma das
# duas definições vence por completo e as cores somem. Por isso aqui só
# aparecem chaves que o stylix não usa.
#
# O repo de referência (github.com/Sly-Harvey/NixOS, MIT) tem SETE variantes de
# launcher e 17 arquivos `.rasi` só de paleta. Aqui é uma variante, e a paleta
# não existe como arquivo — é derivada do esquema.
{
  config,
  osConfig,
  lib,
  pkgs,
  ...
}:

lib.mkIf osConfig.lcars.user.hyprland.enable {
  programs.rofi = {
    enable = true;

    # `rofi`, não `rofi-wayland`: os dois foram fundidos no nixpkgs, e o nome
    # antigo aborta a avaliação com um throw.
    package = pkgs.rofi;

    # Sem isto, abrir um item que precisa de terminal não faz nada — e o rofi
    # não avisa.
    terminal = "${pkgs.kitty}/bin/kitty";

    extraConfig = {
      modi = "drun,run,window";
      show-icons = true;
      drun-display-format = "{name}";
    };

    # `mkLiteral` marca o valor para sair SEM aspas no .rasi — "11px" com
    # aspas não é uma medida válida para o rofi. O helper vem do config do
    # Home Manager, não do lib.
    theme =
      let
        inherit (config.lib.formats.rasi) mkLiteral;
      in
      lib.mkIf osConfig.lcars.system.theme.rice {
        "window" = {
          width = mkLiteral "600px";
          border = mkLiteral "2px";
          border-radius = mkLiteral "11px";
          padding = mkLiteral "12px";
        };

        "inputbar" = {
          padding = mkLiteral "8px 12px";
          border-radius = mkLiteral "10px";
          spacing = mkLiteral "8px";
        };

        "listview" = {
          lines = mkLiteral "8";
          columns = mkLiteral "1";
          spacing = mkLiteral "4px";
          padding = mkLiteral "8px 0 0 0";
        };

        "element" = {
          padding = mkLiteral "8px";
          border-radius = mkLiteral "10px";
          spacing = mkLiteral "10px";
        };

        "element-icon" = {
          size = mkLiteral "24px";
        };
      };
  };
}
