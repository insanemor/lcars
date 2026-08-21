# nvim.nix — o editor do usuário.
#
# Opt-in por `lcars.user.nvim.enable`, ligado no profile. A flag vem do config
# do NixOS (veja user/options.nix).
#
# Este módulo faz três coisas, em ordem de importância:
#
#   1. Habilita o `programs.neovim` do Home Manager, que escreve o
#      ~/.config/nvim/init.vim mínimo, define o pacote nixpkgs e cria o
#      diretório ~/.config/nvim. Sem isto, o pacote entra no PATH mas não há
#      onde o plugin entrar.
#
#   2. Escreve o init.lua que carrega o plugin herdr-nvim a partir da árvore
#      do store (mesmo input que user/app/herdr.nix usa para a metade
#      herdr). O runtimepath é prefixado pelo caminho do store e depois o
#      plugin é inicializado com `setup({})`, a configuração mínima que a
#      README do upstream documenta.
#
#   3. A fonte e o tamanho vêm do NIXPKGS, e as cores do stylix via
#      `programs.neovim` (a integração do Home Manager com o esquema base16
#      já cuida dos dois). É o mesmo trato do kitty, do noctalia e dos
#      outros — um só lugar decide a cor de tudo.
#
# POR QUE NÃO HÁ `programs.nvim`-alguma-coisa
# ------------------------------------------
# O `pkgs.neovim` do nixpkgs unstable é o caminho certeiro; nada aqui depende
# de um overlay. A entrega em escopo não instala lazy.nvim nem outro gerenciador
# de plugins: o plugin é carregado direto pela árvore do store, e é uma única
# dependência. Auto-update / tema visual via LSP é entrega à parte.
#
# POR QUE init.lua E NÃO `programs.neovim.extraPackages`
# -------------------------------------------------------
# O `programs.neovim` do Home Manager aceita `plugins`, mas o tratador dele
# só conhece pacotes do vim-plugins (nixpkgs) com `vim` builder. A árvore
# do herdr-nvim não é um pacote — é um diretório do flake input. Carregar
# a árvore direto no runtimepath é mais simples e correto: o plugin é
# versionado pelo lock do flake, como todo o resto.
{
  osConfig,
  inputs,
  lib,
  ...
}:
lib.mkIf osConfig.lcars.user.nvim.enable {
  programs.neovim = {
    enable = true;
    defaultEditor = true;

    # herdr-nvim é lua puro — sem require de python nem ruby (conferido na
    # árvore do input). Sem os providers legados, o eval não avisa mais e o
    # fechamento fica menor.
    withRuby = false;
    withPython3 = false;
  };

  # O init.lua do usuário: carrega o herdr-nvim a partir do store e chama o
  # setup com defaults do upstream. Sem opacidade — qualquer ajuste visível
  # aqui é legível.
  #
  # O caminho é o do input `herdr-nvim`, e não um pacote do nixpkgs: ele não
  # existe lá, e a árvore está no flake.lock do mesmo jeito que todo o resto.
  # É a mesma lógica de user/app/herdr.nix — entrada pelo flake, versão fixa.
  #
  # `vim.opt.rtp:prepend` (e não `vim.opt.rtp:append`) garante que o plugin
  # ganhe dos do nixpkgs na resolução de nomes; sem isto, qualquer
  # `require("...")` do plugin que batesse com um módulo do runtimepath
  # padrão pegaria o primeiro.
  xdg.configFile."nvim/init.lua".text = ''
    -- ATENÇÃO: arquivo gerado por user/app/nvim.nix. Editar aqui não
    -- adianta — é um link para o /nix/store, e o próximo `nupdate` o
    -- reescreve.

    -- Fonte, tamanho e paleta de cores vêm do `programs.neovim` do
    -- Home Manager (integração com stylix quando lcars.system.theme.enable
    -- estiver ligado). Aqui só carregamos o plugin herdr-nvim.

    vim.opt.runtimepath:prepend("${inputs.herdr-nvim}")

    require("herdr-nvim").setup({})
  '';
}
