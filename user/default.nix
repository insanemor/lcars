# user/ — módulos do Home Manager, carregados para vars.username.
#
# Diferente de system/, aqui não há options opt-in: o que está nesta lista é
# aplicado. O que for específico da sua pessoa e não deve ir para o repo
# público vive em user/personal/ (escape hatch) ou no 1Password.
{ ... }:

{
  imports = [
    ./shell/zsh.nix
    ./shell/starship.nix
    ./app/git.nix
    ./app/direnv.nix
    ./app/dotfiles.nix
  ];
}
