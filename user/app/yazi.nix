# yazi.nix — o gerenciador de arquivos TUI do usuário.
#
# Opt-in por `lcars.user.yazi.enable`, ligado no profile. A flag vem do config
# do NixOS (veja user/options.nix).
#
# Este módulo faz duas coisas:
#
#   1. Habilita o `programs.yazi` do Home Manager: instala o pacote, escreve
#      o config mínimo em ~/.config/yazi e cria os diretórios que ele espera.
#      Sem isto, o `pkgs.yazi` entra no PATH mas não há config e a primeira
#      execução cria arquivos que ficam fora do controle do Nix.
#
#   2. Liga `enableZshIntegration`, que expõe o wrapper `y` no PATH — em vez
#      do `yazi` solto, `y` faz `cd` pro diretório onde você saiu do programa.
#      É o que faz a invocação do terminal ser útil: rode `y`, navegue, saia
#      com `q`, e o shell já está dentro do diretório escolhido. Sem o wrapper,
#      o `yazi` abriria, mostraria os arquivos e deixaria o usuário em
#      `~` depois.
#
# POR QUE NÃO CUSTOMIZAR yazi.toml/keymap.toml/theme.toml
# --------------------------------------------------------
# O default do programa já é o que a maioria quer, e mexer aqui sem critério
# só atrapalha quem está acostumado com o upstream. A issue #88 mantém o
# escopo no default — ajuste de gosto fica pra outra entrega, se um dia fizer
# falta.
{
  osConfig,
  lib,
  ...
}:
lib.mkIf osConfig.lcars.user.yazi.enable {
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;

    # Explícito porque o default legado (stateVersion < 26.05) seria "yy" —
    # e o resto deste módulo já documenta e assume o wrapper como `y`.
    shellWrapperName = "y";
  };
}
