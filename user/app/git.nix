# git.nix — defaults públicos e forkáveis. Opt-in por `lcars.user.git.enable`,
# ligado no profile; a flag vem do config do NixOS (veja user/options.nix).
{ osConfig, lib, user, ... }:

lib.mkIf osConfig.lcars.user.git.enable {
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
