# xdg-user-dirs.nix — Desktop, Documentos, Imagens, Vídeos... em português,
# declarados, em vez de deixar por conta do que o xdg-user-dirs-update decidir
# rodar (ou não) no primeiro login gráfico.
#
# Por que isto existe
# --------------------
# `system/core/default.nix` já fixa `i18n.defaultLocale = "pt_BR.UTF-8"`, e o
# pacote `xdg-user-dirs` (que cria estas pastas a partir do locale) já vem
# com qualquer ambiente GNOME/freedesktop — mas ele roda por um serviço
# disparado no login gráfico, não pelo Home Manager, e nada aqui garantia que
# rodasse antes de algo procurar por `~/Vídeos`. Numa máquina recém-formatada,
# se esse serviço atrasar ou o locale ainda não tiver se propagado, os
# diretórios nascem em inglês (Videos, Pictures) — e `user/wm/noctalia.nix`
# aponta para os nomes em português (`video_directory`, `download_dir` do
# noctalia-config.toml), então o mpvpaper e o wallhaven simplesmente não
# encontram nada (issue #150).
#
# Declarar por `xdg.userDirs` resolve isso na ativação do Home Manager, antes
# de qualquer sessão gráfica existir, e cria os diretórios de propósito
# (`createDirectories = true`) em vez de só escrever o arquivo de mapeamento.
#
# Os nomes abaixo são os que `xdg-user-dirs-update` já produz sozinho com o
# locale pt_BR — não é uma escolha nova, é fixar o que já era o resultado
# esperado. `XDG_PROJECTS_DIR` não é um dos campos padrão do XDG (por isso
# `extraConfig`, e não uma opção nomeada): é uma extensão específica desta
# máquina, mantida pelo mesmo motivo dos outros.
{ osConfig, lib, ... }:

lib.mkIf osConfig.lcars.user.xdgUserDirs.enable {
  xdg.userDirs = {
    enable = true;
    createDirectories = true;

    desktop = "$HOME/Área de trabalho";
    documents = "$HOME/Documentos";
    download = "$HOME/Downloads";
    music = "$HOME/Músicas";
    pictures = "$HOME/Imagens";
    publicShare = "$HOME/Público";
    templates = "$HOME/Modelos";
    videos = "$HOME/Vídeos";

    extraConfig = {
      XDG_PROJECTS_DIR = "$HOME/Projetos";
    };
  };
}
