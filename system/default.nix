# system/ — módulos NixOS, agrupados pelo papel que cumprem.
#
# Todos são importados em toda máquina, mas nenhum liga sozinho: cada um é
# opt-in por `lcars.system.<caminho>.enable`, e o caminho da flag espelha o
# caminho do arquivo. Quem decide é o profile (profiles/<nome>/), e a máquina
# pode sobrescrever ponto a ponto.
#
# O espelho disto do lado do Home Manager é `lcars.user.<módulo>`, declarado
# em user/options.nix.
#
#   core/       identidade, locale, boot, usuário
#   unfree.nix  a lista de pacotes proprietários liberados — sem flag
#   security/   sshd e firewall
#   hardware/   o que depende do hardware: áudio, teclado, notebook, VM
#   theme/      cor, fontes e papel de parede — transversal, não é de um WM
#   wm/         ambientes gráficos (Plasma, Hyprland) e a tela de login
#   app/        aplicativos de sistema
#
# A linha entre core/ e hardware/ é esta: em core/ está o que vale igual em
# qualquer máquina sua (fuso, locale, bootloader); em hardware/, o que muda
# com a máquina física — o teclado dela, se tem bateria, se é convidado QEMU.
{ ... }:

{
  imports = [
    ./core
    ./unfree.nix
    ./security
    ./hardware/audio.nix
    ./hardware/keyboard.nix
    ./hardware/laptop.nix
    ./hardware/vm.nix
    ./theme
    ./wm
    ./app/1password
  ];
}
