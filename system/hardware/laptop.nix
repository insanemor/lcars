{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.lcars.system.hardware.laptop;
in
{
  options.lcars.system.hardware.laptop = {
    enable = mkEnableOption "Ajustes para notebook (bateria, suspensão).";

    # tlp e power-profiles-daemon disputam o mesmo controle de energia e o
    # NixOS aborta a avaliação se os dois estiverem ligados. Escolha um.
    # O Plasma integra com "ppd"; "tlp" dá mais controle fino de bateria.
    powerManager = mkOption {
      type = types.enum [ "tlp" "ppd" ];
      default = "tlp";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      services.thermald.enable = mkDefault true;
      services.logind.lidSwitch = "suspend";
      services.logind.lidSwitchExternalPower = "ignore";
    }

    (mkIf (cfg.powerManager == "tlp") {
      # É services.tlp — hardware.tlp nunca existiu.
      services.power-profiles-daemon.enable = false;
      services.tlp.enable = true;
      services.tlp.settings = {
        START_CHARGE_THRESH_BAT0 = 80;
        STOP_CHARGE_THRESH_BAT0  = 90;
        # TLP_DEFAULT_MODE aceita "AC" ou "BAT", não "balance".
        TLP_DEFAULT_MODE         = "AC";
        CPU_SCALING_GOVERNOR_ON_AC  = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      };
    })

    (mkIf (cfg.powerManager == "ppd") {
      services.tlp.enable = false;
      services.power-profiles-daemon.enable = true;
    })
  ]);
}
