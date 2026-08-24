# vscode.nix — editor de código gráfico.
#
# Opt-in por `lcars.user.vscode.enable`, ligado no profile. A flag vem do
# config do NixOS (veja user/options.nix).
#
# `programs.vscode`, e não `home.packages`
# -----------------------------------------
# O módulo do Home Manager registra o `.desktop` e o `code` no PATH como
# `home.packages` faria, mas também deixa `~/.config/Code/User/settings.json`
# e extensões geríveis depois, se algum dia isto crescer. Hoje não gerimos
# nenhum dos dois — perfil limpo, extensões instaladas pela própria UI —,
# mas usar o módulo certo desde já evita migrar de `home.packages` para
# `programs.vscode` no dia em que precisar.
#
# Tema, fonte e cores não entram aqui: o VS Code não é um dos alvos do
# stylix, e configurá-los a mão criaria uma segunda fonte de verdade que o
# resto do sistema não compartilha.
{
  osConfig,
  lib,
  pkgs,
  ...
}:

lib.mkIf osConfig.lcars.user.vscode.enable {
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
  };
}
