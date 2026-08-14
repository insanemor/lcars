# Agregador dos módulos lcars.
#
# Todos são importados em todo host — mas cada um é opt-in via
# `lcars.<nome>.enable`, então importar não liga nada sozinho.
# Quem decide o que roda é `hosts/<host>/default.nix`.
{ ... }:

{
  imports = [
    ./common
    ./desktop
    ./laptop
    ./vm
    ./onePassword
  ];
}
