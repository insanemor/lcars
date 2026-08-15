{ config, lib, pkgs, sys, user, inputs, ... }:

with lib;

let
  cfg = config.lcars.system.app.onePassword;
in
{
  # --- Options ---------------------------------------------------------
  options.lcars.system.app.onePassword = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Instala o 1Password e configura o agente SSH.";
    };

    enableCli = mkOption { type = types.bool; default = user.onePassword.enableCli; };
    enableGui = mkOption { type = types.bool; default = user.onePassword.enableGui; };
    enableSshAgent = mkOption { type = types.bool; default = user.onePassword.enableSshAgent; };

    polkitOwner = mkOption {
      type = types.str;
      default = user.username;
      description = "Usuário autorizado a usar a GUI do 1Password sem prompt de senha.";
    };

    user = mkOption {
      type = types.str;
      default = user.username;
      description = "Usuário Linux dono do socket do agente SSH.";
    };
  };

  # --- Implementation --------------------------------------------------
  config = mkIf cfg.enable {

    # 1Password é software proprietário — precisa ser liberado explicitamente.
    # Usamos só o predicate (não allowUnfree global) para o desvio ficar
    # limitado aos pacotes do 1Password.
    nixpkgs.config.allowUnfreePredicate =
      pkg: builtins.elem (lib.getName pkg) [
        "1password-cli"
        "1password-gui"
        "1password"
      ];

    # 1Password CLI
    programs._1password = mkIf cfg.enableCli {
      enable = true;
      package = pkgs._1password-cli;
    };

    # 1Password GUI. `polkitPolicyOwners` é uma lista de nomes de usuário — o
    # módulo já gera a regra polkit e põe esses usuários nos grupos
    # `onepassword`/`onepassword-cli`, então não escrevemos polkit à mão.
    programs._1password-gui = mkIf cfg.enableGui {
      enable = true;
      package = pkgs._1password-gui;
      polkitPolicyOwners = [ cfg.polkitOwner ];
    };

    # Hosts do GitHub conhecidos — evita prompts MITM na primeira vez.
    #
    # As aspas em "github.com" não são estilo: sem elas o ponto é lido como
    # caminho de atributo, e o Nix procura a option
    # `programs.ssh.knownHosts.github.com` (github → com), que não existe.
    programs.ssh.knownHosts = {
      "github.com" = {
        hostNames = [ "github.com" ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLvab/yH7LoQwSAvAfvxl0g0";
      };
    };

    # O agente SSH do 1Password é ligado DENTRO do app (Settings → Developer),
    # não por um módulo NixOS — `services._1password` não existe. O que cabe
    # ao sistema é apontar o ssh para o socket que o app expõe.
    programs.ssh.extraConfig = mkIf cfg.enableSshAgent ''
      Host *
        IdentityAgent ~/.1password/agent.sock
    '';
  };
}
