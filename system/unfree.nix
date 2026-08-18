# system/unfree.nix — a porta única do software proprietário.
#
# O nixpkgs recusa avaliar um pacote com licença unfree a menos que alguém
# diga, explicitamente, que aquele pacote pode entrar. Este arquivo é onde
# esse "pode" mora — e desde a #66 ele vale para todos de uma vez.
#
# Por que global, e não mais a liberação nome a nome
# --------------------------------------------------
# Até a #66 havia uma option `lcars.system.unfreePackages`: cada módulo
# acrescentava os nomes dos seus pacotes proprietários, e este arquivo montava
# um `allowUnfreePredicate` a partir da lista. A ideia era que nada entrasse
# por descuido.
#
# O custo apareceu no uso: todo pacote proprietário novo custava duas
# edições em arquivos diferentes, e o erro de esquecer a segunda é
# "has an unfree license" na avaliação — legível, mas em outro lugar do que a
# mudança. O usuário decidiu pagar o preço inverso: `allowUnfree = true`, e o
# que decide o que entra na máquina passa a ser só o módulo que instala.
#
# A lista foi REMOVIDA, e não deixada de lado. Com `allowUnfree = true` o
# nixpkgs nunca consulta o predicate (a checagem é `allowUnfree ||
# allowUnfreePredicate pkg`), então mantê-lo criaria duas fontes de verdade
# sobre a mesma decisão — uma delas morta e sem aviso de que era morta.
#
# Para voltar ao desvio por nome, o histórico da #47 tem o desenho pronto: a
# option era `listOf str`, os módulos contribuíam de dentro do próprio `mkIf`
# e o predicate se escrevia num lugar só (era isso que impedia dois módulos de
# apagarem o predicate um do outro, já que `nixpkgs.config` mescla por
# atributo).
_:

{
  config.nixpkgs.config.allowUnfree = true;
}
