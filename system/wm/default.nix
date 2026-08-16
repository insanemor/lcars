# system/wm — ambientes gráficos, e o que eles compartilham.
#
# Mais de um pode estar ligado ao mesmo tempo: os dois aparecem na tela de
# login e você escolhe na hora. É o que torna seguro experimentar um ambiente
# novo sem perder o que já funciona.
#
# Este arquivo existe porque algumas coisas são de "ter ambiente gráfico", não
# de um WM em particular, e declará-las dentro de cada módulo geraria conflito
# de definição no instante em que dois estivessem ligados:
#
#   - o SDDM em si
#   - qual sessão abre por padrão
#   - as fontes e o dconf
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.lcars.system.wm;
  algumWm = cfg.plasma.enable || cfg.hyprland.enable;

  # Quando você não escolhe, o Plasma ganha: é o ambiente completo, e serve de
  # rede se o outro não subir. Trocar é uma linha em machines/<host>.
  automatica =
    if cfg.plasma.enable then
      (if cfg.plasma.wayland then "plasma" else "plasmax11")
    else if cfg.hyprland.enable then
      "hyprland"
    else
      "";

  sessao = if cfg.defaultSession != "" then cfg.defaultSession else automatica;
in
{
  imports = [
    ./plasma.nix
    ./hyprland.nix
  ];

  options.lcars.system.wm = {
    defaultSession = mkOption {
      type = types.str;
      default = "";
      example = "hyprland";
      description = ''
        Sessão pré-selecionada na tela de login. Vazio = decide sozinho,
        preferindo o Plasma quando os dois estão ligados.

        Os nomes vêm dos .desktop que cada ambiente instala: "plasma",
        "plasmax11", "hyprland". Com o sistema no ar, `ls /run/current-system/sw/share/wayland-sessions/`
        mostra os que existem.
      '';
    };

    sddm.wayland = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Roda o próprio SDDM em Wayland. Independe de qual sessão você escolhe
        depois — é só a tela de login.
      '';
    };
  };

  config = mkIf algumWm {
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = cfg.sddm.wayland;
    };

    # `sessao` pode ser vazia se alguém ligar um WM sem sessão conhecida; aí
    # não declaramos nada e o SDDM usa a ordem dele.
    services.displayManager.defaultSession = mkIf (sessao != "") sessao;

    # As fontes moraram dentro do plasma.nix, e não eram do KDE: qualquer
    # ambiente gráfico precisa delas, e desligar o Plasma levava as fontes do
    # sistema inteiro junto — com o sintoma aparecendo longe da causa.
    #
    # `enableDefaultPackages` traz o conjunto que o NixOS considera básico
    # (DejaVu, Liberation, gyre, unifont e as CJK). As de baixo são as que
    # queremos garantir por nome; o stylix acrescenta as dele — a Nerd Font do
    # terminal, entre elas — a partir de lcars.system.theme.fonts.
    fonts = {
      enableDefaultPackages = true;
      packages = with pkgs; [
        noto-fonts
        # noto-fonts-emoji foi renomeado para noto-fonts-color-emoji no
        # nixpkgs; o nome antigo aborta a avaliação com um throw.
        noto-fonts-color-emoji
        liberation_ttf
        dejavu_fonts
      ];
    };

    # Também não é do KDE: aplicativos GTK guardam preferência no dconf, e sem
    # isto elas não persistem entre sessões.
    programs.dconf.enable = true;
  };
}
