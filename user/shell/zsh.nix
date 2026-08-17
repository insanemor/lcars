# zsh.nix — o shell interativo. Opt-in por `lcars.user.zsh.enable`, ligado no
# profile; a flag vem do config do NixOS, lida por `osConfig` (veja
# user/options.nix).
#
# Esta flag é a única de user/ que mexe também no sistema: ela decide o shell
# de login da conta, em system/core.
#
# A ORDEM DE CARGA IMPORTA AQUI
# -----------------------------
# São quatro camadas que precisam entrar na sequência certa:
#
#   1. oh-my-zsh    — o framework, com seus plugins
#   2. powerlevel10k — o tema, que substitui o prompt
#   3. p10k.zsh      — a configuração do tema, que só vale depois dele
#   4. promptCores   — as cores do esquema, que precisam vencer o preset
#
# Os três primeiros são `plugins`, que o home-manager carrega em ordem e depois
# do oh-my-zsh. O quarto é `initContent` com `mkAfter`, justamente porque roda
# no fim: é o que dá a ele a última palavra sobre a cor.
#
# Inverter qualquer par quebra em silêncio — o prompt cai no padrão, ou as
# cores do preset vencem as do tema, sem erro em lugar nenhum.
{
  config,
  osConfig,
  lib,
  pkgs,
  ...
}:

let
  cores = config.lib.stylix.colors.withHashtag;

  # As cores do prompt, a partir do esquema base16.
  #
  # O powerlevel10k aceita hex — está em internal/p10k.zsh:535,
  # `elif [[ $1 == '#'[[:xdigit:]]## ]]` — e não só os 256 índices do terminal
  # que o preset usa. É o que permite pintar o prompt com a paleta exata em vez
  # de "o azul do terminal, seja ele qual for".
  #
  # Isto entra DEPOIS do preset, sobrescrevendo só os segmentos do dia a dia. O
  # p10k.zsh continua sendo o arquivo que você edita com `p10k configure` — se
  # esta sobreposição fosse gerada lá dentro, o assistente a apagaria no
  # primeiro uso.
  #
  # O que fica de fora e continua com os índices do preset: ícone de sistema,
  # bateria, versões de linguagem, nuvens. Aparecem raramente e não valem a
  # manutenção de mais trinta linhas.
  promptCores = ''
    # --- cores do prompt, geradas de lcars.system.theme.scheme ---------
    # Editar aqui não adianta: este bloco é gerado por user/shell/zsh.nix.
    # Para mudar a paleta, mude o esquema; para mudar a forma, p10k.zsh.
    #
    # Aspas simples nos valores: `#` inicia comentário no zsh, e ainda que
    # dentro de uma atribuição ele não inicie, a documentação do p10k usa
    # aspas. Não custa nada e tira a dúvida.

    # diretório: o ciano da marca, com o fundo escuro por cima
    typeset -g POWERLEVEL9K_DIR_BACKGROUND='${cores.base0D}'
    typeset -g POWERLEVEL9K_DIR_FOREGROUND='${cores.base00}'
    typeset -g POWERLEVEL9K_DIR_SHORTENED_FOREGROUND='${cores.base01}'
    typeset -g POWERLEVEL9K_DIR_ANCHOR_FOREGROUND='${cores.base00}'

    # git: verde limpo, lime sujo, água com arquivo novo, vermelho em conflito
    typeset -g POWERLEVEL9K_VCS_CLEAN_BACKGROUND='${cores.base0B}'
    typeset -g POWERLEVEL9K_VCS_MODIFIED_BACKGROUND='${cores.base0A}'
    typeset -g POWERLEVEL9K_VCS_UNTRACKED_BACKGROUND='${cores.base0C}'
    typeset -g POWERLEVEL9K_VCS_CONFLICTED_BACKGROUND='${cores.base08}'
    typeset -g POWERLEVEL9K_VCS_LOADING_BACKGROUND='${cores.base03}'
    typeset -g POWERLEVEL9K_VCS_FOREGROUND='${cores.base00}'

    # o caractere do prompt: verde quando o último comando deu certo
    typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND='${cores.base0B}'
    typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND='${cores.base08}'

    # status do último comando
    typeset -g POWERLEVEL9K_STATUS_OK_BACKGROUND='${cores.base0B}'
    typeset -g POWERLEVEL9K_STATUS_OK_FOREGROUND='${cores.base00}'
    typeset -g POWERLEVEL9K_STATUS_OK_PIPE_BACKGROUND='${cores.base0B}'
    typeset -g POWERLEVEL9K_STATUS_OK_PIPE_FOREGROUND='${cores.base00}'
    typeset -g POWERLEVEL9K_STATUS_ERROR_BACKGROUND='${cores.base08}'
    typeset -g POWERLEVEL9K_STATUS_ERROR_FOREGROUND='${cores.base00}'
    typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE_BACKGROUND='${cores.base08}'
    typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE_FOREGROUND='${cores.base00}'
    typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL_BACKGROUND='${cores.base08}'
    typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL_FOREGROUND='${cores.base00}'

    # tempo de execução e relógio: discretos, na escala de fundo
    typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_BACKGROUND='${cores.base02}'
    typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND='${cores.base05}'
    typeset -g POWERLEVEL9K_TIME_BACKGROUND='${cores.base01}'
    typeset -g POWERLEVEL9K_TIME_FOREGROUND='${cores.base04}'

    # tarefas em segundo plano e direnv
    typeset -g POWERLEVEL9K_BACKGROUND_JOBS_BACKGROUND='${cores.base0C}'
    typeset -g POWERLEVEL9K_BACKGROUND_JOBS_FOREGROUND='${cores.base00}'
    typeset -g POWERLEVEL9K_DIRENV_BACKGROUND='${cores.base0A}'
    typeset -g POWERLEVEL9K_DIRENV_FOREGROUND='${cores.base00}'
  '';
in
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

    # Depois de tudo: o oh-my-zsh, o tema e o preset já rodaram, e é isto que
    # dá à sobreposição a última palavra sobre a cor.
    initContent = lib.mkAfter promptCores;

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
