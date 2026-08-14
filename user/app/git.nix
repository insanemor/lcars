# git.nix — defaults públicos e forkáveis.
{ lib, user, ... }:

{
  programs.git = {
    enable = true;
    userName  = user.fullName;
    userEmail = user.email;

    # Só configura assinatura quando existe uma chave. Sem `gpgKey` no
    # settings.nix, ou com ele em null, o bloco inteiro sai da config — em vez
    # de declarar `format = "ssh"` sem chave nenhuma.
    signing =
      let gpgKey = user.gpgKey or null; in
      lib.mkIf (gpgKey != null && gpgKey != "") {
        format = "ssh";
        key = gpgKey;
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
