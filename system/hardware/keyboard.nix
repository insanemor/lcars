# keyboard.nix — layout do teclado, no console e na sessão gráfica.
#
# Isto morava no bloco de locale de system/core, junto com idioma e fuso.
# Layout parece preferência de idioma, mas é do teclado FÍSICO: duas máquinas
# com teclados diferentes precisam de valores diferentes, e ali o valor era
# fixo para todas.
#
# Uma fonte só para os dois contextos
# -----------------------------------
# O console (TTY) e o X/Wayland usam vocabulários diferentes: o console fala
# keymaps do kernel ("us-acentos", "br-abnt2"), o XKB fala layout + variante
# ("us"+"intl", "br"+"abnt2"). Declarar os dois à mão convida a divergirem —
# que é exatamente o que acontecia antes desta issue: o TTY tinha "us-acentos"
# e a sessão gráfica, sem configuração nenhuma, subia em "us" puro, sem
# acentuação.
#
# `console.useXkbConfig` resolve: ele compila o layout XKB para o console com
# `ckbcomp`, em tempo de build. Então declaramos só o XKB, e o console segue.
# Isso não exige o xserver habilitado — o módulo do console lê apenas os
# valores de `services.xserver.xkb`, e funciona numa máquina headless.
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.lcars.system.hardware.keyboard;
in
{
  options.lcars.system.hardware.keyboard = {
    enable = mkEnableOption "layout de teclado do console e da sessão gráfica";

    layout = mkOption {
      type = types.str;
      default = "us";
      example = "br";
      description = ''
        Layout XKB. Vale para a sessão gráfica e, via ckbcomp, também para o
        console. Vários layouts separados por vírgula são aceitos.
      '';
    };

    variant = mkOption {
      type = types.str;
      default = "intl";
      example = "abnt2";
      description = ''
        Variante do layout. O default "intl" é o US internacional com
        acentuação por dead keys — o equivalente XKB do keymap "us-acentos"
        que este repo usava no console. Num teclado ABNT2 brasileiro, use
        layout = "br" com variant = "abnt2". String vazia = sem variante.
      '';
    };

    consoleFont = mkOption {
      type = types.str;
      default = "Lat2-Terminus16";
      description = "Fonte do console (TTY).";
    };
  };

  config = mkIf cfg.enable {
    # A fonte da verdade. Mesmo sem X, estas opções são só dados — quem as
    # consome aqui é o console, logo abaixo.
    services.xserver.xkb = {
      layout = cfg.layout;
      variant = cfg.variant;
    };

    # Para model e options (troca de layout por atalho, por exemplo), declare
    # `services.xserver.xkb.model` / `.options` direto na máquina: são poucos
    # os casos, e não vale um espelho de option para cada um.

    console = {
      useXkbConfig = true;
      font = cfg.consoleFont;
      packages = with pkgs; [ terminus_font ];
    };
  };
}
