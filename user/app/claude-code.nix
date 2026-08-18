# claude-code.nix — o CLI do Claude Code no ambiente do usuário.
#
# Opt-in por `lcars.user.claudeCode.enable`, ligado no profile. A flag vem do
# config do NixOS (veja user/options.nix).
#
# O pacote é unfree, e avalia porque `system/unfree.nix` liga o `allowUnfree`
# global — não há nada a declarar deste lado. Aliás não haveria como: em
# `user/`, `config` é o do Home Manager, que não conhece `nixpkgs.config` nem
# `lcars.*`.
#
# POR QUE `home.packages`, E NÃO `programs.claude-code`
# ----------------------------------------------------
# O Home Manager tem um módulo `programs.claude-code` que escreve settings.json,
# agents, commands e servidores MCP. Nada disso está no escopo aqui: o que se
# quer é o binário no PATH, com a configuração continuando em ~/.claude, fora
# do store e editável pelo próprio Claude Code. Um módulo que gerasse o
# settings.json colocaria esse arquivo em symlink read-only, e toda alteração
# feita pela ferramenta (ou pelo `/config`) passaria a exigir um rebuild.
#
# A versão é a do nixpkgs pinado no flake.lock. O `claude update` embutido não
# funciona numa instalação do Nix — o binário está no store, read-only —, e
# atualizar é `nix flake update` como no resto do sistema.
{
  osConfig,
  lib,
  pkgs,
  ...
}:

lib.mkIf osConfig.lcars.user.claudeCode.enable {
  home.packages = [ pkgs.claude-code ];
}
