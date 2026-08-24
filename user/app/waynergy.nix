# waynergy.nix — compartilhar teclado e mouse com outras máquinas, com esta
# entrando como CLIENTE de um servidor Synergy que roda em outro computador.
#
# Opt-in por `lcars.user.waynergy.enable`. A flag vem do config do NixOS (veja
# user/options.nix), e o lugar de ligá-la é machines/<host>/default.nix, não um
# profile: `host` é o endereço do servidor na SUA rede, e profile vale para
# todo clone do repositório.
#
# POR QUE waynergy, E NÃO O PRÓPRIO SYNERGY
# -----------------------------------------
# Não é preferência — o Synergy não tem como funcionar aqui, nos dois papéis, e
# isto foi verificado antes de o módulo existir (issue #146):
#
#   1. O pacote `synergy` do nixpkgs é a versão 1.14.6.19-stable, X11-pura. As
#      buildInputs são libx11/libxi/libxtst/libxrandr/libxinerama/libxkbfile, e
#      não há libei, libportal nem wayland. O upstream só tem MSWindows*, OSX*
#      e XWindows* em src/lib/platform. A captura é XGrabKeyboard/XGrabPointer
#      e a injeção é XTestFake*Event: nada disso atravessa o compositor.
#
#   2. XWayland não salva. Um grab dentro do XWayland só enxerga eventos que o
#      compositor já entregou ao domínio X — quando o cursor está sobre a barra
#      do noctalia ou qualquer janela Wayland, o X nem sabe que ele existe. E o
#      XTEST injeta só em janelas X11: não move o cursor do niri. Agrava que
#      este repo usa xwayland-satellite (system/wm/niri.nix), que é rootless —
#      a root window do X não corresponde aos monitores físicos, então nem a
#      geometria das telas seria lida direito.
#
#   3. Nem o Synergy com suporte a Wayland resolveria. A Symless lista só GNOME
#      46+ e KDE Plasma 6.1+, porque capturar o cursor na borda exige o portal
#      `org.freedesktop.portal.InputCapture` — que o niri NÃO implementa
#      (upstream niri-wm/niri#823; o RemoteDesktop é o #390). Instalar o
#      xdg-desktop-portal-gnome não supre: a implementação dele depende de
#      internals do Mutter. A prova cruzada está no próprio nixpkgs — o
#      `deskflow` 1.26.0 TEM libei e libportal e mesmo assim falha no niri. O
#      que falta não é o pacote, é o compositor.
#
# O waynergy escapa disso porque não usa portal nenhum. Ele fala o protocolo
# Synergy pela rede com o servidor, e injeta o input pelos protocolos Wayland
# que o niri já implementa: zwlr_virtual_pointer_manager_v1 (versão 2, em
# src/protocols/virtual_pointer.rs do niri), zwp_virtual_keyboard_manager_v1 e
# keyboard_shortcuts_inhibit — que são exatamente os .xml em protocol/ do
# waynergy.
#
# A consequência é a regra desta máquina: ela é SEMPRE CLIENTE. O teclado e o
# mouse físicos ficam na máquina do servidor. Não há como inverter isso hoje.
#
# COMPATIBILIDADE COM O SERVIDOR
# ------------------------------
# Verificada contra um Synergy 3.5.1 de verdade, não por suposição: o servidor
# anuncia protocolo "Synergy 1.8" no handshake, e o waynergy aceita tanto
# "Synergy" quanto "Barrier" sem rejeitar por número de versão
# (src/uSynergy.c). Serve, portanto, para Synergy 1, Synergy 3, Barrier,
# Input Leap e Deskflow do outro lado — é o mesmo protocolo de fio na 24800.
#
# É SERVIÇO, NÃO exec-once
# ------------------------
# O CLAUDE.md deste repo já registrou duas vezes (#19 e #24) o preço de pôr
# processo de vida longa no `exec-once` do compositor: falha calada, sem
# reinício, sem `systemctl status` para checar. Aqui isso pesa ainda mais,
# porque o waynergy não tem reconexão robusta — o próprio README diz que o
# jeito de reconectar é mandar SIGUSR1 para o processo se re-executar. Com
# `Restart = "always"` o systemd faz esse papel: servidor reiniciou, rede caiu,
# notebook suspendeu, e a unit volta sozinha.
#
# Não existe `services.waynergy` no home-manager (conferido no upstream), por
# isso a unit é escrita à mão em vez de reaproveitada.
#
# POR QUE A CONFIGURAÇÃO VAI POR LINHA DE COMANDO
# -----------------------------------------------
# O waynergy também lê um config.ini em ~/.config/waynergy, e seria tentador
# gerá-lo com `xdg.configFile`. Não dá: xdg.configFile cria LINK READ-ONLY para
# o /nix/store, e é nesse mesmo diretório que o TOFU grava o hash do
# certificado do servidor na primeira conexão. Diretório imutável ali = TLS que
# nunca confia em ninguém. Então a configuração declarada vira argumento de
# ExecStart, e o diretório fica gravável para o estado que é do programa.
#
# O PASSO MANUAL QUE SOBRA
# ------------------------
# Cadastrar esta tela no layout do servidor, com o mesmo nome de
# `screenName`. No Synergy 3 isso é feito arrastando um computador novo no
# canvas da GUI; no Synergy 1 e no Barrier, editando o synergy.conf. O servidor
# RECUSA cliente com nome que não conhece, e o sintoma é uma conexão que abre e
# fecha logo em seguida ("new client disconnected" no log do servidor). Não há
# como fazer esse cadastro daqui: ele vive na outra máquina.
{
  osConfig,
  lib,
  pkgs,
  ...
}:

