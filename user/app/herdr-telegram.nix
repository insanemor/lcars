# herdr-telegram.nix — o herdr-telegram-plugin: cada pane do herdr vira um
# tópico de fórum num grupo do Telegram, para operar os agentes por mensagem
# (sem LLM envolvido — é ponte de teclado/tela, não um chat inteligente).
#
# Opt-in por `lcars.user.herdrTelegram.enable`, ligado no profile — separado
# de `lcars.user.herdr.enable`, que também precisa estar ligado (sem herdr não
# há pane para o daemon observar; este módulo não afirma essa dependência por
# código, só por convenção do profile). A flag vem do config do NixOS (veja
# user/options.nix).
#
# POR QUE É MÓDULO PRÓPRIO, E NÃO MAIS UMA SEÇÃO DE herdr.nix
# --------------------------------------------------------------
# Todo plugin ali é "link e esquece": `herdr plugin link` registra o plugin, e
# é o herdr quem dispara a ação quando o usuário aperta uma tecla. Este é
# diferente — precisa de um DAEMON DE VIDA LONGA (`node dist/index.js
# --daemon`) rodando o tempo todo, não uma ação sob demanda. O CLAUDE.md deste
# repo já registrou duas vezes (#19, #24) o preço de pôr esse tipo de processo
# no `exec-once` do compositor: falha calada, sem reinício, sem
# `systemctl status` para checar. A saída aqui é a mesma do onedrivegui
# (user/app/onedrive.nix): um `systemd.user.services` de verdade.
#
# O BUILD
# -------
# O upstream não publica pacote pronto — o próprio `herdr-plugin.toml` dele
# declara `[[build]] command = ["npm", "ci"]` e `["npm", "run", "build"]`, mas
# `herdr plugin link` PULA o `[[build]]` do manifesto (mesma observação já
# registrada no cabeçalho de herdr.nix para os outros plugins). Por isso o
# build entra por `pkgs.buildNpmPackage`, que roda o `npm run build` (`tsc`)
# de verdade — diferente do herdr-annotations, que só precisa de
# `node_modules` (`dontNpmBuild = true`) e não tem essa etapa.
#
# `npmDepsHash` veio de `nix run nixpkgs#prefetch-npm-deps -- package-lock.json`
# contra o checkout do commit fixado abaixo — não por tentativa com fake hash:
# o `prefetch-npm-deps` lê o lockfile offline e já devolve o hash certo. O
# build inteiro (`npm run build` incluso) foi confirmado com `nix-build` de
# verdade antes desta entrega, não só avaliado — `dist/index.js` e
# `dist/plugin.js` saem no lugar que o manifesto espera.
#
# O SEGREDO: bot_token NUNCA vai para o Nix store
# -------------------------------------------------
# O `config.toml` gerado abaixo é `xdg.configFile` — link read-only para o
# store — e só carrega `progress_interval_ms`, nenhum segredo. O `bot_token`
# chega ao processo por variável de ambiente (`HERDR_TG_BOT_TOKEN`, que
# src/config.ts:115 do upstream lê ANTES do arquivo), via `EnvironmentFile=`
# do systemd apontando para um arquivo mutável fora do store, escrito pela
# ativação abaixo a partir do 1Password — mesmo padrão do refresh_token do
# onedrive (user/app/onedrive.nix; ver docs/secrets.md). O item é
# `op://Dotfiles/herdr telegram bot/token`; se ainda não existir, crie-o:
#
#   op item create --category Login --title "herdr telegram bot" \
#     --vault Dotfiles "token=<token do @BotFather>"
#
# O `-` na frente do caminho em `EnvironmentFile` é o que deixa a unit subir
# mesmo sem o arquivo (primeira ativação, sem 1Password desbloqueado): o
# processo falha ao iniciar por falta de bot_token (erro visível em
# `journalctl --user -u herdr-telegram`), e `Restart=on-failure` tenta de novo
# a cada 30s — sem esconder o problema, que é o objetivo (ao contrário de um
# `exec-once` que morreria calado).
#
# O PASSO MANUAL QUE SOBRA: /pair
# ---------------------------------
# Depois do primeiro deploy com o bot_token correto, autorize o chat mandando
# `/pair` para o bot no Telegram — o daemon grava o chat autorizado em
# ~/.local/state/herdr-telegram/state.json (estado mutável do próprio plugin,
# fora do Nix, no mesmo espírito de ~/.local/state/herdr/... dos outros
# plugins). É passo único por chat, não repete a cada `nupdate`.
#
# HERDR_BIN_PATH
# --------------
# O upstream resolve o binário do herdr por `which herdr` ou caminhos comuns
# (src/herdr-client.ts) — nenhum dos dois confiável dentro de uma unit
# systemd de PATH mínimo. `HERDR_BIN_PATH`, que o mesmo arquivo lê primeiro,
# resolve isso com o caminho absoluto do store — o mesmo pacote que
# herdr.nix instala em home.packages.
{
  config,
  osConfig,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  herdr = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # A árvore inteira (dist/, node_modules/, herdr-plugin.toml) copiada para
  # $out — GRAVÁVEL, ao contrário do store original — porque `plugin link`
  # espera a raiz de um plugin de verdade, não só o resultado do build.
  # `node_modules` precisa estar ao lado de `dist/`: a resolução de módulo do
  # Node parte da localização do arquivo que importa (dist/index.js), não do
  # cwd, e sobe procurando `node_modules` a partir dali — funciona porque
  # `cp -r` preserva os dois lado a lado, igual a um pacote npm instalado
  # normalmente.
  pluginTelegram = pkgs.buildNpmPackage {
    pname = "herdr-telegram-plugin";
    version = "0.1.0";
    src = inputs.herdr-telegram-plugin;
    npmDepsHash = "sha256-cj5CsonI6Wy8QqFGxc+Gg5sX0oosXyQv3WjssMZMJYk=";
    installPhase = ''
      mkdir -p $out
      cp -r . $out
    '';
  };
in
lib.mkIf osConfig.lcars.user.herdrTelegram.enable {
  # Registro do plugin — mesmo formato idempotente dos demais em herdr.nix:
  # roda na unit home-manager-<user>.service, só precisa de HOME para achar
  # ~/.config/herdr, e não depende do servidor do herdr estar de pé.
  home.activation.herdrPluginTelegram = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! saida=$(${lib.getExe herdr} plugin link ${pluginTelegram} 2>&1); then
      echo "lcars: falha ao registrar o herdr-telegram-plugin — o bot não vai encontrar o herdr"
      echo "$saida"
    fi
  '';

  # Só o não-segredo. Ver "O SEGREDO" no cabeçalho do arquivo para o
  # bot_token, que não mora aqui.
  xdg.configFile."herdr-telegram/config.toml".text = ''
    # ATENÇÃO: arquivo gerado por user/app/herdr-telegram.nix. Editar aqui não
    # adianta — é um link para o /nix/store, e o próximo `nupdate` o
    # reescreve. O bot_token NÃO mora aqui — vem de EnvironmentFile, ver
    # systemd.user.services.herdr-telegram.

    [telegram]
    progress_interval_ms = 15000
  '';

  # O daemon de vida longa. Sobe com a sessão gráfica (mesmo alvo do
  # onedrivegui — é dentro dela que o herdr roda, via kitty), reinicia
  # sozinho se cair.
  systemd.user.services.herdr-telegram = {
    Unit = {
      Description = "herdr-telegram-plugin — bridge Telegram por pane do herdr";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${lib.getExe pkgs.nodejs} ${pluginTelegram}/dist/index.js --daemon";
      EnvironmentFile = "-${config.home.homeDirectory}/.config/herdr-telegram/bot_token.env";
      Environment = [ "HERDR_BIN_PATH=${lib.getExe herdr}" ];
      Restart = "on-failure";
      RestartSec = 30;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # bot_token do 1Password. Sem `op` no PATH ou sem conseguir ler o item, a
  # ativação avisa e segue; a unit sobe e falha por falta de bot_token até o
  # segredo existir (ver "O SEGREDO" no topo do arquivo).
  #
  # SEM PRÉ-CHECAGEM POR `op whoami` — de propósito, ao contrário do
  # onedrive.nix/opencode.nix. `op whoami` se mostrou um proxy não confiável
  # pra "o `op read` vai funcionar" no modelo de integração deste repo
  # (desbloqueio via app + "Integrate with 1Password CLI", sem `op signin`
  # clássico — ver docs/secrets.md): reproduzido ao vivo, `op whoami` falhava
  # ("account is not signed in") de forma estável enquanto `op read` contra
  # este mesmo item funcionava normalmente, também de forma estável (issue
  # #141). A pré-checagem só produzia um falso "sem login" e pulava a
  # leitura de verdade — o `bot_token.env` nunca chegava a ser escrito, e o
  # daemon ficava em crashloop por falta de token. A correção é tentar o
  # `op read` direto e deixar o próprio código de saída dele decidir.
  home.activation.herdrTelegramSecret = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    conf_dir="$HOME/.config/herdr-telegram"
    env_file="$conf_dir/bot_token.env"

    # O `op` por caminho absoluto, o do wrapper primeiro — esta ativação roda
    # numa unit systemd cujo PATH não tem /run/wrappers/bin. Mesma receita do
    # onedrive.nix e do dotfiles.nix.
    op=""
    for candidato in /run/wrappers/bin/op "$(command -v op 2>/dev/null || true)"; do
      if [ -n "$candidato" ] && [ -x "$candidato" ]; then
        op="$candidato"
        break
      fi
    done

    # `setsid`: sem terminal de controle, o `op` não tem como abrir prompt.
    # Numa máquina sem conta configurada, `op read` NÃO falha — ele entra no
    # fluxo de configuração e pergunta "Do you want to add an account manually
    # now?", travando a ativação. E `2>/dev/null` não segura isso: o prompt vai
    # direto para /dev/tty, não para o stderr (#161). Redirecionar o stdin
    # também não resolve, pela mesma razão — só tirar o tty resolve.
    setsid=${lib.getExe' pkgs.util-linux "setsid"}

    if [ -z "$op" ]; then
      echo "lcars: herdr-telegram precisa de bot_token, mas o \`op\` (1Password CLI) não está no PATH — veja docs/secrets.md."
    else
      ref="op://Dotfiles/herdr telegram bot/token"
      erro="$(mktemp)"
      if token=$("$setsid" -w "$op" read "$ref" 2>"$erro"); then
        mkdir -p "$conf_dir"
        chmod 700 "$conf_dir"
        tmp="$env_file.tmp"
        umask 077
        printf 'HERDR_TG_BOT_TOKEN=%s\n' "$token" > "$tmp"
        mv "$tmp" "$env_file"
        chmod 600 "$env_file"
        systemctl --user restart herdr-telegram.service 2>/dev/null || true
        echo "lcars: herdr-telegram bot_token atualizado a partir do 1Password."
      elif grep -qi "no accounts configured" "$erro"; then
        echo "lcars: nenhuma conta do 1Password configurada nesta máquina — herdr-telegram fica sem bot_token. Configure o app e rode nupdate. Veja docs/secrets.md."
      else
        motivo="$(head -1 "$erro" 2>/dev/null || true)"
        echo "lcars: não consegui ler $ref''${motivo:+ — $motivo} — confira se o item existe no 1Password (vault Dotfiles) e se o app está desbloqueado (Settings → Developer → Integrate with 1Password CLI), depois rode nupdate. Veja docs/secrets.md."
      fi
      rm -f "$erro"
    fi
  '';
}
