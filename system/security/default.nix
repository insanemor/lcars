# system/security — acesso remoto e firewall.
#
# Separado de system/core porque é a parte que decide quem entra na máquina, e
# porque um servidor e um desktop querem políticas diferentes aqui sem mexer
# no resto da base.
{ config, lib, pkgs, sys, user, ... }:

with lib;

let
  cfg = config.lcars.security;
in
{
  options.lcars.security = {
    enable = mkOption { type = types.bool; default = true; };

    sshKeys = mkOption {
      type = types.listOf types.str;
      default = user.sshKeys or [ ];
      description = ''
        Chaves públicas SSH autorizadas para o usuário. Enquanto esta lista
        estiver vazia não há como entrar por ssh — o login local por senha
        (lcars.core.initialPassword) continua sendo o caminho.
      '';
    };

    ssh.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Instala e liga o sshd (somente autenticação por chave).";
    };

    firewall.enable = mkOption { type = types.bool; default = true; };

    firewall.allowedTCPPorts = mkOption {
      type = types.listOf types.port;
      default = [ ];
      description = "Portas TCP extras. A do ssh é aberta pelo próprio módulo.";
    };
  };

  config = mkIf cfg.enable {

    users.users.${user.username}.openssh.authorizedKeys.keys = cfg.sshKeys;

    # Só chave. O login local por senha (console/SDDM) segue funcionando.
    services.openssh = mkIf cfg.ssh.enable {
      enable = true;
      openFirewall = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };

    networking.firewall = {
      enable = cfg.firewall.enable;
      allowedTCPPorts = cfg.firewall.allowedTCPPorts;
    };
  };
}
