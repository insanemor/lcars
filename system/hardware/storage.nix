# storage.nix — discos que chegam depois do boot.
#
# O `fileSystems` do hardware-configuration.nix cuida do que a máquina monta
# ao ligar. Este módulo cuida do resto: o pendrive que você espeta agora, o HD
# externo, a partição do outro sistema operacional — e de quem os monta, que
# num desktop sem Plasma nem GNOME não é ninguém por padrão.
#
# POR QUE ISTO NÃO EXISTIA
# ------------------------
# Porque a VM não tem porta USB com nada plugado. Rodando só em
# `machines/Standard-PC-Q35-ICH9-2009`, o repo nunca precisou montar disco
# nenhum, e a falta não aparecia. Numa máquina de verdade ela aparece no
# primeiro pendrive.
#
# Verificado por avaliação antes desta issue (#150), com o profile `personal`
# ligado:
#
#   services.udisks2.enable      false
#   services.gvfs.enable         false
#   boot.supportedFilesystems    {"ext4":true,"vfat":true}
#
# Os dois primeiros são `false` porque quem normalmente os liga é um desktop
# environment completo (`services.desktopManager.plasma6`, GNOME), e este repo
# não tem nenhum desde a #34 — o niri é um compositor, não um DE. O terceiro
# é o conjunto que o `nixos-generate-config` detectou nos discos daquela
# máquina, e nada mais.
#
# O QUE CADA PEÇA FAZ, PORQUE ELAS SE PARECEM
# -------------------------------------------
#   udisks2   o daemon que enxerga os blocos e sabe montá-los. É ele que
#             responde "existe um disco novo em /dev/sdb1". Sem ele o
#             Nautilus não lista dispositivo nenhum na barra lateral.
#
#   gvfs      a camada do GIO que o Nautilus usa para *falar* com o udisks2, e
#             também o que dá lixeira (trash://), rede (smb://, sftp://) e
#             celular por MTP. Sem ela o Nautilus abre, mas "Outros locais"
#             fica vazio e apagar arquivo é apagar de verdade.
#
# São complementares, não alternativas: ligar um sem o outro dá meia
# funcionalidade, e é por isso que este módulo liga os dois juntos.
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.lcars.system.hardware.storage;
in
{
  options.lcars.system.hardware.storage = {
    enable = mkEnableOption "montagem de discos removíveis (udisks2 + gvfs) e sistemas de arquivos além do que o boot exige";

    ntfs = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Suporte a NTFS, o sistema de arquivos do Windows. Traz o `ntfs3g`, o
        que permite montar (e escrever em) partições e HDs externos vindos de
        outra máquina.

        Ligado por padrão porque disco externo grande costuma vir de fábrica
        em NTFS, e a falta só aparece na hora de montar — com um erro de
        "unknown filesystem type", que não sugere em nada o que arrumar.
      '';
    };

    exfat = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Suporte a exFAT — o formato dos pendrives e cartões SD grandes, que o
        FAT32 não alcança por causa do limite de 4 GB por arquivo.

        O driver está no kernel desde a 5.4; o que esta flag acrescenta são as
        ferramentas de espaço de usuário (`exfatprogs`), sem as quais dá para
        montar mas não para verificar nem formatar.
      '';
    };
  };

  config = mkIf cfg.enable {
    # O daemon e a camada que o Nautilus usa para falar com ele. Veja o
    # cabeçalho: são complementares.
    services.udisks2.enable = true;
    services.gvfs.enable = true;

    # `boot.supportedFilesystems` é um attrset de bool no nixos-unstable — a
    # forma de lista (`[ "ntfs" ]`) ainda é aceita por compatibilidade, mas a
    # atual é esta, e ela funde com o que o hardware-configuration.nix já
    # detectou em vez de disputar com ele.
    boot.supportedFilesystems = {
      ntfs = mkIf cfg.ntfs true;
      exfat = mkIf cfg.exfat true;
    };

    # Ferramentas de linha de comando para quando o gráfico não serve: montar
    # à mão pelo `udisksctl`, ou olhar a saúde de um disco antes de confiar
    # nele.
    #
    # `udiskie` NÃO está aqui, e é uma escolha: ele é o automontador que sobe
    # com a sessão e monta tudo que aparece. O noctalia já traz o seu painel
    # de dispositivos, e dois automontadores sobre o mesmo udisks2 é a
    # armadilha da #24 outra vez — um monta, o outro reclama do que não
    # conseguiu montar.
    # O `smartmontools` não está aqui de propósito: quem o instala é
    # user/wm/noctalia.nix, junto do plugin drive-health que o consome.
    environment.systemPackages = with pkgs; [
      udisks # udisksctl: montar, desmontar e listar pela CLI
    ];
  };
}
