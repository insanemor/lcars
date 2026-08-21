# onedrive.nix — o cliente OneDrive (abi-1/onedrive) do lado do usuário.
#
# Opt-in por `lcars.user.onedrive.enable`, ligado no profile. A flag vem do
# config do NixOS (veja user/options.nix).
#
# O SYNC_DIR É DECLARATIVO
# -------------------------
# `~/.config/onedrive/config` é escrito pelo `xdg.configFile`, com
# `sync_dir` vindo de `lcars.user.onedrive.syncDir`. Isso vira um symlink
# somente-leitura para o Nix store: mudar o diretório sincronizado é editar
# a flag e rodar `nupdate`, não editar o arquivo à mão — o valor do arquivo
# precisa ficar entre aspas (`sync_dir = "~/OneDrive"`), formato confirmado
# no config de exemplo do próprio pacote.
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
  ...
}:

lib.mkIf osConfig.lcars.user.onedrive.enable {
  xdg.configFile."onedrive/config".text = ''
    sync_dir = "${osConfig.lcars.user.onedrive.syncDir}"
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
        echo "lcars: onedrive refresh_token atualizado a partir do 1Password."
      else
        echo "lcars: não consegui ler $ref — abra o app 1Password, desbloqueie a CLI, e siga o procedimento em docs/secrets.md."
      fi
    fi
  '';
}
