{ config, lib, pkgs, vars, ... }:

with lib;

{
  options.lcars.desktop = {
    enable = mkEnableOption "Ambiente desktop base (X/Wayland + fontes + áudio).";
    gdm = mkOption { type = types.bool; default = true; };
  };

  config = mkIf config.lcars.desktop.enable {

    services.xserver.enable = true;
    services.xserver.displayManager.gdm.enable = config.lcars.desktop.gdm;

    services.desktopManager.gnome.enable = true;

    sound.enable = true;
    hardware.pulseaudio.enable = true;

    environment.systemPackages = with pkgs; [
      gnome.gnome-tweaks
      gnome.dconf-editor
      fontconfig
      noto-fonts
      noto-fonts-emoji
      liberation_ttf_fonts
      dejavu_fonts
      i3status-rust
      rofi-wayland
    ];

    programs.dconf.enable = true;
    services.xserver.displayManager.defaultSession = "gnome";
  };
}
