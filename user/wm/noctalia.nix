# noctalia.nix — o shell do desktop.
#
# Barra, launcher, notificações, tela de bloqueio, dock, OSD e histórico de
# área de transferência, numa peça só. Substituiu waybar + swaync + rofi, que
# eram três módulos com três formatos de configuração e nenhuma interface de
# ajuste.
#
# O ciclo de ajuste
# -----------------
# É o motivo de ele estar aqui. Você mexe no centro de controle, olha o
# resultado na hora, e quando gostar:
#
#     nsave        # exporta, valida, mostra o diff, pergunta e publica
#
# É o scripts/save.sh, o caminho de volta do nupdate. Sem ele, o que você
# ajustou vive só no state-dir daquela máquina e some num clone novo — ou no
# próximo nupdate, que faz git reset --hard.
#
# Por que `fromTOML` e não `settings = ./arquivo.toml`
# ----------------------------------------------------
# A option aceita um caminho, mas aí a definição inteira vira um valor só, e o
# stylix também escreve em `programs.noctalia.settings`. Caminho e attrset não
# se fundem: uma das duas definições venceria por completo. Lido como attrset,
# os dois se combinam chave a chave.
#
# Por que não `mkDefault`
# -----------------------
# Foi a primeira tentativa e está errada. A prioridade é resolvida *antes* da
# fusão e vale para a definição inteira: `mkDefault` sobre o attrset todo o
# marca com prioridade 1000, e como o stylix define na prioridade normal (100),
# o attrset inteiro era descartado — o arquivo daqui não chegava a existir na
# configuração final. Verificado com `nix eval`: sem isto, nem
# `settings.shell.settings_show_advanced` sobrevivia.
#
# Definido na prioridade normal, os dois lados fundem por chave. O preço é que
# uma chave definida dos dois lados vira erro de conflito — daí a lista abaixo.
{
  osConfig,
  lib,
  ...
}:

let
  arquivo = ./noctalia-config.toml;

  # Os caminhos que o stylix escreve dentro de `settings` (stylix,
  # modules/noctalia/hm.nix). O stylix os escreve no config dir, e é de lá que
  # `noctalia config export merged` lê — então eles voltam no export, e aí os
  # dois lados definiriam a mesma chave, o que o sistema de módulos trata como
  # conflito e aborta.
  #
  # Retirá-los do que exportamos é o que mantém o ciclo GUI → export → commit
  # funcionando sem você ter que lembrar de editar o arquivo à mão.
  gerenciadosPeloStylix = [
    [
      "theme"
      "source"
    ]
    [
      "theme"
      "custom_palette"
    ]
    [
      "theme"
      "mode"
    ]
    [
      "shell"
      "font_family"
    ]
    [
      "wallpaper"
      "default"
      "path"
    ]
    [
      "dock"
      "background_opacity"
    ]
    [
      "notification"
      "background_opacity"
    ]
    [
      "osd"
      "background_opacity"
    ]
  ];

  removerCaminho =
    attrs: caminho:
    let
      chave = builtins.head caminho;
      resto = builtins.tail caminho;
    in
    if !(attrs ? ${chave}) then
      attrs
    else if resto == [ ] then
      builtins.removeAttrs attrs [ chave ]
    else if builtins.isAttrs attrs.${chave} then
      attrs // { ${chave} = removerCaminho attrs.${chave} resto; }
    else
      attrs;

  exportado = builtins.fromTOML (builtins.readFile arquivo);

  # Só poda quando o stylix está de fato no ar. Com o tema desligado ninguém
  # define essas chaves, e removê-las jogaria fora escolha sua sem substituto.
  temaLigado = osConfig.lcars.system.theme.enable;
in
lib.mkIf osConfig.lcars.user.noctalia.enable {
  programs.noctalia = {
    enable = true;

    # Por serviço, não por exec-once do compositor: reinicia se cair e responde
    # a `systemctl --user status noctalia`. Veja a regra no CLAUDE.md.
    systemd.enable = true;

    settings =
      if temaLigado then builtins.foldl' removerCaminho exportado gerenciadosPeloStylix else exportado;
  };
}
