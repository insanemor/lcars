{ pkgs, ... }:

{
  programs.starship = {
    enable = true;
    enableFishCompletion = true;
  };

  home.packages = [ pkgs.starship ];
}
