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
# (tema, posição da tab bar, etc.), o próximo switch reverte. É a mesma
# promessa de qualquer preferência gerenciada — você ganha em reprodutibilidade
# entre máquinas, perde em ajustes improvisados pela GUI.
#
# Quando o hook não roda
# ----------------------
# Em uma máquina nova, o Preferences ainda não existe — ele nasce no primeiro
# boot do Vivaldi. O hook loga um aviso e sai sem fazer nada. Depois de
# abrir o navegador uma vez e logar no Sync, basta rodar `home-manager switch`
# de novo: o hook encontra o arquivo e aplica o merge.
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
  jq = lib.getExe pkgs.jq;
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

  # Deep-merge das preferências gerenciadas (lidas de `vivaldi-prefs.json`)
  # no Preferences que o navegador mantém em
  # `~/.config/vivaldi/Default/Preferences`. Roda em `home-manager switch`,
  # depois do `writeBoundary` (qualquer escrita de arquivo do HM já
  # aconteceu).
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
    prefs="$HOME/.config/vivaldi/Default/Preferences"
    managed=${managedPrefsPath}

    if [ ! -f "$prefs" ]; then
      echo "lcars/vivaldi: $prefs ainda não existe — abra o Vivaldi uma vez para ele criar o perfil, depois rode \`home-manager switch\` de novo."
      exit 0
    fi

    tmp="$prefs.tmp"
    if ! ${jq} -s '.[0] * .[1]' "$prefs" "$managed" > "$tmp"; then
      echo "lcars/vivaldi: falha no merge com jq — Preferences mantido como estava" >&2
      rm -f "$tmp"
      exit 0
    fi
    mv "$tmp" "$prefs"
    echo "lcars/vivaldi: preferências gerenciadas aplicadas"
  '';

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
