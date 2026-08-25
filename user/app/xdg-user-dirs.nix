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
# esperado.
{ osConfig, lib, ... }:

lib.mkIf osConfig.lcars.user.xdgUserDirs.enable {
  xdg.userDirs = {
    enable = true;
    createDirectories = true;

    # Explícito, e não o default: a partir de home.stateVersion 26.05 o
    # home-manager para de exportar XDG_PICTURES_DIR e companhia como
    # variável de ambiente. Nada neste repo lê essas variáveis diretamente,
    # mas seletores de arquivo GTK/Qt de terceiros costumam depender delas —
    # `true` mantém o comportamento que `xdg-user-dirs-update` sempre teve
    # (issue #153). Sem esta linha o eval avisa a cada rebuild.
    setSessionVariables = true;

    desktop = "$HOME/Área de trabalho";
    documents = "$HOME/Documentos";
    download = "$HOME/Downloads";
    music = "$HOME/Músicas";
    pictures = "$HOME/Imagens";
    projects = "$HOME/Projetos";
    publicShare = "$HOME/Público";
    templates = "$HOME/Modelos";
    videos = "$HOME/Vídeos";
  };
}
