# profiles/ — presets nomeados de flags.
#
# Uma máquina diz o que ela É, não uma lista de módulos:
#
#   # machines/meu-pc/default.nix
#   lcars.profile = "personal";
#   lcars.system.wm.plasma.enable = false;  # override pontual, se quiser
#
# Todos os profiles são importados sempre; cada um só aplica suas flags quando
# `lcars.profile` casa com o seu nome. As flags são definidas com `mkDefault`,
# o que dá à máquina prioridade normal para sobrescrever qualquer uma delas
# individualmente, sem precisar copiar o profile inteiro.
#
# O profile governa os DOIS lados da máquina:
#
#   lcars.system.<caminho>   módulos NixOS de system/
#   lcars.user.<módulo>      módulos do Home Manager de user/
#
# Em ambos o caminho da flag espelha o do arquivo — `lcars.system.wm.plasma`
# é system/wm/plasma.nix, `lcars.user.direnv` é user/app/direnv.nix.
# `lcars.profile` fica na raiz por não pertencer a nenhum dos dois.
{ lib, ... }:

{
  imports = [
    ./basic
    ./personal
  ];

  options.lcars.profile = lib.mkOption {
    type = lib.types.enum [ "basic" "personal" ];
    default = "basic";
    description = ''
      Preset de flags desta máquina. Ao adicionar um profile novo, crie o
      diretório em profiles/, importe-o acima e inclua o nome neste enum.
    '';
  };
}
