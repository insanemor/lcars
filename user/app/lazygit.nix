# lazygit.nix — o TUI de git do usuário, com config versionado.
#
# Opt-in por `lcars.user.lazygit.enable`, ligado no profile. A flag vem do
# config do NixOS (veja user/options.nix).
#
# O pacote é `pkgs.lazygit`, do nixpkgs unstable. O binário já entrava no
# PATH via user/app/herdr.nix (é o alvo do popup de `prefix+Shift+g` e
# também roda direto via `lg` no shell) — aqui ele continua entrando, mas
# deixa de ser uma dependência implícita do módulo do herdr.
#
# O config vai em ~/.config/lazygit/config.yml, o caminho que o próprio
# lazygit declara como global na sua documentação (docs/Config.md, seção
# "User Config"). Sem este arquivo, o lazygit sobe com `gui.sidePanels`
# no default — que inclui `stash` e `reflog`, dois painéis que o usuário
# não consulta — e com `gui.showCommandLog: true`, outro ruído fixo no
# rodapé.
#
# Mantemos só o que muda do default: colocar o arquivo inteiro é ruído no
# diff e abre espaço pra divergir do upstream silenciosamente.
#
# SIDE PANEL: QUATRO BLOCOS VERTICAIS
# -----------------------------------
# A lista `gui.sidePanels` aceita uma ou mais seções; cada seção vira um
# bloco vertical na coluna da esquerda. Quatro entradas de um painel só
# cada (`[status]`, `[files]`, `[branches]`, `[commits]`) dão quatro
# blocos separados, todos visíveis ao mesmo tempo.
#
# 'files', 'branches' e 'commits' são obrigatórios — sem nenhum dos três
# o lazygit recusa a configuração (validado na doc). `stash` e `reflog`
# ficam de fora, então não aparecem em lugar nenhum.
#
# A doc também permite abas dentro de uma seção (entrada com vários
# nomes). Foi tentado em #96, mas o usuário não descobriu as outras
# abas sem usar `[`/`]`; voltar a quatro blocos resolve.
#
# PARA ESCONDER O COMMAND LOG: `gui.showCommandLog: false` na seção
# `gui`.
{
  osConfig,
  lib,
  pkgs,
  ...
}:
lib.mkIf osConfig.lcars.user.lazygit.enable {
  # No PATH porque é ferramenta de uso direto (o alias `lg` em
  # user/shell/zsh.nix), não só o alvo do popup do herdr.
  home.packages = [ pkgs.lazygit ];

  xdg.configFile."lazygit/config.yml".text = ''
    # ATENÇÃO: arquivo gerado por user/app/lazygit.nix. Editar aqui não
    # adianta — é um link para o /nix/store, e o próximo `nupdate` o
    # reescreve.

    # Esconde a barra de log de comandos no rodapé.
    gui:
      showCommandLog: false

      # Quatro blocos verticais separados na coluna da esquerda, um
      # painel por bloco: status, files, branches, commits. stash e
      # reflog ficam de fora. files, branches e commits são
      # obrigatórios — sem nenhum dos três o lazygit recusa a
      # configuração.
      sidePanels:
        - [status]
        - [files]
        - [branches]
        - [commits]
  '';
}