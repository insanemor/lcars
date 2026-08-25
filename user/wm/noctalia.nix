# noctalia.nix — o shell do desktop.
#
# Barra, launcher, notificações, tela de bloqueio, dock, OSD e histórico de
# área de transferência, numa peça só. Substituiu waybar + swaync + rofi, que
# eram três módulos com três formatos de configuração e nenhuma interface de
# ajuste.
#
# O ciclo de ajuste
# -----------------
# É o motivo de ele estar aqui. Você mexe no centro de controle, olha o
# resultado na hora, e quando gostar, publica manualmente:
#
#     noctalia config export merged > user/wm/noctalia-config.toml
#     noctalia config validate user/wm/noctalia-config.toml
#     git -C ~/.dotfiles diff -- user/wm/noctalia-config.toml
#     git -C ~/.dotfiles add -- user/wm/noctalia-config.toml
#     git -C ~/.dotfiles commit -- user/wm/noctalia-config.toml
#
# CUIDADO: o export REESCREVE o arquivo do zero, em ordem alfabética e sem
# comentário nenhum. Não escreva nada lá que precise sobreviver — o cabeçalho
# que existia foi apagado no primeiro ciclo real. O que precisa durar mora
# aqui, neste arquivo, que o export não toca.
#
# CUIDADO AO COMMITAR: o índice deste repositório nunca está limpo — o
# nupdate faz `git add -f machines/<host>` a cada execução, porque flakes só
# leem arquivos rastreados. Um `git commit -m "..."` seco, sem `-- <arquivo>`,
# leva `machines/` junto sem avisar (foi o que aconteceu na #33). Sempre
# commite pelo caminho explícito, como acima.
#
# Sem publicar, o que você ajustou vive só no state-dir desta máquina e some
# num clone novo — ou no próximo nupdate, que faz git reset --hard.
#
# Por que `fromTOML` e não `settings = ./arquivo.toml`
# ----------------------------------------------------
# A option aceita um caminho, mas aí a definição inteira vira um valor só, e o
# stylix também escreve em `programs.noctalia.settings`. Caminho e attrset não
# se fundem: uma das duas definições venceria por completo. Lido como attrset,
# os dois se combinam chave a chave.
#
# Por que não `mkDefault`
# -----------------------
# Foi a primeira tentativa e está errada. A prioridade é resolvida *antes* da
# fusão e vale para a definição inteira: `mkDefault` sobre o attrset todo o
# marca com prioridade 1000, e como o stylix define na prioridade normal (100),
# o attrset inteiro era descartado — o arquivo daqui não chegava a existir na
# configuração final. Verificado com `nix eval`: sem isto, nem
# `settings.shell.settings_show_advanced` sobrevivia.
#
# Definido na prioridade normal, os dois lados fundem por chave. O preço é que
# uma chave definida dos dois lados vira erro de conflito — daí a lista abaixo.
{
  config,
  osConfig,
  lib,
  pkgs,
  ...
}:

