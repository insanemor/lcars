# system/core — o que toda máquina tem: identidade, locale, boot, usuário.
#
# O que NÃO mora aqui: fileSystems, swapDevices e boot.initrd vêm do
# machines/<host>/hardware-configuration.nix; ssh e firewall vivem em
# system/security.
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
  cfg = config.lcars.system.core;

  # Resolve um nome de pacote vindo do settings.nix. Aceita caminho aninhado
  # ("kdePackages.kate"), o que `pkgs.${name}` não faz — interpolação de
  # atributo procura uma chave chamada literalmente "kdePackages.kate".
  # Erra com uma mensagem que diz qual nome está errado, em vez do
  # "attribute missing" cru do Nix.
  pkgByName =
    name:
    let
      path = lib.splitString "." name;
    in
    lib.attrByPath path
      (throw "lcars: pacote '${name}' não existe em nixpkgs — confira o nome no settings.nix")
      pkgs;
in
{
  options.lcars.system.core = {
    enable = mkOption {
      type = types.bool;
      default = true;
    };
    locale = mkOption {
      type = types.str;
      default = sys.locale;
    };
    timezone = mkOption {
      type = types.str;
      default = sys.timezone;
    };

    extraPackages = mkOption {
      type = types.listOf types.str;
      default = sys.extraPackages or [ ];
      description = ''
        Nomes de pacotes nixpkgs a instalar no sistema. Aceita caminho
        aninhado, como "kdePackages.kate".
      '';
    };

    # As três opções abaixo descrevem COMO ESTA MÁQUINA BOOTOU, então quem as
    # declara é machines/<host>/default.nix, não o settings.nix. Nada aqui é
    # detectável pelo nixos-generate-config.
    bootLoader = mkOption {
      type = types.enum [
        "systemd-boot"
        "grub"
        "none"
      ];
      default = "systemd-boot";
      description = ''
        "systemd-boot" para UEFI, "grub" para BIOS legado (usa grubDevice),
        "none" quando a máquina configura o bootloader por conta própria.
      '';
    };

    grubDevice = mkOption {
      type = types.str;
      default = "";
      description = ''
        Disco onde instalar o GRUB quando bootLoader = "grub". O DISCO, não a
        partição: "/dev/sda", não "/dev/sda1".
      '';
    };

    bootMountPath = mkOption {
      type = types.str;
      default = "/boot";
      description = ''
        Onde a partição EFI está montada. Só usado com bootLoader =
        "systemd-boot"; confira no hardware-configuration.nix se a sua não for
        a habitual /boot.
      '';
    };

    # Um swapfile só é criado se você pedir, para não colidir com o swap que o
    # hardware-configuration.nix já tenha detectado.
    swapFileSize = mkOption {
      type = types.nullOr types.int;
      default = sys.swapFileSize or null;
      description = "Tamanho em MiB de /swapfile. null = não criar swapfile.";
    };

    # zram é a terceira forma de swap deste repo, e as três convivem: zram
    # (RAM comprimida), swapfile (acima) e partição de swap (declarada pelo
    # hardware-configuration.nix). Veja o bloco de configuração abaixo.
    zram = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Swap em RAM comprimida. Em vez de mandar a página para o disco, o
          kernel a comprime e a mantém na memória — ordens de grandeza mais
          rápido que qualquer SSD, ao custo de um pouco de CPU.

          NÃO substitui a partição de swap se você quiser hibernar: o zram
          desaparece quando a máquina desliga, e é justamente aí que a imagem
          de hibernação precisaria estar escrita. Ver o bloco de configuração.
        '';
      };

      memoryPercent = mkOption {
        type = types.int;
        default = 50;
        description = ''
          Quanto da RAM o dispositivo zram pode ocupar, em porcentagem, já
          contando a compressão — 50 numa máquina de 64 GB dá um swap de
          32 GB que na prática cabe em bem menos memória real.

          O default do NixOS é 50; valores acima de 100 existem e fazem
          sentido com taxas de compressão altas, mas passam a disputar RAM
          com o que você está de fato rodando.
        '';
      };
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

    # GRUB sem disco gera um erro tardio e obscuro no instalador do bootloader.
    # Melhor falhar já na avaliação, dizendo onde arrumar.
    assertions = [
      {
        assertion = cfg.bootLoader != "grub" || cfg.grubDevice != "";
        message = ''
          lcars: lcars.system.core.bootLoader = "grub" exige
          lcars.system.core.grubDevice preenchido em
          machines/<host>/default.nix — o DISCO, ex. "/dev/sda", não a
          partição "/dev/sda1".
        '';
      }
    ];

    system.stateVersion = "24.05";

    # --- flakes ---------------------------------------------------------
    # Obrigatório: sem isto o próximo `nixos-rebuild --flake` falha.
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
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

    # O teclado NÃO mora aqui. Layout parece assunto de idioma, mas é do
    # teclado físico e muda de máquina para máquina — está em
    # system/hardware/keyboard.nix, com a fonte e o layout do console.

    # --- boot ----------------------------------------------------------
    boot.loader = mkMerge [
      (mkIf (cfg.bootLoader == "systemd-boot") {
        systemd-boot.enable = true;
        systemd-boot.configurationLimit = mkDefault 10;
        efi.canTouchEfiVariables = true;
        efi.efiSysMountPoint = cfg.bootMountPath;
      })
      (mkIf (cfg.bootLoader == "grub") {
        grub.enable = true;
        grub.device = cfg.grubDevice;
      })
    ];

    swapDevices = mkIf (cfg.swapFileSize != null) [
      {
        device = "/swapfile";
        size = cfg.swapFileSize;
      }
    ];

    # --- zram ------------------------------------------------------------
    # As três formas de swap deste repo convivem, e o kernel escolhe por
    # prioridade — o `zramSwap` do NixOS já nasce com prioridade 5, acima da
    # de qualquer partição ou swapfile (que ficam em -2). Na prática:
    #
    #   1. a página comprimida vai para o zram, em RAM;
    #   2. só quando ele enche é que o disco entra.
    #
    # HIBERNAR EXIGE A PARTIÇÃO, e é o ponto que se perde com facilidade: a
    # imagem de hibernação é escrita no swap DE DISCO, com a máquina prestes a
    # desligar. Um sistema só com zram não tem onde escrevê-la — o zram morre
    # junto com a energia. Por isso o repo não trata as duas como alternativas.
    #
    # Quem declara a partição é o machines/<host>/hardware-configuration.nix,
    # gerado pelo nixos-generate-config, e quem aponta o initrd para ela na
    # volta é `boot.resumeDevice` — declarado na máquina, porque é o UUID
    # daquele disco. Sem `resumeDevice`, a hibernação escreve e o boot seguinte
    # ignora a imagem: a máquina volta zerada, como se tivesse desligado.
    zramSwap = mkIf cfg.zram.enable {
      enable = true;
      inherit (cfg.zram) memoryPercent;
    };

    # --- firmware -------------------------------------------------------
    # Os blobs que o kernel carrega em tempo de boot: GPU, Wi-Fi, bluetooth,
    # placas de rede. Sem eles o driver não fica "sem aceleração" — ele
    # ABORTA, e o hardware simplesmente não existe para o sistema.
    #
    # O caso que trouxe esta linha para cá foi uma Radeon RX 6900 XT passada
    # a uma VM: instalação sem um erro, sessão do niri de pé, e o monitor
    # ligado à placa preto. No journal do convidado:
    #
    #   amdgpu: Direct firmware load for amdgpu/sienna_cichlid_smc.bin
    #           failed with error -2
    #   amdgpu: Fatal error during GPU init
    #
    # Erro -2 é ENOENT: o arquivo não estava lá. A placa nunca virou
    # /dev/dri/card*, e o compositor enxergava só a saída virtual.
    #
    # Por que ninguém tinha notado: o `nixos-generate-config` escreve esta
    # option no hardware-configuration.nix, que é gerado por máquina e está
    # no .gitignore. Ou seja, funcionava por acidente em quem gerou o arquivo
    # com ela, e faltava em quem não gerou. Isto vale para toda máquina, e é
    # por isso que mora aqui.
    hardware.enableRedistributableFirmware = true;

    # O microcode NÃO vem junto — e é fácil acreditar que vem, porque já veio.
    # Hoje, no nixos-unstable, o default é `false` puro:
    #
    #   # nixos/modules/hardware/cpu/amd-microcode.nix
    #   hardware.cpu.amd.updateMicrocode = lib.mkOption {
    #     default = false;
    #
    # Quem o ligava era, de novo, o hardware-configuration.nix gerado — que
    # escreve `mkDefault config.hardware.enableRedistributableFirmware` e cria
    # a impressão de herança. Verificado por avaliação: com o firmware ligado
    # acima e sem as duas linhas abaixo, o microcode continua desligado.
    #
    # Os dois fabricantes ficam ligados porque este repo não sabe em que CPU
    # vai rodar, e não há como descobrir em tempo de avaliação. O custo é um
    # par de megabytes de initrd: o kernel carrega o que serve à CPU que
    # encontrar e ignora o resto.
    hardware.cpu.amd.updateMicrocode = true;
    hardware.cpu.intel.updateMicrocode = true;

    # --- preferências do usuário ---------------------------------------
    # Os programas em si precisam estar instalados — por um módulo (o
    # navegador vem de user/app/vivaldi.nix), por userSettings.packages ou
    # por systemSettings.extraPackages. Aqui só dizemos qual usar.
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

    # O shell da conta acompanha o módulo de user/ que o configura. Sem isto,
    # desligar lcars.user.zsh.enable deixaria a conta num zsh sem ~/.zshrc —
    # pior que o bash, em vez de uma escolha.
    #
    # Um módulo de system/ lendo uma flag de user/ é seguro porque
    # `lcars.user.*` é option NixOS, declarada em user/options.nix (veja o
    # cabeçalho de lá): estamos na mesma árvore de módulos, e por isso o
    # acesso é por `config`, não por `osConfig`.
    #
    # `programs.zsh.enable` é o que registra o zsh em /etc/shells; sem ele,
    # `shell = pkgs.zsh` aponta para um shell que o sistema não reconhece.
    # O bash não precisa de equivalente: o módulo programs.bash é sempre
    # ativo no NixOS e já o deixa registrado.
    programs.zsh.enable = config.lcars.user.zsh.enable;

    users.users.${user.username} = {
      isNormalUser = true;
      description = user.fullName;
      home = "/home/${user.username}";
      # bashInteractive, não bash: `pkgs.bash` é a build sem readline, para
      # scripts. Como shell de login ela não tem histórico nem edição de
      # linha. É por isso que users.defaultUserShell do NixOS é o Interactive.
      shell = if config.lcars.user.zsh.enable then pkgs.zsh else pkgs.bashInteractive;
      extraGroups = [
        "networkmanager"
        "wheel"
        "video"
        "audio"
      ];
      initialPassword = mkIf (cfg.initialPassword != null) cfg.initialPassword;
      packages = map pkgByName ((user.packages or [ ]) ++ cfg.userPackages);
    };

    # --- pacotes base --------------------------------------------------
    environment.systemPackages =
      with pkgs;
      [
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
      ]
      ++ map pkgByName cfg.extraPackages;
  };
}
