# system/core — o que toda máquina tem: identidade, locale, boot, usuário.
#
# O que NÃO mora aqui: fileSystems, swapDevices e boot.initrd vêm do
# machines/<host>/hardware-configuration.nix; ssh e firewall vivem em
# system/security.
{ config, lib, pkgs, vars, ... }:

with lib;

let
  cfg = config.lcars.core;
in
{
  options.lcars.core = {
    enable = mkOption { type = types.bool; default = true; };
    locale  = mkOption { type = types.str;   default = vars.locale; };
    timezone = mkOption { type = types.str;  default = vars.timezone; };

    extraPackages = mkOption {
      type = types.listOf types.str;
      default = vars.systemPackages;
      description = "Nomes de pacotes nixpkgs a instalar no sistema.";
    };

    # Isto depende de a máquina ter bootado em UEFI ou em BIOS legado — algo
    # que o nixos-generate-config não decide por você.
    bootLoader = mkOption {
      type = types.enum [ "systemd-boot" "grub" "none" ];
      default = "systemd-boot";
      description = ''
        "systemd-boot" para UEFI, "grub" para BIOS legado (usa grubDevice),
        "none" quando a máquina configura o bootloader por conta própria.
      '';
    };

    grubDevice = mkOption {
      type = types.str;
      default = "/dev/sda";
      description = "Disco onde instalar o GRUB quando bootLoader = \"grub\".";
    };

    # Um swapfile só é criado se você pedir, para não colidir com o swap que o
    # hardware-configuration.nix já tenha detectado.
    swapFileSize = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Tamanho em MiB de /swapfile. null = não criar swapfile.";
    };

    # Sem isto, uma instalação nova fica sem nenhuma forma de login: o sshd de
    # system/security aceita apenas chave.
    initialPassword = mkOption {
      type = types.nullOr types.str;
      default = "lcars";
      description = ''
        Senha inicial do usuário, aplicada só na primeira criação da conta.
        Troque com `passwd` no primeiro login. null = não definir senha.
      '';
    };

    userPackages = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Nomes de pacotes nixpkgs a instalar no usuário. Esta lista é SOMADA a
        vars.userPackages, não a substitui — assim um profile pode acrescentar
        ferramentas sem apagar o que você pôs em vars/local.nix.
      '';
    };
  };

  config = mkIf cfg.enable {

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

    console = {
      font = "Lat2-Terminus16";
      keyMap = "us-acentos";
      packages = with pkgs; [ terminus_font ];
    };

    # --- boot ----------------------------------------------------------
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

    # --- usuário -------------------------------------------------------
    users.mutableUsers = true;
    programs.zsh.enable = true;
    users.users.${vars.username} = {
      isNormalUser = true;
      description  = vars.fullName;
      home         = "/home/${vars.username}";
      shell        = pkgs.zsh;
      extraGroups  = [ "networkmanager" "wheel" "video" "audio" ];
      initialPassword = mkIf (cfg.initialPassword != null) cfg.initialPassword;
      packages = map (p: pkgs.${p}) (vars.userPackages ++ cfg.userPackages);
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
  };
}
