# system/wm — ambientes gráficos, e o que eles compartilham.
#
# Mais de um pode estar ligado ao mesmo tempo: todos aparecem na tela de login
# e você escolhe na hora. Hoje são niri e Hyprland — Plasma saiu na #34, e o
# Hyprland voltou na #142, como opção ao lado do niri, não no lugar dele — e a
# estrutura continua preparada para conviverem, e é ela que torna seguro
# experimentar um ambiente novo sem perder o que funciona.
#
# Este arquivo existe porque algumas coisas são de "ter ambiente gráfico", não
# de um WM em particular, e declará-las dentro de cada módulo geraria conflito
# de definição no instante em que dois estivessem ligados:
#
#   - a tela de login em si (regreet)
#   - qual sessão abre por padrão
#   - as fontes e o dconf
#
# POR QUE REGREET, E NÃO SDDM
# ----------------------------
# O SDDM não é tematizado pelo stylix (system/theme/default.nix) — ficava
# de fora do esquema de cores que pinta o resto do sistema. `regreet` (GTK)
# tem suporte nativo: o módulo do stylix (autoEnable no source do próprio
# stylix) tematiza cor, fonte, cursor, ícone e papel de fundo automaticamente,
# a partir das mesmas flags de `lcars.system.theme`, sem configuração extra
# aqui. `services.displayManager.regreet.enable = true` já é auto-suficiente:
# liga `services.greetd`, PAM, o compositor `cage` que hospeda o regreet — não
# precisa configurar nenhum dos dois à mão (issue #133).
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.lcars.system.wm;
  algumWm = cfg.niri.enable || cfg.hyprland.enable;

  # Hyprland vence quando os dois estão ligados: é o default do profile
  # personal desde a #142. Niri é o fallback, para quem ligou só ele.
  automatica =
    if cfg.hyprland.enable then
      "hyprland"
    else if cfg.niri.enable then
      "niri"
    else
      "";

  sessao = if cfg.defaultSession != "" then cfg.defaultSession else automatica;

  # O pacote do Hyprland instala DUAS sessões em share/wayland-sessions:
  # hyprland.desktop e hyprland-uwsm.desktop. A segunda aparecia na tela de
  # login como "Hyprland (uwsm-managed)" e roda o compositor por dentro do uwsm
  # (Universal Wayland Session Manager) — que este repo não configura:
  # `programs.hyprland.withUWSM`, a opção que liga `programs.uwsm.enable`, está
  # desligada. Era um caminho não testado à distância de um clique (#165).
  #
  # Esta derivação carrega só o .desktop que queremos. Nada do Hyprland é
  # recompilado: `programs.hyprland.package` continua intocado, e o compositor,
  # o portal e os wrappers do módulo do nixpkgs seguem usando o pacote de
  # sempre — o que muda é apenas quais arquivos de sessão o NixOS entrega ao
  # regreet. Tirar o .desktop no próprio pacote (`overrideAttrs`) custaria uma
  # compilação inteira do Hyprland a cada bump do nixpkgs.
  sessaoHyprland =
    pkgs.runCommand "hyprland-sessao"
      {
        passthru.providedSessions = [ "hyprland" ];
        preferLocalBuild = true;
        allowSubstitutes = false;
      }
      ''
        mkdir -p "$out/share/wayland-sessions"
        cp ${config.programs.hyprland.package}/share/wayland-sessions/hyprland.desktop \
          "$out/share/wayland-sessions/"
      '';
in
{
  imports = [
    ./niri.nix
    ./hyprland.nix
  ];

  options.lcars.system.wm = {
    defaultSession = mkOption {
      type = types.str;
      default = "";
      example = "niri";
      description = ''
        Sessão pré-selecionada na tela de login. Vazio = decide sozinho, e
        hoje isso quer dizer Hyprland quando ele está ligado.

        Os nomes válidos são os `providedSessions` dos pacotes listados em
        `services.displayManager.sessionPackages`, logo abaixo — hoje
        `hyprland` e `niri`. Não adianta procurar em
        `/run/current-system/sw/share/wayland-sessions/`: esse diretório não
        existe, porque `/share/wayland-sessions` não está em
        `environment.pathsToLink`. Errar o nome não passa calado — o NixOS
        tem uma assertion que aborta a avaliação listando os nomes aceitos.
      '';
    };
  };

  config = mkIf algumWm {
    services.displayManager.regreet.enable = true;

    # `sessao` pode ser vazia se alguém ligar um WM sem sessão conhecida; aí
    # não declaramos nada e o regreet usa a ordem dele.
    services.displayManager.defaultSession = mkIf (sessao != "") sessao;

    # ATENÇÃO: esta lista é COMPLETA, e é ela que vira a tela de login.
    #
    # Normalmente cada módulo acrescenta o seu pacote aqui por conta própria
    # (`programs.hyprland` e `programs.niri` fazem `sessionPackages = [ cfg.package ]`,
    # sem mkDefault). Como o NixOS monta o diretório de sessões copiando todo o
    # `share/wayland-sessions/` de cada pacote da lista, não há como remover um
    # único .desktop sem reescrever a lista inteira — daí o mkForce.
    #
    # A consequência é a de sempre com mkForce: WM novo que não for somado aqui
    # não aparece na tela de login, por mais que o módulo dele esteja ligado.
    services.displayManager.sessionPackages = mkForce (
      optional cfg.hyprland.enable sessaoHyprland ++ optional cfg.niri.enable config.programs.niri.package
    );

    # As fontes moraram dentro do plasma.nix, e não eram do KDE: qualquer
    # ambiente gráfico precisa delas, e desligar o Plasma levava as fontes do
    # sistema inteiro junto — com o sintoma aparecendo longe da causa.
    #
    # `enableDefaultPackages` traz o conjunto que o NixOS considera básico
    # (DejaVu, Liberation, gyre, unifont e as CJK). As de baixo são as que
    # queremos garantir por nome; o stylix acrescenta as dele — a Nerd Font do
    # terminal, entre elas — a partir de lcars.system.theme.fonts.
    fonts = {
      enableDefaultPackages = true;
      packages = with pkgs; [
        noto-fonts
        # noto-fonts-emoji foi renomeado para noto-fonts-color-emoji no
        # nixpkgs; o nome antigo aborta a avaliação com um throw.
        noto-fonts-color-emoji
        liberation_ttf
        dejavu_fonts
      ];
    };

    # Também não é do KDE: aplicativos GTK guardam preferência no dconf, e sem
    # isto elas não persistem entre sessões.
    programs.dconf.enable = true;
  };
}
