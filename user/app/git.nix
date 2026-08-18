# git.nix — defaults públicos e forkáveis. Opt-in por `lcars.user.git.enable`,
# ligado no profile; a flag vem do config do NixOS (veja user/options.nix).
{
  osConfig,
  lib,
  pkgs,
  user,
  ...
}:

let
  gpgKey = user.gpgKey or null;
  assina = gpgKey != null && gpgKey != "";

  # A GUI do 1Password é quem guarda a chave e traz o `op-ssh-sign`.
  onePassword = osConfig.lcars.system.app.onePassword;
  comOnePassword = onePassword.enable && onePassword.enableGui;
in
lib.mkIf osConfig.lcars.user.git.enable {
  programs.git = {
    enable = true;

    signing = lib.mkIf assina {
      format = "ssh";
      key = gpgKey;
      signByDefault = true;
    };

    settings = {
      init.defaultBranch = "main";
      pull.rebase = true;
      rerere.enabled = true;
      push.autoSetupRemote = true;
      user.Name = user.fullName;
      user.Email = user.email;
    }
    # Assinar com uma chave que vive DENTRO do cofre exige o `op-ssh-sign`: o
    # `ssh-keygen -Y sign` padrão espera um arquivo de chave privada em disco, e
    # com o 1Password não há arquivo nenhum — a chave nunca sai do app. Sem esta
    # linha, e com `gpgKey` preenchido, todo commit falharia com um erro de
    # chave não encontrada.
    #
    # Fora do `signing` de propósito: aquele bloco é tipado pelo home-manager e
    # não tem campo para o programa de assinatura.
    #
    # Aninhado, e não `"gpg.ssh".program`: o tipo é
    # `attrsOf (attrsOf (either valor secao))` (home-manager,
    # modules/programs/git.nix:41-49), então três níveis viram `[gpg "ssh"]`,
    # que é a subseção que o git procura. Com as aspas sairia uma seção de nome
    # literal `gpg.ssh`, e a chave não seria lida.
    // lib.optionalAttrs (assina && comOnePassword) {
      gpg.ssh.program = "${pkgs._1password-gui}/bin/op-ssh-sign";
    };

    aliases = {
      co = "checkout";
      br = "branch";
      ci = "commit";
      st = "status";
      lg = "log --oneline --graph --decorate";
    };
  };
}