let
  arquivo = ./noctalia-config.toml;

  # Os caminhos que o stylix escreve dentro de `settings` (stylix,
  # modules/noctalia/hm.nix). O stylix os escreve no config dir, e é de lá que
  # `noctalia config export merged` lê — então eles voltam no export, e aí os
  # dois lados definiriam a mesma chave, o que o sistema de módulos trata como
  # conflito e aborta.
  #
  # Retirá-los do que exportamos é o que mantém o ciclo GUI → export → commit
  # funcionando sem você ter que lembrar de editar o arquivo à mão.
  gerenciadosPeloStylix = [
    [
      "theme"
      "source"
    ]
    [
      "theme"
      "custom_palette"
    ]
    [
      "theme"
      "mode"
    ]
    [
      "shell"
      "font_family"
    ]
    [
      "wallpaper"
      "default"
      "path"
    ]
    [
      "dock"
      "background_opacity"
    ]
    [
      "notification"
      "background_opacity"
    ]
    [
      "osd"
      "background_opacity"
    ]
  ];

  removerCaminho =
    attrs: caminho:
    let
      chave = builtins.head caminho;
      resto = builtins.tail caminho;
    in
    if !(attrs ? ${chave}) then
      attrs
    else if resto == [ ] then
      builtins.removeAttrs attrs [ chave ]
    else if builtins.isAttrs attrs.${chave} then
      attrs // { ${chave} = removerCaminho attrs.${chave} resto; }
    else
      attrs;

  exportado = builtins.fromTOML (builtins.readFile arquivo);

  # Só poda quando o stylix está de fato no ar. Com o tema desligado ninguém
  # define essas chaves, e removê-las jogaria fora escolha sua sem substituto.
  temaLigado = osConfig.lcars.system.theme.enable;

  # --- efeitos ----------------------------------------------------------
  # Com `lcars.system.theme.animations = false`, os efeitos caros saem. O que
  # eles custam não é uniforme: animação e blur redesenham a tela inteira em
  # GPU, e numa placa fraca — ou numa VM cuja aceleração é traduzida por VirGL
  # — é o que se sente primeiro.
  #
  # Nada aqui muda funcionalidade: os painéis abrem e fecham igual, só sem a
  # transição.
  animacoes = osConfig.lcars.system.theme.animations;

  efeitos = [
    [
      "shell"
      "animation"
      "enabled"
    ]
    [
      "shell"
      "shadow"
      "alpha"
    ]
    [
      "bar"
      "shadow"
    ]
    [
      "dock"
      "shadow"
    ]
    [
      "backdrop"
      "blur_intensity"
    ]
    [
      "lockscreen"
      "blurred_desktop"
    ]
  ];

  semEfeitos = {
    shell = {
      animation.enabled = false;
      shadow.alpha = 0.0;
    };
    bar.shadow = false;
    dock.shadow = false;
    backdrop.blur_intensity = 0.0;
    lockscreen.blurred_desktop = false;
  };

  # --- o que não sobrevive a outra máquina ------------------------------
  # O export escreve caminhos absolutos de quem exportou, e uma das chaves
  # guarda o NOME DAS SAÍDAS de vídeo daquela máquina. Num clone — ou na mesma
  # máquina depois de uma reformatação — elas apontam para arquivos e monitores
  # que não existem, e o efeito é silencioso: o launcher fica sem ícone e o
  # papel de parede não sobe. Foi o que a instalação limpa da #157 mostrou.
  #
  # As três primeiras voltam recalculadas logo abaixo. As três últimas só saem:
  # `wallpaper.last` é o que você escolheu da última vez, `wallpaper.monitors`
  # é por saída de vídeo, e `wallpaper.default.path` é uma imagem sua. Nenhuma
  # tem valor certo para outra máquina — quem escolhe é o centro de controle,
  # em SUPER+C, e a escolha vive no state-dir.
  #
  # Podar aqui é o que mantém o ciclo `nsave` seguro: no próximo
  # `noctalia config export merged` os caminhos voltam ao TOML, e esta lista os
  # tira de novo antes de virarem a configuração de alguém.
  pessoais = [
    [
      "plugin_settings"
      "noctalia/mpvpaper"
      "video_directory"
    ]
    [
      "plugin_settings"
      "noctalia/wallhaven"
      "download_dir"
    ]
    [
      "widget"
      "launcher"
      "custom_image"
    ]
    [
      "wallpaper"
      "last"
    ]
    [
      "wallpaper"
      "monitors"
    ]
    # Também está em gerenciadosPeloStylix, que só poda com o tema ligado.
    # Aqui sai sempre: com o tema desligado, nada define esta chave e o que
    # sobraria era o caminho de uma imagem que não existe nesta máquina.
    [
      "wallpaper"
      "default"
      "path"
    ]
  ];

  # O `$HOME` literal que `xdg.userDirs` guarda não serve para o noctalia, que
  # lê estas chaves como caminho, não como linha de shell. Expandir aqui deixa
  # `user/app/xdg-user-dirs.nix` como fonte única dos nomes ("Vídeos",
  # "Imagens") — repeti-los seria a divergência que custou a #150.
  comHome = lib.replaceStrings [ "$HOME" ] [ config.home.homeDirectory ];

  # O logo é do repositório, não da máquina: é o mesmo PNG de onde saem os
  # glifos U+F8F0 a U+F8F3 da fonte do sistema (system/theme/logo-fonte).
  # Apontando para o store, o ícone do launcher existe em qualquer clone, sem
  # depender de nada em ~/Imagens.
  logoSimbioIT = ../../system/theme/logo-fonte/logo-original.png;

  daMaquina = {
    plugin_settings."noctalia/mpvpaper".video_directory = comHome config.xdg.userDirs.videos;
    plugin_settings."noctalia/wallhaven".download_dir =
      "${comHome config.xdg.userDirs.pictures}/wallhaven";
    widget.launcher.custom_image = "${logoSimbioIT}";
  };

  # A poda serve aos três casos pelo mesmo motivo: o TOML e o Nix não podem
  # definir a mesma chave, senão o módulo aborta por conflito. Quem vai
  # sobrescrever, poda antes.
  podar = attrs: caminhos: builtins.foldl' removerCaminho attrs caminhos;

  base = podar exportado (
    pessoais ++ (lib.optionals temaLigado gerenciadosPeloStylix) ++ (lib.optionals (!animacoes) efeitos)
  );

  # O CLI que o plugin felipeartur/ai-usagebar chama por nome
  # (github.com/akitaonrails/ai-usagebar). Não está no nixpkgs — diferente do
  # gSlapper (não seguido, ver #116/#117: C, meson, GStreamer, empacotar do
  # zero não compensava), este é Rust puro, com Cargo.lock na raiz e sem
  # dependência de sistema incomum. Fixado na tag v1.3.1, não no branch: o
  # mesmo motivo do herdr (user/app/herdr.nix) — reprodutível, sem quebrar
  # num `nupdate --inputs` por conta alheia.
  #
  # `checkFlags` pula só um teste (`rollback_archives_and_their_directory_
  # are_private`): ele espera o binário `tar` num jeito que o sandbox do Nix
  # não fornece pra esse caso específico, e o teste é sobre rollback de
  # arquivos do Claude Desktop — sem relação com o que o plugin realmente
  # usa (`ai-usagebar usage --json`). Os outros 1058+ testes continuam
  # rodando; build real confirmado com `nix build`, não só `nix eval`.
  aiUsagebarCli = pkgs.rustPlatform.buildRustPackage rec {
    pname = "ai-usagebar";
    version = "1.3.1";

    src = pkgs.fetchFromGitHub {
      owner = "akitaonrails";
      repo = "ai-usagebar";
      rev = "685ecc65c0022e471c3892637a95046bdf894730"; # tag v1.3.1
      hash = "sha256-9PWYgcdLnBYEUGvgAOSeBRoXjsF21oA/SSAlupFwryE=";
    };

    cargoLock.lockFile = "${src}/Cargo.lock";

    checkFlags = [
      "--skip=claude_desktop::app::tests::rollback_archives_and_their_directory_are_private"
    ];

    meta = {
      description = "CLI que lê a cota de uso de provedores de IA (Claude, Codex, Cursor...)";
      homepage = "https://github.com/akitaonrails/ai-usagebar";
      mainProgram = "ai-usagebar";
    };
  };

  # Plugins do noctalia habilitados por flag. Cada plugin vira uma entrada em
  # `[plugins].enabled`, e o noctalia baixa o repositório oficial sozinho na
  # primeira ativação. Adicionar um plugin novo é declarar a flag em
  # user/options.nix e somar o id aqui.
  pluginsHabilitados =
    (lib.optional osConfig.lcars.user.noctalia.plugins.wallhaven.enable "noctalia/wallhaven")
    ++ (lib.optional osConfig.lcars.user.noctalia.plugins.nixMonitor.enable "avivbintangaringga/nix-monitor")
    ++ (lib.optional osConfig.lcars.user.noctalia.plugins.niriDisplays.enable "raycursive/niri-displays")
    ++ (lib.optional osConfig.lcars.user.noctalia.plugins.niriAnimations.enable "imjustdoingmypart/niri-animations")
    ++ (lib.optional osConfig.lcars.user.noctalia.plugins.miniDocker.enable "8bury/mini-docker")
    ++ (lib.optional osConfig.lcars.user.noctalia.plugins.gitCompanion.enable "tphilippot/git_companion")
    ++ (lib.optional osConfig.lcars.user.noctalia.plugins.driveHealth.enable "gustav0ar/drive-health")
    ++ (lib.optional osConfig.lcars.user.noctalia.plugins.aiUsagebar.enable "felipeartur/ai-usagebar")
    ++ (lib.optional osConfig.lcars.user.noctalia.plugins.mpvpaper.enable "noctalia/mpvpaper")
    ++ (lib.optional osConfig.lcars.user.noctalia.plugins.notes.enable "noctalia/notes");

  # `recursiveUpdate` e não `//`: os efeitos vivem a dois níveis
  # (`shell.animation.enabled`), e a fusão rasa apagaria as outras chaves de
  # `shell` que vieram do seu export.
  settingsComEfeitos = if animacoes then base else lib.recursiveUpdate base semEfeitos;

  # `//` aqui é seguro: `plugins.enabled` vive um nível só, e ele só é escrito
  # quando há pelo menos um plugin — sem flag ligada, o attrset fica
  # exatamente como veio do TOML.
  comPlugins =
    if pluginsHabilitados == [ ] then
      settingsComEfeitos
    else
      settingsComEfeitos // { plugins.enabled = pluginsHabilitados; };

  # `recursiveUpdate` de novo, e não `//`: `daMaquina` toca em três chaves que
  # vivem fundo (`plugin_settings."noctalia/mpvpaper".video_directory`), e a
  # fusão rasa apagaria o resto de `plugin_settings` e de `widget`.
  attrsetFinal = lib.recursiveUpdate comPlugins daMaquina;
