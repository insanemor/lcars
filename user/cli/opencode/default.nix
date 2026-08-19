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
{
  osConfig,
  lib,
  pkgs,
  ...
}:

lib.mkIf osConfig.lcars.user.opencode.enable {
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
