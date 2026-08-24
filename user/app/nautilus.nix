# nautilus.nix — o gerenciador de arquivos gráfico.
#
# Opt-in por `lcars.user.nautilus.enable`, ligado no profile. A flag vem do
# config do NixOS (veja user/options.nix).
#
# Por que este módulo existe, se `useNautilus` já está ligado
# -------------------------------------------------------------
# `system/wm/niri.nix` liga `programs.niri.useNautilus = true` por padrão, mas
# isso só registra `pkgs.nautilus` em `services.dbus.packages` — usado pelo
# xdg-desktop-portal-gnome como seletor de arquivos do "salvar como"/"abrir".
# `services.dbus.packages` alimenta só os service directories do dbus
# (`nixos/modules/services/system/dbus.nix`), não `environment.systemPackages`:
# o binário e o `.desktop` do Nautilus não chegam ao PATH nem ao launcher de
# aplicativos por essa flag. Sem este módulo não havia gerenciador de arquivos
# abrível como programa — só o seletor do portal, dentro de outro app.
#
# `home.packages`, e não `programs.nautilus` — porque não existe
# ------------------------------------------------------------
# O Home Manager não tem um módulo dedicado ao Nautilus, só o pacote. A cor e
# a fonte da interface vêm do dconf (`programs.dconf.enable`, já ligado em
# `system/wm/default.nix` para qualquer app GTK) e do tema GTK do stylix — não
# há nada específico do Nautilus a configurar aqui.
{
  osConfig,
  lib,
  pkgs,
  ...
}:

lib.mkIf osConfig.lcars.user.nautilus.enable {
  home.packages = [ pkgs.nautilus ];

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory" = "org.gnome.Nautilus.desktop";
    };
  };
}
