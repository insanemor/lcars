# system/core — o que toda máquina tem: identidade, locale, boot, usuário.
#
# O que NÃO mora aqui: fileSystems, swapDevices e boot.initrd vêm do
# machines/<host>/hardware-configuration.nix; ssh e firewall vivem em
# system/security.
{ config, lib, pkgs, sys, user, ... }:

with lib;

let
  cfg = config.lcars.core;

  # Resolve um nome de pacote vindo do settings.nix. Aceita caminho aninhado
  # ("kdePackages.kate"), o que `pkgs.${name}` não faz — interpolação de
  # atributo procura uma chave chamada literalmente "kdePackages.kate".
  # Erra com uma mensagem que diz qual nome está errado, em vez do
  # "attribute missing" cru do Nix.
  pkgByName = name:
    let path = lib.splitString "." name;
    in lib.attrByPath path
         (throw "lcars: pacote '${name}' não existe em nixpkgs — confira o nome no settings.nix")
         pkgs;
in
{
  options.lcars.core = {
    enable = mkOption { type = types.bool; default = true; };
    locale  = mkOption { type = types.str;   default = sys.locale; };
    timezone = mkOption { type = types.str;  default = sys.timezone; };

    extraPackages = mkOption {
      type = types.listOf types.str;
      default = sys.extraPackages or [ ];
      description = ''
        Nomes de pacotes nixpkgs a instalar no sistema. Aceita caminho
        aninhado, como "kdePackages.kate".
      '';
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
      default = sys.grubDevice or "";
      description = ''
        Disco onde instalar o GRUB quando bootLoader = "grub". O DISCO, não a
        partição: "/dev/sda", não "/dev/sda1".
      '';
    };

    # Um swapfile só é criado se você pedir, para não colidir com o swap que o
    # hardware-configuration.nix já tenha detectado.
    swapFileSize = mkOption {
      type = types.nullOr types.int;
      default = sys.swapFileSize or null;
      description = "Tamanho em MiB de /swapfile. null = não criar swapfile.";
    };

    # Sem isto, uma instalação nova fica sem nenhuma forma de login: o sshd de
    # system/security aceita apenas chave.
    initialPassword = mkOption {
      type = types.nullOr types.str;
      default = user.initialPassword or "lcars";
      description = ''
        Senha inicial do usuário, aplicada só na primeira criação da conta.
        Troque com `passwd` no primeiro login. null = não definir senha.
      '';
    };

    userPackages = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Nomes de pacotes nixpkgs a instalar no usuário, aceitando caminho
        aninhado ("kdePackages.kate"). Esta lista é SOMADA a
        userSettings.packages, não a substitui — assim um profile pode
        acrescentar ferramentas sem apagar o que você pôs no settings.nix.
      '';
    };
  };

  config = mkIf cfg.enable {

    # bootMode = "bios" sem grubDevice gera um erro tardio e obscuro no
    # instalador do GRUB. Melhor falhar já na avaliação, dizendo o que fazer.
    assertions = [
      {
        assertion = cfg.bootLoader != "grub" || cfg.grubDevice != "";
        message = ''
          lcars: bootMode = "bios" exige systemSettings.grubDevice preenchido
          no settings.nix (o disco, ex.: "/dev/sda" — não a partição).
        '';
      }
    ];

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
        efi.efiSysMountPoint = sys.bootMountPath;
      })
      (mkIf (cfg.bootLoader == "grub") {
        grub.enable = true;
        grub.device = cfg.grubDevice;
      })
    ];

    swapDevices = mkIf (cfg.swapFileSize != null) [
      { device = "/swapfile"; size = cfg.swapFileSize; }
    ];

    # --- preferências do usuário ---------------------------------------
    # Os programas em si precisam estar instalados (userSettings.packages ou
    # systemSettings.extraPackages) — aqui só dizemos qual usar.
    environment.variables = {
      EDITOR = user.editor;
      VISUAL = user.editor;
      BROWSER = user.browser;
      TERMINAL = user.terminal;
    };

    # --- rede ----------------------------------------------------------
    networking.networkmanager.enable = mkDefault true;

    # --- usuário -------------------------------------------------------
    users.mutableUsers = true;
    programs.zsh.enable = true;
    users.users.${user.username} = {
      isNormalUser = true;
      description  = user.fullName;
      home         = "/home/${user.username}";
      shell        = pkgs.zsh;
      extraGroups  = [ "networkmanager" "wheel" "video" "audio" ];
      initialPassword = mkIf (cfg.initialPassword != null) cfg.initialPassword;
      packages = map pkgByName ((user.packages or [ ]) ++ cfg.userPackages);
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
    ] ++ map pkgByName cfg.extraPackages;
  };
}
