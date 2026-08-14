{ ... }:

{
  programs.starship = {
    enable = true;
    # `enableFishCompletion` não existe — as opções são enable*Integration.
    enableZshIntegration = true;
    enableBashIntegration = true;
  };
}
