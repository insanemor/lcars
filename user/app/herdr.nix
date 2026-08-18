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
# O PLUGIN BROWSER VEM DO FLAKE, NÃO DE UM `plugin install`
# ---------------------------------------------------------
# `herdr plugin install <owner>/<repo>` baixa o plugin em tempo de execução
# para ~/.config/herdr/plugins/github/…, e é um passo manual por máquina — o
# atalho `prefix + b` existiria em toda instalação nova e não faria nada até
# alguém lembrar do comando. Foi assim até a #58.
#
# O que o Nix pode fazer, e faz abaixo: o plugin entra como input do flake
# (`herdr-browser`, preso a um commit no flake.lock) e a ativação do Home
# Manager o registra com `herdr plugin link`, apontando para o caminho no
# store. O registro em si — ~/.config/herdr/plugins.json — continua sendo um
# arquivo mutável que o herdr reescreve; por isso a ativação, e não um
# `xdg.configFile`, que viraria um link read-only no caminho de algo que o
# programa precisa escrever.
#
# É idempotente: a gravação remove a entrada de mesmo plugin_id antes de
# reinserir (src/cli/plugin.rs:905), então rodar a cada `nupdate` é seguro, e
# um caminho de store novo simplesmente substitui o antigo.
#
# Quem já tinha rodado o `plugin install` à mão não precisa fazer nada: o link
# sobrescreve a entrada. O checkout antigo fica órfão em
# ~/.config/herdr/plugins/github/ e pode ser apagado.
#
# O QUE NÃO ESTÁ AQUI
# -------------------
# Os outros plugins do herdr (file viewer, claude-usage) — nenhum atalho os
# usa hoje. Se um dia entrarem, seguem este mesmo molde. É por isso que o token
# `$claude_usage` da sidebar continua inerte até alguém instalá-lo à mão.
#
# COMANDO `shell` QUE FALHA NÃO DIZ NADA
# --------------------------------------
# Vale para os atalhos daqui e para qualquer um que se acrescente: um
# `[[keys.command]]` com `type = "shell"` é spawnado com stdin, stdout e stderr
# em /dev/null, e o herdr não olha o código de saída — ele só reporta se o
# próprio spawn falhar (src/app/input/navigate.rs:880). Um comando errado, um
# plugin ausente ou uma opção inválida dão exatamente o mesmo resultado na
# tela: nada. Foi assim que a #55 passou despercebida. Ao mexer num destes
# comandos, rode-o à mão num painel antes de confiar nele.
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
  #
  # O caminho chega ao plugin por `--env HERDR_BROWSER_CHROME=` no comando,
  # jamais como `VAR=valor cmd` na frente dele. Quem lança o processo do plugin
  # é o SERVIDOR do herdr, não o CLI: o CLI só manda uma mensagem pelo socket, e
  # o servidor monta o ambiente do zero, a partir do que veio pela API mais as
  # variáveis HERDR_* (src/app/api/plugins/panes.rs:232). Um prefixo de ambiente
  # morre no processo do CLI, sem nunca alcançar o plugin — era o que acontecia
  # até a #55.
  chromium = lib.getExe pkgs.chromium;

  # O plugin browser, direto do input — é uma árvore de arquivos, não um
  # pacote: `flake = false` no flake.nix. O que o `plugin link` quer é
  # exatamente isto, o diretório que tem o herdr-plugin.toml na raiz.
  #
  # O diretório é READ-ONLY, por estar no store. O plugin aguenta: o perfil do
  # Chromium e o resto do estado vão para o state dir do herdr
  # (~/.local/state/herdr/plugins/…, veja src/plugin_paths.rs:21), e a
  # configuração para o config dir — nada é escrito na raiz do plugin. Se um
  # dia o upstream passar a escrever lá, a saída é a ativação copiar esta
  # árvore para um caminho mutável e linkar de lá.
  # Onde um link abre, e por quê
  # ----------------------------
  # São três caminhos, e antes da #60 só o primeiro chegava ao painel:
  #
  #   Ctrl+clique num link do terminal  → link_handler de plugin, senão xdg-open
  #   CLI que autentica (aws sso, okta) → $BROWSER / xdg-open, sem passar pelo herdr
  #   qualquer coisa fora do herdr      → xdg-open
  #
  # O wrapper abaixo cobre os dois primeiros. Ele vira o `$BROWSER` da sessão e
  # decide pelo ambiente: dentro de um painel do herdr abre no plugin, fora
  # dele chama o navegador de verdade.
  #
  # `HERDR_ENV=1` é o que marca "estou dentro": todo pty que o herdr cria
  # recebe essa variável (src/pty/backend/unix.rs:77). Não é heurística, é o
  # mesmo sinal que o próprio herdr usa para recusar rodar aninhado.
  #
  # As duas saídas de emergência, porque um Chromium dirigido por CDP não
  # serve para tudo — ele tem perfil próprio, sem os cookies e as senhas do seu
  # navegador, e não faz passkey nem extensão:
  #
  #   LCARS_BROWSER_EXTERNO=1 aws sso login   # este login vai no Vivaldi
  #   lcars-browser <url>                     # e o wrapper é chamável à mão
  navegadorExterno =
    if osConfig.lcars.user.vivaldi.enable then
      lib.getExe config.programs.vivaldi.finalPackage
    else
      "${pkgs.xdg-utils}/bin/xdg-open";

  navegador = pkgs.writeShellScriptBin "lcars-browser" ''
    set -u
    url="''${1:-}"

    # Sem URL não há o que abrir no painel: cai direto no navegador, que sabe
    # subir sozinho.
    if [ -n "$url" ]       && [ "''${LCARS_BROWSER_EXTERNO:-}" != "1" ]       && { [ "''${HERDR_ENV:-}" = "1" ] || [ "''${LCARS_BROWSER_FORCA_PAINEL:-}" = "1" ]; }; then
      if "${lib.getExe herdr}" plugin pane open         --plugin official.browser --entrypoint browser         --placement split --direction right --focus         --env HERDR_BROWSER_CHROME=${chromium}         --env HERDR_BROWSER_INITIAL_URL="$url" >/dev/null 2>&1; then
        exit 0
      fi
      echo "lcars-browser: painel do herdr não abriu; indo para o navegador" >&2
    fi

    # `env -u BROWSER` porque o xdg-open, quando não acha associação, tenta
    # justamente o $BROWSER — que é este script. Sem isso, um sistema sem
    # mimeapps declarado entraria em laço.
    exec ${pkgs.coreutils}/bin/env -u BROWSER ${navegadorExterno} "$url"
  '';

  # A ação que o link handler novo chama. Ela força o painel: o processo de uma
  # ação de plugin não é um pty do herdr, então `HERDR_ENV` não vale como
  # sinal, e sem isto o clique cairia no navegador de fora — exatamente o que
  # queremos evitar.
  abrirNoPainel = pkgs.writeShellScript "lcars-herdr-abrir-url" ''
    LCARS_BROWSER_FORCA_PAINEL=1 exec ${lib.getExe navegador} "''${HERDR_PLUGIN_CLICKED_URL:-}"
  '';

  # O plugin, com um link handler a mais.
  #
  # O upstream declara um só, e o pattern dele é localhost — é por isso que o
  # `http://localhost:3000` do dev server abre no painel e o resto vai para
  # fora. Trocar aquele pattern NÃO resolveria: a ação dele
  # (src/actions/open-localhost.ts) valida a URL e morre com "refusing
  # non-localhost URL" para qualquer outro host.
  #
  # Então acrescentamos uma ação nossa, que abre um painel com
  # HERDR_BROWSER_INITIAL_URL — variável que o viewer.ts do plugin lê sem
  # validar host nenhum (src/viewer.ts:196). O código do plugin fica intacto;
  # o que muda é só o manifesto.
  #
  # A ordem importa e está certa por construção: handlers são testados na
  # ordem do manifesto, então o de localhost (que vem antes, do upstream)
  # continua tratando localhost pelo caminho nativo, e o nosso pega o resto.
  #
  # Ids locais aceitam letras, números, `:`, `_` e `-`, e ponto NÃO
  # (src/app/api/plugins/manifest.rs:602) — daí `lcars-open-url`.
  pluginBrowser = pkgs.runCommand "herdr-browser-com-link-handler" { } ''
    cp -r ${inputs.herdr-browser} $out
    chmod -R u+w $out
    cat >> $out/herdr-plugin.toml <<'MANIFESTO'

    [[actions]]
    id = "lcars-open-url"
    title = "Abrir a URL no painel do herdr"
    contexts = ["workspace"]
    command = ["${abrirNoPainel}"]

    [[link_handlers]]
    id = "lcars-any-http"
    title = "Abrir no painel do herdr"
    pattern = "^https?://"
    action = "lcars-open-url"
    MANIFESTO
  '';

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
    # superfícies: a escala de fundo do esquema, do mais fundo ao mais claro.
    # São estes quatro, e só: o herdr pinta a sidebar e a linha ativa a partir
    # deles, e calcula o fundo de seleção sozinho (automatic_selection_bg, em
    # src/ui/panes.rs). Havia aqui `sidebar_bg`, `active_row_bg` e
    # `selection_bg`, que o CustomThemeColors não tem — o herdr os ignorava e
    # avisava "config.toml has unknown keys" no topo da tela (#54).
    panel_bg    = "${cores.base00}"
    surface0    = "${cores.base01}"
    surface1    = "${cores.base02}"
    surface_dim = "${cores.base01}"

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

    # Runtime do plugin browser, e o único caso aqui em que o pacote precisa
    # estar no PATH sem ser para o usuário chamar: o manifesto do plugin roda
    # o painel com `["bun", "run", "src/viewer.ts"]`, pelo nome, e quem procura
    # esse executável é o servidor do herdr. Caminho absoluto não resolveria —
    # o comando está fixo no manifesto, que é do upstream do plugin.
    pkgs.bun

    # No PATH para poder ser chamado à mão: `lcars-browser <url>` abre a URL no
    # painel de dentro do herdr, e no navegador de fora.
    navegador
  ];

  # O `$BROWSER` da sessão do usuário passa a ser o wrapper — é o que redireciona
  # `aws sso login`, `gh auth login` e qualquer CLI que abra o navegador de
  # dentro de um painel. Fora do herdr o wrapper repassa para o navegador de
  # verdade, então nada muda para as aplicações gráficas.
  #
  # Aqui, e não em `environment.variables` do lado NixOS, por duas razões: a
  # variável só interessa a processos da sessão do usuário, e o
  # `settings.nix` continua sendo quem nomeia o navegador (`browser`), sem que
  # este módulo o sobrescreva.
  home.sessionVariables.BROWSER = lib.getExe navegador;

  # Ativações dos plugins do herdr. Os dois têm o mesmo formato: idempotente,
  # rodam na unit home-manager-<user>.service, só precisam de HOME para achar
  # ~/.config/herdr, e o servidor do herdr não precisa estar de pé — o
  # `plugin link` grava o registro direto quando o servidor não responde, e
  # atualiza via socket quando responde. (A lição contrária, do que NÃO pode
  # morar aqui, está em user/shell/atuin.nix.)
  #
  # O do browser é incondicional: ele é requisito para o prefix+b funcionar
  # e o `lcars.user.herdr.enable` que envolve este arquivo já garante que
  # só roda quando o herdr existe. O do herdr-nvim é opt-in pela mesma flag
  # do `programs.neovim`: se o nvim está desligado, não há painel para abrir
  # e o link é ruído.
  home.activation =
    let
      pluginBrowserAtivacao = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if ! saida=$(${lib.getExe herdr} plugin link ${pluginBrowser} 2>&1); then
          echo "lcars: falha ao registrar o plugin browser do herdr — prefix+b não vai abrir"
          echo "$saida"
        fi
      '';

      pluginHerdrNvimAtivacao = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if ! saida=$(${lib.getExe herdr} plugin link ${inputs.herdr-nvim} 2>&1); then
          echo "lcars: falha ao registrar o plugin herdr-nvim — prefix+e e prefix+o não vão funcionar"
          echo "$saida"
        fi
      '';
    in
    {
      herdrPluginBrowser = pluginBrowserAtivacao;
    }
    // lib.optionalAttrs osConfig.lcars.user.nvim.enable {
      herdrPluginHerdrNvim = pluginHerdrNvimAtivacao;
    };

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
    #  painel. Não há passo manual: o plugin vem do input `herdr-browser` e é
    #  registrado na ativação (veja o cabeçalho). Confira com
    #  `herdr plugin list`.
    #
    #  O `bun` que ele roda vem do módulo (veja home.packages), e o Chromium
    #  vai por `--env`, que é o único jeito de a variável chegar ao processo do
    #  plugin.
    # =================================================================
    [[keys.command]]
    key         = "prefix+b"
    type        = "shell"
    command     = '"''${HERDR_BIN_PATH}" plugin pane open --plugin official.browser --entrypoint browser --placement split --direction right --focus --env HERDR_BROWSER_CHROME=${chromium}'
    description = "browser em split (chromium)"

    [[keys.command]]
    key         = "prefix+shift+b"
    type        = "shell"
    command     = '"''${HERDR_BIN_PATH}" plugin pane open --plugin official.browser --entrypoint browser --placement overlay --focus --env HERDR_BROWSER_CHROME=${chromium}'
    description = "browser em overlay (chromium)"

    # =================================================================
    #  Plugin herdr-nvim (chmarax.herdr-nvim) — sidebar de nvim dentro
    #  do painel, com file picker ancorado nos arquivos que o agente
    #  tocou. Não há passo manual: o plugin vem do input `herdr-nvim` e
    #  é registrado na ativação (veja home.activation.herdrPluginHerdrNvim
    #  abaixo). Confira com `herdr plugin list`.
    #
    #  `type = "plugin_action"`: delega ao herdr o caminho completo até o
    #  binário do plugin (a `entrypoint`), com o nome da ação — é a
    #  forma que a README do upstream documenta (seção "Install",
    #  binding keys). Sem o prefixo `chmarax.herdr-nvim.` o herdr não
    #  saberia em qual plugin procurar a ação.
    #
    #  A descrição da segunda entrada bate com a da README: o picker
    #  lista arquivos por agente e abre o escolhido na sidebar.
    # =================================================================
    [[keys.command]]
    key         = "prefix+e"
    type        = "plugin_action"
    command     = "chmarax.herdr-nvim.toggle"
    description = "nvim sidebar (toggle)"

    [[keys.command]]
    key         = "prefix+o"
    type        = "plugin_action"
    command     = "chmarax.herdr-nvim.pick-file"
    description = "abrir arquivo do output do agente na sidebar"

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
