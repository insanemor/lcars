# onedrive.nix — o cliente OneDrive (abi-1/onedrive) do lado do usuário.
#
# Opt-in por `lcars.user.onedrive.enable`, ligado no profile. A flag vem do
# config do NixOS (veja user/options.nix).
#
# CONFIG SEMEADO UMA VEZ, DEPOIS MUTÁVEL — POR CAUSA DO ONEDRIVEGUI
# --------------------------------------------------------------------
# `~/.config/onedrive/config` e `~/.config/onedrive-gui/profiles` nasceram
# como `xdg.configFile` (symlink somente-leitura pro Nix store) nas #127 e
# #130, mas isso quebrou o `onedrivegui`: `OneDriveGUI.py:55` chama
# `save_global_config()` incondicionalmente TODA VEZ que o app abre — não só
# ao importar ou salvar manualmente — e essa função regrava os dois arquivos
# com `open(path, "w")` direto. Symlink somente-leitura vira
# `OSError: [Errno 30] Read-only file system` no primeiro start (issue #131).
#
# Por isso os dois nascem como arquivo REAL e gravável, escrito pela
# activation abaixo só na primeira vez (se já existe, não mexe) — o
# onedrivegui fica livre para reescrevê-los depois. Trade-off: `sync_dir`
# (vindo de `lcars.user.onedrive.syncDir`) só vale na primeira ativação;
# mudar depois é editar `~/.config/onedrive/config` direto ou pelo
# onedrivegui, não força mais pela flag em todo `nupdate`. O valor no
# arquivo fica entre aspas (`sync_dir = "~/OneDrive"`), formato confirmado
# no config de exemplo do próprio pacote onedrive.
#
# POR QUE ESTE ARQUIVO EXISTE, SENDO QUE O SERVIÇO É DECLARADO EM system/
# ------------------------------------------------------------------------
# O `services.onedrive` cria a unit `onedrive@.service` com ExecStart
# `onedrive --monitor --confdir=%h/.config/%i`, e um `onedrive-launcher.service`
# que sobe `onedrive@onedrive` no login (sem o arquivo
# `~/.config/onedrive-launcher`, que é o nosso caso). Para a unit não
# falhar calada no primeiro start, o cliente precisa de um
# `~/.config/onedrive/refresh_token` válido em disco — o que ele cria na
# primeira execução interativa, e é o que esta activation reproduz.
#
# O ciclo é:
#
#   1. Uma vez, com o navegador aberto, rodar `onedrive` na linha de comando
#      e seguir o OAuth. O cliente grava `~/.config/onedrive/refresh_token`.
#   2. Criar um item `onedrive` no vault do 1Password com o campo
#      `refresh_token` contendo o conteúdo do arquivo.
#   3. Daí em diante, `home-manager switch` puxa o token do 1Password e
#      escreve no caminho certo, com `chmod 600`. A unit sobe sem prompt.
#
# A mesma tolerância a `op` indisponível que `user/cli/opencode/default.nix`
# já usa vale aqui: sem CLI ou sem login, sai uma linha amarela e o serviço
# não sobe — o usuário autentica à mão (passo 1) e roda `nupdate` de novo.
# A unit só falha visível em `systemctl --user status onedrive@onedrive`,
# não no `nixos-rebuild`, que é o que se quer.
#
# POR QUE A ATIVAÇÃO REINICIA O SERVIÇO
# --------------------------------------
# `onedrive-launcher.service` é system-level (`services.onedrive`,
# `wantedBy = default.target`) e pode subir `onedrive@onedrive.service` como
# parte da troca de config do `nixos-rebuild switch`, numa ordem que não
# espera esta activation terminar. Sem token em disco, o cliente cai num
# fluxo de OAuth interativo que TRAVA esperando input de terminal — e como
# o processo trava em vez de sair, o `Restart=on-failure` do unit nunca
# dispara, porque não há falha detectável. O mesmo vale para um token
# expirado sendo renovado com o serviço já de pé: o cliente só lê o token na
# inicialização. Por isso, depois de escrever o token com sucesso, a
# activation reinicia a unit — `|| true` porque, se `services.onedrive.enable`
# ainda não tiver subido a unit nesta mesma ativação, o restart falha por ela
# não existir, e isso não deve quebrar o rebuild.
#
# O TOKEN NO ATOMIC WRITE
# -----------------------
# A escrita vai por `tmp + mv`, e não direto no destino: o serviço pode estar
# lendo o arquivo no mesmo instante, e um `printf > token` truncado o pegaria
# com tamanho zero. O `mv` no mesmo filesystem é atômico, e é o padrão que
# o `user/app/dotfiles.nix` já usa.
#
# O VAULT
# -------
# O vault é fixo em "Dotfiles" para casar com o item `onedrive/refresh_token`.
# Mesma justificativa que o opencode: o item é fixo, e o erro de "vault
# errado" precisa ser óbvio em vez de aceitar silenciosamente um override que
# mascara config quebrada. Veja `user/cli/opencode/default.nix`.
{
  osConfig,
  lib,
  pkgs,
  ...
}:

