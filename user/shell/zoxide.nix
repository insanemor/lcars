# zoxide.nix — `z <parte-do-nome>` pula pra um diretório visitado antes,
# ranqueado por frequência e recência. Opt-in por `lcars.user.zoxide.enable`,
# ligado no profile. A flag vem do config do NixOS (veja user/options.nix).
#
# Sem `--cmd cd`: o `cd` nativo continua exatamente como está, e o zoxide
# entra como comando novo (`z`/`zi`), não como substituto. Trocar o próprio
# `cd` é uma mudança de comportamento maior, fora do que foi pedido — dá pra
# ligar depois, se fizer falta.
{
  osConfig,
  lib,
  ...
}:

lib.mkIf osConfig.lcars.user.zoxide.enable {
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
}
