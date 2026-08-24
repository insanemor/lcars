# steam/ — a loja de jogos, e o que ela arrasta junto.
#
# Opt-in por `lcars.system.app.steam.enable`, e DESLIGADO até no profile
# `personal` (veja o comentário lá). Quem liga é a máquina que joga: o custo
# não é o Steam em si, é o `enable32Bit` abaixo.
#
# POR QUE ISTO É UM MÓDULO DE SISTEMA, E NÃO UM PACOTE DO USUÁRIO
# ---------------------------------------------------------------
# `home.packages = [ pkgs.steam ]` instala um Steam que abre e não roda quase
# nada. O que falta não é o programa, é a metade de 32 bits do driver gráfico,
# e ela não é do usuário — é do sistema:
#
#   hardware.graphics.enable32Bit
#
# Verificado por avaliação antes desta issue (#150): `hardware.graphics.enable`
# já era `true` (algum módulo da cadeia niri/stylix o liga), mas o
# `enable32Bit` era `false`. Com ele desligado, um jogo de 32 bits — e o
# Proton inteiro, que carrega bibliotecas de 32 bits mesmo para rodar jogo de
# 64 — não encontra driver nenhum e cai em software rendering, ou nem abre.
# Numa RX 6800/6900 isso é a diferença entre a placa existir e não existir.
#
# É por isso que a flag mora aqui e não no perfil: `enable32Bit` duplica o
# conjunto de drivers Mesa no store de toda máquina que o ligar. Num notebook
# que nunca vai rodar jogo, é peso puro.
#
# O QUE O MÓDULO DO NIXPKGS JÁ FAZ, E POR ISSO NÃO ESTÁ AQUI
# -----------------------------------------------------------
# `programs.steam.enable` traz o pacote, monta o FHS em que o Steam roda e
# liga `hardware.steam-hardware` (as regras de udev de controle, Steam Deck e
# headset VR). Nada disso precisa ser repetido — o que este arquivo acrescenta
# é o 32 bits e as portas, que ele não decide por você.
{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.lcars.system.app.steam;
in
{
  options.lcars.system.app.steam = {
    enable = mkEnableOption "o Steam, com as bibliotecas gráficas de 32 bits que o Proton exige";

    remotePlay = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Abre no firewall as portas do Remote Play (streaming do jogo para
        outra tela da mesma casa). Só serve se você for de fato transmitir
        para outro aparelho.
      '';
    };

    dedicatedServer = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Abre as portas de servidor dedicado (hospedar partida para outros).
        Fora desse caso, mantenha fechado.
      '';
    };

    gamemode = mkOption {
      type = types.bool;
      default = true;
      description = ''
        `gamemoded`: enquanto um jogo roda, ajusta o governor da CPU e a
        prioridade dos processos, e desfaz tudo ao sair. O Steam o usa quando
        a linha de lançamento do jogo é `gamemoderun %command%`.

        Ligado junto porque não custa nada com o jogo fechado — é um daemon
        adormecido — e porque descobrir que ele existe depois de meses de
        stutter é o tipo de perda que este repo tenta evitar.
      '';
    };
  };

  config = mkIf cfg.enable {
    # A metade de 32 bits do driver. É o motivo deste módulo existir; veja o
    # cabeçalho. `hardware.graphics.enable` já vem ligado pela cadeia gráfica,
    # mas declarar aqui torna o módulo autossuficiente numa máquina que só
    # jogue, sem sessão do niri.
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    programs.steam = {
      enable = true;
      remotePlay.openFirewall = cfg.remotePlay;
      dedicatedServer.openFirewall = cfg.dedicatedServer;
    };

    programs.gamemode.enable = cfg.gamemode;
  };
}
