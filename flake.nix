{
  description = "lcars — flake NixOS forkável, multi-host, com dotfiles e secrets integrados ao 1Password";

  inputs = {
    # Núcleo
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Home manager (dotfiles a nível de usuário)
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Segredos vindos do 1Password para serviços NixOS / systemd
    opnix = {
      url = "github:brizzbuzz/opnix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # SOPS opcional — útil para secrets necessários antes de o 1Password subir
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # FUTURO — descomente para ligar um repo privado sobreposto:
    # lcars-private = {
    #   url = "git+ssh://git@github.com/<voce>/lcars-private.git";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };

  outputs = { self, nixpkgs, home-manager, opnix, ... }@inputs:
    let
      lib = nixpkgs.lib;

      # ---------------------------------------------------------------
      # settings.nix — quem você é e o que você gosta. Versionado, e igual em
      # todas as suas máquinas: o que muda de uma para outra (bootloader,
      # disco do GRUB, VM, notebook) mora em machines/<host>/default.nix.
      #
      # Campos avançados (sshKeys, packages, swapFileSize, gpgKey,
      # initialPassword, extraPackages) são opcionais — os módulos que os leem
      # trazem o próprio default.
      # ---------------------------------------------------------------
      settings = import ./settings.nix;

      sys  = settings.systemSettings;
      user = settings.userSettings;

      system = sys.system or "x86_64-linux";

      # Fábrica de máquina.
      #
      #   settings.nix   o que você editou — vale como default para tudo
      #   system/        módulos NixOS, opt-in por lcars.<x>.enable
      #   profiles/      presets que ligam essas flags (mkDefault)
      #   machines/      hardware da máquina, e overrides se você tiver várias
      #   user/          módulos do Home Manager, opt-in por lcars.user.<x>
      mkMachine = hostName: extras:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs settings sys user hostName; };

          modules = [
            ./system
            # As flags lcars.user.* moram no config do NixOS, não no do Home
            # Manager — é o que permite ao profile ligar os dois lados no
            # mesmo lugar. Veja o cabeçalho do arquivo.
            ./user/options.nix
            ./profiles
            ./machines/${hostName}

            home-manager.nixosModules.home-manager

            # O que vem do settings.nix. Tudo com mkDefault, para que
            # machines/<host>/default.nix possa sobrescrever qualquer campo
            # quando o repo servir mais de uma máquina.
            ({ ... }: {
              networking.hostName = lib.mkDefault hostName;

              lcars.profile = lib.mkDefault sys.profile;

              # O bootloader NÃO é decidido aqui. Ele depende de a máquina ter
              # bootado em UEFI ou BIOS, então quem o declara é
              # machines/<host>/default.nix. O default da option é
              # "systemd-boot" (veja system/core).

              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = { inherit settings sys user; };
                sharedModules = [ ./user/personal ];

                # Tudo do usuário num atributo só. Separar em
                # `users.${x}.imports` e `users.${x}.home` não compila: o Nix
                # funde caminhos ESTÁTICOS ({ a.b = 1; a.c = 2; }), mas não
                # sabe em tempo de parse que duas chaves interpoladas serão
                # iguais — constrói cada uma e acusa
                # "dynamic attribute already defined".
                users.${user.username} = {
                  imports = [ ./user ];
                  home = {
                    username = user.username;
                    homeDirectory = "/home/${user.username}";
                    stateVersion = "24.05";
                  };
                };
              };
            })

            inputs.opnix.nixosModules.default
          ] ++ extras;
        };

      # Auto-descoberta: todo diretório em machines/ vira uma entrada em
      # nixosConfigurations. `template` fica de fora por ser só o modelo.
      #
      # Com uma máquina só, você nunca mexe aqui: o instalador cria
      # machines/<hostname>/ e o settings.nix aponta para ele.
      machineDirs =
        let entries = builtins.readDir ./machines;
        in lib.filter
          (name: entries.${name} == "directory" && name != "template")
          (builtins.attrNames entries);

      discoveredMachines =
        lib.genAttrs machineDirs (name: mkMachine name [ ]);
    in
    {
      # Exposto para quem quiser registrar uma máquina à mão com módulos
      # extras:  meu-pc = self.mkMachine "meu-pc" [ ./algo-extra.nix ];
      inherit mkMachine;

      nixosConfigurations = discoveredMachines;
    }
      // lib.optionalAttrs (inputs ? lcars-private)
            { nixosModules.default = inputs.lcars-private.nixosModules.default; };
}
