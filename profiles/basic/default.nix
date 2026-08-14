# profile "basic" — máquina headless.
#
# Base do sistema, acesso por ssh, nada de gráfico. É o default: uma máquina
# que não declara `lcars.profile` sobe assim.
{ config, lib, ... }:

with lib;

{
  config = mkIf (config.lcars.profile == "basic") {
    lcars.core.enable     = mkDefault true;
    lcars.security.enable = mkDefault true;

    lcars.wm.gnome.enable = mkDefault false;

    # 1Password é proprietário e puxa a GUI junto; numa máquina headless não
    # ganha nada. Ligue explicitamente se quiser só o CLI aqui.
    lcars.apps.onePassword.enable = mkDefault false;
  };
}
