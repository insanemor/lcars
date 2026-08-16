# zsh.nix — setup genérico e público de shell. Opt-in por
# `lcars.user.zsh.enable`, ligado no profile; a flag vem do config do NixOS,
# não do Home Manager (veja user/options.nix).
#
# Bits sensíveis (seu nome em prompt customizado etc.) pertencem ao
# 1Password (userSettings.dotfilesFrom1Password) ou ao escape hatch
# `user/personal/default.nix`.
{
  osConfig,
  lib,
  pkgs,
  ...
}:

lib.mkIf osConfig.lcars.user.zsh.enable {
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
      ll = "ls -alF --color";
      la = "ls -A --color";
      l = "ls -CF --color";
      gs = "git status";
      gp = "git push";
      gpl = "git pull";

      # Atualiza o repo e aplica no sistema. Aceita --inputs (atualiza o
      # nixpkgs junto) e --no-check (pula a avaliação).
      #
      # Caminho fixo porque o instalador clona em ~/.dotfiles e é de lá que o
      # flake é aplicado; se um dia o caminho virar configurável, esta linha
      # acompanha.
      nupdate = "$HOME/.dotfiles/scripts/update.sh";

      # O caminho de volta: exporta a configuração do noctalia, mostra o que
      # mudou, commita e publica. Aceita -m, -n (dry run) e -y.
      #
      # Existe porque o nupdate faz `git reset --hard`: um ajuste feito aqui e
      # não publicado some no próximo nupdate.
      nsave = "$HOME/.dotfiles/scripts/save.sh";
    };

    # A integração do direnv com o zsh já é injetada pelo próprio módulo
    # (programs.direnv). Não repita aqui com um `source` manual: o caminho
    # dentro do pacote muda, e a linha quebra sem avisar.
  };

  home.packages = with pkgs; [
    zsh-completions
  ];
}
