# Hosts sempre carregados junto com o diretório por máquina.
# Adicione aqui tudo que TODA máquina deve ter (ex.: pacotes globais).
{ config, lib, pkgs, vars, ... }:

{
  users.users.${vars.username}.packages = with pkgs; [
    zsh
    starship
    ripgrep
    fd
    bat
    eza
    direnv
    nix-direnv
  ];
}
