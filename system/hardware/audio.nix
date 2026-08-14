# audio.nix — servidor de som.
#
# Isto morava em system/wm/plasma.nix, onde o próprio comentário já admitia
# que áudio "não é específico de nenhum ambiente gráfico em particular". O
# efeito prático era não existir máquina com som e sem KDE: um servidor de
# mídia teria que ligar o Plasma inteiro para ter PipeWire.
#
# Agora é flag própria. Um desktop liga as duas coisas pelo profile; uma
# máquina de áudio headless liga só esta.
{ config, lib, ... }:

with lib;

let
  cfg = config.lcars.system.hardware.audio;
in
{
  options.lcars.system.hardware.audio = {
    enable = mkEnableOption "PipeWire como servidor de som (ALSA, PulseAudio e JACK)";

    support32Bit = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Compatibilidade ALSA para aplicações de 32 bits. Necessário para jogos
        e para software proprietário antigo; desligue numa máquina que só roda
        binários de 64 bits.
      '';
    };

    jack = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Emulação JACK, para software de áudio profissional (Ardour, Carla).
        Fora desse caso não faz falta.
      '';
    };
  };

  config = mkIf cfg.enable {
    # PulseAudio e PipeWire disputam o mesmo socket. É `services.pulseaudio`
    # no nixos-unstable — `hardware.pulseaudio` foi renomeado.
    services.pulseaudio.enable = false;

    # Prioridade de tempo real para o daemon de áudio, sem o que há falhas
    # audíveis sob carga.
    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = cfg.support32Bit;
      pulse.enable = true;
      jack.enable = cfg.jack;
    };
  };
}
