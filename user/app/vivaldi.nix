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
# A parte do estado interno do navegador que o Vivaldi Sync já cobre —
# bookmarks, abas, histórico, senhas, extensões, reading list, notes — fica
# por conta da conta do usuário. Declarar aqui seria uma segunda fonte de
# verdade que a primeira sobrescreve no próximo login.
#
# O que ESTÁ aqui
# --------------
# O subconjunto do `Preferences` que o Sync NÃO cobre: posição da barra de
# endereço, posição da tab bar, posição do painel lateral, ordem dos botões
# nas toolbars, status bar, densidade da UI, scrollbar, agendamento de tema,
# workspaces, macros (chained commands), retenção de histórico, default
# search engine. Vive em `vivaldi-prefs.json` ao lado deste arquivo, e o
# hook de activation (mais abaixo) faz deep-merge por cima do Preferences que
# o navegador criou — sem sobrescrever o que o Sync grava nem as preferências
# geradas em runtime (cookies, login data, pinned_tabs, account_values etc.).
#
# Por que deep-merge, e não xdg.configFile
# -----------------------------------------
# `xdg.configFile."vivaldi/Default/Preferences".source = ...` cria um symlink
# para o JSON gerenciado: o navegador não conseguiria gravar nada nele
# (qualquer salvamento de preferência falha, sync de preferências futuras
# também). Por isso o Preferences tem que continuar sendo um arquivo comum
# do usuário; o Nix só entra como camada por cima, no momento do
# `home-manager switch`.
#
# O trade-off é direto: se o usuário ajusta uma chave gerenciada pela GUI
# (tema, posição da tab bar, etc.), ela volta ao valor do repositório — antes
# no switch seguinte, agora assim que o navegador for fechado, porque é aí que
# ele grava o Preferences e a unidade `path` acorda. É a mesma promessa de
# qualquer preferência gerenciada — você ganha em reprodutibilidade entre
# máquinas, perde em ajustes improvisados pela GUI. Para mudar de verdade,
# edite `vivaldi-prefs.json`.
#
# Máquina nova, e por que a ativação não basta
# -------------------------------------------
# Numa máquina nova o Preferences não existe na hora da ativação — ele nasce
# no primeiro boot do Vivaldi. A ordem é sempre a mesma e sempre foi contra
# nós: o rebuild ativa o Home Manager (não há o que fazer), o usuário abre o
# navegador (o arquivo nasce, cru), e nada mais dispara o merge. O navegador
# ficava sem as preferências até alguém lembrar de rodar `nupdate` outra vez
# (#158, visto na instalação limpa da #157).
#
# Por isso o merge tem duas entradas: a ativação do Home Manager e uma unidade
# `path` do systemd do usuário, que espera o arquivo aparecer ou mudar. As duas
# chamam o mesmo executável.
#
# Ele sai sem escrever em três situações, e nenhuma é erro: o perfil ainda não
# existe, o navegador está aberto (ele reescreve o Preferences inteiro ao sair,
# e essa escrita dispara a unidade de novo), ou o conteúdo já é o desejado.
#
# O stylix também não o alcança: não há alvo para Vivaldi, e a paleta de
# interface é escolhida na Configuração dele.
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

