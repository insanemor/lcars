# starship.nix — prompt. Opt-in por `lcars.user.starship.enable`, ligado no
# profile. A flag vem do config do NixOS, não do Home Manager: veja
# user/options.nix.
{ osConfig, lib, ... }:

lib.mkIf osConfig.lcars.user.starship.enable {
  programs.starship = {
    enable = true;
    # `enableFishCompletion` não existe — as opções são enable*Integration.
    enableZshIntegration = true;
    enableBashIntegration = true;
  };
}
