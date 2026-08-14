# git.nix — defaults públicos e forkáveis.
{ lib, vars, ... }:

{
  programs.git = {
    enable = true;
    userName  = vars.fullName;
    userEmail = vars.email;

    # Só configura assinatura quando existe uma chave. Com gpgKey = null o
    # bloco inteiro sai da config, em vez de declarar `format = "ssh"` sem
    # chave nenhuma.
    signing = lib.mkIf (vars.gpgKey != null && vars.gpgKey != "") {
      format = "ssh";
      key = vars.gpgKey;
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
