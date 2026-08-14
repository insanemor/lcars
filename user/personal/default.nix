# user/personal — escape hatch.
#
# Caso algum dia você queira manter dotfiles pessoais FORA do repo público
# sem criar um segundo repositório git, o Home Manager já suporta um
# caminho de "private":
#
#   ~/.config/home-manager/private.nix
#
# Tudo que você colocar ali é carregado DEPOIS dos módulos públicos
# deste repo e mesclado. Usos comuns:
#
#   - Aliases pessoais referenciando $HOME/<caminho-secreto>
#   - Overrides de configuração SSH
#   - Ferramentas só de um host (ex.: apps pessoais de cripto)
#   - Paths/arquivos ligados a SSO/secrets só do 1Password
#
# Até você criar esse arquivo, a lista de imports abaixo fica vazia.
# Manter esse stub no repo público deixa o caminho pronto para o dia
# em que você decidir não commitar coisas pessoais.
{ ... }:

{
  imports = [
    # "${config.home.homeDirectory}/.config/home-manager/private.nix"
  ];
}
