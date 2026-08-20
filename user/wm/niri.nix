# niri.nix — a configuração do compositor.
#
# Opt-in por `lcars.user.niri.enable`, ligada no profile. A flag vem do config
# do NixOS, lida por `osConfig` (veja user/options.nix).
#
# O modelo é diferente, e os atalhos acompanham
# ---------------------------------------------
# No Hyprland você movia o foco entre janelas num plano. Aqui a unidade é a
# COLUNA: as janelas formam uma fita horizontal infinita, e a tela é uma janela
# de visualização que rola por ela. Uma coluna pode ter mais de uma janela
# empilhada na vertical.
#
# Daí a divisão dos atalhos: H e L andam entre colunas, J e K entre as janelas
# de uma mesma coluna. Os workspaces, que no Hyprland eram uma grade de nove,
# aqui são uma pilha vertical dinâmica — mas os atalhos numéricos continuam,
# porque a memória dos dedos não muda de arquitetura junto.
#
# A cor vem do stylix, mas à mão
# ------------------------------
# O stylix não tem alvo para niri (conferido em `modules/`: há hyprland, kde,
# gtk e qt, não niri). Então nada aqui é pintado sozinho, e as cores abaixo são
# lidas de `config.lib.stylix.colors` e escritas explicitamente. Trocar
# `lcars.system.theme.scheme` continua repintando tudo — só não é automático,
# é este arquivo que faz.
{
  config,
  osConfig,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cores = config.lib.stylix.colors;
  rice = osConfig.lcars.system.theme.rice;
  animacoes = osConfig.lcars.system.theme.animations;
  teclado = osConfig.lcars.system.hardware.keyboard;

  mod = "Mod";

  # CAMINHO ABSOLUTO, e não o nome do programa.
  #
  # O niri resolve `spawn` no PATH que herdou do gerenciador de sessão do
  # usuário, que não é o do shell interativo. Com nomes soltos os atalhos
  # simplesmente não fazem nada — sem erro na tela, porque o compositor apenas
  # não acha o binário. O próprio nixpkgs comenta o risco em
  # programs/wayland/niri.nix, ao justificar `enableDefaultPath = false`:
  # "breaking spawn actions that rely on it".
  #
  # `getExe` usa o `meta.mainProgram` do pacote, então não há nome de binário
  # escrito à mão aqui.
  exe = lib.getExe;

  terminal = exe pkgs.kitty;
  noctalia = exe config.programs.noctalia.package;

  # O terminal sem o multiplexador. O kitty abre no herdr porque
  # user/app/kitty.nix aponta o `shell` para ele; passar um comando na linha
  # de comando faz o kitty ignorar aquela linha e rodar o que se pediu — aqui,
  # o zsh puro.
  #
  # Não é preferência, é a saída de emergência: o herdr é um binário compilado
  # de um input preso numa tag, e se um `nupdate --inputs` o quebrar, este é o
  # atalho que ainda dá um terminal gráfico para rodar o rollback. Sem ele
  # sobraria o TTY.
  terminalPuro = [
    terminal
    (exe pkgs.zsh)
  ];

  # Painéis do noctalia, por IPC — o shell já está no ar, isto só o chama.
  painel = id: [
    noctalia
    "msg"
    "panel-toggle"
    id
  ];
in
lib.mkIf osConfig.lcars.user.niri.enable {
  wayland.windowManager.niri = {
    enable = true;

    # O pacote aqui NÃO é para instalar o compositor — quem faz isso é o módulo
    # NixOS (system/wm/niri.nix, via programs.niri-glass), e é o mesmo
    # derivation, de modo que não há segunda cópia no store.
    #
    # Ele está aqui pelo `checkConfig`, cujo default é `package != null`. Com o
    # pacote em null a validação não roda, e um erro de KDL só apareceria na
    # tela preta; com ele, `niri validate` roda no build e a configuração
    # inválida nunca chega à máquina.
    #
    # Apontar para o niri-glass e não para o `pkgs.niri` é obrigatório: o
    # KDL abaixo tem o bloco `liquid-glass { ... }`, que o `pkgs.niri` do
    # nixpkgs-unstable não conhece — `niri validate` rodaria contra o
    # binário errado e falharia. O pacote do niri-glass é o fork com os
    # patches no shader (#107).
    package = inputs.niri-glass.packages.${pkgs.stdenv.hostPlatform.system}.niri-glass;

    # false, e não é descuido. As unidades systemd do niri — que é de onde sai
    # o `graphical-session.target` de que o serviço do noctalia depende — já
    # são instaladas pelo módulo NixOS (`systemd.packages = [ cfg.package ]`,
    # nixpkgs, programs/wayland/niri.nix:41). Ligar aqui seria a segunda cópia.
    #
    # E não é só redundância: o módulo do home-manager tem uma assertion de
    # `systemd.enable -> package != null`, então ligar isto com o pacote em
    # null aborta a avaliação com
    # "wayland.windowManager.niri.systemd.enable requires a non-null package".
    # Foi o que aconteceu na primeira tentativa.
    systemd.enable = false;

    settings = {
      # --- entrada -------------------------------------------------------
      # O layout precisa ser declarado AQUI, e isto contraria o que este
      # arquivo dizia antes.
      #
      # `services.xserver.xkb` configura o servidor X e o console; o NixOS não
      # exporta XKB_DEFAULT_LAYOUT nem as irmãs para sessões Wayland
      # (procurado em nixos/modules/ — não existe). Um compositor Wayland
      # nativo não tem de onde herdar, e sem estas linhas o niri usa "us" puro,
      # ignorando o que você configurou.
      #
      # A fonte de verdade continua sendo uma só: os valores vêm de
      # lcars.system.hardware.keyboard, o mesmo módulo que serve o console e o
      # SDDM. O que muda é que agora eles chegam ao compositor.
      input = {
        keyboard.xkb = {
          inherit (teclado) layout;
        }
        # Variante vazia não é o mesmo que variante ausente: o xkb trata ""
        # como nome de variante e não encontra nada.
        // lib.optionalAttrs (teclado.variant != "") { inherit (teclado) variant; };

        focus-follows-mouse = { };
        touchpad = {
          tap = { };
          natural-scroll = { };
        };
      };

      # --- forma ---------------------------------------------------------
      layout = {
        gaps = if rice then 9 else 4;

        # O anel de foco. Com `rice`, o gradiente base0D → base0A — que no
        # simbiot-dark é o ciano do logo indo ao lime, herdeiro direto da borda
        # que o Hyprland tinha. Sem `rice`, uma cor sólida, ainda do esquema.
        #
        # Em qualquer esquema continua sendo "primária → destaque": não há cor
        # fixa escrita aqui.
        focus-ring = {
          width = if rice then 2 else 1;
          inactive-color = "#${cores.base02}";
        }
        // (
          if rice then
            {
              active-gradient._props = {
                from = "#${cores.base0D}";
                to = "#${cores.base0A}";
                angle = 45;
              };
            }
          else
            { active-color = "#${cores.base0D}"; }
        );

        # Larguras predefinidas, cicladas por Mod+R. É o que substitui o
        # "redimensionar arrastando" num layout que rola: você escolhe entre
        # frações da tela em vez de mirar a borda.
        preset-column-widths._children = [
          { proportion = 0.33333; }
          { proportion = 0.5; }
          { proportion = 0.66667; }
        ];
        default-column-width.proportion = 0.5;
      };

      # Sem decoração do cliente: quem desenha a moldura é o compositor, e é
      # assim que o anel de foco acima fica visível em todos os aplicativos.
      prefer-no-csd = { };

      # Transições do compositor. `off` não tira funcionalidade: a janela
      # aparece no lugar em vez de deslizar até ele, e o workspace troca
      # instantaneamente. Numa GPU fraca é o que se sente.
      animations = lib.optionalAttrs (!animacoes) { off = { }; };

      # --- o que sobe com a sessão ---------------------------------------
      # Vazio, e é para continuar assim.
      #
      # O noctalia sobe por unidade systemd
      # (`programs.noctalia.systemd.enable`, em user/wm/noctalia.nix), que
      # reinicia o que cai e responde a `systemctl --user status noctalia`.
      # A regra está no CLAUDE.md e já custou três entregas: antes de pôr
      # qualquer coisa em `spawn-at-startup`, procure um serviço.
      spawn-at-startup._children = [ ];

      # --- atalhos --------------------------------------------------------
      binds = {
        "${mod}+Return".spawn = [ terminal ];
        "${mod}+Shift+Return".spawn = terminalPuro;
        "${mod}+Q".close-window = { };

        # Painéis do noctalia — os mesmos do Hyprland, mesma memória de dedos.
        "${mod}+D".spawn = painel "launcher";
        "${mod}+C".spawn = painel "control-center";
        "${mod}+V".spawn = painel "clipboard";
        "${mod}+Escape".spawn = painel "session";
        "${mod}+N".spawn = [
          noctalia
          "msg"
          "panel-open"
          "control-center"
          "notifications"
        ];

        # Foco: H e L entre colunas, J e K dentro da coluna.
        "${mod}+H".focus-column-left = { };
        "${mod}+L".focus-column-right = { };
        "${mod}+J".focus-window-down = { };
        "${mod}+K".focus-window-up = { };
        "${mod}+Left".focus-column-left = { };
        "${mod}+Right".focus-column-right = { };
        "${mod}+Down".focus-window-down = { };
        "${mod}+Up".focus-window-up = { };

        # Mover a coluna pela fita.
        "${mod}+Shift+H".move-column-left = { };
        "${mod}+Shift+L".move-column-right = { };
        "${mod}+Shift+J".move-window-down = { };
        "${mod}+Shift+K".move-window-up = { };

        # Juntar a janela ao lado nesta coluna, ou tirá-la para uma própria.
        # Não há equivalente no Hyprland: é o que faz uma coluna ter mais de
        # uma janela empilhada.
        "${mod}+comma".consume-or-expel-window-left = { };
        "${mod}+period".consume-or-expel-window-right = { };

        # Tamanho.
        "${mod}+R".switch-preset-column-width = { };
        "${mod}+F".maximize-column = { };
        "${mod}+Shift+F".fullscreen-window = { };
        "${mod}+W".toggle-column-tabbed-display = { };

        # Workspaces: pilha vertical, dinâmica. Os números continuam valendo.
        "${mod}+Page_Down".focus-workspace-down = { };
        "${mod}+Page_Up".focus-workspace-up = { };
        "${mod}+Shift+Page_Down".move-column-to-workspace-down = { };
        "${mod}+Shift+Page_Up".move-column-to-workspace-up = { };

        # Captura de tela — nativa do niri, com seleção de região. É por isso
        # que grim e slurp saíram do system/wm/niri.nix.
        "${mod}+Shift+S".screenshot = { };
        "Print".screenshot-screen = { };
        "${mod}+Print".screenshot-window = { };

        "${mod}+Shift+E".quit = { };

        # Mídia e brilho. `allow-when-locked` porque volume e brilho fazem
        # sentido com a tela bloqueada — é o que o teclado do notebook espera.
        "XF86AudioRaiseVolume" = {
          _props.allow-when-locked = true;
          spawn = [
            (exe pkgs.pamixer)
            "-i"
            "5"
          ];
        };
        "XF86AudioLowerVolume" = {
          _props.allow-when-locked = true;
          spawn = [
            (exe pkgs.pamixer)
            "-d"
            "5"
          ];
        };
        "XF86AudioMute" = {
          _props.allow-when-locked = true;
          spawn = [
            (exe pkgs.pamixer)
            "-t"
          ];
        };
        "XF86AudioPlay" = {
          _props.allow-when-locked = true;
          spawn = [
            (exe pkgs.playerctl)
            "play-pause"
          ];
        };
        "XF86AudioNext" = {
          _props.allow-when-locked = true;
          spawn = [
            (exe pkgs.playerctl)
            "next"
          ];
        };
        "XF86AudioPrev" = {
          _props.allow-when-locked = true;
          spawn = [
            (exe pkgs.playerctl)
            "previous"
          ];
        };
        "XF86MonBrightnessUp" = {
          _props.allow-when-locked = true;
          spawn = [
            (exe pkgs.brightnessctl)
            "set"
            "5%+"
          ];
        };
        "XF86MonBrightnessDown" = {
          _props.allow-when-locked = true;
          spawn = [
            (exe pkgs.brightnessctl)
            "set"
            "5%-"
          ];
        };
      }
      # Workspaces 1–9: Mod troca, Mod+Shift leva a coluna junto. Gerados em
      # laço pelo mesmo motivo de antes — dezoito linhas escritas à mão são
      # dezoito chances de errar um número.
      // builtins.listToAttrs (
        builtins.concatLists (
          builtins.genList (
            i:
            let
              n = toString (i + 1);
            in
            [
              {
                name = "${mod}+${n}";
                value.focus-workspace._args = [ (i + 1) ];
              }
              {
                name = "${mod}+Shift+${n}";
                value.move-column-to-workspace._args = [ (i + 1) ];
              }
            ]
          ) 9
        )
      );

      # --- efeito de vidro fosco (niri-glass) ------------------------------
      # O bloco `liquid-glass` é o que o fork do niri-glass adiciona ao
      # shader do compositor: faz a janela amostrar o wallpaper e mostrá-lo
      # com efeito de vidro fosco. Só faz sentido aqui — o `pkgs.niri` do
      # nixpkgs não reconhece o nó e abortaria o `niri validate` (#107).
      #
      # O preset é o mais sutil que o README do Niri-glass documenta:
      # `background-effect { blur true xray true liquid-glass { saturation
      # 1.0 } }` com todos os outros parâmetros do liquid-glass em zero
      # (refraction, glow, edge-lighting, fringing, vibrancy, adaptive-dim,
      # adaptive-boost, physical-refraction, lens-distortion). Janela
      # desfoca o que está atrás e deixa o wallpaper passar com nitidez
      # — "só um detalhe para ver o desenho do wallpaper", como pedido.
      window-rule._children = [
        {
          match._props = {
            app-id = ".*";
          };
          background-effect = {
            blur = true;
            xray = true;
            liquid-glass = {
              saturation = 1.0;
            };
          };
        }
      ];
    };
  };

  # Nem o terminal nem o shell estão aqui, e é deliberado: quem os instala são
  # user/app/kitty.nix e user/wm/noctalia.nix, pelos módulos `programs.*`.
  #
  # Um pacote em `home.packages` fica no PATH sem configuração nenhuma — foi
  # assim que o kitty rodou por várias entregas com fonte e cores de fábrica,
  # enquanto o resto do sistema já usava a paleta.
  #
  # Os atalhos acima continuam funcionando: `getExe` aponta para o caminho no
  # store, que é dependência deste arquivo, e não depende de o pacote estar
  # instalado no perfil.
}