let
  cfg = osConfig.lcars.user.waynergy;

  # Os argumentos na ordem em que o ExecStart os recebe. Lista, e não string
  # com espaços, porque systemd não passa por shell: quem separa os argumentos
  # é o próprio systemd, e um nome de tela com espaço quebraria calado se isto
  # fosse concatenação.
  args = [
    "--host"
    cfg.host
    "--port"
    (toString cfg.port)
    "--name"
    cfg.screenName

    # wlr é o backend que usa zwlr_virtual_pointer + zwp_virtual_keyboard, os
    # protocolos que o niri implementa. Os outros dois que o waynergy oferece
    # não servem aqui: `kde` fala o org_kde_kwin_fake_input, que o niri não
    # tem, e `uinput` injeta direto no kernel — funcionaria, mas passa por
    # cima do compositor (o README avisa que isso vaza input entre sessões e
    # fura tela de bloqueio) e exigiria regra de udev e grupo dedicado.
    # Explícito de propósito: sem a flag o waynergy autodetecta, e uma
    # autodetecção que erre cairia justamente no uinput.
    "--backend"
    "wlr"

    "--loglevel"
    cfg.logLevel
  ]
  ++ lib.optionals cfg.tls [
    "--enable-crypto"
    "--enable-tofu"
  ]
  ++ lib.optional (!cfg.tls) "--disable-crypto"
  ++ lib.optional (!cfg.clipboard) "--no-clip";
in
lib.mkIf cfg.enable {
  # Falha na avaliação, não em runtime. Sem host o serviço subiria e ficaria
  # em loop de erro no journal — o tipo de falha que só se descobre depois de
  # rebootar na máquina errada.
  assertions = [
    {
      assertion = cfg.host != "";
      message = ''
        lcars.user.waynergy.enable está ligado, mas lcars.user.waynergy.host
        está vazio — não há servidor para conectar.

        Defina o endereço do servidor Synergy em machines/<host>/default.nix:

          lcars.user.waynergy.host = "192.168.0.10";
      '';
    }
  ];

  home.packages = [ pkgs.waynergy ];

  systemd.user.services.waynergy = {
    Unit = {
      Description = "waynergy — cliente Synergy para compositores Wayland";

      # Depende da sessão gráfica por necessidade, não por organização: o
      # waynergy conecta ao compositor por WAYLAND_DISPLAY, e sem sessão de pé
      # não há socket para conectar.
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${pkgs.waynergy}/bin/waynergy ${lib.escapeShellArgs args}";

      # "always", não "on-failure": quando o servidor sai do ar o waynergy
      # encerra LIMPO, com status 0, e um on-failure o deixaria parado até o
      # próximo login. Ver "É SERVIÇO, NÃO exec-once" no topo do arquivo.
      Restart = "always";
      RestartSec = 5;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
