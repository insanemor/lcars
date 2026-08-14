# git.nix — defaults públicos e forkáveis.
{ lib, user, ... }:

{
  programs.git = {
    enable = true;
    userName  = user.fullName;
    userEmail = user.email;

    # Só configura assinatura quando existe uma chave. Com gpgKey = null o
    # bloco inteiro sai da config, em vez de declarar `format = "ssh"` sem
    # chave nenhuma.
    signing = lib.mkIf (user.gpgKey != null && user.gpgKey != "") {
      format = "ssh";
      key = user.gpgKey;
      signByDefault = true;
    };

    extraConfig = {
      init.defaultBranch   = "main";
      pull.rebase          = true;
      rerere.enabled       = true;
      push.autoSetupRemote = true;
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
