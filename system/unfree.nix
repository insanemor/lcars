# system/unfree.nix — a porta única do software proprietário.
#
# O nixpkgs recusa avaliar um pacote com licença unfree a menos que alguém
# diga, explicitamente, que aquele pacote pode entrar. Este arquivo é onde
# esse "pode" mora, e a option abaixo é o jeito de acrescentar nomes.
#
# Por que uma option, e não `allowUnfreePredicate` em cada módulo
# ---------------------------------------------------------------
# Porque duas definições não somam — a segunda apaga a primeira, sem erro.
# `nixpkgs.config` é mesclado por atributo (mergeAttrs raso), então
# `allowUnfreePredicate` é um valor comum: dois módulos que o definam entregam
# UM dos dois predicados ao nixpkgs, e o pacote coberto pelo outro passa a
# falhar a avaliação com "has an unfree license". Até a #47 só o 1Password o
# definia, e o problema não aparecia; o Vivaldi seria o segundo.
#
# Com a lista, os módulos contribuem em vez de disputar: o tipo é listOf, que
# o sistema de módulos concatena, e o predicate é escrito num lugar só.
#
# Note que continua NÃO havendo `allowUnfree = true` global. O desvio é por
# nome: um pacote proprietário que ninguém listou aqui não entra por descuido.
{
  config,
  lib,
  ...
}:

with lib;

{
  options.lcars.system.unfreePackages = mkOption {
    type = types.listOf types.str;
    default = [ ];
    example = [ "1password-gui" ];
    description = ''
      Nomes de pacotes proprietários liberados para avaliação. O nome é o que
      `lib.getName` devolve — normalmente o `pname` da derivação, sem versão.
      Cada módulo acrescenta os seus dentro do próprio `mkIf`, e as listas são
      somadas.
    '';
  };

  config = {
    nixpkgs.config.allowUnfreePredicate = pkg: elem (getName pkg) config.lcars.system.unfreePackages;

    # O Vivaldi contribui daqui, e não de user/app/vivaldi.nix, porque as duas
    # árvores de módulos são separadas: lá `config` é o do Home Manager, que
    # não tem `nixpkgs.config` nem `lcars.*` — um módulo de user/ não alcança
    # esta option. A flag, essa sim, é lida dos dois lados (veja
    # user/options.nix).
    #
    # `widevine-cdm` entra junto porque é o CDM que o `enableWidevine = true`
    # do pacote linka para dentro do Vivaldi; sem ele na lista, é ele que
    # barra a avaliação. Os codecs proprietários NÃO precisam de linha:
    # `vivaldi-ffmpeg-codecs` é LGPL 2.1, livre.
    lcars.system.unfreePackages = optionals config.lcars.user.vivaldi.enable [
      "vivaldi"
      "widevine-cdm"
    ];
  };
}
