# system/theme — a cor de tudo, a partir de um lugar só.
#
# Por que isto não fica em system/wm/: tema é transversal. Um esquema base16
# pinta o Hyprland, o noctalia, o terminal, os aplicativos GTK e Qt, o
# Plasma e até o console TTY. Amarrá-lo a um ambiente gráfico faria a cor do
# console depender de qual desktop está ligado, o que não faz sentido.
#
# O caminho alternativo, que este módulo evita
# --------------------------------------------
# O repo que serviu de referência (github.com/Sly-Harvey/NixOS, MIT) fia a cor
# à mão em cada programa: 17 paletas .rasi só para o launcher, CSS próprio para a
# barra, e assim por diante — 218 arquivos em desktop/hyprland. Funciona, mas
# cada programa novo é mais um arquivo de cor para manter em sincronia.
#
# O stylix parte de um esquema base16 e deriva o resto. Trocar de esquema é
# uma linha, e nada fica para trás.
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.lcars.system.theme;
in
{
  options.lcars.system.theme = {
    enable = mkEnableOption "tema unificado via stylix — cor, fontes e papel de parede";

    scheme = mkOption {
      type = types.str;
      default = "simbiot-dark";
      example = "gruvbox-dark-hard";
      description = ''
        Nome de um esquema base16. Procurado primeiro em
        `system/theme/schemes/<nome>.yaml`, neste repositório, e só depois
        entre os que o pacote `base16-schemes` traz.

        Deste repositório:

          simbiot-dark   as cores do site da SimbioIT

        Do pacote, veja a lista com:

          ls ${"$"}{pkgs.base16-schemes}/share/themes/

        Alguns conhecidos: catppuccin-mocha, gruvbox-dark-hard, nord,
        tokyo-night-dark, rose-pine, dracula, solarized-dark.

        Para criar o seu, ponha um .yaml em `schemes/` com as chaves base00
        a base0F e use o nome do arquivo aqui.
      '';
    };

    polarity = mkOption {
      type = types.enum [
        "dark"
        "light"
        "either"
      ];
      default = "dark";
      description = ''
        Diz ao stylix se o esquema é claro ou escuro. Programas que têm modo
        claro e escuro separados usam isto para escolher.
      '';
    };

    wallpaper = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Imagem de fundo. `null` deixa o Hyprland pintar uma cor sólida
        derivada do esquema, sem daemon de papel de parede — é o padrão, e o
        que sobrevive numa VM sem aceleração 3D.

        Apontar para uma imagem liga o hyprpaper, que a renderiza.
      '';
    };

    # A forma é separada da cor de propósito: quem gosta da paleta mas não do
    # visual em ilhas não deve ter que escolher entre os dois.
    rice = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Aplica a geometria do rice ao compositor: anel de foco em gradiente
        e espaçamento maior entre janelas. Desligar deixa o anel sólido e a
        forma discreta, ainda pintada pelo esquema.

        A forma da barra e dos painéis não passa por aqui: quem a define é o
        noctalia, pelo próprio arquivo de configuração (user/wm).

        Inspirado em github.com/Sly-Harvey/NixOS (MIT) — de lá vêm as formas;
        as cores continuam saindo do esquema base16 acima.
      '';
    };

    # Separada da `rice` de propósito: forma e custo de GPU são eixos
    # diferentes. Gradiente e espaçamento são desenhados uma vez; animação e
    # blur redesenham a tela a cada quadro. Quem tem GPU fraca quer desligar o
    # segundo sem abrir mão do primeiro.
    animations = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Animações e efeitos que custam GPU: transições do compositor,
        sombras e blur do shell.

        Desligar não muda funcionalidade nenhuma — as janelas e os painéis
        abrem e fecham igual, só sem a transição. O ganho aparece em máquina
        com GPU fraca, ou numa VM cuja aceleração é traduzida (VirGL), onde
        redesenhar a tela inteira a cada quadro é o gargalo.
      '';
    };

    fonts = {
      size = mkOption {
        type = types.int;
        default = 11;
        description = "Corpo da fonte de interface, em pontos.";
      };

      sansSerif = mkOption {
        type = types.str;
        default = "JetBrainsMono Nerd Font";
        example = "Noto Sans";
        description = ''
          Fonte da interface: menus, diálogos, e a barra e os painéis do
          noctalia — o stylix usa a sansSerif em tudo que não é terminal.

          O padrão é a MESMA Nerd Font do terminal, e isso é uma escolha
          deliberada, não um descuido: ela é monoespaçada, então a interface
          inteira fica com largura fixa. Em troca, os ícones da barra e do
          prompt existem em toda superfície, sem depender de o fontconfig
          achar um fallback.

          Para o visual convencional, use "Noto Sans" — que já está instalado
          por system/wm/default.nix.
        '';
      };

      monospace = mkOption {
        type = types.str;
        default = "JetBrainsMono Nerd Font";
        description = ''
          Fonte do terminal e do editor. Uma Nerd Font por padrão porque a
          a barra e o prompt usam ícones que só existem nelas — com uma fonte
          comum, aparecem quadradinhos vazios.
        '';
      };
    };

    # Opacidade das janelas, propagada para `stylix.opacity` (que cada alvo
    # consulta — kitty usa `terminal`, noctalia usa `desktop`/`popups`/etc.).
    # Default 1.0 mantém o opaco; valores menores deixam o papel de parede
    # aparecer por trás, ao custo de nitidez do texto.
    #
    # Por que mora aqui e não no módulo do kitty: o stylix já escreve
    # `programs.kitty.settings.background_opacity` (modules/kitty/hm.nix), e
    # tentar setar a mesma chave em `user/app/kitty.nix` colide com ele. Setar
    # `stylix.opacity.terminal` é a única entrada que respeita a hierarquia
    # sem precisar podar chaves (#102).
    opacity = {
      terminal = mkOption {
        type = types.float;
        default = 1.0;
        description = ''
          Opacidade do terminal (kitty, foot, wezterm, alacritty, ghostty).
          1.0 = opaco; 0.9 = um pouco para ver o wallpaper; valores abaixo
          de 0.7 começam a atrapalhar a leitura do texto.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    stylix = {
      enable = true;
      inherit (cfg) polarity;
      opacity = {
        terminal = cfg.opacity.terminal;
      };
      # Um esquema do repositório vence o de mesmo nome no pacote. É o que
      # permite `scheme = "simbiot-dark"` conviver com `scheme = "nord"` na
      # mesma option, sem uma segunda para "esquema próprio" — o nome continua
      # sendo a interface inteira.
      #
      # O `pathExists` é resolvido na avaliação, e `./schemes` entra no store
      # junto com o resto do flake, então o arquivo precisa estar rastreado pelo
      # git como qualquer outro.
      base16Scheme =
        let
          proprio = ./schemes + "/${cfg.scheme}.yaml";
        in
        if builtins.pathExists proprio then
          proprio
        else
          "${pkgs.base16-schemes}/share/themes/${cfg.scheme}.yaml";

      # `null` quando você não aponta uma imagem, e isso é deliberado.
      #
      # O stylix exige `image` OU `base16Scheme`; como o esquema está definido
      # acima, a imagem é opcional. E ela não é neutra: definir `image` faz o
      # stylix auto-habilitar o alvo hyprpaper, que sobe um daemon com pilha
      # OpenGL — o mesmo que segfaultava na VM sem GPU (#26).
      #
      # Sem imagem, o fundo do Hyprland é o `misc.background_color` que o
      # próprio stylix deriva de base00: uma cor sólida, pintada pelo
      # compositor, sem processo nenhum a mais. O Plasma usa o papel de parede
      # padrão dele.
      #
      # Antes daqui havia um gradiente gerado com ImageMagick. Saiu: para duas
      # cores quase idênticas (base00 e base01) a diferença para a cor sólida é
      # imperceptível, e não compensava a dependência de build nem a superfície
      # de falha.
      image = cfg.wallpaper;

      fonts = {
        monospace = {
          package = pkgs.nerd-fonts.jetbrains-mono;
          name = cfg.fonts.monospace;
        };
        # O pacote é o mesmo da monospace porque o padrão é a mesma família.
        # Trocar apenas o NOME acima para uma fonte de outra família funciona
        # se ela já estiver instalada — Noto Sans, Liberation e DejaVu estão,
        # por system/wm/default.nix —, mas não puxa pacote novo.
        sansSerif = {
          package = pkgs.nerd-fonts.jetbrains-mono;
          name = cfg.fonts.sansSerif;
        };
        serif = {
          package = pkgs.noto-fonts;
          name = "Noto Serif";
        };
        emoji = {
          package = pkgs.noto-fonts-color-emoji;
          name = "Noto Color Emoji";
        };

        sizes = {
          applications = cfg.fonts.size;
          terminal = cfg.fonts.size;
          desktop = cfg.fonts.size;
          popups = cfg.fonts.size;
        };
      };
    };
  };
}
