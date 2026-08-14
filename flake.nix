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

    # SOPS opcional — útil quando o bootstrap precisa rodar antes do 1Password
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
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Carrega variáveis específicas do usuário (ignoradas pelo git).
      # Caso vars/local.nix não exista, cai no template — assim `nix flake check`
      # roda mesmo em forks sem secrets.
      vars =
        let local = ./vars/local.nix; in
        if builtins.pathExists local then
          import local { inherit lib; }
        else
          import ./vars/example.nix { inherit lib; };

      # Fábrica de máquina. A hierarquia entra toda aqui:
      #
      #   system/    módulos NixOS, opt-in por lcars.<x>.enable
      #   profiles/  presets que ligam essas flags com mkDefault
      #   machines/  a máquina em si: escolhe o profile e sobrescreve o resto
      #   user/      módulos do Home Manager
      mkMachine = hostName: extras:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs vars hostName; };

          modules = [
            ./system
            ./profiles
            ./machines/${hostName}

            home-manager.nixosModules.home-manager

            ({ ... }: {
              networking.hostName = lib.mkDefault hostName;

              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = { inherit vars; };
                sharedModules = [ ./user/personal ];
                users.${vars.username}.imports = [ ./user ];
                users.${vars.username}.home = {
                  username = vars.username;
                  homeDirectory = "/home/${vars.username}";
                  stateVersion = "24.05";
                };
              };
            })

            inputs.opnix.nixosModules.default
          ] ++ extras;
        };

      # Auto-descoberta: todo diretório em machines/ vira uma entrada em
      # nixosConfigurations. Adicionar uma máquina = criar o diretório.
      # `template` fica de fora por ser só o modelo a copiar.
      machineDirs =
        let entries = builtins.readDir ./machines;
        in lib.filter
          (name: entries.${name} == "directory" && name != "template")
          (builtins.attrNames entries);

      discoveredMachines =
        lib.genAttrs machineDirs (name: mkMachine name [ ]);

      # Helper empacotado de `nix run` para preencher as vars locais.
      bootstrap = pkgs.writeShellApplication {
        name = "lcars-bootstrap";
        runtimeInputs = with pkgs; [ gnused gnugrep ];
        text = builtins.readFile ./scripts/bootstrap.sh;
      };
    in
    {
      # Exposto para quem quiser registrar uma máquina à mão com módulos
      # extras:  meu-pc = self.mkMachine "meu-pc" [ ./algo-extra.nix ];
      inherit mkMachine;

      nixosConfigurations = discoveredMachines;

      apps.${system}.bootstrap = {
        type = "app";
        program = "${bootstrap}/bin/lcars-bootstrap";
      };

      packages.${system} = { inherit bootstrap; default = bootstrap; };
    }
      // lib.optionalAttrs (inputs ? lcars-private)
            { nixosModules.default = inputs.lcars-private.nixosModules.default; };
}
