{ config, lib, pkgs, vars, ... }:

with lib;

let
  cfg = config.lcars.desktop;
in
{
  options.lcars.desktop = {
    enable = mkEnableOption "Ambiente desktop base (GNOME + fontes + áudio).";
    gdm = mkOption { type = types.bool; default = true; };
  };

  config = mkIf cfg.enable {

    services.xserver.enable = true;

    # As opções de display/desktop manager saíram de services.xserver.* nas
    # versões recentes do nixpkgs — hoje moram em services.displayManager.* e
    # services.desktopManager.*.
    services.displayManager.gdm.enable = cfg.gdm;
    services.displayManager.defaultSession = "gnome";
    services.desktopManager.gnome.enable = true;

    # `sound.enable` e `hardware.pulseaudio` não existem mais. Áudio hoje é
    # pipewire, que fala ALSA/Pulse/JACK.
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    # Fontes vão em fonts.packages, não em systemPackages — só assim o
    # fontconfig do sistema as enxerga.
    fonts = {
      enableDefaultPackages = true;
      packages = with pkgs; [
        noto-fonts
        noto-fonts-emoji
        liberation_ttf
        dejavu_fonts
      ];
    };

    environment.systemPackages = with pkgs; [
      gnome-tweaks
      dconf-editor
      firefox
    ];

    programs.dconf.enable = true;
  };
}
