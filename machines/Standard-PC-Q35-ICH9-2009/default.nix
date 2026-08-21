# --------------------------------------------------------------------
# Máquina de template.
#
# Este arquivo descreve O QUE ESTA MÁQUINA É. Tudo que vale igual em todas as
# suas máquinas — usuário, locale, profile, 1Password — está no settings.nix
# da raiz, e não aqui. A divisão existe para o settings.nix nunca divergir
# entre clones: sem ela, todo `git pull` daria conflito.
#
#   1. cp -r machines/template machines/<nome>
#   2. Na máquina alvo, gere o hardware-configuration.nix:
#        sudo nixos-generate-config --show-hardware-config \
#          > machines/<nome>/hardware-configuration.nix
#   3. Ajuste as linhas abaixo para o que esta máquina é
#   4. `git add -f machines/<nome>` — flakes só enxergam arquivos que o git
#      rastreia, e o hardware-configuration.nix está no .gitignore.
#
# `machines/<dir>` vira uma entrada de nixosConfigurations automaticamente, e
# é o nome do diretório que vira networking.hostName — não há campo de hostname
# em lugar nenhum. `template` é ignorado pela auto-descoberta. O instalador
# nomeia o diretório com o modelo do hardware; na mão, escolha o que quiser.
# --------------------------------------------------------------------
{
  config,
  lib,
  pkgs,
  sys,
  user,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # --- boot -----------------------------------------------------------
  # Depende de a máquina ter bootado em UEFI ou em BIOS legado, algo que o
  # nixos-generate-config não decide por você. O instalador detecta e preenche;
  # na mão, confira com `[ -d /sys/firmware/efi ] && echo uefi || echo bios`.
  #
  #   "systemd-boot"  UEFI — usa bootMountPath, normalmente /boot
  #   "grub"          BIOS legado — exige grubDevice preenchido
  lcars.system.core.bootLoader = "systemd-boot";

  # Só com bootLoader = "grub". O DISCO, não a partição: "/dev/sda", não
  # "/dev/sda1". Descubra com:
  #   lsblk -no pkname "$(findmnt -no SOURCE /)"
  lcars.system.core.grubDevice = "";

  # --- ajustes de hardware --------------------------------------------
  # Ninguém detecta isto por você. Ligue à mão o que esta máquina for: vm traz
  # virtio e qemu-guest-agent, laptop traz tlp, limite de carga da bateria e
  # suspensão ao fechar a tampa.
  lcars.system.hardware.vm.enable = false;
  lcars.system.hardware.laptop.enable = false;

  # As linhas acima existem descomentadas de propósito: o instalador as
  # reescreve com `sed`, que só substitui linha já presente. Apagá-las faria
  # ele falhar em silêncio — foi o que aconteceu na #15.

  # --- outros ajustes desta máquina -----------------------------------
  # O profile e o settings.nix aplicam tudo com mkDefault, então basta declarar
  # aqui o que você quer diferente NESTA máquina:
  #
  #   lcars.profile                          = "basic";   # outro preset só aqui
  #   lcars.system.core.bootMountPath        = "/efi";    # se a ESP não é /boot
  #   lcars.system.core.swapFileSize         = 8192;
  #   lcars.system.wm.plasma.enable          = false;   # só Hyprland
  #   lcars.system.wm.defaultSession         = "hyprland";
  #   lcars.system.hardware.audio.enable     = true;      # som sem desktop
  #   lcars.system.hardware.keyboard.layout  = "br";      # teclado ABNT2
  #   lcars.system.hardware.keyboard.variant = "abnt2";
  #   lcars.system.security.sshKeys          = [ "ssh-ed25519 AAAA..." ];
  #
  #   lcars.user.direnv.enable               = false;     # ambiente do usuário
  #   lcars.user.dotfiles.enable             = false;

  # --- fundo da tela de login (regreet) --------------------------------
  # Direto no regreet, não em lcars.system.theme.wallpaper: aquela flag
  # alimenta stylix.image, que auto-liga o alvo hyprpaper do stylix NO
  # DESKTOP também (system/theme/default.nix documenta o efeito colateral).
  # Entraria em conflito com o mpvpaper que já toca um vídeo como wallpaper
  # do desktop (plugin noctalia/mpvpaper, escolhido pela própria interface,
  # não declarado aqui). O regreet só teria de fato ganhado o mesmo
  # tratamento se essa opção global fosse usada — o que este bloco evita.
  #
  # A imagem é um frame extraído desse mesmo vídeo (não é o vídeo em si: o
  # cage, que hospeda o regreet, só roda um app em modo kiosk, sem camada de
  # fundo separada — vídeo de verdade exigiria reescrever o compositor do
  # greeter do zero, risco desproporcional pra tela de login, issue #134).
  #
  # `./matrix-login.png`, e não um path absoluto: flakes avaliam em modo
  # puro e só leem arquivo rastreado pelo git — testado ao vivo, um path
  # absoluto fora do repo aborta com "access to absolute path ... is
  # forbidden in pure evaluation mode". Mesmo padrão que
  # `system/theme/default.nix` já usa para os esquemas base16.
  services.displayManager.regreet.settings.background = {
    path = ./matrix-login.png;
    fit = "Cover";
  };
}
