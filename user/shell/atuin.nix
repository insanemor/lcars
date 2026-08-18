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
# perder o que está no servidor, e uma máquina nova sem ela não decifra nada. O
# atuin guarda dois arquivos em ~/.local/share/atuin/:
#
#   key      — a chave de criptografia, a MESMA em todas as máquinas
#   session  — o token de sessão, obtido no login
#
# Sem os dois, o atuin roda local e o sync falha calado. É por isso que eles
# vêm do 1Password na ativação, no mesmo espírito de user/app/dotfiles.nix: uma
# máquina nova nasce sincronizada depois de um `op signin` e um `nupdate`, sem
# ninguém digitar senha.
#
# O PASSO QUE É SEU, E NÃO DO REPOSITÓRIO
# ---------------------------------------
# Registrar a conta envolve senha, e senha não entra em arquivo versionado nem
# em script de ativação. Uma vez, na máquina que já tem o histórico:
#
#   atuin register -u <usuário> -e <email>   # ou `atuin login`, se já existe
#   atuin key                                # imprime a chave
#
# Depois, no vault do 1Password (`userSettings.onePassword.vault`), crie um
# item chamado `atuin` com dois campos:
#
#   key      = a saída de `atuin key`
#   session  = o conteúdo de ~/.local/share/atuin/session
#
# A partir daí toda máquina se vira sozinha. O 1Password é a fonte da verdade:
# se você fizer `atuin login` numa máquina e não atualizar o item, a próxima
# ativação devolve a session do vault por cima — é o mesmo trato do `nupdate`,
# em que o repositório vence.
{
  config,
  osConfig,
  lib,
  user,
  ...
}:

let
  dataDir = "${config.home.homeDirectory}/.local/share/atuin";

  vault = user.onePassword.vault;

  # Um item com dois campos, e não dois itens Document como em dotfiles.nix:
  # são dois segredos de uma coisa só, e assim há um lugar único para olhar
  # quando o sync parar.
  segredos = [
    {
      campo = "key";
      destino = "${dataDir}/key";
    }
    {
      campo = "session";
      destino = "${dataDir}/session";
    }
  ];
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

  # Os dois segredos, do 1Password, em tempo de ATIVAÇÃO.
  #
  # Não são symlinks para o store: são arquivos de verdade em ~/.local/share,
  # porque o atuin os lê com permissão restrita e, no caso da session, pode
  # querer reescrevê-los. `entryAfter [ "writeBoundary" ]` é o ponto em que o
  # home-manager já materializou o resto.
  #
  # Nada aqui pode derrubar o `home-manager switch`: sem `op`, sem login, ou com
  # o item ainda não criado, o bloco imprime uma linha e segue — o atuin fica
  # local, que é um estado utilizável. Mesmo desenho de user/app/dotfiles.nix.
  home.activation.atuinFrom1Password = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ${lib.escapeShellArg dataDir}

    if ! command -v op >/dev/null 2>&1; then
      echo "lcars: 'op' não está no PATH — atuin fica local, sem sync"
    elif [ -z "''${OP_SERVICE_ACCOUNT_TOKEN:-}" ] && ! op whoami >/dev/null 2>&1; then
      echo "lcars: sem login no 1Password — atuin fica local, sem sync"
    else
      ${lib.concatMapStringsSep "\n  " (s: ''
        if op read ${lib.escapeShellArg "op://${vault}/atuin/${s.campo}"} \
             > ${lib.escapeShellArg "${s.destino}.tmp"} 2>/dev/null; then
          chmod 600 ${lib.escapeShellArg "${s.destino}.tmp"}
          mv ${lib.escapeShellArg "${s.destino}.tmp"} ${lib.escapeShellArg s.destino}
        else
          rm -f ${lib.escapeShellArg "${s.destino}.tmp"}
          echo "lcars: atuin sem '${s.campo}' no 1Password (op://${vault}/atuin/${s.campo}) — sync desligado"
        fi
      '') segredos}
    fi
  '';
}
