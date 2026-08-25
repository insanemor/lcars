# =====================================================================
# lcars — quem você é e o que você gosta
#
#   $EDITOR settings.nix
#   sudo nixos-rebuild switch --flake .#<máquina>
#
# Este arquivo é versionado e vale IGUAL em todas as suas máquinas. É por isso
# que nada aqui descreve hardware: bootloader, disco do GRUB, VM, notebook e
# teclado são fatos de cada máquina e moram em machines/<nome>/default.nix.
#
# A divisão existe para o `git pull` ser limpo. Se este arquivo tivesse o que
# muda de máquina para máquina, todo clone divergiria do repositório e cada
# atualização daria conflito.
# =====================================================================

{
  # -------------------------------------------------------------------
  # SISTEMA
  # -------------------------------------------------------------------
  systemSettings = {
    profile = "personal";

    timezone = "America/Sao_Paulo";
    locale = "pt_BR.UTF-8";

    # Arquitetura. Isto é fato da máquina, mas fica aqui por necessidade:
    # flake.nix o lê ANTES de montar o nixosSystem, então não pode vir de um
    # módulo. Mude só se não for PC de 64 bits.
    system = "x86_64-linux";
  };

  # -------------------------------------------------------------------
  # USUÁRIO
  # -------------------------------------------------------------------
  userSettings = {
    username = "ins";

    # fullName e email identificam você em git commits, GPG e no gerenciador
    # de login. O instalador os preenche na hora; os placeholders abaixo
    # existem para o repositório em si não carregar dado pessoal de ninguém —
    # editá-los aqui é esperado e é o que deixa o clone "sujo" de propósito
    # (ver cabeçalho do arquivo).
    fullName = "Seu Nome";
    email = "seu@email.com";

    # Alimenta EDITOR e VISUAL em system/core/default.nix. Não houve um par
    # para terminal e navegador: eles só definiam TERMINAL e BROWSER, que nada
    # neste repositório lia — quem abre link no desktop é o mimeapps do xdg, e
    # quem abre terminal é o atalho do compositor, cada um com o seu próprio
    # nome de pacote. Duas perguntas a menos no instalador (#157).
    editor = "nano";

    # ---------------------------------------------------------------
    # 1Password
    # ---------------------------------------------------------------
    onePassword = {
      enableCli = true;
      enableGui = true;
      enableSshAgent = true;

      # Vault onde os segredos deste repositório vivem: os itens Document dos
      # dotfiles e o item `atuin`. É o nome como ele aparece em `op vault list`
      # — confira lá antes de mudar. Um nome que não existe na conta não dá
      # erro de avaliação: o `op` é que reclama, na ativação, e o segredo
      # simplesmente não chega — foi o que aconteceu na #50, e de novo na #52
      # quando o vault mudou de nome do outro lado.
      vault = "Dotfiles";
    };

    # Dotfiles guardados como itens Document no 1Password. Cada nome aqui é
    # buscado em op://<vault>/dotfiles-<nome>/file e aparece em
    # ~/.config/dotfiles/<nome> na ativação.
    # Use nomes SEM "./".
    dotfilesFrom1Password = [
      # "zshrc"
      # "gitconfig"
    ];
  };
}
