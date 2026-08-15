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
    locale   = "pt_BR.UTF-8";

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
    fullName = "Rodrigo Moreira";
    email    = "moreira@zaia.com.br";

    editor   = "nano";
    terminal = "konsole";
    browser  = "firefox";

    # ---------------------------------------------------------------
    # 1Password
    # ---------------------------------------------------------------
    onePassword = {
      enableCli      = true;
      enableGui      = true;
      enableSshAgent = true;

      # Vault onde os itens Document dos dotfiles vivem.
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
