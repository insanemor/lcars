# onedrive.nix — o cliente OneDrive (abi-1/onedrive) e o onedrivegui, do
# lado do usuário.
#
# Opt-in por `lcars.user.onedrive.enable`, ligado no profile. A flag vem do
# config do NixOS (veja user/options.nix).
#
# POR QUE O MOTOR É O ONEDRIVEGUI, NÃO O SYSTEMD `onedrive@onedrive.service`
# ----------------------------------------------------------------------------
# Este repo já tentou o caminho "óbvio": `services.onedrive` (módulo do
# NixOS, ligado em `system/app/onedrive`) como motor, com o `onedrivegui`
# (#129) só de visor por cima. Não funciona — o `onedrivegui` não tem modo
# "observar" um processo alheio: toda a tela de status/progresso vem de
# parsear o `stdout` do subprocesso que ELE MESMO lança
# (`workers.py:MonitorWorker`, via `subprocess.Popen`). Como o cliente
# `onedrive` recusa uma segunda instância no mesmo confdir, clicar "Play" na
# tela sempre esbarrava no `onedrive@onedrive.service` já rodando (issue
# #132). A troca: `services.onedrive` sai do profile personal
# (`profiles/personal/default.nix`, era da #126), e quem sincroniza agora é
# o próprio `onedrivegui`, supervisionado pelo `systemd.user.services.onedrivegui`
# abaixo — mesma filosofia de "serviço, nunca exec-once" do CLAUDE.md, só
# muda qual é o serviço.
#
# `system/app/onedrive/default.nix` continua existindo no repositório (não
# é removido): é o motor certo para outro host/profile que prefira sync
# puro sem GUI, ou que precise sincronizar antes de qualquer login gráfico
# — o `onedrivegui.service` só sobe com `graphical-session.target`.
#
# CONFIG SEMEADO UMA VEZ, DEPOIS MUTÁVEL — POR CAUSA DO ONEDRIVEGUI
# --------------------------------------------------------------------
# `~/.config/onedrive/config`, `~/.config/onedrive-gui/profiles` e
# `~/.config/onedrive-gui/gui_settings` nasceram como `xdg.configFile`
# (symlink somente-leitura pro Nix store) nas #127 e #130, mas isso quebrou
# o `onedrivegui`: `OneDriveGUI.py:55` chama `save_global_config()`
# incondicionalmente TODA VEZ que o app abre — não só ao importar ou salvar
# manualmente — e essa função regrava os arquivos com `open(path, "w")`
# direto. Symlink somente-leitura vira `OSError: [Errno 30] Read-only file
# system` no primeiro start (issue #131); o mesmo valeria para
# `gui_settings`, que `GuiSettings.save()` regrava a cada mudança de
# configuração.
#
# Por isso os três nascem como arquivo REAL e gravável, escrito pela
# activation abaixo só na primeira vez (se já existe, não mexe) — o
# onedrivegui fica livre para reescrevê-los depois. Trade-off: `sync_dir`
# (vindo de `lcars.user.onedrive.syncDir`) só vale na primeira ativação;
# mudar depois é editar `~/.config/onedrive/config` direto ou pelo
# onedrivegui, não força mais pela flag em todo `nupdate`. O valor no
# arquivo fica entre aspas (`sync_dir = "~/OneDrive"`), formato confirmado
# no config de exemplo do próprio pacote onedrive. `auto_sync = True` no
# profile é o que faz o app sincronizar sozinho, sem precisar de "Play"; e
# `start_minimized = True` no `gui_settings` evita abrir janela toda sessão
# gráfica — ele minimiza pra bandeja se houver uma disponível, ou fica numa
# janela minimizada/taskbar como fallback (o niri não garante bandeja).
#
# O REFRESH_TOKEN
# ----------------
# Para o cliente não falhar calado no primeiro start, precisa de um
# `~/.config/onedrive/refresh_token` válido em disco — o que ele cria na
# primeira execução interativa, e é o que a activation abaixo reproduz.
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
# não sincroniza — o usuário autentica à mão (passo 1) e roda `nupdate` de
# novo. A falha só fica visível em `systemctl --user status onedrivegui`,
# não no `nixos-rebuild`, que é o que se quer.
#
# POR QUE A ATIVAÇÃO REINICIA O SERVIÇO
# --------------------------------------
# O cliente `onedrive` só lê o `refresh_token` na sua própria inicialização
# — se o token for renovado (rotação, ou simplesmente porque expirou) com o
# `onedrivegui` já rodando e sincronizando, o processo em curso continua com
# o token velho até cair. Por isso, depois de escrever o token com sucesso,
# a activation reinicia `onedrivegui.service` (o app inteiro, que já sobe de
# novo autenticado e sincronizando via `auto_sync`) — `|| true` porque, numa
# ativação em que `lcars.user.onedrive.enable` acabou de ligar, a unit pode
# ainda não existir, e isso não deve quebrar o rebuild.
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
  # O binário CLI ainda é necessário — é ele que o onedrivegui invoca por
  # baixo. Antes vinha do módulo services.onedrive (system/app/onedrive);
  # agora o motor é o onedrivegui, então o pacote vem direto daqui.
  home.packages = [
    pkgs.onedrive
    pkgs.onedrivegui
  ];

  # onedrivegui é o motor de sync (ver comentário no topo do arquivo) — sobe
  # com a sessão gráfica, supervisionado como qualquer outro serviço deste
  # repo. graphical-session.target é o mesmo alvo que o serviço do noctalia
  # usa — confirmado que o niri o publica via programs/wayland/niri.nix do
  # nixpkgs (user/wm/niri.nix:105-108).
  systemd.user.services.onedrivegui = {
    Unit = {
      Description = "OneDriveGUI — sincroniza o OneDrive com progresso visual";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.onedrivegui}/bin/onedrivegui";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Semeia os três arquivos como reais/graváveis, só se ainda não existem —
  # ver comentário no topo do arquivo (issues #131, #132). `config_file` no
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
        printf 'auto_sync = True\n'
        printf 'account_type =\n'
        printf 'free_space =\n'
      } > "$tmp"
      mv "$tmp" "$gui_profiles"
      echo "lcars: onedrivegui profile semeado em $gui_profiles (auto_sync = True)."
    fi

    gui_settings="$gui_dir/gui_settings"
    if [ ! -e "$gui_settings" ]; then
      mkdir -p "$gui_dir"
      tmp="$gui_settings.tmp"
      {
        printf '[SETTINGS]\n'
        printf 'start_minimized = True\n'
      } > "$tmp"
      mv "$tmp" "$gui_settings"
      echo "lcars: onedrivegui settings semeado em $gui_settings (start_minimized = True)."
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
        systemctl --user restart onedrivegui.service 2>/dev/null || true
        echo "lcars: onedrive refresh_token atualizado a partir do 1Password."
      else
        echo "lcars: não consegui ler $ref — abra o app 1Password, desbloqueie a CLI, e siga o procedimento em docs/secrets.md."
      fi
    fi
  '';
}
