# dotfiles.nix — liga itens do tipo Document do 1Password a ~/.config/dotfiles/.
#
# Itens listados em userSettings.dotfilesFrom1Password viram arquivos em
# ~/.config/dotfiles/<rel>. Você os aponta para o destino que quiser
# (ex.: ~/.zshrc) com `xdg.configFile` ou `home.file` simples.
#
# A busca no 1Password acontece na ativação, via op.
#
# Opt-in por `lcars.user.dotfiles.enable`, ligado no profile; a flag vem do
# config do NixOS (veja user/options.nix).
{
  config,
  osConfig,
  lib,
  pkgs,
  sys,
  user,
  ...
}:

with lib;

let
  cacheDir = "${config.home.homeDirectory}/.1password/dotfiles";

  items = map (rel: rec {
    inherit rel;
    # Nome de atributo seguro: nada de "/" nem "." em chaves de xdg.configFile.
    key = builtins.replaceStrings [ "/" "." ] [ "-" "-" ] rel;
    cachePath = "${cacheDir}/${rel}";
    opPath = "op://${user.onePassword.vault}/dotfiles-${rel}/file";
  }) (user.dotfilesFrom1Password or [ ]);
in
mkIf osConfig.lcars.user.dotfiles.enable {
  # Os arquivos são materializados em tempo de ATIVAÇÃO, não de build — então
  # precisam ser symlinks para fora do store. `source = <path>` faria o
  # home-manager tentar copiá-los para o store durante o build e falhar,
  # porque nesse momento eles ainda não existem.
  xdg.configFile = builtins.listToAttrs (
    map (item: {
      name = "dotfiles/${item.rel}";
      value = {
        source = config.lib.file.mkOutOfStoreSymlink item.cachePath;
        force = true;
      };
    }) items
  );

  # Ativação: puxa cada Document do 1Password em `home-manager switch`.
  # Requer `op signin` ou token de service account na sessão do usuário.
  home.activation.dotfilesFrom1Password = mkIf (items != [ ]) (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p ${escapeShellArg cacheDir}

      # O `op` por caminho absoluto, o do wrapper primeiro. Esta ativação roda
      # numa unit systemd cujo PATH não tem /run/wrappers/bin, então
      # `command -v op` falha sempre — e, entre os dois binários possíveis, só
      # o wrapper (setgid do grupo `onepassword-cli`) é aceito pelo aplicativo.
      # A história completa está em user/shell/atuin.nix e na #56.
      op=""
      for candidato in /run/wrappers/bin/op "$(command -v op 2>/dev/null || true)"; do
        if [ -n "$candidato" ] && [ -x "$candidato" ]; then
          op="$candidato"
          break
        fi
      done

      if [ -z "$op" ]; then
        echo "lcars: 'op' não encontrado (nem /run/wrappers/bin/op, nem no PATH) — pulando dotfiles do 1Password"
      elif [ -z "''${OP_SERVICE_ACCOUNT_TOKEN:-}" ] && ! "$op" whoami >/dev/null 2>&1; then
        echo "lcars: sem login no 1Password — pulando dotfiles"
      else
        ${concatMapStringsSep "\n  " (item: ''
          if "$op" read ${escapeShellArg item.opPath} > ${escapeShellArg "${item.cachePath}.tmp"} 2>${escapeShellArg "${item.cachePath}.tmp.err"}; then
            mv ${escapeShellArg "${item.cachePath}.tmp"} ${escapeShellArg item.cachePath}
            rm -f ${escapeShellArg "${item.cachePath}.tmp.err"}
          else
            rm -f ${escapeShellArg "${item.cachePath}.tmp"}
            erro=""
            if [ -s ${escapeShellArg "${item.cachePath}.tmp.err"} ]; then
              erro="$(head -1 ${escapeShellArg "${item.cachePath}.tmp.err"})"
            fi
            rm -f ${escapeShellArg "${item.cachePath}.tmp.err"}
            echo "lcars: falha ao ler ${item.rel} do 1Password''${erro:+ — $erro}"
          fi
        '') items}
      fi
    ''
  );
}
