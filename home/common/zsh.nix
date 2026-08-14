# zsh.nix — setup genérico e público de shell.
# Bits sensíveis (seu nome em prompt customizado etc.) pertencem ao
# 1Password (vars.dotfilesFrom1Password) ou ao escape hatch
# `home/modules/personal/default.nix`.
{ pkgs, ... }:

{
  programs.zsh = {
    enable = true;

    # Opções nativas do home-manager. Declarar via `plugins` exigiria apontar
    # `src` para o subdiretório certo dentro do pacote; isto faz o mesmo, certo.
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;

    history = {
      size = 50000;
      save = 50000;
      ignoreDups = true;
      share = true;
    };

    shellAliases = {
      ll  = "ls -alF --color";
      la  = "ls -A --color";
      l   = "ls -CF --color";
      gs  = "git status";
      gp  = "git push";
      gpl = "git pull";
    };

    # A integração do starship e do direnv com o zsh já é injetada pelos
    # próprios módulos (programs.starship / programs.direnv). Não repita aqui:
    # o antigo `source ${pkgs.starship}/share/starship/init.zsh` apontava para
    # um caminho que não existe no pacote.
  };

  home.packages = with pkgs; [
    zsh-completions
  ];
}
