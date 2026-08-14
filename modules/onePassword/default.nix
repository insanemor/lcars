{ config, lib, pkgs, vars, inputs, ... }:

with lib;

let
  cfg = config.lcars.onePassword;
in
{
  # --- Options ---------------------------------------------------------
  options.lcars.onePassword = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Instala o 1Password e configura o agente SSH.";
    };

    enableCli = mkOption { type = types.bool; default = true; };
    enableGui = mkOption { type = types.bool; default = true; };
    enableSshAgent = mkOption { type = types.bool; default = true; };

    polkitOwner = mkOption {
      type = types.str;
      default = vars.username;
      description = "Usuário autorizado a usar a GUI do 1Password sem prompt de senha.";
    };

    user = mkOption {
      type = types.str;
      default = vars.username;
      description = "Usuário Linux dono do socket do agente SSH.";
    };
  };

  # --- Implementation --------------------------------------------------
  config = mkIf cfg.enable {

    # 1Password é software proprietário — precisa ser habilitado explicitamente.
    nixpkgs.config.allowUnfreePredicate =
      pkg: builtins.elem (lib.getName pkg) [
        "1password-cli"
        "1password-gui"
        "1password"
      ];

    nixpkgs.config.allowUnfree = true;

    # 1Password CLI (multi-plataforma)
    programs._1password = {
      enable = cfg.enableCli;
      package = pkgs._1password-cli;
    };

    # 1Password GUI (para hosts desktop; seguro manter também em laptops)
    programs._1password-gui = mkIf cfg.enableGui {
      enable = true;
      package = pkgs._1password-gui;
      polkitPolicyOwners = optional cfg.polkitOwner (lib.getName cfg.polkitOwner);
    };

    # Hosts do GitHub conhecidos — evita prompts MITM na primeira vez
    programs.ssh.knownHosts = {
      github.com = {
        hostNames = [ "github.com" ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLvab/yH7LoQwSAvAfvxl0g0";
      };
    };

    # Autentique uma vez via leitura de QR code pelo celular;
    # o daemon então expõe o socket do agente SSH em ~/.1password/agent.sock
    services._1password = mkIf cfg.enableSshAgent {
      enable = true;
      sshAgent = {
        enable = true;
        package = pkgs._1password-cli;
        sshConfig = ''
          Host *
            IdentityAgent ${config.users.users.${cfg.user}.home}/.1password/agent.sock
            AddKeysToAgent yes
            IdentityFile ~/.ssh/id_ed25519
        '';
      };
    };

    # Agente polkit do 1Password — autoriza o dono da GUI.
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "com.1password.standalone.pid" &&
            subject.local == true && subject.active == true &&
            subject.user == "${cfg.polkitOwner}") {
          return polkit.Result.YES;
        }
        return polkit.Result.NOT_HANDLED;
      });
    '';
  };
}
