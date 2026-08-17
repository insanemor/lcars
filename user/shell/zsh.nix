# zsh.nix — o shell interativo. Opt-in por `lcars.user.zsh.enable`, ligado no
# profile; a flag vem do config do NixOS, lida por `osConfig` (veja
# user/options.nix).
#
# Esta flag é a única de user/ que mexe também no sistema: ela decide o shell
# de login da conta, em system/core.
#
# A ORDEM DE CARGA IMPORTA AQUI
# -----------------------------
# São três camadas que precisam entrar na sequência certa:
#
#   1. oh-my-zsh    — o framework, com seus plugins
#   2. powerlevel10k — o tema, que substitui o prompt
#   3. p10k.zsh     — a configuração do tema, que só vale depois dele
#
# O home-manager carrega `plugins` na ordem em que aparecem na lista, e depois
# do oh-my-zsh. Por isso o p10k e sua configuração são declarados ali, nessa
# ordem, e não em `initContent` — que roda depois de tudo e faria o arquivo de
# configuração ser lido antes do tema existir.
{
  osConfig,
  lib,
  pkgs,
  ...
}:

lib.mkIf osConfig.lcars.user.zsh.enable {
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;

    history = {
      size = 50000;
      save = 50000;
      ignoreDups = true;
      share = true;
    };

    oh-my-zsh = {
      enable = true;

      # Enxuta de propósito. Cada plugin é código que roda a cada shell
      # aberto, e o oh-my-zsh já tem fama de deixar a abertura lenta — numa
      # VM com CPU disputada isso se nota.
      #
      # O que NÃO está aqui, e por quê:
      #
      #   zsh-autosuggestions e zsh-syntax-highlighting — já vêm pelas options
      #   `autosuggestion` e `syntaxHighlighting` acima, que o home-manager
      #   carrega dos pacotes do nixpkgs. Repetir na lista do oh-my-zsh
      #   carregaria os mesmos plugins duas vezes.
      plugins = [
        "git" # aliases e o status do repositório no prompt
        "sudo" # ESC ESC repete o último comando com sudo
        "systemd" # aliases para systemctl
      ];

      # Vazio, e não "powerlevel10k": o p10k não é um tema do oh-my-zsh, e sim
      # um plugin próprio. Apontá-lo aqui faria o framework procurar um arquivo
      # no diretório de temas dele, que não existe — e cair no prompt padrão
      # sem avisar.
      theme = "";
    };

    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh/themes/powerlevel10k/powerlevel10k.zsh-theme";
      }
      {
        # A configuração do tema entra como plugin pelo mesmo motivo de ordem:
        # precisa ser lida depois do tema, e antes do primeiro prompt.
        name = "p10k-config";
        src = ./.;
        file = "p10k.zsh";
      }
    ];

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
  };

  # A integração do direnv com o zsh já é injetada pelo próprio módulo
  # (programs.direnv). Não repita aqui com um `source` manual: o caminho
  # dentro do pacote muda, e a linha quebra sem avisar.

  home.packages = with pkgs; [
    zsh-completions
  ];
}
