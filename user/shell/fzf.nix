# fzf.nix — busca difusa no terminal: Ctrl+T (arquivos), Alt+C (diretórios) e
# completion (**<Tab>). Opt-in por `lcars.user.fzf.enable`, ligado no profile.
# A flag vem do config do NixOS (veja user/options.nix).
#
# O CTRL+R FICA COM O ATUIN, NÃO COM O FZF
# ------------------------------------------
# A integração padrão do fzf (`fzf --zsh`) também tenta o Ctrl+R, pra busca
# fuzzy no próprio histórico. Mas essa tecla já é do atuin aqui
# (user/shell/atuin.nix), que é a busca melhor das duas: fuzzy, global
# entre máquinas, sincronizada. Hoje não há conflito ativo — conferido
# gerando o initContent de verdade: o fzf entra com `mkOrder 910` e o
# atuin no default (1000), então o atuin já roda depois e vence sozinho.
#
# Ainda assim, user/shell/zsh.nix tem um `bindkey` de garantia, via
# `lib.mkAfter`, pro Ctrl+R continuar do atuin mesmo se o nixpkgs um dia
# mudar essa ordem interna (não é contrato público).
{
  osConfig,
  lib,
  ...
}:

lib.mkIf osConfig.lcars.user.fzf.enable {
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
}
