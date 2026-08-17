# --------------------------------------------------------------------
# Flags dos módulos do Home Manager — declaradas do lado NixOS.
#
# Por que este arquivo existe, e por que ele não vive dentro da árvore do
# Home Manager: `system/` e `user/` são avaliados em árvores de módulos
# SEPARADAS. Em `user/`, `config` é o config do Home Manager, onde `lcars.*`
# não existe — e um profile, que é módulo NixOS, não conseguiria escrever numa
# option declarada lá dentro.
#
# Então as flags nascem aqui, no config do NixOS, junto das de `system/`.
# É o que permite ao profile ligar os dois lados no mesmo lugar:
#
#   # profiles/personal/default.nix
#   lcars.system.wm.plasma.enable = mkDefault true;   # o desktop
#   lcars.user.direnv.enable      = mkDefault true;   # o meu shell
#
# Do outro lado da fronteira, cada módulo de user/ lê a flag por `osConfig`,
# que o Home Manager expõe justamente quando roda como módulo NixOS:
#
#   # user/app/direnv.nix
#   { osConfig, lib, ... }:
#   lib.mkIf osConfig.lcars.user.direnv.enable { ... }
#
# Todas vêm DESLIGADAS, como em system/: nada liga sozinho, quem decide é o
# profile. Para acrescentar um módulo em user/: declare a flag aqui, importe-o
# em user/default.nix, envolva o corpo no mkIf e ligue-o nos profiles.
# --------------------------------------------------------------------
{ lib, ... }:

{
  options.lcars.user = {
    zsh.enable = lib.mkEnableOption "o shell zsh do usuário — autosuggestion, syntax highlighting, histórico compartilhado e aliases";

    atuin.enable = lib.mkEnableOption "o histórico de comandos no atuin — busca no Ctrl+R e sync criptografado entre máquinas, com a chave vinda do 1Password";

    git.enable = lib.mkEnableOption "a configuração do git — identidade vinda do settings.nix, aliases e assinatura por chave SSH";

    direnv.enable = lib.mkEnableOption "o direnv com nix-direnv, para shells por projeto";

    dotfiles.enable = lib.mkEnableOption "os dotfiles puxados de itens Document do 1Password na ativação";

    kitty.enable = lib.mkEnableOption "o terminal — a fonte e as cores vêm do stylix, via lcars.system.theme";

    herdr.enable = lib.mkEnableOption "o multiplexador de terminal — workspaces, painéis e sessões persistentes, com os atalhos herdados do tmux (prefixo Ctrl-a)";

    niri.enable = lib.mkEnableOption "a configuração do niri — atalhos, forma e cores (o compositor é lcars.system.wm.niri)";

    noctalia.enable = lib.mkEnableOption "o shell do desktop — barra, launcher, notificações, lock e dock numa peça só; substitui waybar, rofi e swaync";
  };
}
