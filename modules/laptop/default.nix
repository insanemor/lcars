{ config, lib, pkgs, ... }:

with lib;

{
  # Configurações específicas de notebook (bateria, suspensão, energia).
  options.lcars.laptop.enable = mkEnableOption "Ajustes para notebook (bateria, suspensão).";

  config = mkIf config.lcars.laptop.enable {

    hardware.tlp.enable = true;
    hardware.tlp.settings = {
      START_CHARGE_THRESH_BAT0 = 80;
      STOP_CHARGE_THRESH_BAT0  = 90;
      RESTORE_THRESH_BAT0      = 100;
      TLP_DEFAULT_MODE         = "balance";
      TLP_RADIO_DISABLE_BT     = "on";
    };

    services.power-profiles-daemon.enable = true;

    services.logind = {
      lidSwitch = "suspend";
      lidSwitchExternalPower = "ignore";
      extraConfig = ''
        HandleHibernateKey=ignore
      '';
    };
  };
}
