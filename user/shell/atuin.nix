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
# O SYNC, E POR QUE ELE PRECISA DO 1PASSWORD
# ------------------------------------------
# O sync é contra o servidor público, `https://api.atuin.sh`. O histórico vai
# criptografado ponta a ponta: o servidor guarda blocos que não sabe ler, e a
# chave nunca sai daqui.
#
# Isso tem uma consequência prática: **a chave é o histórico**. Perdê-la é
# perder o que está no servidor, e uma máquina nova sem ela não decifra nada.
# Sem chave e sem login, o atuin roda local e o sync falha calado.
#
# A ativação resolve os dois de uma vez: quando o atuin não está logado, ela
# faz o login, com usuário, senha e chave lidos do 1Password (veja o bloco lá
# embaixo). Uma máquina nova nasce sincronizada com um `op signin` e um
# `nupdate`.
#
# A #46 fazia diferente — copiava `key` e `session` do vault, o que só
# funcionava se alguém já tivesse gerado a session à mão e a guardado lá. O
# passo manual não sumia, só mudava de lugar.
#
# "ESTOU LOGADO?" É PERGUNTA PARA O ATUIN, NÃO PARA O DISCO
# ---------------------------------------------------------
# `atuin status` responde: sai com 1 e diz "You are not logged in to a sync
# server" quando não há login, e imprime endereço e usuário quando há.
#
# A #48 perguntava a um arquivo, `~/.local/share/atuin/session`, e errava. A
# 18.18 não cria esse arquivo — num HOME limpo ela deixa apenas os bancos
# (`history.db`, `meta.db`, `records.db`), e o estado de login vive dentro do
# meta.db. A guarda nunca era verdadeira e toda ativação caía no login (#49).
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
#
# A SENHA APARECE NO `ps` — POR UM SEGUNDO, UMA VEZ POR MÁQUINA
# -------------------------------------------------------------
# `atuin login` não lê a senha de stdin nem de variável de ambiente: `-p` é a
# única forma (conferido no --help da 18.18.1). Enquanto o comando roda, a
# senha está no argv, visível a quem puder ler `/proc` desta máquina.
#
# É um risco real e pequeno — máquina pessoal, um login por máquina, cerca de
# um segundo — e foi aceito de propósito, na #48, em troca de a máquina nova não
# precisar de nenhum passo manual. Se um dia deixar de valer a troca, a saída é
# tirar o login daqui e fazê-lo à mão, uma vez por máquina; copiar um arquivo de
# sessão pronto não é alternativa, porque a 18.18 não guarda a sessão em arquivo.
{
  config,
  osConfig,
  lib,
  user,
  ...
}:

let
  dataDir = "${config.home.homeDirectory}/.local/share/atuin";

  # Um item com três campos, e não itens Document como em user/app/dotfiles.nix:
  # são três partes de uma credencial só, e assim há um lugar único para olhar
  # quando o sync parar.
  item = "op://${user.onePassword.vault}/atuin";

  atuin = lib.getExe config.programs.atuin.package;
in
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

  # O login, em tempo de ATIVAÇÃO, com o que estiver no 1Password.
  #
  # `entryAfter [ "writeBoundary" ]` é o ponto em que o home-manager já
  # materializou o resto — inclusive o binário do atuin, que é chamado aqui pelo
  # caminho absoluto no store, e não pelo nome: o PATH da ativação não é o do
  # shell interativo.
  #
  # Nada aqui pode derrubar o `home-manager switch`. Sem `op`, sem sessão no
  # 1Password, com campo faltando no item ou com o servidor do atuin fora do ar,
  # o bloco imprime uma linha e segue — o atuin fica local, que é um estado
  # utilizável. Mesmo desenho de user/app/dotfiles.nix.
  home.activation.atuinLogin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ${lib.escapeShellArg dataDir}

    # Quem responde se há login é o próprio atuin: `status` sai com 1 e diz
    # "You are not logged in to a sync server" quando não há.
    #
    # A #48 perguntava a um arquivo, `~/.local/share/atuin/session`, e errava:
    # a 18.18 não cria esse arquivo — o estado vive no meta.db. A guarda nunca
    # era verdadeira, e toda ativação caía no login (#49). Ler o meta.db aqui
    # seria trocar um palpite por outro: o formato é interno do atuin, e o
    # comando é a interface pública.
    if timeout 15 ${atuin} status >/dev/null 2>&1; then
      : # já logado nesta máquina — não relogar a cada rebuild
    elif ! command -v op >/dev/null 2>&1; then
      echo "lcars: 'op' não está no PATH — atuin fica local, sem sync"
    elif [ -z "''${OP_SERVICE_ACCOUNT_TOKEN:-}" ] && ! op whoami >/dev/null 2>&1; then
      echo "lcars: sem login no 1Password — atuin fica local, sem sync"
    else
      # Os três de uma vez. Se qualquer um faltar, não há login a tentar, e o
      # `op read` cala a boca sozinho — a mensagem daqui é mais útil que a dele.
      atuin_user="$(op read ${lib.escapeShellArg "${item}/username"} 2>/dev/null || true)"
      atuin_pass="$(op read ${lib.escapeShellArg "${item}/password"} 2>/dev/null || true)"
      atuin_key="$(op read ${lib.escapeShellArg "${item}/key"} 2>/dev/null || true)"

      if [ -z "$atuin_user" ] || [ -z "$atuin_pass" ] || [ -z "$atuin_key" ]; then
        echo "lcars: item ${item} incompleto no 1Password (quero username, password e key) — atuin fica local, sem sync"
      # `timeout` porque isto é uma chamada de rede no meio de um rebuild: com o
      # servidor mudo, o switch ficaria pendurado esperando.
      elif timeout 30 ${atuin} login \
             -u "$atuin_user" -p "$atuin_pass" -k "$atuin_key" >/dev/null 2>&1; then
        echo "lcars: atuin logado — o histórico desta máquina passa a sincronizar"
      else
        echo "lcars: 'atuin login' falhou (senha, chave ou servidor) — atuin fica local, sem sync"
      fi

      # A senha sai da memória do shell assim que deixa de ser necessária. É
      # higiene, não proteção: enquanto o login rodou, ela esteve no argv.
      unset atuin_user atuin_pass atuin_key
    fi
  '';
}
