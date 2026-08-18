# vivaldi.nix — o navegador.
#
# Opt-in por `lcars.user.vivaldi.enable`, ligado no profile. A flag vem do
# config do NixOS (veja user/options.nix).
#
# Por que um módulo, e não um nome em `userSettings.packages`
# ----------------------------------------------------------
# Porque o pacote de fábrica não serve para uso diário nesta máquina, e por
# duas razões que a lista de pacotes não tem onde expressar:
#
#   1. O `pkgs.vivaldi` puro vem SEM codecs proprietários e SEM Widevine. O
#      resultado é vídeo em H.264 que não toca (metade do YouTube, todo MP4
#      local) e serviço com DRM que mostra tela preta (Netflix, Prime,
#      Spotify Web). Os dois são argumentos da derivação, e chegam por
#      `override` — impossível a partir de um nome numa lista de strings.
#
#   2. O niri é Wayland puro. Um Chromium sem dica de plataforma sobe em
#      XWayland: fonte borrada em tela HiDPI e escala fracionária que o
#      compositor tem de emular. A flag abaixo resolve, e também é coisa de
#      derivação — o Home Manager a aplica por `override`.
#
# É a mesma lição do kitty, no arquivo ao lado: instalar o pacote não é
# configurar o programa.
#
# `programs.vivaldi` é o mesmo módulo do chromium
# ----------------------------------------------
# No Home Manager, chromium, brave, edge e vivaldi saem todos de
# modules/programs/chromium.nix — daí este módulo aceitar `extensions`,
# `dictionaries` e `nativeMessagingHosts` sem que nada disso apareça aqui.
#
# O que ele faz com `commandLineArgs` é o detalhe que importa: em vez de um
# script por cima, ele reaplica o `override` do pacote com as flags. É por
# isso que o `override` daqui embaixo sobrevive — os dois se somam, e o
# binário final tem codecs, Widevine e ozone de uma vez.
#
# O que NÃO está aqui
# -------------------
# Nada de dentro do navegador: marcadores, abas, atalhos, tema, extensões,
# mecanismo de busca. O Vivaldi guarda tudo isso no perfil dele e sincroniza
# pela conta do usuário — declarar aqui seria uma segunda fonte de verdade que
# a primeira sobrescreve no próximo login. O stylix também não o alcança: não
# há alvo para Vivaldi, e a paleta de interface é escolhida na Configuração
# dele.
#
# O CHROMIUM DO HERDR CONTINUA SENDO OUTRO
# ----------------------------------------
# `user/app/herdr.nix` traz um `pkgs.chromium` como motor do painel de browser,
# e ele NÃO é substituído por este navegador: o Vivaldi falha ali com "timed
# out waiting for CDP Page.enable". São dois programas com papéis diferentes —
# aquele é um renderizador headless-ish falando CDP, fora do PATH; este é o
# navegador que o usuário abre.
{
  osConfig,
  lib,
  pkgs,
  ...
}:

lib.mkIf osConfig.lcars.user.vivaldi.enable {
  programs.vivaldi = {
    enable = true;

    package = pkgs.vivaldi.override {
      # H.264, AAC e afins, do `vivaldi-ffmpeg-codecs` (LGPL 2.1, livre).
      proprietaryCodecs = true;

      # O CDM da Google, que destrava streaming com DRM. É unfree, e por isso
      # aparece por nome em system/unfree.nix junto com o próprio Vivaldi.
      enableWidevine = true;
    };

    commandLineArgs = [
      # Wayland nativo quando houver um compositor, X11 quando não houver — é
      # o que `auto` decide em tempo de execução. Sem esta flag o Chromium
      # escolhe X11 sempre, e sob o niri isso significa XWayland.
      "--ozone-platform-hint=auto"
    ];
  };
}
