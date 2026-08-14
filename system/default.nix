# system/ — módulos NixOS, agrupados pelo papel que cumprem.
#
# Todos são importados em toda máquina, mas nenhum liga sozinho: cada um é
# opt-in por `lcars.<caminho>.enable`. Quem decide é o profile
# (profiles/<nome>/), e a máquina pode sobrescrever ponto a ponto.
#
#   core/       identidade, locale, boot, usuário
#   security/   sshd e firewall
#   hardware/   ajustes por tipo de máquina (notebook, VM)
#   wm/         ambiente gráfico (KDE Plasma)
#   app/        aplicativos de sistema
{ ... }:

{
  imports = [
    ./core
    ./security
    ./hardware/laptop.nix
    ./hardware/vm.nix
    ./wm/plasma.nix
    ./app/1password
  ];
}
