# user/ — módulos do Home Manager, carregados para user.username.
#
# Como em system/, todos são importados sempre e nenhum liga sozinho: cada um
# é opt-in por `lcars.user.<módulo>.enable`, e quem decide é o profile.
#
# A diferença é onde a flag mora. Estes módulos são avaliados na árvore do
# Home Manager, cujo `config` não conhece `lcars.*`; as options são declaradas
# do lado NixOS, em user/options.nix, e lidas aqui por `osConfig`. É o que
# permite a um profile — que é módulo NixOS — ligar os dois lados no mesmo
# lugar.
#
# O que for específico da sua pessoa e não deve ir para o repo público vive em
# user/personal/ (escape hatch, sem flag) ou no 1Password.
{ ... }:

{
  imports = [
    ./shell/zsh.nix
    ./shell/atuin.nix
    ./shell/fzf.nix
    ./shell/zoxide.nix
    ./app/git.nix
    ./app/kitty.nix
    ./app/vivaldi.nix
    ./app/herdr.nix
    ./app/direnv.nix
    ./app/dotfiles.nix
    ./app/nvim.nix
    ./app/claude-code.nix
    ./wm/niri.nix
    ./wm/noctalia.nix
  ];
}
