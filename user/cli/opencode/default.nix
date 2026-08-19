# opencode.nix — o CLI do OpenCode (sst/opencode, "OpenCode Go") no ambiente
# do usuário.
#
# Opt-in por `lcars.user.opencode.enable`, ligado no profile. A flag vem do
# config do NixOS (veja user/options.nix).
#
# POR QUE OPENCODE GO, E NÃO O CRUSH
# -----------------------------------
# O `herdr-usage-bar` lê o que cada agente grava em disco e exibe $context,
# $limit e $provider na sidebar. Claude Code, Codex, OpenCode Go, Grok, OMP
# e Pi são suportados pelo upstream; Crush não — ver #90. Para o uso do
# agente aparecer na usage bar e na tela de agents da herdr, é mais barato
# trocar de harness do que escrever um extractor novo. O OpenCode Go tem
# suporte nativo (subscription windows via `OPENCODE_GO_COOKIE`, e pay-as-
# you-go lendo o SQLite local de sessões) e aceita um provider MiniMax
# catalogado, então a leitura do uso cai sem código novo. O módulo do Crush
# (#89) fica no flake, desligado, como referência — quem quiser reativar é
# só ligar `lcars.user.crush.enable`.
#
# O PACOTE
# --------
# O pacote nixpkgs é `pkgs.opencode`, versão 1.16.2 — MIT, sem unfree. O nome
# comercial é "OpenCode Go" porque tem um plano de assinatura próprio, mas o
# binário do nixpkgs é o mesmo CLI open-source. A versão é a do flake.lock;
# atualizar é `nix flake update`.
#
# O QUE VAI NO FLAKE, E O QUE NÃO VAI
# ------------------------------------
# O `xdg.configFile."opencode/opencode.json"` declara o provider MiniMax
# (baseURL, modelID) mas NÃO traz a key. A key mora em
# ~/.local/share/opencode/auth.json, que o opencode consulta em runtime —
# arquivo mutável, NÃO coberto por este módulo. O activation script abaixo
# puxa a key do 1Password e escreve nesse arquivo, tentando falhar de forma
# suave se o `op` não estiver desbloqueado: o sistema sobe sem a key, e o
# usuário roda `/connect` no TUI como escape hatch.
#
# O path do item 1Password é `op://<vault>/minimax token/token`. O vault é
# o que `settings.nix` declara em `onePassword.vault` (no flake, "Dotfiles").
# Se você moveu o item no vault, ajuste o path abaixo; ele não é descoberto
# automaticamente porque a doc do OpenCode não expõe `op` como caminho
# oficial (o caminho oficial é `/connect`, interativo).
#
# O TEMA
# ------
# O opencode aceita tema custom em `~/.config/opencode/themes/<nome>.json`,
# referenciado em `tui.json` pela chave `theme` — ver opencode.ai/docs/themes.
# Aqui o arquivo `lcars.json` é gerado a partir de `config.lib.stylix.colors`
# (o mesmo esquema base16 que pinta o kitty via `programs.kitty`), e o
# `tui.json` aponta `theme: "lcars"`. Trocar `lcars.system.theme.scheme`
# propaga para o opencode sem edição manual.
#
# Mapeamento base16 -> chave de tema (referência: stylix base16 canônico,
# base08 = red, base09 = orange, base0A = yellow, base0B = green, base0C =
# cyan, base0D = blue, base0E = magenta, base0F = varies):
#
#   background        <- base00  (fundo)
#   backgroundPanel   <- base01  (painel um nível acima)
#   backgroundElement <- base02  (elemento interativo / botão)
#   border            <- base03  (cinza médio)
#   borderSubtle      <- base02
#   borderActive      <- base04  (cinza claro)
#   text              <- base05  (texto principal)
#   textMuted         <- base04  (texto secundário)
#   primary           <- base0D  (blue)
#   secondary         <- base0E  (magenta)
#   accent            <- base0C  (cyan)
#   error             <- base08  (red)
#   warning           <- base0A  (yellow)
#   success           <- base0B  (green)
#   info              <- base0C  (cyan)
#
#   diffAdded/diffHighlightAdded    <- base0B
#   diffRemoved/diffHighlightRemoved <- base08
#   diffContext/diffHunkHeader       <- base04
#   diffAddedBg/diffRemovedBg/diffContextBg <- base01
#   diffLineNumber                   <- base03
#   *LineNumberBg                    <- base01
#
#   markdownHeading/markdownLink/markdownListItem/markdownImage <- base0D
#   markdownLinkText/markdownListEnumeration/markdownImageText   <- base0C
#   markdownCode                                              <- base0B
#   markdownEmph                                              <- base0A
#   markdownStrong                                            <- base09
#   markdownText/markdownCodeBlock/markdownPunctuation  <- base05
#   markdownBlockQuote/markdownHorizontalRule            <- base04
#
#   syntaxKeyword/syntaxOperator   <- base0E
#   syntaxFunction                 <- base0D
#   syntaxVariable/syntaxType      <- base0A (type) / base0C (variable)
#   syntaxString                   <- base0B
#   syntaxNumber                   <- base09
#   syntaxComment                  <- base03
#   syntaxPunctuation              <- base05
#
# O bloco é gateado por `lcars.system.theme.enable`: sem stylix,
# `config.lib.stylix.colors` não existe (ver user/shell/zsh.nix:37) e o
# opencode usa o built-in `opencode` sem customização — coerente, porque o
# resto do sistema também está sem tema unificado.
{
  config,
  osConfig,
  lib,
  pkgs,
  ...
}:

