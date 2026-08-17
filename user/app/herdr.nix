# herdr.nix — o multiplexador de terminal: workspaces, painéis e sessões que
# continuam vivas depois de o terminal fechar. É o lugar do tmux, e os atalhos
# daqui são deliberadamente os do tmux — prefixo Ctrl-a, `|` e `-` para dividir,
# `hjkl` para andar — para que a memória muscular atravesse a mudança.
#
# Opt-in por `lcars.user.herdr.enable`, ligado no profile. A flag vem do config
# do NixOS (veja user/options.nix).
#
# QUEM O ABRE É O TERMINAL
# ------------------------
# Com a flag ligada, user/app/kitty.nix aponta o `shell` do kitty para este
# pacote: abrir o terminal é abrir o herdr. Os painéis daqui de dentro nascem
# do `default_shell = "zsh"` lá embaixo e não passam pelo kitty, o que é o que
# torna o arranjo seguro. A saída para um terminal sem ele é
# `mod+Shift+Return`, em user/wm/niri.nix.
#
# DE ONDE VEM O PACOTE
# --------------------
# Do input `herdr` do flake, não do nixpkgs — lá ele não existe. O upstream
# publica o próprio flake, e é `packages.<system>.default` que instalamos aqui.
# É também por isso que este módulo recebe `inputs`, o que nenhum outro de
# user/ precisa: veja o comentário do extraSpecialArgs em flake.nix.
#
# Compilar leva minutos e não há cache binário. Atualizar é `nupdate --inputs`;
# `herdr update`, que o programa oferece, não funciona — o binário está no
# store, que é read-only, e de todo modo a versão passaria a divergir do flake.
#
# O CONFIG.TOML É GERADO, E ISSO TEM UM CUSTO
# -------------------------------------------
# O arquivo abaixo vira um symlink read-only para o store. O herdr, porém,
# escreve no próprio config em três situações: ao terminar o onboarding (grava
# `onboarding = false`), em `herdr config reset-keys`, e ao salvar ajustes pela
# tela de settings. A primeira está resolvida — a configuração já nasce com
# `onboarding = false`, então ele não tenta. As outras duas vão falhar, e a
# resposta certa é editar este arquivo e rodar `nupdate`, que é o mesmo trato
# de todo dotfile gerado neste repo.
#
# O QUE NÃO ESTÁ AQUI
# -------------------
# Os plugins do herdr (file viewer, browser, claude-usage) são baixados em
# tempo de execução por `herdr plugin`, num diretório mutável que o Nix não
# gerencia. Os atalhos do browser existem abaixo, mas ficam inertes até o
# plugin ser instalado uma vez, à mão. O mesmo vale para o token
# `$claude_usage` da sidebar.
{
  config,
  osConfig,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cores = config.lib.stylix.colors.withHashtag;

  herdr = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # O popup do lazygit aponta para o caminho no store, e não para o nome do
  # programa. Na máquina Garuda essa linha carregava um PATH inteiro escrito à
  # mão (asdf, bun, linuxbrew) porque o herdr podia ter subido antes de o shell
  # montar o ambiente; aqui o caminho é absoluto e imutável, e a questão
  # simplesmente não existe.
  lazygit = lib.getExe pkgs.lazygit;

  # O plugin browser do herdr fala CDP com um Chromium. Ele vai como caminho
  # absoluto e NÃO entra no PATH: é um motor de renderização para o painel, não
  # um navegador para usar. (Vivaldi não serve — falha com "timed out waiting
  # for CDP Page.enable".)
  chromium = lib.getExe pkgs.chromium;

  # As cores, do esquema base16 do stylix — o mesmo que pinta o terminal, o
  # prompt, GTK e Qt. O herdr aceita hex em todos os tokens (veja
  # src/config/theme.rs no upstream), então a paleta inteira é sobrescrita e
  # nada do tema base aparece; `name` fica no default só por ele ser
  # obrigatório ter um.
  #
  # Na máquina Garuda estas quatro linhas eram hex escritos à mão em cima do
  # catppuccin. Aqui trocar `lcars.system.theme.scheme` repinta o herdr junto
  # com o resto do sistema, que é a razão de o esquema existir.
  tema = ''
    [theme]
    name        = "catppuccin"
    auto_switch = false

    [theme.custom]
    # superfícies: a escala de fundo do esquema, do mais fundo ao mais claro
    panel_bg      = "${cores.base00}"
    sidebar_bg    = "${cores.base01}"
    surface0      = "${cores.base01}"
    surface1      = "${cores.base02}"
    surface_dim   = "${cores.base01}"
    active_row_bg = "${cores.base02}"
    selection_bg  = "${cores.base02}"

    # texto: do apagado ao normal
    overlay0 = "${cores.base03}"
    overlay1 = "${cores.base04}"
    subtext0 = "${cores.base04}"
    text     = "${cores.base05}"

    # acentos. `accent` pinta borda de painel ativo e aba ativa, e é o ciano da
    # marca — o mesmo base0D que o noctalia usa como cor primária, para que o
    # painel focado combine com a barra do desktop.
    accent = "${cores.base0D}"
    blue   = "${cores.base0D}"
    teal   = "${cores.base0C}"
    green  = "${cores.base0B}"
    yellow = "${cores.base0A}"
    peach  = "${cores.base09}"
    red    = "${cores.base08}"
    mauve  = "${cores.base0E}"
  '';
in
lib.mkIf osConfig.lcars.user.herdr.enable {
  home.packages = [
    herdr
    # No PATH porque é ferramenta de uso direto, não só o alvo do popup.
    pkgs.lazygit
  ];

  xdg.configFile."herdr/config.toml".text = ''
    # ATENÇÃO: arquivo gerado por user/app/herdr.nix. Editar aqui não adianta —
    # é um link para o /nix/store, e o próximo `nupdate` o reescreve.

    # O onboarding já vem dado por respondido. Não é preferência: sem isto o
    # herdr tentaria gravar `onboarding = false` neste arquivo, que é
    # read-only, na primeira vez que subisse.
    onboarding = false

    # =================================================================
    #  Atalhos — os mesmos do antigo ~/.tmux.conf:
    #
    #    prefixo           = Ctrl-a
    #    split vertical    = prefix + |
    #    split horizontal  = prefix + -
    #    navegar painéis   = Alt + setas (sem prefixo) e prefix + hjkl
    #    trocar painéis    = prefix + Shift+HJKL
    #    zoom no painel    = prefix + z
    #    fechar painel     = prefix + x
    #    nova aba          = prefix + c        (janela, no tmux)
    #    fechar aba        = prefix + Shift+x  (kill-window)
    #    trocar de aba     = Shift + Left/Right, sem prefixo
    #    nova workspace    = prefix + Shift+n  (sessão, no tmux)
    #    fechar workspace  = prefix + Shift+d  (kill-session)
    #    renomear ws       = prefix + Shift+w
    #    ir para ws        = prefix + g        (switch-client)
    #    trocar de ws      = Ctrl + Up/Down, sem prefixo
    #    recarregar config = prefix + Shift+r  (default do herdr)
    #    modo resize       = prefix + r        (hjkl redimensiona, Esc sai)
    #    lazygit           = prefix + Shift+g  (popup 90%)
    #
    #  A tabela completa, dentro do programa: prefix + ?
    # =================================================================

    [keys]
    prefix = "ctrl+a"

    # prefix + r é o modo resize, então recarregar fica no default do herdr
    # (prefix + Shift+r) — daí `reload_config` não aparecer aqui.

    # --- splits ------------------------------------------------------
    split_vertical   = ["prefix+|", "prefix+\\"]
    split_horizontal = ["prefix+-", "prefix+_"]

    # --- foco entre painéis ------------------------------------------
    focus_pane_left  = ["prefix+h", "alt+left"]
    focus_pane_down  = ["prefix+j", "alt+down"]
    focus_pane_up    = ["prefix+k", "alt+up"]
    focus_pane_right = ["prefix+l", "alt+right"]

    # dentro do navigate-mode, hjkl puro
    navigate_pane_left  = "h"
    navigate_pane_down  = "j"
    navigate_pane_up    = "k"
    navigate_pane_right = "l"

    # --- mover e dimensionar painéis ---------------------------------
    swap_pane_left  = "prefix+shift+h"
    swap_pane_down  = "prefix+shift+j"
    swap_pane_up    = "prefix+shift+k"
    swap_pane_right = "prefix+shift+l"

    zoom        = "prefix+z"
    resize_mode = "prefix+r"

    # --- abas (as janelas do tmux) -----------------------------------
    new_tab      = "prefix+c"
    next_tab     = "shift+right"
    previous_tab = "shift+left"
    rename_tab   = "prefix+shift+t"
    close_tab    = "prefix+shift+x"
    switch_tab   = "prefix+1..9"

    # --- workspaces (as sessões do tmux) -----------------------------
    new_workspace      = "prefix+shift+n"
    rename_workspace   = "prefix+shift+w"
    close_workspace    = "prefix+shift+d"
    goto               = "prefix+g"
    previous_workspace = "ctrl+up"
    next_workspace     = "ctrl+down"

    # =================================================================
    #  Popup do lazygit, como no tmux.conf antigo.
    # =================================================================
    [[keys.command]]
    key         = "prefix+shift+g"
    type        = "popup"
    command     = "${lazygit}"
    description = "lazygit (Source Control TUI)"
    width       = "90%"
    height      = "90%"

    # =================================================================
    #  Plugin browser (official.browser) — Chromium desenhado dentro do
    #  painel. Depende do plugin, que o Nix não instala: da primeira vez,
    #  instale-o à mão com `herdr plugin install` (a sintaxe está em
    #  `herdr plugin --help`) e confira com `herdr plugin list`.
    # =================================================================
    [[keys.command]]
    key         = "prefix+b"
    type        = "shell"
    command     = 'HERDR_BROWSER_CHROME=${chromium} "''${HERDR_BIN_PATH}" plugin pane open --plugin official.browser --entrypoint browser --placement split --direction right --focus'
    description = "browser em split (chromium)"

    [[keys.command]]
    key         = "prefix+shift+b"
    type        = "shell"
    command     = 'HERDR_BROWSER_CHROME=${chromium} "''${HERDR_BIN_PATH}" plugin pane open --plugin official.browser --entrypoint browser --placement overlay --focus'
    description = "browser em overlay (chromium)"

    ${tema}

    # =================================================================
    #  Terminal
    # =================================================================
    [terminal]
    default_shell = "zsh"
    shell_mode    = "auto"
    new_cwd       = "follow"

    # =================================================================
    #  Sidebar. O token `$claude_usage` vem do plugin unit1.claude-usage,
    #  instalado à mão; sem ele a linha fica vazia e o resto continua.
    # =================================================================
    [ui.sidebar.agents]
    row_gap = 0
    rows = [
      ["state_icon", "workspace", "tab"],
      ["agent", "state_text"],
    ]

    [ui.sidebar.spaces]
    row_gap = 0
    rows = [
      ["state_icon", "workspace"],
      ["branch", "$local_branches"],
      ["git_status"],
      ["$claude_usage"],
    ]

    # =================================================================
    #  Sessões — o que o tmux-resurrect e o tmux-continuum faziam:
    #  `pane_history` repõe o conteúdo dos painéis, e
    #  `resume_agents_on_restore` retoma as conversas dos agentes depois
    #  de o servidor reiniciar.
    # =================================================================
    [session]
    resume_agents_on_restore = true

    [experimental]
    pane_history   = true
    kitty_graphics = true
  '';
}
