# =====================================================================
# lcars — configuração desta instalação
#
# Este é o ÚNICO arquivo que você precisa editar, e o default básico do repo:
#
#   $EDITOR settings.nix
#   sudo nixos-rebuild switch --flake .#<máquina>
#
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
    # Só usado quando bootMode = "bios": o DISCO onde instalar o GRUB
    # ("/dev/sda"), não a partição. O instalador preenche sozinho ao detectar
    # boot legado; em UEFI fica vazio mesmo.
    #
    # Este campo precisa EXISTIR aqui, ainda que vazio: o install.sh o escreve
    # com `sed`, que só substitui linha já presente. Sem a linha, ele falharia
    # em silêncio — foi o que aconteceu na #15.
    grubDevice = "";
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
