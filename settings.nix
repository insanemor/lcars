# =====================================================================
# lcars — configuração desta instalação
#
# Este é o ÚNICO arquivo que você precisa editar, e o default básico do repo:
#
#   $EDITOR settings.nix
#   sudo nixos-rebuild switch --flake .#<máquina>
#
# É versionado, então editá-lo deixa o clone sujo — é o esperado. O que está
# aqui é o mínimo que o flake precisa. Os campos avançados são opcionais: sem
# eles, cada módulo usa o próprio default.
#
#   systemSettings.extraPackages   [ ]        pacotes nixpkgs no sistema
#   systemSettings.grubDevice      ""         disco do GRUB, quando bootMode = "bios"
#   systemSettings.swapFileSize    null       MiB de /swapfile
#   userSettings.packages          [ ]        pacotes só para o seu usuário
#   userSettings.sshKeys           [ ]        chaves autorizadas (o sshd só aceita chave)
#   userSettings.initialPassword   "lcars"    senha da primeira criação da conta
#   userSettings.gpgKey            null       chave SSH para assinar commits
#
# A máquina em si NÃO se configura aqui: quem define networking.hostName e o
# alvo do rebuild é o nome do diretório em machines/ (veja flake.nix), e as
# flags de hardware ficam em machines/<máquina>/default.nix.
# =====================================================================

{
  # -------------------------------------------------------------------
  # SISTEMA
  # -------------------------------------------------------------------
  systemSettings = {
    hostname = "nemor";
    profile = "personal";

    timezone = "America/Sao_Paulo";
    locale   = "pt_BR.UTF-8";

    bootMode = "uefi";
    bootMountPath = "/boot";
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
