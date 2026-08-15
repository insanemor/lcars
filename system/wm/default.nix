# system/wm — ambientes gráficos, e o que eles compartilham.
#
# Mais de um pode estar ligado ao mesmo tempo: os dois aparecem na tela de
# login e você escolhe na hora. É o que torna seguro experimentar um ambiente
# novo sem perder o que já funciona.
#
# Este arquivo existe porque duas coisas são do display manager, não de um WM
# em particular, e declará-las dentro de cada módulo geraria conflito de
# definição no instante em que dois estivessem ligados:
#
#   - o SDDM em si
#   - qual sessão abre por padrão
{ config, lib, ... }:

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
  };
}
