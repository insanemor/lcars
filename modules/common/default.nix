{ config, lib, pkgs, vars, ... }:

with lib;

let
  cfg = config.lcars.common;
in
{
  options.lcars.common = {
    enable = mkOption { type = types.bool; default = true; };
    locale  = mkOption { type = types.str;   default = vars.locale; };
    timezone = mkOption { type = types.str;  default = vars.timezone; };

    extraPackages = mkOption {
      type = types.listOf types.str;
      default = vars.systemPackages;
    };

    # `hardware-configuration.nix` é quem declara fileSystems e boot.initrd.
    # Este módulo só escolhe qual bootloader instalar, porque isso depende de
    # a máquina ter bootado em UEFI ou em BIOS legado — algo que o
    # nixos-generate-config não decide por você.
    bootLoader = mkOption {
      type = types.enum [ "systemd-boot" "grub" "none" ];
      default = "systemd-boot";
      description = ''
        "systemd-boot" para UEFI, "grub" para BIOS legado (usa grubDevice),
        "none" quando o host já configura o bootloader por conta própria.
      '';
    };

    grubDevice = mkOption {
      type = types.str;
      default = "/dev/sda";
      description = "Disco onde instalar o GRUB quando bootLoader = \"grub\".";
    };

    # Um swapfile só é criado se você pedir. Antes isto era incondicional e
    # colidia com o swap que o hardware-configuration.nix já tivesse detectado.
    swapFileSize = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Tamanho em MiB de /swapfile. null = não criar swapfile.";
    };

    # Sem isto, uma instalação nova fica sem nenhuma forma de login: o sshd
    # abaixo aceita apenas chaves, e users.users.<u> não define senha alguma.
    initialPassword = mkOption {
      type = types.nullOr types.str;
      default = "lcars";
      description = ''
        Senha inicial do usuário, aplicada só na primeira criação da conta.
        Troque com `passwd` no primeiro login. null = não definir senha.
      '';
    };

    sshKeys = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Chaves públicas SSH autorizadas para o usuário.";
    };
  };

  config = mkIf cfg.enable {

    # --- identidade do sistema ------------------------------------------
    system.stateVersion = "24.05";

    # --- flakes ---------------------------------------------------------
    # Obrigatório: sem isto o próximo `nixos-rebuild --flake` falha.
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    # --- locale / fuso horário ------------------------------------------
    time.timeZone = cfg.timezone;
    i18n = {
      defaultLocale = cfg.locale;
      supportedLocales = [
        "pt_BR.UTF-8/UTF-8"
        "en_US.UTF-8/UTF-8"
        "C.UTF-8/UTF-8"
      ];
      extraLocaleSettings = {
        LC_MESSAGES = "pt_BR.UTF-8";
      };
    };

    # --- console -------------------------------------------------------
    console = {
      font = "Lat2-Terminus16";
      keyMap = "us-acentos";
      packages = with pkgs; [ terminus_font ];
    };

    # --- boot ----------------------------------------------------------
    # fileSystems e swapDevices vêm de hosts/<host>/hardware-configuration.nix.
    boot.loader = mkMerge [
      (mkIf (cfg.bootLoader == "systemd-boot") {
        systemd-boot.enable = true;
        systemd-boot.configurationLimit = mkDefault 10;
        efi.canTouchEfiVariables = true;
      })
      (mkIf (cfg.bootLoader == "grub") {
        grub.enable = true;
        grub.device = cfg.grubDevice;
      })
    ];

    swapDevices = mkIf (cfg.swapFileSize != null) [
      { device = "/swapfile"; size = cfg.swapFileSize; }
    ];

    # --- rede ----------------------------------------------------------
    networking.networkmanager.enable = mkDefault true;

    # --- usuários -----------------------------------------------------
    users.mutableUsers = true;
    programs.zsh.enable = true;
    users.users.${vars.username} = {
      isNormalUser = true;
      description  = vars.fullName;
      home         = "/home/${vars.username}";
      shell        = pkgs.zsh;
      extraGroups  = [ "networkmanager" "wheel" "video" "audio" ];
      initialPassword = mkIf (cfg.initialPassword != null) cfg.initialPassword;
      openssh.authorizedKeys.keys = cfg.sshKeys;
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
    ] ++ map (p: pkgs.${p}) cfg.extraPackages;

    # --- integração com 1Password (sempre) -----------------------------
    lcars.onePassword.enable = mkDefault true;

    # --- firewall ------------------------------------------------------
    networking.firewall.enable = true;

    # --- ssh -----------------------------------------------------------
    # Só chaves. O login local por senha (console/GDM) continua funcionando
    # via initialPassword acima.
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
