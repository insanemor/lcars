# kitty.nix — o terminal.
#
# Opt-in por `lcars.user.kitty.enable`, ligado no profile. A flag vem do config
# do NixOS (veja user/options.nix).
#
# Por que este arquivo existe, se o kitty já era instalado
# --------------------------------------------------------
# Ele era instalado por `home.packages` em user/wm/niri.nix, e só. O pacote
# estava no PATH e o programa rodava — com os defaults de fábrica: fonte
# genérica e paleta própria.
#
# O stylix tem alvo para kitty, mas ele age sobre `programs.kitty` do Home
# Manager. Sem o módulo habilitado, nenhum kitty.conf é gerado e não há onde a
# fonte e as cores entrarem. Era por isso que a paleta simbiot-dark pintava
# tudo menos o terminal, e a Nerd Font não aparecia justamente onde os ícones
# do prompt precisam dela.
#
# É a mesma lição que o comentário do noctalia já registrava: instalar o pacote
# não é configurar o programa.
#
# O que NÃO está aqui
# -------------------
# Nem fonte, nem tamanho, nem uma única cor. Tudo isso vem do stylix, a partir
# de `lcars.system.theme` — o mesmo lugar que serve o resto do sistema. Escrever
# a fonte aqui criaria uma segunda fonte de verdade que ninguém lembraria de
# atualizar.
{
  osConfig,
  lib,
  ...
}:

lib.mkIf osConfig.lcars.user.kitty.enable {
  programs.kitty = {
    enable = true;

    settings = {
      # Rolagem generosa: o padrão do kitty são 2000 linhas, e uma saída de
      # build de NixOS passa disso sem esforço.
      scrollback_lines = 10000;

      # Sem o aviso de "sua configuração mudou, recarregue" a cada rebuild.
      confirm_os_window_close = 0;

      # A barra de título é desenhada pelo compositor, não pelo kitty — é o que
      # `prefer-no-csd` do niri pede, e o que faz o anel de foco aparecer.
      hide_window_decorations = "yes";
    };
  };
}
