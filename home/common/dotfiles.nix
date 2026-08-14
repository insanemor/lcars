# dotfiles.nix — liga itens do tipo Document do 1Password a ~/.config/dotfiles/.
#
# Itens listados em vars.dotfilesFrom1Password viram arquivos em
# ~/.config/dotfiles/<rel>. Você os aponta para o destino que quiser
# (ex.: ~/.zshrc) com `xdg.configFile` ou `home.file` simples.
#
# A busca no 1Password acontece na ativação, via op.
{ config, lib, pkgs, vars, ... }:

with lib;

{
  # Cria ~/.config/dotfiles/ como diretório gerenciado.
  xdg.configFile = let
    files = map (rel: {
      target = "dotfiles/${rel}";
      path = "${config.home.homeDirectory}/.1password/dotfiles/${rel}";
    }) vars.dotfilesFrom1Password;
  in builtins.listToAttrs (map (f: {
    name  = "dotfiles-${builtins.replaceStrings ["/" "."] ["-" "."] f.target}";
    value = { source = f.path; force = true; };
  }) files);

  # Ativação: puxa cada Document do 1Password em `home-manager switch`.
  # Requer `op signin` ou token de service account na sessão do usuário.
  home.activation.dotfilesFrom1Password =
    let
      items = map (rel: {
        rel' = rel;
        targetPath = "${config.home.homeDirectory}/.1password/dotfiles/${rel}";
        opPath = "op://${vars.onePassword.vault}/dotfiles-${rel}/file";
      }) vars.dotfilesFrom1Password;
    in
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      #/bin/sh -e
      mkdir -p "${config.home.homeDirectory}/.1password/dotfiles"
      ${concatMapStringsSep "\n" (item: ''
        if [ -n "''${OP_SERVICE_ACCOUNT_TOKEN:-}" ] || op whoami >/dev/null 2>&1; then
          run() { op read "${item.opPath}" > "${item.targetPath}.tmp" && mv "${item.targetPath}.tmp" "${item.targetPath}"; }
          run
        else
          echo "pulando ${item.rel'}: sem login no 1Password"
        fi
      '') items}
    '';
}