lib.mkIf osConfig.lcars.user.opencode.enable (
  let
    s = config.lib.stylix.colors;

    mkTheme = builtins.toJSON {
      primary = s.base0D;
      secondary = s.base0E;
      accent = s.base0C;
      error = s.base08;
      warning = s.base0A;
      success = s.base0B;
      info = s.base0C;
      text = s.base05;
      textMuted = s.base04;
      background = s.base00;
      backgroundPanel = s.base01;
      backgroundElement = s.base02;
      border = s.base03;
      borderActive = s.base04;
      borderSubtle = s.base02;
      diffAdded = s.base0B;
      diffRemoved = s.base08;
      diffContext = s.base04;
      diffHunkHeader = s.base04;
      diffHighlightAdded = s.base0B;
      diffHighlightRemoved = s.base08;
      diffAddedBg = s.base01;
      diffRemovedBg = s.base01;
      diffContextBg = s.base01;
      diffLineNumber = s.base03;
      diffAddedLineNumberBg = s.base01;
      diffRemovedLineNumberBg = s.base01;
      markdownText = s.base05;
      markdownHeading = s.base0D;
      markdownLink = s.base0D;
      markdownLinkText = s.base0C;
      markdownCode = s.base0B;
      markdownBlockQuote = s.base04;
      markdownEmph = s.base0A;
      markdownStrong = s.base09;
      markdownHorizontalRule = s.base04;
      markdownListItem = s.base0D;
      markdownListEnumeration = s.base0C;
      markdownImage = s.base0D;
      markdownImageText = s.base0C;
      markdownCodeBlock = s.base05;
      syntaxComment = s.base03;
      syntaxKeyword = s.base0E;
      syntaxFunction = s.base0D;
      syntaxVariable = s.base0C;
      syntaxString = s.base0B;
      syntaxNumber = s.base09;
      syntaxType = s.base0A;
      syntaxOperator = s.base0E;
      syntaxPunctuation = s.base05;
    };

    mkTui = builtins.toJSON {
      "$schema" = "https://opencode.ai/tui.json";
      theme = "lcars";
    };
  in
  {
    home.packages = [
      pkgs.opencode

      # `jq` é usado pelo activation script abaixo para serializar a key de
      # forma segura — a string da key passa por `%s` e é re-codificada como
      # JSON literal, sem risco de injeção por aspas, barras ou caracteres de
      # controle. Sem `jq` no runtime, o `home-manager switch` falharia.
      pkgs.jq
    ];

    # Config do opencode — provider MiniMax, baseURL, modelID M3. A key fica
    # fora deste arquivo (auth.json, populado pelo activation script abaixo).
    xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
      provider = {
        minimax = {
          options = {
            baseURL = "https://api.minimax.io/v1";
          };
          models = {
            M3 = {
              name = "M3";
              modelID = "M3";
            };
          };
        };
      };
    };

    # Tema do opencode gerado a partir do stylix — mesmo esquema base16 do
    # kitty. Gated por lcars.system.theme.enable: sem stylix não há
    # config.lib.stylix.colors, e sem esses dois arquivos o opencode usa o
    # built-in `opencode` (default coerente com o resto do sistema, que
    # também está sem tema unificado). Ver comentário do bloco "O TEMA" no
    # topo do arquivo para o mapeamento base16 -> chave de cor.
    xdg.configFile."opencode/tui.json".text = lib.mkIf osConfig.lcars.system.theme.enable mkTui;
    xdg.configFile."opencode/themes/lcars.json".text =
      lib.mkIf osConfig.lcars.system.theme.enable mkTheme;

    # Popula ~/.local/share/opencode/auth.json com a key do MiniMax vinda do
    # 1Password. Roda em toda ativação: idempotente (sobrescreve) e tolerante
    # a `op` indisponível — se o app não está desbloqueado, o opencode sobe
    # sem autenticar e o usuário roda `/connect` no TUI.
    #
    # O vault é fixo em "Dotfiles" para casar com o item `minimax token/token`
    # que o usuário já guarda nesse vault. `OP_VAULT` foi desconsiderado aqui
    # justamente para o erro de "vault errado" ser óbvio (em vez de aceitar
    # silenciosamente um override que mascara config quebrada).
    #
    # O activation script escreve no estado do opencode, NÃO no configFile,
    # porque o auth.json é mutável por construção: o próprio opencode
    # reescreve ao rodar `/connect`, `opencode auth logout` e similares. Um
    # symlink read-only do store quebraria esses fluxos.
    home.activation.opencodeAuth = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      auth_dir="$HOME/.local/share/opencode"
      auth_file="$auth_dir/auth.json"
      jq_bin=${lib.getExe pkgs.jq}
      ref="op://Dotfiles/minimax token/token"

      if ! command -v op >/dev/null 2>&1; then
        echo "lcars: opencode precisa de API key, mas o \`op\` (1Password CLI) não está no PATH — abra o app e rode \`/connect\` dentro do opencode."
      elif ! key=$(op read "$ref" 2>/dev/null); then
        echo "lcars: não consegui ler $ref — abra o app 1Password, desbloqueie a CLI, e rode \`/connect\` dentro do opencode como fallback."
      else
        mkdir -p "$auth_dir"
        chmod 700 "$auth_dir"
        umask 077
        "$jq_bin" -n \
          --arg key "$key" \
          '{minimax: {type: "api", key: $key}}' \
          > "$auth_file"
        chmod 600 "$auth_file"
        echo "lcars: opencode auth.json atualizado a partir do 1Password."
      fi
    '';
  }
)
