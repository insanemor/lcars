# bluetooth.nix — o rádio BlueZ.
#
# Fica em hardware/ porque é fato da máquina: uma placa Wi-Fi moderna traz o
# bluetooth no mesmo chip (a Intel AX200 do dragon-pc é assim), e uma VM não
# tem rádio nenhum. Por isso a flag não vem ligada de fábrica em profile
# algum, e sim no profile de desktop.
#
# Verificado por avaliação antes desta issue (#150): com o profile `personal`
# ligado, `hardware.bluetooth.enable` era `false`. O default do NixOS é
# desligado e nenhum módulo daqui o ligava — sem isto, fone, controle e
# teclado bluetooth simplesmente não existem para o sistema, e não há erro
# nenhum a procurar: o rádio nunca é iniciado.
#
# O FIRMWARE JÁ ESTÁ RESOLVIDO
# ----------------------------
# O blob que o chip carrega vem de `hardware.enableRedistributableFirmware`,
# ligado para toda máquina em system/core/default.nix (a lição da GPU que
# abortava com ENOENT). Sem ele, ligar o BlueZ daria um adaptador que aparece
# e morre no `dmesg`.
#
# QUEM DESENHA A INTERFACE
# ------------------------
# O noctalia já traz um widget de bluetooth na barra (veja `end = [ ...
# "bluetooth" ... ]` em user/wm/noctalia-config.toml), e ele fala com o BlueZ
# direto por D-Bus. É por isso que o `blueman` existe aqui como option
# DESLIGADA: dois applets sobre o mesmo daemon é a armadilha da #24 de novo —
# não é redundância, é disputa. Ligue-o só numa máquina sem noctalia.
{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.lcars.system.hardware.bluetooth;
in
{
  options.lcars.system.hardware.bluetooth = {
    enable = mkEnableOption "o bluetooth (BlueZ) — fone, controle e teclado sem fio";

    powerOnBoot = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Liga o adaptador junto com a máquina. Desligue numa máquina onde o
        rádio deva ficar apagado até você pedir — o `bluetoothctl power on`
        continua funcionando de qualquer forma.
      '';
    };

    blueman = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Applet GTK de bluetooth (`blueman-applet` na bandeja, e o
        `blueman-manager` para parear).

        Desligado por padrão porque o noctalia já tem o widget dele na barra,
        e dois applets disputando o mesmo daemon dão o sintoma da #24: um
        funciona, o outro reclama. Numa máquina sem noctalia, ligue.
      '';
    };
  };

  config = mkIf cfg.enable {
    hardware.bluetooth = {
      enable = true;
      inherit (cfg) powerOnBoot;

      settings.General = {
        # Sem isto, um fone que também toca música às vezes conecta só como
        # headset (mono, qualidade de telefone) e nunca oferece o perfil A2DP.
        Enable = "Source,Sink,Media,Socket";

        # Nome que aparece no celular e no fone ao parear. O default do BlueZ
        # é o hostname, que aqui é o modelo da placa-mãe — pouco reconhecível
        # numa lista de dispositivos.
        Name = mkDefault config.networking.hostName;
      };
    };

    services.blueman.enable = cfg.blueman;

    # Não há pacote de codec a acrescentar aqui. Os codecs de fone bluetooth
    # (SBC, AAC, aptX, LDAC) são compilados DENTRO do pipewire do nixpkgs, e
    # quem serve o áudio é lcars.system.hardware.audio — pôr uma biblioteca
    # de codec em `environment.systemPackages` não muda o que o PipeWire
    # oferece, porque a ligação é em tempo de build, não em tempo de execução.
  };
}
