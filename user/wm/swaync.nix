# swaync.nix — notificações.
#
# O Hyprland não tem servidor de notificação. Sem um, nada avisa que a bateria
# está acabando, que um download terminou ou que uma mensagem chegou — e o
# programa que tentou notificar não recebe erro, então o silêncio parece
# normal.
#
# A cor vem do stylix (system/theme/), que tem alvo para swaync.
{ osConfig, lib, ... }:

lib.mkIf osConfig.lcars.user.swaync.enable {
  services.swaync = {
    enable = true;

    settings = {
      positionX = "right";
      positionY = "top";
      control-center-width = 420;

      # Segundos até uma notificação comum sumir sozinha. As marcadas como
      # críticas ignoram isto e ficam até você fechar — é o comportamento
      # esperado para "bateria em 5%".
      timeout = 8;
      timeout-low = 4;
      timeout-critical = 0;

      notification-window-width = 400;
      keyboard-shortcuts = true;
      image-visibility = "when-available";
    };
  };

  # O pacote NÃO é declarado aqui: `services.swaync` já o instala, e com ele
  # vem o `swaync-client` que o atalho SUPER+N chama. Declarar de novo em
  # home.packages seria duplicação — inofensiva, porque o Nix deduplica
  # derivações idênticas, mas enganosa para quem lê.
}