in
lib.mkIf osConfig.lcars.user.noctalia.enable {
  programs.noctalia = {
    enable = true;

    # Por serviço, não por spawn-at-startup do compositor: reinicia se cair e
    # responde a `systemctl --user status noctalia`. Veja a regra no CLAUDE.md.
    #
    # O `graphical-session.target` de que ele depende vem das unidades que o
    # módulo NixOS do compositor instala — niri (system/wm/niri.nix) ou
    # Hyprland (system/wm/hyprland.nix), o que estiver ligado.
    systemd.enable = true;

    settings = attrsetFinal;
  };

  # Cada plugin em si é só um id que o noctalia baixa sozinho (acima). Os
  # binários que eles chamam em runtime não vêm junto.
  home.packages =
    # noctalia/mpvpaper: `mpvpaper` desenha o papel de parede, `mpv`
    # renderiza as miniaturas do seletor.
    (lib.optionals osConfig.lcars.user.noctalia.plugins.mpvpaper.enable [
      pkgs.mpvpaper
      pkgs.mpv
    ])
    # gustav0ar/drive-health: `smartctl` lê temperatura e SMART. `lsblk`
    # (util-linux) e `pkexec` (agente polkit do próprio noctalia) já vêm de
    # série no sistema, sem precisar somar nada aqui.
    ++ (lib.optionals osConfig.lcars.user.noctalia.plugins.driveHealth.enable [
      pkgs.smartmontools
    ])
    # felipeartur/ai-usagebar: o CLI de verdade (aiUsagebarCli, definido
    # acima) lê a cota de uso. `xdg-utils` é opcional — só serve o link
    # "abrir a página do projeto" quando o CLI não está no PATH, o que nunca
    # acontece aqui, mas custa pouco ter.
    ++ (lib.optionals osConfig.lcars.user.noctalia.plugins.aiUsagebar.enable [
      aiUsagebarCli
      pkgs.xdg-utils
    ]);
}
