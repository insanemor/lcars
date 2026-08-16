{
  config,
  lib,
  pkgs,
  sys,
  user,
  ...
}:

with lib;

let
  cfg = config.lcars.system.wm.plasma;
in
{
  options.lcars.system.wm.plasma = {
    enable = mkEnableOption "Ambiente desktop KDE Plasma 6 (+ SDDM e fontes). O áudio é lcars.system.hardware.audio.";

    wayland = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Qual das duas sessões do Plasma vem pré-selecionada: a Wayland
        ("plasma") ou a X11 ("plasmax11"). As duas continuam disponíveis na
        tela de login.

        Quem lê isto é system/wm/default.nix, ao decidir a sessão padrão.
      '';
    };

    excludePackages = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "elisa"
        "khelpcenter"
      ];
      description = ''
        Nomes de pacotes de `kdePackages` a NÃO instalar, entre os que o
        módulo plasma6 traz por padrão.
      '';
    };
  };

  config = mkIf cfg.enable {

    # X11 segue ligado para ter a sessão Plasma X11 na tela de login e para o
    # XWayland dos aplicativos que ainda não falam Wayland.
    services.xserver.enable = true;

    # Nas versões recentes do nixpkgs as opções de desktop manager vivem em
    # services.desktopManager.*, não mais dentro de services.xserver.
    services.desktopManager.plasma6.enable = true;

    # O SDDM e a escolha da sessão padrão NÃO ficam aqui: são de
    # system/wm/default.nix. Declará-los neste módulo daria conflito de
    # definição assim que um segundo ambiente fosse ligado junto — e é
    # justamente conviver com outro que torna seguro experimentar.

    environment.plasma6.excludePackages = map (p: pkgs.kdePackages.${p}) cfg.excludePackages;

    # O áudio NÃO mora aqui: é system/hardware/audio.nix, ligado por
    # `lcars.system.hardware.audio.enable`. Um desktop quer os dois, mas o
    # profile liga cada um explicitamente — este módulo não o faz por trás.

    # As fontes e o `programs.dconf.enable` moravam aqui, e nenhum dos dois é
    # do KDE: foram para system/wm/default.nix, onde valem para qualquer
    # ambiente gráfico. Desligar o Plasma não pode levar as fontes do sistema
    # inteiro junto.
  };
}
