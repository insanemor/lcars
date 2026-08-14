{
  description = "lcars-public — flake NixOS forkável, multi-host, com dotfiles e secrets integrados ao 1Password";

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

      # Fábrica genérica de host. Junta módulos comuns + diretório do host + extras.
      mkHost = hostName: extras:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs vars; };

          modules = [
            ./modules/common
            ./hosts/common
            ./hosts/${hostName}

            home-manager.nixosModules.home-manager

            ({ ... }: {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = { inherit vars; };
                sharedModules = [ ./home/modules/personal ];
                users.${vars.username}.imports = [
                  ./home/common/zsh.nix
                  ./home/common/git.nix
                  ./home/common/starship.nix
                  ./home/common/direnv.nix
                  ./home/common/dotfiles.nix
                ];
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

      # Helper empacotado de `nix run` para preencher as vars locais.
      bootstrap = pkgs.writeShellApplication {
        name = "lcars-bootstrap";
        runtimeInputs = with pkgs; [ gnused gnugrep ];
        text = builtins.readFile ./scripts/bootstrap.sh;
      };
    in
    {
      # Adicione suas máquinas aqui:
      nixosConfigurations = {
        # meu-laptop = self.mkHost "meu-laptop" [ ./modules/laptop ./modules/desktop ];
        # meu-pc     = self.mkHost "meu-pc"     [ ./modules/desktop ];
        # minha-vm   = self.mkHost "minha-vm"   [ ./modules/vm ];
      };

      apps.${system}.bootstrap = {
        type = "app";
        program = toString bootstrap;
      };

      packages.${system} = { inherit bootstrap; default = bootstrap; };
    }
      // lib.optionalAttrs (inputs ? lcars-private)
            { nixosModules.default = inputs.lcars-private.nixosModules.default; };
}
