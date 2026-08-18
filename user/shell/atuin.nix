# atuin.nix — o histórico de comandos, num banco em vez de um arquivo de texto.
#
# Opt-in por `lcars.user.atuin.enable`, ligado no profile. A flag vem do config
# do NixOS (veja user/options.nix).
#
# O QUE ELE SUBSTITUI, E O QUE ELE NÃO SUBSTITUI
# ----------------------------------------------
# O `Ctrl+R` passa a ser a busca do atuin: tela cheia, difusa, sobre um SQLite
# que guarda o diretório, o código de saída e a duração de cada comando.
#
# A seta pra cima NÃO muda — continua sendo a do zsh, o histórico da sessão por
# prefixo, e é o que `--disable-up-arrow` garante lá embaixo. Foi escolha
# deliberada: aquela tecla já está na memória muscular.
#
# O histórico nativo do zsh (user/shell/zsh.nix, `history`) também fica de pé.
# São 50 000 linhas num arquivo de texto, custo desprezível, e é a rede de
# segurança para o dia em que o atuin sair do caminho.
#
# O SYNC, E QUEM FAZ O LOGIN
# --------------------------
# O sync é contra o servidor público, `https://api.atuin.sh`. O histórico vai
# criptografado ponta a ponta: o servidor guarda blocos que não sabe ler, e a
# chave nunca sai daqui.
#
# Isso tem uma consequência prática: **a chave é o histórico**. Perdê-la é
# perder o que está no servidor, e uma máquina nova sem ela não decifra nada.
# Sem chave e sem login, o atuin roda local e o sync falha calado.
#
# O login NÃO acontece aqui. Ele mora no fim do `nupdate`
# (scripts/update.sh), que lê usuário, senha e chave do 1Password e chama
# `atuin login` quando `atuin status` diz que não há sessão.
#
# POR QUE NÃO AQUI — a história vale o espaço, porque a tentação de trazer de
# volta é grande e o erro é silencioso:
#
#   #48 pôs o login em `home.activation.atuinLogin`. Módulo é o lugar óbvio de
#   tudo neste repositório, e este parecia igual aos outros. Não é. A ativação
#   do home-manager roda na unit `home-manager-<user>.service`, que não tem a
#   sessão gráfica do usuário — nem variáveis, nem socket, nem alguém para
#   autorizar o popup com que o 1Password libera o CLI. Foram quatro rodadas
#   até a mensagem final do journal, sempre com o `op` funcionando no terminal
#   ao lado: "sem login no 1Password" (#56, #57).
#
# A regra que fica: **o que precisa da sessão do usuário não pode morar na
# ativação.** Ali cabe o declarativo — pacote, config, integração de shell.
# O que depende de haver alguém na frente da máquina mora no script que essa
# pessoa digita.
#
# "ESTOU LOGADO?" É PERGUNTA PARA O ATUIN, NÃO PARA O DISCO
# ---------------------------------------------------------
# `atuin status` responde: sai com 1 e diz "You are not logged in to a sync
# server" quando não há login, e imprime endereço e usuário quando há. É o que
# o `nupdate` usa para não relogar à toa.
#
# A #48 perguntava a um arquivo, `~/.local/share/atuin/session`, e errava. A
# 18.18 não cria esse arquivo — num HOME limpo ela deixa apenas os bancos
# (`history.db`, `meta.db`, `records.db`), e o estado de login vive dentro do
# meta.db (#49).
#
# O ITEM NO 1PASSWORD
# -------------------
# Um item chamado `atuin`, no vault de `userSettings.onePassword.vault`, com
# três campos — os dois primeiros são os de qualquer item de login:
#
#   username  — o usuário da conta atuin
#   password  — a senha
#   key       — a saída de `atuin key`, o campo que você acrescenta
#
# O PASSO QUE É SEU, E NÃO DO REPOSITÓRIO
# ---------------------------------------
# Criar a conta. Uma vez, na máquina que já tem o histórico:
#
#   atuin register -u <usuário> -e <email>   # ou `atuin login`, se já existe
#   atuin import auto                        # traz o ~/.zsh_history
#   atuin key                                # imprime a chave; vai para o item
#
# CUIDADO COM `atuin key` NUMA MÁQUINA SEM CHAVE
# ----------------------------------------------
# Ele não reclama: **gera uma chave nova** e a imprime, como se estivesse
# mostrando a sua. Numa máquina que ainda não logou, isso cria uma segunda
# chave, que não decifra nada do que está no servidor. Rode `atuin key` só onde
# a chave certa já existe, e leve a saída para o 1Password — nunca o contrário.
{
  osConfig,
  lib,
  ...
}:

lib.mkIf osConfig.lcars.user.atuin.enable {
  programs.atuin = {
    enable = true;

    # A integração entra no .zshrc; o zsh é o shell deste repo (user/shell/zsh.nix).
    enableZshIntegration = true;

    # A ÚNICA razão de esta lista existir. Sem a flag, o atuin toma também a
    # seta pra cima — veja o cabeçalho.
    flags = [ "--disable-up-arrow" ];

    settings = {
      # --- sync ------------------------------------------------------
      auto_sync = true;
      sync_address = "https://api.atuin.sh";

      # A cada 5 minutos, e só quando um comando roda — o atuin não tem daemon
      # aqui, então este número é um teto, não uma promessa.
      sync_frequency = "5m";

      # Não há o que atualizar: o binário vem do nixpkgs, no store read-only.
      # Deixar ligado só produziria um aviso periódico sobre uma versão que
      # este sistema não pode instalar — a mesma história do `herdr update`.
      update_check = false;

      # --- busca -----------------------------------------------------
      # Difusa e global: procurar por pedaços do comando, em qualquer máquina
      # e qualquer diretório. É o que faz o histórico sincronizado valer a
      # pena; `filter_mode` alterna no próprio Ctrl+R, com Ctrl+R de novo.
      search_mode = "fuzzy";
      filter_mode = "global";

      # A janela não toma a tela inteira: 25 linhas abaixo do prompt, com o
      # que estava na tela ainda visível acima.
      style = "compact";
      inline_height = 25;

      # Data no formato daqui — dd/mm — para `atuin search --before 01/09/2026`.
      dialect = "uk";

      # `enter_accept` fica no default do atuin (true): Enter executa o comando
      # escolhido, Tab o traz para a linha para editar. Se um dia o Enter
      # disparar algo indesejado, é esta linha que você acrescenta como false.
    };
  };
}
