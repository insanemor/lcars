# kitty.nix — o terminal.
#
# Opt-in por `lcars.user.kitty.enable`, ligado no profile. A flag vem do config
# do NixOS (veja user/options.nix).
#
# Por que este arquivo existe, se o kitty já era instalado
# --------------------------------------------------------
# Ele era instalado por `home.packages` em user/wm/niri.nix, e só. O pacote
# estava no PATH e o programa rodava — com os defaults de fábrica: fonte
# genérica e paleta própria.
#
# O stylix tem alvo para kitty, mas ele age sobre `programs.kitty` do Home
# Manager. Sem o módulo habilitado, nenhum kitty.conf é gerado e não há onde a
# fonte e as cores entrarem. Era por isso que a paleta simbiot-dark pintava
# tudo menos o terminal, e a Nerd Font não aparecia justamente onde os ícones
# do prompt precisam dela.
#
# É a mesma lição que o comentário do noctalia já registrava: instalar o pacote
# não é configurar o programa.
#
# O que NÃO está aqui
# -------------------
# Nem fonte, nem tamanho, nem uma única cor. Tudo isso vem do stylix, a partir
# de `lcars.system.theme` — o mesmo lugar que serve o resto do sistema. Escrever
# a fonte aqui criaria uma segunda fonte de verdade que ninguém lembraria de
# atualizar.
#
# O SHELL DO KITTY É O HERDR
# --------------------------
# Quando `lcars.user.herdr.enable` também está ligado, o kitty roda o herdr no
# lugar do shell de login: abrir o terminal é abrir o multiplexador, já com as
# sessões de antes de pé. É o que o `tmux attach` no `.zshrc` fazia na máquina
# antiga, e o hábito não tinha atravessado a mudança — o herdr entrou na #41
# como programa no PATH, a um comando de distância de toda sessão.
#
# Não há recursão nisso: os painéis abertos DENTRO do herdr não passam pelo
# kitty, eles nascem do `default_shell = "zsh"` do config.toml (veja
# user/app/herdr.nix). É também por isso que o caminho escolhido foi este, e
# não um `exec herdr` no .zshrc — lá, sem uma variável de ambiente confiável
# marcando "já estou dentro", o risco é um loop de shells.
#
# A saída de emergência mora em outro arquivo: `mod+Shift+Return`, em
# user/wm/niri.nix, abre um kitty rodando o zsh direto. O herdr é um binário
# compilado de um input preso numa tag — se um `nupdate --inputs` o quebrar,
# aquele atalho é o terminal que roda o rollback.
{
  osConfig,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  # Mesmo pacote que user/app/herdr.nix instala, e pelo mesmo motivo: o herdr
  # não existe no nixpkgs, vem do input do próprio upstream. Aqui ele é só o
  # caminho no store para o `shell` abaixo — quem instala é o outro módulo.
  herdr = lib.getExe inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
lib.mkIf osConfig.lcars.user.kitty.enable (
  # Opacidade — para o liquid-glass do niri-glass (#107/#108) ter onde
  # aparecer.
  #
  # O `background-effect { xray; liquid-glass }` do window-rule em
  # user/wm/niri.nix só revela o vidro nas partes da JANELA que já são
  # transparentes — ele não força nada a ficar translúcido (confirmado na wiki
  # do niri e no shader do fork). Sem nenhum app com opacidade própria, o
  # efeito ficava sem onde aparecer: zero janela mostrava qualquer traço dele.
  # A #109 investigou isso dentro da VM (journalctl + screenshot) e confirmou
  # o compositor funcionando — faltava só isto.
  #
  # `stylix.opacity.terminal`, e não `programs.kitty.settings.background_opacity`
  # direto: o stylix já escreve essa chave (`modules/kitty/hm.nix`, com o
  # default 1.0 do próprio stylix), e as duas definições na mesma prioridade
  # são conflito de avaliação — pego pelo `check.sh --eval` do profile
  # personal. É a opção que o próprio stylix expõe pra isto, vale pra todo
  # terminal que ele tematiza, não só o kitty.
  #
  # Só com `theme.enable`, e é por isso que isto está fora de
  # `programs.kitty.settings`, somado por `//`: no profile `basic`, o stylix
  # nem chega a existir do lado do Home Manager —
  # `home-manager.users.<user>.stylix` não é opção — e `check.sh --eval`
  # prova isso na hora.
  #
  # Limitação do PRÓPRIO kitty, não deste repo: a opacidade só vale nas
  # células com a cor de fundo PADRÃO do terminal. Onde um programa pinta uma
  # cor de fundo explícita — os painéis e a status bar do herdr, por exemplo —
  # a célula continua opaca, de propósito, pra manter texto legível. Por isso
  # o vidro aparece forte com o terminal ocioso e quase some com a TUI cheia
  # de cor. Não é bug, é o `kitty/options/definition.py` upstream.
  lib.optionalAttrs osConfig.lcars.system.theme.enable {
    stylix.opacity.terminal = 0.8;
  }
  // {
    programs.kitty = {
      enable = true;

      settings = {
        # Rolagem generosa: o padrão do kitty são 2000 linhas, e uma saída de
        # build de NixOS passa disso sem esforço.
        scrollback_lines = 10000;

        # Sem o aviso de "sua configuração mudou, recarregue" a cada rebuild.
        confirm_os_window_close = 0;

        # A barra de título é desenhada pelo compositor, não pelo kitty — é o que
        # `prefer-no-csd` do niri pede, e o que faz o anel de foco aparecer.
        hide_window_decorations = "yes";
      }
      # Caminho absoluto no store, e não o nome do programa: o kitty é lançado
      # pelo compositor, cujo PATH não é o do shell interativo. Com o herdr
      # desligado a linha não é gerada, e o kitty volta ao shell de login da
      # conta — é o que mantém o profile `basic` inteiro.
      // lib.optionalAttrs osConfig.lcars.user.herdr.enable {
        shell = herdr;
      };

      # COLAR — Ctrl+V e Ctrl+Insert, além do Ctrl+Shift+V de fábrica (#71)
      # --------------------------------------------------------------------
      # O padrão do kitty é só `ctrl+shift+v` (e `shift+insert`): ele reserva
      # `ctrl+v` de propósito, pra não atropelar programas de terminal que usam
      # essa combinação — o caso mais comum é o modo visual-block do vim/nvim.
      # Foi assim que a #71 apareceu: "copio, mas não consigo colar" era
      # digitar `Ctrl+V`/`Ctrl+Insert` (o hábito de toda GUI) contra um kitty
      # que só reconhece `Ctrl+Shift+V`.
      #
      # As duas linhas abaixo pagam esse preço às claras: um keybinding do
      # kitty intercepta ANTES da tecla chegar ao programa dentro do terminal
      # (o herdr, ou o que estiver rodando dentro dele). Com isto ligado,
      # `Ctrl+V` sempre cola — inclusive dentro do vim/nvim, onde antes entrava
      # em modo visual-block. Escolha deliberada do usuário: o Ctrl+V "como em
      # qualquer app" pesa mais que o atalho do vim, que continua acessível por
      # `v` (visual) e `Ctrl+Shift+V` residual não muda nada aqui.
      keybindings = {
        "ctrl+v" = "paste_from_clipboard";
        "ctrl+insert" = "paste_from_clipboard";
      };
    };
  }
)
