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
#
# O Home Manager não sabe de nada disso: ele avisa em todo eval que fzf e
# atuin disputam o Ctrl+R para zsh, porque só olha se as duas integrações
# estão ligadas, não o `mkOrder` real. `historyWidget.zsh.command = ""`
# torna declarativo o que os parágrafos acima já garantem por ordem — o
# fzf simplesmente não entra na disputa, e o dono continua sendo o atuin.
{
  osConfig,
  lib,
  ...
}:

lib.mkIf osConfig.lcars.user.fzf.enable {
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    historyWidget.zsh.command = "";
  };
}