let
  # O subconjunto do `~/.config/vivaldi/Default/Preferences` que o Vivaldi
  # Sync não cobre e que queremos replicar entre máquinas. O arquivo é
  # lido e re-emitido via `writeText` para que o activation script tenha
  # um path estável no /nix/store e a checagem do `check.sh --eval` não
  # dependa do estado do filesystem do usuário.
  managedPrefsPath = pkgs.writeText "vivaldi-managed-prefs.json" (
    builtins.readFile ./vivaldi-prefs.json
  );

  # O merge em si, num executável — porque duas coisas o chamam: a ativação do
  # Home Manager e a unidade `path` que espera o Preferences aparecer (#158).
  # Enquanto ele existia só dentro do activation script, uma máquina nova
  # ficava sem as preferências até alguém lembrar de rodar o switch de novo.
  aplicarPrefs = pkgs.writeShellApplication {
    name = "lcars-vivaldi-prefs";
    runtimeInputs = with pkgs; [
      jq
      procps
      coreutils
    ];
    text = ''
      prefs="$HOME/.config/vivaldi/Default/Preferences"
      managed=${managedPrefsPath}

      if [ ! -f "$prefs" ]; then
        echo "lcars/vivaldi: o perfil ainda não existe. Abra o Vivaldi uma vez;"
        echo "               as preferências entram sozinhas quando você fechá-lo."
        exit 0
      fi

      # Com o navegador aberto, não adianta escrever: ele mantém o Preferences
      # em memória e o reescreve inteiro ao sair, jogando fora o que
      # puséssemos agora. Sair aqui não perde nada — essa escrita final é
      # justamente o que dispara a unidade `path` de novo.
      if pgrep -u "$(id -u)" -x vivaldi-bin > /dev/null 2>&1; then
        echo "lcars/vivaldi: navegador aberto — aplico quando você fechá-lo."
        exit 0
      fi

      tmp="$(mktemp -d)"
      trap 'rm -rf "$tmp"' EXIT

      # Deep-merge com override: para objetos, recursivamente; para arrays e
      # escalares, substituição.
      if ! jq -s '.[0] * .[1]' "$prefs" "$managed" > "$tmp/novo"; then
        echo "lcars/vivaldi: falha no merge com jq — Preferences mantido como estava" >&2
        exit 1
      fi

      # Comparação CANÔNICA, não byte a byte: o jq reindenta o arquivo, então
      # o resultado nunca sai igual ao que o Chromium escreve (compacto).
      # Sem isto o merge reescreveria o arquivo em toda execução — e como é
      # justamente a escrita que dispara a unidade `path`, isso seria um laço
      # que não para.
      jq -S -c . "$prefs" > "$tmp/antes"
      jq -S -c . "$tmp/novo" > "$tmp/depois"
      if cmp -s "$tmp/antes" "$tmp/depois"; then
        echo "lcars/vivaldi: preferências já estavam aplicadas"
        exit 0
      fi

      # `cat >`, e não `mv`: mantém o inode, o dono e as permissões do arquivo
      # que o navegador criou.
      cat "$tmp/novo" > "$prefs"
      echo "lcars/vivaldi: preferências gerenciadas aplicadas"
    '';
  };
