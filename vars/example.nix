# Este arquivo é carregado pelo flake.nix como `args.vars`.
#
# Copie `vars/example.nix` para `vars/local.nix` e preencha os valores.
# `vars/local.nix` está no .gitignore — nunca faça commit dele.

{ lib }:

{
  # Quem você é. Usado pelo home-manager + defaults do git.
  username   = "your-username";
  fullName   = "Your Full Name";
  email      = "you@example.com";
  gpgKey     = null;        # opcional; "" desabilita

  # Locale / fuso — definidos explicitamente para que uma VM nova não
  # suba com os defaults do POSIX.
  timezone   = "America/Sao_Paulo";
  locale     = "pt_BR.UTF-8";

  # Identidade do host (também lido de /etc/hostname se null)
  defaultHostName = "nixos";

  # Integração com 1Password
  onePassword = {
    enableCli = true;
    enableGui = true;
    enableSshAgent = true;
    # usuário dono da polkit policy da GUI do 1Password
    polkitOwner = "your-username";
    # Vault onde os itens Document vivem (consumido por dotfilesFrom1Password).
    vault = "Personal";
  };

  # Arquivos desta lista viram arquivos gerenciados em ~/.config/dotfiles/<rel>,
  # populados a partir de Document do 1Password na ativação.
  # Caminho do Document:  op://<vault>/dotfiles-<rel>/file
  dotfilesFrom1Password = [
    # "./zshrc"     # → ~/.config/dotfiles/zshrc
    # "./gitconfig"
  ];

  # Pacotes extras do NixOS (nível de sistema)
  systemPackages = [
    # "git"
    # "vim"
  ];

  # Pacotes extras do home (nível de usuário)
  userPackages = [
    "zsh"
    "starship"
  ];
}
