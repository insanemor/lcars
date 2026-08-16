{
  config,
  lib,
  pkgs,
  sys,
  user,
  inputs,
  ...
}:

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

    enableCli = mkOption {
      type = types.bool;
      default = user.onePassword.enableCli;
    };
    enableGui = mkOption {
      type = types.bool;
      default = user.onePassword.enableGui;
    };
    enableSshAgent = mkOption {
      type = types.bool;
      default = user.onePassword.enableSshAgent;
    };

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
      pkg:
      builtins.elem (lib.getName pkg) [
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

    # Chaves de host do GitHub — dispensam o "quer confiar neste host?" do
    # primeiro clone, e recusam um host que não seja o GitHub de verdade.
    #
    # NUNCA ESCREVA ESTAS CHAVES DE MEMÓRIA. A primeira versão deste bloco
    # tinha uma ED25519 inventada, com o prefixo certo e o final fabricado
    # (#30). Ela não expôs ninguém — a verificação falha fechada, recusando a
    # conexão —, mas quebrou todo SSH para o GitHub, e de um jeito circular: o
    # `nupdate` não conseguia trazer a correção porque o `git fetch` depende
    # justamente do que estava quebrado.
    #
    # As três abaixo vieram de `ssh-keyscan`, e as fingerprints foram
    # conferidas contra as que o GitHub publica em
    # docs.github.com/authentication/keeping-your-account-secure/githubs-ssh-key-fingerprints
    #
    # Para reconferir a qualquer momento:
    #
    #     ssh-keyscan -t rsa,ecdsa,ed25519 github.com | ssh-keygen -lf -
    #
    #     3072 SHA256:uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s (RSA)
    #      256 SHA256:p2QAMXNIC1TJYWeIOttrVc98/R1BUFWu3/LiyKgUfQM (ECDSA)
    #      256 SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU (ED25519)
    #
    # As três, e não só a ED25519: quem decide o algoritmo é a negociação entre
    # cliente e servidor, e com uma só no arquivo um cliente que escolha outra
    # cai no mesmo "REMOTE HOST IDENTIFICATION HAS CHANGED".
    #
    # O nome do atributo é só um rótulo — quem casa com o host é `hostNames`,
    # e é por isso que as três podem apontar para github.com. As aspas em
    # "github.com" ali dentro não são estilo: sem elas o ponto viraria caminho
    # de atributo.
    programs.ssh.knownHosts = {
      "github.com-ed25519" = {
        hostNames = [ "github.com" ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
      };
      "github.com-ecdsa" = {
        hostNames = [ "github.com" ];
        publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=";
      };
      "github.com-rsa" = {
        hostNames = [ "github.com" ];
        publicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=";
      };
    };

    # O agente SSH do 1Password é ligado DENTRO do app (Settings → Developer),
    # não por um módulo NixOS — `services._1password` não existe. O que cabe
    # ao sistema é apontar o ssh para o socket que o app expõe.
    #
    # Depende de enableGui, e não só de enableSshAgent: quem cria o socket é o
    # app gráfico. Com a GUI desligada — uma máquina headless, o profile basic —
    # esta linha apontaria para um caminho que nunca vai existir, e todo `ssh`
    # da máquina passaria por um agente ausente antes de cair nas chaves do
    # disco.
    programs.ssh.extraConfig = mkIf (cfg.enableSshAgent && cfg.enableGui) ''
      Host *
        IdentityAgent ~/.1password/agent.sock
    '';
  };
}
