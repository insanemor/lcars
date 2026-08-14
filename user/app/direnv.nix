# direnv.nix — shells por projeto. Opt-in por `lcars.user.direnv.enable`,
# ligado no profile. Veja user/options.nix.
{ osConfig, lib, ... }:

lib.mkIf osConfig.lcars.user.direnv.enable {
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
