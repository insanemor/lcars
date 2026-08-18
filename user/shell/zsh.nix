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
#                      (só quando há tema; veja `temaLigado` abaixo)
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
  user,
  ...
}:

let
  # O tema é opcional, e o prompt precisa saber disso.
  #
  # `config.lib.stylix` só existe quando o módulo do stylix está habilitado, e
  # quem o habilita é system/theme, sob `lcars.system.theme.enable`. O profile
  # basic desliga o tema de propósito — numa máquina headless um esquema de
  # cores é peso morto — mas mantém o zsh ligado. Sem esta guarda, a avaliação
  # do basic morria em `attribute 'stylix' missing`, e como o nupdate avalia os
  # DOIS profiles, isso bloqueava o rebuild até de quem usa o personal.
  #
  # Mesmo padrão de user/wm/noctalia.nix, que já lia a flag por osConfig.
  temaLigado = osConfig.lcars.system.theme.enable;

  # OS SUBSTITUTOS SÓ VIRAM ALIAS SE ESTIVEREM INSTALADOS
  # -----------------------------------------------------
  # `eza` e `bat` vêm da lista de pacotes do usuário, que system/core monta
  # somando `lcars.system.core.userPackages` (o profile) a
  # `userSettings.packages` (você). O profile `personal` põe os dois; o `basic`
  # não põe nenhum, porque `userPackages` tem default `[ ]`.
  #
  # Sem esta checagem, um `alias ls = "eza"` deixaria uma máquina headless SEM
  # `ls` — estrago grande demais para um confortinho de terminal. O alias só
  # existe onde o programa existe.
  pacotes = (user.packages or [ ]) ++ osConfig.lcars.system.core.userPackages;
  temPacote = nome: builtins.elem nome pacotes;

  temEza = temPacote "eza";
  temBat = temPacote "bat";

  # Só é avaliado quando `temaLigado` — o Nix não força o que não se usa, e é
  # justamente isso que mantém o atributo inexistente fora do caminho.
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
    # Sem tema, o prompt fica com as cores do próprio preset do p10k — que
    # funciona, só não segue o esquema. É o comportamento certo para uma
    # máquina headless, onde não há esquema nenhum a seguir.
    initContent = lib.mkAfter (if temaLigado then promptCores else "");

    shellAliases = {
      # --- listagem ----------------------------------------------------
      # Com o eza instalado, é ele quem atende por `ls` — e por ll/la/l, que
      # mantêm o sentido de sempre: tudo em lista longa, tudo em coluna, e a
      # coluna curta. O que muda é o que vem junto: ícone por tipo de arquivo e
      # o estado no git de cada um, que é o que o eza tem e o ls não.
      #
      # `--group-directories-first` porque diretório em cima é o que a gente
      # procura primeiro, e `--git` só faz sentido com repositório por perto —
      # fora dele, a coluna simplesmente não aparece.
      #
      # Sem o eza, tudo continua exatamente como antes.
      #
      # O `ls` de verdade nunca fica inacessível: `\ls` ou `command ls` passam
      # por cima de qualquer alias, e é assim que se escapa deles no zsh.
      ll = if temEza then "eza --icons --group-directories-first --git -l --all" else "ls -alF --color";
      la = if temEza then "eza --icons --group-directories-first --all" else "ls -A --color";
      l = if temEza then "eza --icons --group-directories-first" else "ls -CF --color";

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
    }
    # `ls` e `cat` só mudam de dono onde o substituto existe. Sem o pacote, o
    # alias nem é gerado — nada de `alias cat=cat`, e nada de um `ls --color`
    # que ninguém pediu aparecer numa máquina headless.
    // lib.optionalAttrs temEza {
      ls = "eza --icons --group-directories-first";

      # Árvore, que o ls não faz e o eza faz sem precisar de outro programa.
      # Dois níveis: o bastante para entender um diretório sem inundar a tela.
      lt = "eza --icons --tree --level=2";
    }
    // lib.optionalAttrs temBat {
      # O bat sabe quando não está falando com um terminal: em pipe ou
      # redirecionamento ele vira o cat, sem cor, sem número de linha e sem
      # paginador. É o que torna este alias seguro — `cat x | grep y` continua
      # funcionando, e `cat x > y` também.
      cat = "bat";
    }
    # O lazygit vem de user/app/herdr.nix (home.packages), não da lista de
    # pacotes que `temPacote` verifica acima — por isso o guard aqui é a flag
    # do módulo dono do pacote, e não `temPacote "lazygit"`, que sempre daria
    # falso mesmo com o binário instalado. Mesmo princípio de eza/bat: o
    # alias só existe onde o programa existe (#72).
    // lib.optionalAttrs osConfig.lcars.user.herdr.enable {
      lg = "lazygit";
    };
  };

  # A integração do direnv com o zsh já é injetada pelo próprio módulo
  # (programs.direnv). Não repita aqui com um `source` manual: o caminho
  # dentro do pacote muda, e a linha quebra sem avisar.

  home.packages = with pkgs; [
    zsh-completions
  ];
}