in
lib.mkIf osConfig.lcars.user.vivaldi.enable {
  programs.vivaldi = {
    enable = true;

    package = pkgs.vivaldi.override {
      # H.264, AAC e afins, do `vivaldi-ffmpeg-codecs` (LGPL 2.1, livre).
      proprietaryCodecs = true;

      # O CDM da Google, que destrava streaming com DRM. É unfree, como o
      # próprio Vivaldi — os dois avaliam porque system/unfree.nix liga o
      # `allowUnfree` global.
      enableWidevine = true;
    };

    commandLineArgs = [
      # Wayland nativo quando houver um compositor, X11 quando não houver — é
      # o que `auto` decide em tempo de execução. Sem esta flag o Chromium
      # escolhe X11 sempre, e sob o niri isso significa XWayland.
      "--ozone-platform-hint=auto"
    ];

    # "1Password – Password Manager", da Chrome Web Store. O id é público —
    # é o mesmo da URL da loja e da página oficial de deploy do 1Password —
    # e é só isso que esta linha declara: um manifest em
    # ~/.config/vivaldi/External Extensions/ apontando pro update URL da
    # loja, que faz o Vivaldi buscar e instalar a extensão sozinho. Nenhuma
    # senha, nenhuma conta, nenhum token passa por aqui.
    #
    # O pareamento da extensão com o app do 1Password não é nativeMessagingHosts
    # — o 1Password não fala esse protocolo. A ponte é o wrapper setgid
    # 1Password-BrowserSupport, que `programs._1password-gui` já cria em
    # system/app/1password/default.nix. Depois do rebuild, só falta clicar em
    # "conectar" dentro da extensão — interativo, como o login do Vivaldi Sync.
    extensions = [
      { id = "aeblfdkhhhdcdjpifhhbdiojplfjncoa"; }
    ];
  };

  # Duas entradas para o mesmo merge:
  #
  #   1. a ativação do Home Manager, que cobre a máquina onde o Vivaldi já
  #      rodou alguma vez;
  #   2. a unidade `path` abaixo, que cobre a máquina nova — onde, na hora da
  #      ativação, o Preferences ainda não existe.
  #
  # O `jq -s '.[0] * .[1]' existing managed` faz deep-merge com override:
  # para objetos, recursivamente; para arrays e escalares, substituição. As
  # chaves gerenciadas (toolbars, tema, posições) sobrescrevem o que estiver
  # lá; o resto — pinned_tabs, account_values, account_tracker_*, cookies,
  # login data, sessões, o que o Sync grava — fica intacto porque não está
  # no JSON gerenciado.
  #
  # O Vivaldi Sync usa o `account_values` para guardar preferências que ELE
  # sincroniza — não toca em nada fora dali. Por isso é seguro sobrescrever
  # as outras chaves a partir do Nix sem brigar com o Sync.
  home.activation.vivaldiPrefs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe aplicarPrefs} || true
  '';

  # O que faltava numa instalação limpa (#158). A ordem numa máquina nova é
  # sempre a mesma: o rebuild ativa o Home Manager (Preferences não existe),
  # o usuário abre o Vivaldi pela primeira vez (Preferences nasce, cru), e
  # nada mais dispara o merge. Esta unidade fecha esse buraco — quando o
  # arquivo aparece, ou muda, o serviço roda.
  #
  # `PathChanged` e não `PathExists`: `PathExists` continua verdadeiro depois
  # que o serviço termina, e o systemd o reativa em seguida, para sempre.
  # `PathChanged` dispara na escrita, e o próprio script não reescreve quando
  # não há o que mudar — é o que impede o laço.
  #
  # Com o arquivo ainda inexistente, o systemd observa o diretório ancestral
  # mais próximo que existir, então isto funciona antes do primeiro boot do
  # navegador.
  systemd.user.services.vivaldi-prefs = {
    Unit.Description = "Aplica as preferências gerenciadas do Vivaldi";
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe aplicarPrefs;
    };
  };

  systemd.user.paths.vivaldi-prefs = {
    Unit.Description = "Espera o Preferences do Vivaldi aparecer ou mudar";
    Path = {
      PathChanged = "%h/.config/vivaldi/Default/Preferences";
      Unit = "vivaldi-prefs.service";
    };
    Install.WantedBy = [ "default.target" ];
  };

  # Quem abre um link no sistema. Até a #60 isto não era declarado em lugar
  # nenhum: o `xdg-open` não achava associação, caía no fallback da variável
  # `$BROWSER` e acertava o Vivaldi por tabela. Funcionava, e ia continuar
  # funcionando até o dia em que alguma coisa no ambiente mudasse — e aí o
  # sintoma seria um clique que não abre nada, sem erro em lugar nenhum.
  #
  # O nome do arquivo é `vivaldi-stable.desktop`, e não `vivaldi.desktop`: o
  # pacote vem do .deb oficial, e o nixpkgs reescreve o CONTEÚDO do desktop
  # file (o caminho do binário e o WMClass) sem renomeá-lo.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "vivaldi-stable.desktop";
      "x-scheme-handler/http" = "vivaldi-stable.desktop";
      "x-scheme-handler/https" = "vivaldi-stable.desktop";
      "x-scheme-handler/about" = "vivaldi-stable.desktop";
      "x-scheme-handler/unknown" = "vivaldi-stable.desktop";
    };
  };
}
