{ config, lib, pkgs, sys, user, ... }:

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
        Sessão padrão em Wayland. A sessão X11 continua disponível na tela de
        login em qualquer caso — isto só decide qual vem pré-selecionada.
      '';
    };

    excludePackages = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "elisa" "khelpcenter" ];
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

    # SDDM é o display manager do Plasma. Nas versões recentes do nixpkgs as
    # opções de display/desktop manager vivem em services.displayManager.* e
    # services.desktopManager.*, não mais dentro de services.xserver.
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = cfg.wayland;
    };

    services.desktopManager.plasma6.enable = true;

    services.displayManager.defaultSession =
      if cfg.wayland then "plasma" else "plasmax11";

    environment.plasma6.excludePackages =
      map (p: pkgs.kdePackages.${p}) cfg.excludePackages;

    # O áudio NÃO mora aqui: é system/hardware/audio.nix, ligado por
    # `lcars.system.hardware.audio.enable`. Um desktop quer os dois, mas o
    # profile liga cada um explicitamente — este módulo não o faz por trás.

    # Fontes vão em fonts.packages, não em systemPackages — só assim o
    # fontconfig do sistema as enxerga.
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

    # O Plasma é Qt, mas os aplicativos GTK que você instalar leem suas
    # configurações do dconf.
    programs.dconf.enable = true;
  };
}
