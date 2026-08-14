# zsh.nix — setup genérico e público de shell.
# Bits sensíveis (seu nome em prompt customizado etc.) pertencem ao
# 1Password (vars.dotfilesFrom1Password) ou ao escape hatch
# `home/modules/personal/default.nix`.
{ pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    shellAliases = {
      ll  = "ls -alF --color";
      la  = "ls -A --color";
      l   = "ls -CF --color";
      gs  = "git status";
      gp  = "git push";
      gpl = "git pull";
      mk  = "nix run nixpkgs#nixpkgs-update";
    };

    plugins = [
      { name = "fast-syntax-highlighting"; src = pkgs.zsh-fast-syntax-highlighting; }
      { name = "zsh-autosuggestions";      src = pkgs.zsh-autosuggestions; }
    ];

    initExtra = ''
      source ${pkgs.starship}/share/starship/init.zsh
      eval "$(direnv hook zsh)"
    '';
  };

  home.packages = with pkgs; [
    zsh-completions
    zsh-history
  ];
}