lib.mkIf osConfig.lcars.user.onedrive.enable {
  # onedrivegui é companion do cliente, não precisa de flag própria: lê o
  # mesmo confdir (~/.config/onedrive) e o mesmo serviço systemd já
  # configurado abaixo, só dá visão visual do que já está rodando.
  home.packages = [ pkgs.onedrivegui ];

  # Semeia os dois arquivos como reais/graváveis, só se ainda não existem —
  # ver comentário no topo do arquivo (issue #131). `config_file` no
  # profiles precisa ser caminho absoluto: global_config.py abre com
  # `open()` direto, sem expandir `~`.
  home.activation.onedriveConfigSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    conf_dir="$HOME/.config/onedrive"
    config_file="$conf_dir/config"
    if [ ! -e "$config_file" ]; then
      mkdir -p "$conf_dir"
      tmp="$config_file.tmp"
      printf 'sync_dir = "%s"\n' "${osConfig.lcars.user.onedrive.syncDir}" > "$tmp"
      mv "$tmp" "$config_file"
      echo "lcars: onedrive config semeado em $config_file (sync_dir = ${osConfig.lcars.user.onedrive.syncDir})."
    fi

    gui_dir="$HOME/.config/onedrive-gui"
    gui_profiles="$gui_dir/profiles"
    if [ ! -e "$gui_profiles" ]; then
      mkdir -p "$gui_dir"
      tmp="$gui_profiles.tmp"
      {
        printf '[onedrive]\n'
        printf 'config_file = %s\n' "$config_file"
        printf 'auto_sync = False\n'
        printf 'account_type =\n'
        printf 'free_space =\n'
      } > "$tmp"
      mv "$tmp" "$gui_profiles"
      echo "lcars: onedrivegui profile semeado em $gui_profiles."
    fi
  '';

  home.activation.onedriveRefreshToken = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    conf_dir="$HOME/.config/onedrive"
    token_file="$conf_dir/refresh_token"

    # O `op` por caminho absoluto, o do wrapper primeiro. Esta ativação roda
    # numa unit systemd cujo PATH não tem /run/wrappers/bin, então
    # `command -v op` falha sempre. Mesma receita do dotfiles.nix e do
    # opencode — explicada em user/app/dotfiles.nix.
    op=""
    for candidato in /run/wrappers/bin/op "$(command -v op 2>/dev/null || true)"; do
      if [ -n "$candidato" ] && [ -x "$candidato" ]; then
        op="$candidato"
        break
      fi
    done

    if [ -z "$op" ]; then
      echo "lcars: onedrive precisa de refresh_token, mas o \`op\` (1Password CLI) não está no PATH — autentique manualmente e copie o token para o item 1Password. Veja docs/secrets.md."
    elif [ -z "''${OP_SERVICE_ACCOUNT_TOKEN:-}" ] && ! "$op" whoami >/dev/null 2>&1; then
      echo "lcars: sem login no 1Password — onedrive vai subir sem refresh_token; autentique manualmente e copie o token para o item 1Password. Veja docs/secrets.md."
    else
      ref="op://Dotfiles/onedrive/refresh_token"
      if token=$("$op" read "$ref" 2>/dev/null); then
        mkdir -p "$conf_dir"
        chmod 700 "$conf_dir"
        tmp="$token_file.tmp"
        umask 077
        printf '%s' "$token" > "$tmp"
        mv "$tmp" "$token_file"
        chmod 600 "$token_file"
        systemctl --user restart onedrive@onedrive.service 2>/dev/null || true
        echo "lcars: onedrive refresh_token atualizado a partir do 1Password."
      else
        echo "lcars: não consegui ler $ref — abra o app 1Password, desbloqueie a CLI, e siga o procedimento em docs/secrets.md."
      fi
    fi
  '';
}
