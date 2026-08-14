# git.nix — defaults públicos e forkáveis.
{ vars, ... }:

{
  programs.git = {
    enable = true;
    userName  = vars.fullName;
    userEmail = vars.email;
    signing = { format = "ssh"; key = vars.gpgKey; };

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
