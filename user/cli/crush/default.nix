# crush.nix — o agente CLI do Crush (charm.land) no ambiente do usuário.
#
# Opt-in por `lcars.user.crush.enable`, ligado no profile. A flag vem do
# config do NixOS (veja user/options.nix).
#
# O pacote é `pkgs.crush`, do nixpkgs unstable. A versão é a do flake.lock;
# o `crush update` embutido não funciona numa instalação do Nix — o binário
# está no store, read-only. Para subir de versão: `nix flake update`.
#
# O módulo escreve um `crushrc` mínimo em ~/.config/crush/crushrc, só para
# o Crush ter onde escrever a primeira vez e o usuário ter um ponto de
# partida visível. NÃO vem com provedores, modelos, chaves de API nem nada
# que toque em segredo: completude fica por conta do `crush` na primeira
# execução (ou por edição manual usando `xdg.configFile`). Versionar
# segredo aqui seria vazamento direto.
{
  osConfig,
  lib,
  pkgs,
  ...
}:

lib.mkIf osConfig.lcars.user.crush.enable {
  home.packages = [ pkgs.crush ];

  # Bootstrap: o usuário completa o crushrc na primeira execução.
  # Symlink para o store, read-only — por isso mesmo a configuração editável
  # pelo próprio Crush (providers, models, MCP) entra num caminho paralelo
  # gerenciado pela ferramenta, fora do flake.
  xdg.configFile."crush/crushrc".text = ''
    # crushrc mínimo escrito pelo lcars — edite à vontade.
    # Providers, modelos e chaves de API entram aqui (ou via `crush`).
    # See https://charm.land/crush for the full reference.
  '';
}
