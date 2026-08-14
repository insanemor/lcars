{ config, lib, pkgs, vars, ... }:

with lib;

{
  options.lcars.common = {
    enable = mkOption { type = types.bool; default = true; };
    locale  = mkOption { type = types.str;   default = vars.locale; };
    timezone = mkOption { type = types.str;  default = vars.timezone; };
    extraPackages = mkOption {
      type = types.listOf types.str;
      default = vars.systemPackages;
    };
  };

  config = mkIf config.lcars.common.enable {

    # --- identidade do sistema ------------------------------------------
    system.stateVersion = "24.05";
    networking.hostName = config.networking.hostName;

    # --- locale / fuso horário ------------------------------------------
    time.timeZone = config.lcars.common.timezone;
    i18n = {
      defaultLocale = config.lcars.common.locale;
      supportedLocales = [
        "pt_BR.UTF-8/UTF-8"
        "en_US.UTF-8/UTF-8"
      ];
      extraLocaleSettings = {
        LC_ALL     = config.lcars.common.locale;
        LC_MESSAGES = "pt_BR.UTF-8";
      };
    };

    # --- console -------------------------------------------------------
    console = {
      font = "Lat2-Terminus16";
      keyMap = "us-intl";
      packages = with pkgs; [
        terminus_font
        dejavu_fonts
        liberation_ttf_fonts
      ];
    };

    # --- boot & sistemas de arquivos -----------------------------------
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    fileSystems."/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };

    swapDevices = [
      { device = "/swapfile"; size = 8 * 1024; }
    ];

    # --- usuários -----------------------------------------------------
    users.mutableUsers = true;
    users.users.${vars.username} = {
      isNormalUser = true;
      home         = "/home/${vars.username}";
      shell        = pkgs.zsh;
      extraGroups  = [ "networkmanager" "wheel" ];
      openssh.authorizedKeys.keys = [
        # Chaves SSH públicas também podem vir do 1Password via opnix;
        # placeholder por enquanto, para que uma instalação nova seja acessível.
      ];
    };

    # --- pacotes base --------------------------------------------------
    environment.systemPackages = with pkgs; [
      git
      vim
      htop
      curl
      wget
      jq
      rsync
      gnused
      gnugrep
      python3
    ] ++ map (p: pkgs.${p}) config.lcars.common.extraPackages;

    # --- integração com 1Password (sempre) -----------------------------
    lcars.onePassword.enable = true;

    # --- firewall ------------------------------------------------------
    networking.firewall.enable = true;
    networking.firewall.allowedTCPPorts = [
      22    # ssh
    ];

    # --- ssh -----------------------------------------------------------
    services.openssh = {
      enable = true;
      openFirewall = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };
  };
}
