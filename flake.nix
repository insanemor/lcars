{
  description = "lcars — flake NixOS forkável, multi-host, com dotfiles e secrets integrados ao 1Password";

  inputs = {
    # Núcleo
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Home manager (dotfiles a nível de usuário)
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Segredos vindos do 1Password para serviços NixOS / systemd
    opnix = {
      url = "github:brizzbuzz/opnix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # SOPS opcional — útil para secrets necessários antes de o 1Password subir
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Tema: um esquema base16 pinta Hyprland, noctalia, terminal, GTK, Qt,
    # Plasma e o console TTY de uma vez. É o que evita fiar cor programa por
    # programa — veja system/theme/.
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Shell de desktop: barra, launcher, notificações, tela de bloqueio, dock e
    # centro de controle numa peça só, com GUI de ajuste. Veja user/wm/noctalia.nix.
    #
    # O flake dele declara nixpkgs por URL de tarball, não por github:, então
    # `follows` não se aplica — ele traz o próprio. É duplicação de árvore no
    # lock, mas é o que o upstream oferece.
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
    };

    # Multiplexador de terminal — workspaces, painéis e sessões que sobrevivem
    # ao fechar do terminal, no lugar do tmux. Veja user/app/herdr.nix.
    #
    # Vem de fora do nixpkgs porque lá ele não existe: em agosto de 2026 não há
    # `pkgs.herdr`. O upstream mantém o próprio flake, com
    # `packages.<system>.default`, e é ele que usamos.
    #
    # O preço é a compilação: é um binário Rust grande, que ainda constrói o
    # libghostty-vt com o zig, e não há cache binário público. O primeiro
    # rebuild depois de ligar a flag — e cada vez que esta linha subir de
    # versão — leva alguns minutos de CPU. Se um dia entrar no nixpkgs, este
    # input sai e o módulo passa a usar `pkgs.herdr`.
    #
    # PRESO NUMA TAG, e é o único input assim. Os outros seguem o branch
    # principal do upstream, o que é barato quando o pacote vem pronto de um
    # cache binário. Aqui não vem: `nix flake update` sem tag traria qualquer
    # commit que estivesse no topo do master naquele dia — código entre
    # releases, e uma recompilação longa para chegar nele. O upstream também
    # publica pre-releases `preview-*`, que não queremos.
    #
    # Subir de versão é editar a tag aqui e regerar o lock; é para ser um ato
    # deliberado. A documentação oficial recomenda a forma
    # `github:herdrdev/herdr/v0.8.0` (https://herdr.dev/docs/install/), e ela
    # seria a natural aqui — mas `github:` baixa um **tarball**, e o nix
    # resolve a tag para o commit antes de pedi-lo: o que ele busca é o archive
    # por rev, que o codeload responde com 429 de forma consistente. Pelo mesmo
    # endpoint, o archive da tag responde 200 — a diferença é o rev.
    #
    # Daí o `git+https`: pelo protocolo git o fetch passa, e `ref=refs/tags/…`
    # prende na mesma versão que a doc indica. `shallow=1` dispensa o
    # histórico, que aqui não serve para nada.
    herdr = {
      url = "git+https://github.com/herdrdev/herdr?ref=refs/tags/v0.8.0&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Plugin browser do herdr — um Chromium de verdade desenhado dentro de um
    # painel, dirigível por CDP. É o que `prefix + b` abre (veja
    # user/app/herdr.nix).
    #
    # `flake = false`: o repositório é TypeScript rodado pelo bun na hora, sem
    # flake e sem build — o que precisamos dele é a árvore de arquivos, para
    # apontar `herdr plugin link` ao caminho no store.
    #
    # Por que ele está aqui e não sai de um `herdr plugin install`: aquele
    # comando baixa por conta própria em tempo de execução, para um diretório
    # que o Nix não gerencia, e obriga um passo manual por máquina. Pelo input,
    # a versão fica no flake.lock como a de qualquer outra dependência (#58).
    #
    # PRESO NUM COMMIT, e não numa tag, porque o upstream não publica tags. Um
    # `nix flake update` traria o topo do main sem revisão nenhuma; subir de
    # versão aqui é ato deliberado, como no input do herdr.
    #
    # `git+https` pelo mesmo motivo documentado acima: `github:` resolve para
    # um archive por rev no codeload, que responde 429 com frequência.
    herdr-browser = {
      url = "git+https://github.com/ogulcancelik/herdr-browser?ref=main&rev=be6888b71cf4eb5939ee79a746bd1a1c22ade046";
      flake = false;
    };

    # Plugin herdr-nvim — uma sidebar persistente de nvim dentro de um
    # painel do herdr, com file picker ancorado nos arquivos que o agente
    # tocou. Veja user/app/nvim.nix.
    #
    # É, ao mesmo tempo, plugin do herdr e do nvim:
    #
    #   - metade herdr: a raiz deste repo traz um herdr-plugin.toml com
    #     as ações `chmarax.herdr-nvim.toggle` (sidebar) e
    #     `.pick-file` (file picker). O plugin é linkado ao herdr na
    #     ativação do Home Manager, com a mesma receita do herdr-browser.
    #
    #   - metade nvim: o código sob lua/herdr-nvim/ é carregado pelo nvim
    #     em runtimepath. Por ora o init.lua escrito pelo HM aponta para
    #     a árvore do store — sem canal de plugins automático.
    #     Auto-update via lazy.nvim é entrega à parte.
    #
    # `flake = false`: o upstream não publica flake; o que precisamos é do
    # diretório em si, e da árvore Lua dentro dele.
    #
    # PRESO NUM COMMIT (`rev=`), porque o upstream não publica tags e o
    # main recebe PRs a cada release. A revisão é ato deliberado —
    # `nix flake update herdr-nvim` move, e o `nupdate` traz.
    herdr-nvim = {
      url = "git+https://github.com/ChmaraX/herdr-nvim?ref=main&rev=40aadeab3cef3702ef5e05069181c7168084794f";
      flake = false;
    };

    # Plugin herdr-usage-bar — medidores de uso na sidebar do herdr
    # ($provider/$limit/$context), sempre visíveis, não só acima de um
    # threshold. Veja user/app/herdr.nix. Substituiu o herdr-ctx (#79):
    # aquele só mostrava o token acima de 75% de uso: por design, não em
    # tempo real.
    #
    # `flake = false`: diferente do herdr-ctx (TypeScript/bun) e do
    # herdr-file-viewer/herdr-reviewr (Rust), este é Go — o que a árvore
    # fornece é o source, para `pkgs.buildGoModule` (veja herdr.nix).
    #
    # PRESO NUMA TAG: o upstream publica release por tag (v0.1.1).
    herdr-usage-bar = {
      url = "git+https://github.com/silverwolfdoc/herdr-usage-bar?ref=refs/tags/v0.1.1&shallow=1";
      flake = false;
    };

    # Plugin herdr-file-viewer — visualizador de arquivos read-only,
    # git-aware, num painel do herdr. Veja user/app/herdr.nix.
    #
    # `flake = false`: diferente do browser/nvim, este é um binário Rust — o
    # que a árvore fornece é o source, para `rustPlatform.buildRustPackage`
    # (veja herdr.nix), mais o herdr-plugin.toml e os scripts de lançamento
    # que `plugin link` aponta.
    #
    # PRESO NUMA TAG: o upstream publica release por tag (v1.16.0), e a versão
    # do Cargo.toml bate com ela — subir de versão aqui é ato deliberado.
    herdr-file-viewer = {
      url = "git+https://github.com/smarzban/herdr-file-viewer?ref=refs/tags/v1.16.0&shallow=1";
      flake = false;
    };

    # Plugin herdr-reviewr — sidebar de code review: comenta no diff de um
    # agente e manda de volta pro chat. Veja user/app/herdr.nix.
    #
    # `flake = false`, mesma razão do herdr-file-viewer: binário Rust,
    # buildado por rustPlatform.buildRustPackage a partir deste source.
    #
    # PRESO NUMA TAG (v0.32.1), pela mesma razão do herdr-file-viewer.
    herdr-reviewr = {
      url = "git+https://github.com/persiyanov/herdr-reviewr?ref=refs/tags/v0.32.1&shallow=1";
      flake = false;
    };

    # ghzinga — TUI em Rust para abrir issue/PR do GitHub num painel do
    # herdr. Veja user/app/herdr.nix.
    #
    # `flake = false`: o repositório inteiro vira o source do
    # buildRustPackage (binário `gzg`, que entra no PATH) E, ao mesmo tempo,
    # fornece o subdiretório plugins/herdr/ — só um herdr-plugin.toml que
    # chama `gzg` pelo nome — que é o que `plugin link` aponta. Um input só
    # serve às duas metades.
    #
    # PRESO NUMA TAG (v0.5.0), mesma versão do Cargo.toml.
    ghzinga = {
      url = "git+https://github.com/osolmaz/ghzinga?ref=refs/tags/v0.5.0&shallow=1";
      flake = false;
    };

    # Plugin herdr-automatic-rename — nomeia abas pelo programa em foreground
    # e numera workspaces/abas/agentes com o dígito do jump-key (1-9). Veja
    # user/app/herdr.nix.
    #
    # `flake = false`: bash puro, sem build — mesma árvore-de-source direta
    # do herdr-browser/herdr-nvim. A diferença é que este também precisa de
    # um hook fonteado no zsh (shell/hook.zsh) — ver user/shell/zsh.nix.
    #
    # PRESO NUMA TAG (v0.7.0), que o upstream publica.
    herdr-automatic-rename = {
      url = "git+https://github.com/qu8n/herdr-automatic-rename?ref=refs/tags/v0.7.0&shallow=1";
      flake = false;
    };

    # Plugin herdr-bar — Cmd+K: busca fuzzy por aba/agente num popup. Veja
    # user/app/herdr.nix.
    #
    # `flake = false`: Python3 stdlib puro, sem build nem dependência —
    # `python3` já é pacote global do sistema (system/core/default.nix).
    #
    # PRESO NUMA TAG (v0.2.1), que o upstream publica.
    herdr-bar = {
      url = "git+https://github.com/jeffarese/herdr-bar?ref=refs/tags/v0.2.1&shallow=1";
      flake = false;
    };

    # Plugin herdr-annotations — anota texto selecionado no terminal, num
    # popup local. Veja user/app/herdr.nix.
    #
    # `flake = false`: diferente dos outros três — Node/npm, com uma
    # dependência (@inquirer/core) que `pkgs.buildNpmPackage` resolve
    # (npmDepsHash pinado, descoberto por tentativa com nix build de
    # verdade).
    #
    # PRESO NUM COMMIT, porque o upstream não publica tags.
    herdr-annotations = {
      url = "git+https://github.com/jagzmz/herdr-annotations?ref=main&rev=a408ebdeebd5a79fb96a6acc8314b32f2de0c85f";
      flake = false;
    };

    # Plugin herdr-notes — um Markdown permanente por workspace, editável
    # fora do herdr em qualquer editor. Veja user/app/herdr.nix. Diferente
    # do herdr-annotations (#81): aquele é um buffer de coleta que se apaga
    # ao colar, este é documento de verdade — os dois ficam lado a lado.
    #
    # `flake = false`: Go, mesmo toolchain do herdr-usage-bar
    # (rustPlatform.buildRustPackage não serve aqui) — o source vira input
    # pro `pkgs.buildGoModule` em herdr.nix.
    #
    # PRESO NUMA TAG (v0.2.0), que o upstream publica.
    herdr-notes = {
      url = "git+https://github.com/cyperx84/herdr-notes?ref=refs/tags/v0.2.0&shallow=1";
      flake = false;
    };

    # Plugin herdr-yazi — abre o yazi (gerenciador de arquivos TUI) num
    # painel do herdr, com o diretório do painel focado já como cwd. Veja
    # user/app/herdr.nix.
    #
    # `flake = false`: bash + `node -e` puros, sem build — mesma árvore-de-
    # source direta do herdr-automatic-rename / herdr-bar / herdr-browser.
    # O `plugin link` aponta direto pro input (read-only, nada escreve ali):
    # o `[[build]]` do manifesto (que tenta `brew install yazi` no macOS) é
    # pulado pelo link, e no Linux o `yazi` entra via `programs.yazi` no
    # módulo do Home Manager (user/app/yazi.nix).
    #
    # PRESO NUM COMMIT (HEAD `54aa4e6`, v1.1.0): o upstream não publica tags
    # — `nix flake update herdr-yazi` move, o `nupdate` traz. O alvo da
    # entrega era `deaddaac` (v1.0.0), mas o PR #1 do upstream ("feat: add
    # Linux support") já entrou depois da issue #88, e `platforms` no
    # manifesto já vem com `["linux", "macos"]` de fábrica — sem o
    # `substituteInPlace` que a issue planejava. HEAD carrega também a
    # licença MIT que o autor adicionou em `54aa4e6` (sem ela o repo seria
    # "todos os direitos reservados" por padrão, e os PRs externos
    # mergeados ficariam em status ambíguo).
    herdr-yazi = {
      url = "git+https://github.com/speardragon/herdr-yazi?ref=main&rev=54aa4e6dff480189630fa3593146cdcc2768ade9";
      flake = false;
    };

    # Plugin herdr-telegram-plugin — cada pane do herdr vira um tópico de
    # fórum num grupo do Telegram: mensagem no tópico é entrada de teclado no
    # pane, saída do pane volta como mensagem. Zero LLM. Veja
    # user/app/herdr-telegram.nix (módulo próprio, flag própria — não entra em
    # herdr.nix porque, ao contrário dos demais plugins, este roda um daemon
    # de vida longa via systemd.user.services, e não só uma ação sob demanda).
    #
    # `flake = false`: Node/TypeScript com build real (`tsc`, não
    # `dontNpmBuild` como o herdr-annotations) — `pkgs.buildNpmPackage` roda o
    # build de verdade, com `npmDepsHash` descoberto por `prefetch-npm-deps`
    # (equivalente a "por tentativa" para hash de dependências npm — não
    # precisa de fake-hash e nix build de erro, ele lê o package-lock.json
    # offline). Build confirmado com `nix-build` de verdade antes desta
    # entrega: `npm run build` produz dist/index.js e dist/plugin.js.
    #
    # PRESO NUM COMMIT, porque o upstream não publica tags.
    herdr-telegram-plugin = {
      url = "git+https://github.com/mvallebr/herdr-telegram-plugin?ref=main&rev=af947630fe0b6081247665956b2df5d6922f2eb7";
      flake = false;
    };

    # FUTURO — descomente para ligar um repo privado sobreposto:
    # lcars-private = {
    #   url = "git+ssh://git@github.com/<voce>/lcars-private.git";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      opnix,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;

      # ---------------------------------------------------------------
      # settings.nix — quem você é e o que você gosta. Versionado, e igual em
      # todas as suas máquinas: o que muda de uma para outra (bootloader,
      # disco do GRUB, VM, notebook) mora em machines/<host>/default.nix.
      #
      # Campos avançados (sshKeys, packages, swapFileSize, gpgKey,
      # initialPassword, extraPackages) são opcionais — os módulos que os leem
      # trazem o próprio default.
      # ---------------------------------------------------------------
      settings = import ./settings.nix;

      sys = settings.systemSettings;
      user = settings.userSettings;

      system = sys.system or "x86_64-linux";

      # Fábrica de máquina.
      #
      #   settings.nix   o que você editou — vale como default para tudo
      #   system/        módulos NixOS, opt-in por lcars.<x>.enable
      #   profiles/      presets que ligam essas flags (mkDefault)
      #   machines/      hardware da máquina, e overrides se você tiver várias
      #   user/          módulos do Home Manager, opt-in por lcars.user.<x>
      mkMachine =
        hostName: extras:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit
              inputs
              settings
              sys
              user
              hostName
              ;
          };

          modules = [
            ./system
            # As flags lcars.user.* moram no config do NixOS, não no do Home
            # Manager — é o que permite ao profile ligar os dois lados no
            # mesmo lugar. Veja o cabeçalho do arquivo.
            ./user/options.nix

            # O módulo NixOS do stylix integra sozinho com o Home Manager, o
            # que encaixa aqui: o HM roda como módulo NixOS neste repo. Quem
            # liga e configura é system/theme/, com lcars.system.theme.enable.
            inputs.stylix.nixosModules.stylix
            ./profiles
            ./machines/${hostName}

            home-manager.nixosModules.home-manager

            # O que vem do settings.nix. Tudo com mkDefault, para que
            # machines/<host>/default.nix possa sobrescrever qualquer campo
            # quando o repo servir mais de uma máquina.
            (_: {
              networking.hostName = lib.mkDefault hostName;

              lcars.profile = lib.mkDefault sys.profile;

              # O bootloader NÃO é decidido aqui. Ele depende de a máquina ter
              # bootado em UEFI ou BIOS, então quem o declara é
              # machines/<host>/default.nix. O default da option é
              # "systemd-boot" (veja system/core).

              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                # `inputs` entra aqui porque nem todo programa do usuário vem
                # do nixpkgs: user/app/herdr.nix pega o pacote do flake do
                # próprio herdr. Sem isto, o módulo do Home Manager não teria
                # como alcançar os inputs deste flake.
                extraSpecialArgs = {
                  inherit
                    inputs
                    settings
                    sys
                    user
                    ;
                };
                # O módulo do noctalia declara programs.noctalia no Home
                # Manager; user/wm/noctalia.nix é quem o liga e configura.
                sharedModules = [
                  ./user/personal
                  inputs.noctalia.homeModules.default
                ];

                # Sem isto, o Home Manager ABORTA a ativação ao encontrar um
                # arquivo que ele não criou no caminho de um que quer criar —
                # e o rebuild termina com o sistema atualizado e o $HOME não.
                #
                # Acontece sempre que um módulo novo passa a gerenciar um
                # dotfile que já existia. O caso concreto: o stylix liga
                # `gtk.enable`, e o Plasma já havia escrito ~/.gtkrc-2.0 e
                # ~/.config/gtk-3.0/settings.ini para tematizar apps GTK.
                #
                # Com a extensão definida, o arquivo antigo vira <nome>.hm-bak
                # e a ativação segue.
                #
                # NA SEGUNDA colisão do mesmo arquivo, isto sozinho não basta: o
                # home-manager se recusa a sobrescrever um `.hm-bak` que já
                # existe, e a ativação do usuário falha — com o sistema já
                # trocado pelo rebuild. É o `nupdate` (scripts/update.sh) quem
                # evita isso, renomeando com timestamp qualquer `.hm-bak`
                # encontrado ANTES do rebuild (#37). Quem rodar
                # `home-manager switch` direto, sem passar pelo `nupdate`, não
                # tem essa proteção.
                backupFileExtension = "hm-bak";

                # Tudo do usuário num atributo só. Separar em
                # `users.${x}.imports` e `users.${x}.home` não compila: o Nix
                # funde caminhos ESTÁTICOS ({ a.b = 1; a.c = 2; }), mas não
                # sabe em tempo de parse que duas chaves interpoladas serão
                # iguais — constrói cada uma e acusa
                # "dynamic attribute already defined".
                users.${user.username} = {
                  imports = [ ./user ];
                  home = {
                    inherit (user) username;
                    homeDirectory = "/home/${user.username}";
                    stateVersion = "24.05";
                  };
                };
              };
            })

            inputs.opnix.nixosModules.default
          ]
          ++ extras;
        };

      # Auto-descoberta: todo diretório em machines/ vira uma entrada em
      # nixosConfigurations. `template` fica de fora por ser só o modelo.
      #
      # Com uma máquina só, você nunca mexe aqui: o instalador cria
      # machines/<hostname>/ e o settings.nix aponta para ele.
      machineDirs =
        let
          entries = builtins.readDir ./machines;
        in
        lib.filter (name: entries.${name} == "directory" && name != "template") (
          builtins.attrNames entries
        );

      discoveredMachines = lib.genAttrs machineDirs (name: mkMachine name [ ]);
    in
    {
      # Exposto para quem quiser registrar uma máquina à mão com módulos
      # extras:  meu-pc = self.mkMachine "meu-pc" [ ./algo-extra.nix ];
      inherit mkMachine;

      nixosConfigurations = discoveredMachines;
    }
    // lib.optionalAttrs (inputs ? lcars-private) {
      nixosModules.default = inputs.lcars-private.nixosModules.default;
    };
}
