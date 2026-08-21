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
  inputs,
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
  # O que fica de fora e continua com os índices do preset: bateria, e os
  # segmentos que só aparecem em ferramenta específica (nordvpn, ranger,
  # toolbox, midnight commander). Aparecem raramente e não valem a manutenção.
  #
  # DUAS CLASSES DE COR QUE ESTE BLOCO NÃO ALCANÇAVA, e hoje alcança:
  #
  #   1. Variável local de função. As cores do texto do git são `local` dentro
  #      de my_git_formatter, e nenhum `typeset -g` sobrescreve uma local. O
  #      p10k.zsh agora lê parâmetros ali, com o valor do preset como padrão.
  #   2. Conteúdo, e não cor. O template do `context` e o ícone do `os_icon`
  #      carregam cor dentro do próprio texto, via `%F{}`. Por isso o logo da
  #      SimbioIT é gerado aqui embaixo, e não no p10k.zsh.
  # O LOGO DA SIMBIOIT NO LUGAR DO ÍCONE DE SISTEMA
  #
  # Quatro glifos, um por célula do terminal, injetados na fonte por
  # system/theme/logo-fonte (veja lá o desenho e o porquê de ser fonte, e não
  # um caractere Unicode qualquer). O terminal pinta uma cor por célula, então
  # o gradiente do logo vira uma cor por caractere.
  #
  # As quatro cores espelham CORES_CELULA em system/theme/logo-fonte/logo.py,
  # que é onde o desenho vive. Mudou lá, muda aqui.
  #
  # `$'...'` e não aspas simples: é a única forma de citação do zsh que
  # interpreta `\u`, e escrever os codepoints é bem melhor de manter do que
  # colar quatro caracteres invisíveis da área de uso privado no meio do
  # arquivo.
  #
  # Sem fundo, ao contrário do resto da linha 1: com um bloco claro atrás, as
  # cores do logo perdem contraste — o ciano sobre base07 fica em 2:1.
  #
  # Os dois espaços no fim não são enfeite. O segmento seguinte é o dir, com
  # fundo ciano e separador  no MESMO ciano: sem a folga, o lado direito do
  # arco encosta no triângulo e as duas formas viram uma só.
  logoNoPrompt = ''
    typeset -g POWERLEVEL9K_OS_ICON_BACKGROUND=
    typeset -g POWERLEVEL9K_OS_ICON_FOREGROUND='${cores.base0D}'
    typeset -g POWERLEVEL9K_OS_ICON_CONTENT_EXPANSION=$'%F{${cores.base0A}}\uf8f0%F{${cores.base0C}}\uf8f1%F{${cores.base0D}}\uf8f2\uf8f3  '
  '';

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

    # O TEXTO do segmento de git, que até então escapava daqui
    #
    # O nome do branch saía em preto puro. As cores dele são variáveis LOCAIS
    # da função my_git_formatter, no p10k.zsh, e nenhum `typeset -g` alcança
    # uma variável local — o bloco inteiro passava ao largo delas. Lá elas
    # viraram parâmetros com o valor do preset como padrão; aqui os quatro
    # fundos acima são cores CLARAS, então todo texto sobre eles é escuro.
    typeset -g POWERLEVEL9K_VCS_META_FOREGROUND='%F{${cores.base00}}'
    typeset -g POWERLEVEL9K_VCS_CLEAN_TEXT_FOREGROUND='%F{${cores.base00}}'
    typeset -g POWERLEVEL9K_VCS_MODIFIED_TEXT_FOREGROUND='%F{${cores.base00}}'
    typeset -g POWERLEVEL9K_VCS_UNTRACKED_TEXT_FOREGROUND='%F{${cores.base00}}'
    typeset -g POWERLEVEL9K_VCS_CONFLICTED_TEXT_FOREGROUND='%F{${cores.base00}}'

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

    # a moldura das três linhas: base03 é a cor de "comentário e invisível" no
    # base16, que é exatamente o papel dela. No preset são índices de terminal
    # (240), e o valor certo aqui é o mesmo parâmetro, redefinido depois.
    typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX='%F{${cores.base03}}╭─'
    typeset -g POWERLEVEL9K_MULTILINE_NEWLINE_PROMPT_PREFIX='%F{${cores.base03}}├─'
    typeset -g POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX='%F{${cores.base03}}╰─'
    typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_SUFFIX='%F{${cores.base03}}─╮'
    typeset -g POWERLEVEL9K_MULTILINE_NEWLINE_PROMPT_SUFFIX='%F{${cores.base03}}─┤'
    typeset -g POWERLEVEL9K_MULTILINE_LAST_PROMPT_SUFFIX='%F{${cores.base03}}─╯'
    typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_FOREGROUND='${cores.base03}'
    typeset -g POWERLEVEL9K_MULTILINE_NEWLINE_PROMPT_GAP_FOREGROUND='${cores.base03}'

    # CONTEXT (user@máquina), na linha de digitação
    #
    # Sem fundo, ao contrário do resto: as linhas 1 e 2 já são blocos
    # powerline cheios, e mais um bloco logo antes do cursor deixava a linha
    # de digitar tão pesada quanto as de cima. Sem fundo também não há seta
    # ⁠ entre o segmento e o que você digita.
    typeset -g POWERLEVEL9K_CONTEXT_BACKGROUND=
    typeset -g POWERLEVEL9K_CONTEXT_{ROOT,SUDO,REMOTE,REMOTE_SUDO}_BACKGROUND=
    typeset -g POWERLEVEL9K_CONTEXT_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=
    typeset -g POWERLEVEL9K_CONTEXT_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL=

    # O FOREGROUND não pinta o conteúdo — quem faz isso é o template logo
    # abaixo. Ele pinta o espaço de separação, que sem isto ficava com o
    # amarelo 3 do preset pendurado no fim da linha.
    typeset -g POWERLEVEL9K_CONTEXT_FOREGROUND='${cores.base04}'
    typeset -g POWERLEVEL9K_CONTEXT_ROOT_FOREGROUND='${cores.base08}'
    typeset -g POWERLEVEL9K_CONTEXT_{REMOTE,REMOTE_SUDO}_FOREGROUND='${cores.base0A}'

    # No dia a dia: usuário apagado, `@` mais apagado ainda, e a MÁQUINA no
    # ciano da marca, em negrito. É o dado que muda quando você troca de host,
    # e o único que precisa ser lido de relance numa linha que está sempre à
    # vista.
    typeset -g POWERLEVEL9K_CONTEXT_TEMPLATE='%F{${cores.base04}}%n%f%F{${cores.base03}}@%f%B%F{${cores.base0D}}%m%f%b'

    # Root e SSH têm classes próprias, cada uma com o seu template — a linha
    # inteira muda de cor, porque é o caso em que você precisa perceber sem
    # ler.
    typeset -g POWERLEVEL9K_CONTEXT_ROOT_TEMPLATE='%B%F{${cores.base08}}%n@%m%f%b'
    typeset -g POWERLEVEL9K_CONTEXT_{REMOTE,REMOTE_SUDO}_TEMPLATE='%B%F{${cores.base0A}}%n@%m%f%b'

    # NUVEM E LINGUAGEM
    #
    # Estes vinham com índice de terminal — aws em %K{1}, kubecontext em
    # %K{5}, virtualenv em %K{4} — e aparecem os três na MESMA linha, um do
    # lado do outro. Era ali que o prompt saía da paleta de vez.
    #
    # A hierarquia é por consequência, não por tecnologia:
    #
    #   produção   vermelho  o comando errado aqui custa caro
    #   homolog    lime      atenção, sem pânico
    #   o resto    laranja (aws) e violeta (k8s), cada nuvem com a sua cor
    #   linguagem  fundo escuro, é informação e não aviso

    typeset -g POWERLEVEL9K_AWS_DEFAULT_BACKGROUND='${cores.base09}'
    typeset -g POWERLEVEL9K_AWS_DEFAULT_FOREGROUND='${cores.base00}'
    typeset -g POWERLEVEL9K_AWS_PROD_BACKGROUND='${cores.base08}'
    typeset -g POWERLEVEL9K_AWS_PROD_FOREGROUND='${cores.base00}'
    typeset -g POWERLEVEL9K_AWS_TEST_BACKGROUND='${cores.base0A}'
    typeset -g POWERLEVEL9K_AWS_TEST_FOREGROUND='${cores.base00}'

    typeset -g POWERLEVEL9K_KUBECONTEXT_DEFAULT_BACKGROUND='${cores.base0E}'
    typeset -g POWERLEVEL9K_KUBECONTEXT_DEFAULT_FOREGROUND='${cores.base00}'
    typeset -g POWERLEVEL9K_KUBECONTEXT_PROD_BACKGROUND='${cores.base08}'
    typeset -g POWERLEVEL9K_KUBECONTEXT_PROD_FOREGROUND='${cores.base00}'
    typeset -g POWERLEVEL9K_KUBECONTEXT_TEST_BACKGROUND='${cores.base0A}'
    typeset -g POWERLEVEL9K_KUBECONTEXT_TEST_FOREGROUND='${cores.base00}'

    typeset -g POWERLEVEL9K_TERRAFORM_OTHER_BACKGROUND='${cores.base0E}'
    typeset -g POWERLEVEL9K_TERRAFORM_OTHER_FOREGROUND='${cores.base00}'

    # Os gerenciadores de versão são os segmentos que mais aparecem e os que
    # menos precisam ser vistos. Com fundo cheio, a direita do prompt virava
    # uma faixa contínua de cor.
    typeset -g POWERLEVEL9K_VIRTUALENV_BACKGROUND='${cores.base02}'
    typeset -g POWERLEVEL9K_VIRTUALENV_FOREGROUND='${cores.base0C}'
    typeset -g POWERLEVEL9K_PYENV_BACKGROUND='${cores.base02}'
    typeset -g POWERLEVEL9K_PYENV_FOREGROUND='${cores.base0C}'
    typeset -g POWERLEVEL9K_ANACONDA_BACKGROUND='${cores.base02}'
    typeset -g POWERLEVEL9K_ANACONDA_FOREGROUND='${cores.base0C}'
    typeset -g POWERLEVEL9K_ASDF_{PYTHON,NODEJS,GOLANG,RUBY,RUST,TERRAFORM,JAVA}_BACKGROUND='${cores.base02}'
    typeset -g POWERLEVEL9K_ASDF_{PYTHON,NODEJS,GOLANG,RUBY,RUST,TERRAFORM,JAVA}_FOREGROUND='${cores.base0C}'

    ${logoNoPrompt}
  '';

  # O hook do plugin herdr-automatic-rename (user/app/herdr.nix): renomeia a
  # aba em tempo real a cada comando, o que nenhum evento do herdr cobre
  # sozinho (a reconciliação por evento, no próprio plugin, só reage a
  # mudança de painel/foco — não a cada Enter no prompt). Mesmo padrão do
  # alias `lg`, mais abaixo: condicionado à flag de outro módulo
  # (`lcars.user.herdr.enable`), porque o pacote só existe quando ele está
  # ligado.
  #
  # `lib.optionalString` em vez de `lib.optionalAttrs`: aqui o que varia é
  # uma STRING dentro de initContent, não uma chave do attrset do
  # `programs.zsh`.
  hookAutomaticRename = lib.optionalString osConfig.lcars.user.herdr.enable ''
    source "${inputs.herdr-automatic-rename}/shell/hook.zsh"
  '';

  # A integração padrão do fzf (user/shell/fzf.nix) também tenta o Ctrl+R
  # pro seu próprio fuzzy-finder de histórico — mas essa tecla já é do
  # atuin (user/shell/atuin.nix), que é a busca melhor das duas aqui:
  # fuzzy, global, sincronizada entre máquinas.
  #
  # NÃO HÁ CONFLITO ATIVO HOJE: conferido gerando o initContent de verdade
  # (módulos/programs/{fzf,atuin}.nix do Home Manager) — o fzf entra com
  # `mkOrder 910`, o atuin não declara ordem (default 1000), e string de
  # ordem menor vem primeiro. O atuin já roda DEPOIS do fzf e vence por
  # conta própria.
  #
  # Este bindkey existe como garantia, não como correção: se um dia o
  # nixpkgs mudar essa ordem (não é contrato público, é detalhe interno de
  # implementação), o Ctrl+R continua do atuin sem precisar notar a
  # mudança. `atuin init zsh` bindka `bindkey -M emacs '^r' atuin-search`
  # (emacs é o keymap ativo neste repo — não há `bindkey -v` em lugar
  # nenhum); repetir isso depois das duas integrações, via `mkAfter`
  # (ordem 1500), garante a mesma tecla não importa a ordem real das duas.
  #
  # Só entra quando os dois estão ligados — com só um dos dois, não há o
  # que garantir.
  fixCtrlRParaAtuin =
    lib.optionalString (osConfig.lcars.user.fzf.enable && osConfig.lcars.user.atuin.enable)
      ''
        bindkey -M emacs '^r' atuin-search
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
    initContent = lib.mkAfter (
      (if temaLigado then promptCores else "") + hookAutomaticRename + fixCtrlRParaAtuin
    );

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
