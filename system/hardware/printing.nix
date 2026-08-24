# printing.nix — impressão (CUPS) e descoberta na rede (Avahi).
#
# Fica em hardware/ pela mesma razão do bluetooth: depende do que existe em
# volta da máquina. Um servidor não imprime, e uma VM tampouco.
#
# Verificado por avaliação antes desta issue (#150), com o profile `personal`:
# `services.printing.enable` e `services.avahi.enable` eram os dois `false`.
#
# POR QUE OS DOIS JUNTOS
# ----------------------
# Impressora doméstica de hoje não se declara por endereço IP: ela se anuncia
# por mDNS/DNS-SD, e é o Avahi quem escuta esse anúncio. Sem ele, o CUPS sobe
# e a lista de impressoras fica vazia — o sintoma parece "a impressora não
# funciona", quando na verdade ninguém perguntou por ela na rede.
#
# `nssmdns4` é o que estende a resolução de nomes do sistema para o domínio
# `.local`, e é assim que se chama hoje: o antigo `services.avahi.nssmdns` foi
# renomeado no nixpkgs (mais um caso da regra do CLAUDE.md — confira o nome
# atual, não confie na memória).
#
# O FIREWALL
# ----------
# `openFirewall` do Avahi libera a porta 5353/UDP, sem a qual a resposta da
# impressora nunca chega de volta. É a única porta que este módulo abre: o
# CUPS aqui é cliente, não servidor de impressão para outras máquinas — quem
# quiser compartilhar a impressora declara `services.printing.listenAddresses`
# e a porta 631 na própria máquina.
#
# DRIVERS
# -------
# `gutenprint` cobre a maioria das impressoras jato de tinta e laser comuns.
# Marca que exige blob próprio (HP com `hplip`, Brother, Epson novas) entra
# direto em `services.printing.drivers` no machines/<host>, que é onde a
# informação pertence — o modelo da impressora é fato daquela casa, não do
# repositório.
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.lcars.system.hardware.printing;
in
{
  options.lcars.system.hardware.printing = {
    enable = mkEnableOption "impressão via CUPS, com descoberta de impressora na rede pelo Avahi";

    avahi = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Descoberta por mDNS/DNS-SD. Desligue só se a impressora for declarada
        por endereço fixo — sem isto, impressora de rede não aparece sozinha.

        O Avahi serve a mais do que impressão: é ele quem faz `nome.local`
        resolver, o que também vale para NAS e para o Nautilus achar
        compartilhamentos.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.printing = {
      enable = true;
      drivers = with pkgs; [ gutenprint ];
    };

    services.avahi = mkIf cfg.avahi {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
  };
}
