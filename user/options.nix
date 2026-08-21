# --------------------------------------------------------------------
# Flags dos módulos do Home Manager — declaradas do lado NixOS.
#
# Por que este arquivo existe, e por que ele não vive dentro da árvore do
# Home Manager: `system/` e `user/` são avaliados em árvores de módulos
# SEPARADAS. Em `user/`, `config` é o config do Home Manager, onde `lcars.*`
# não existe — e um profile, que é módulo NixOS, não conseguiria escrever numa
# option declarada lá dentro.
#
# Então as flags nascem aqui, no config do NixOS, junto das de `system/`.
# É o que permite ao profile ligar os dois lados no mesmo lugar:
#
#   # profiles/personal/default.nix
#   lcars.system.wm.plasma.enable = mkDefault true;   # o desktop
#   lcars.user.direnv.enable      = mkDefault true;   # o meu shell
#
# Do outro lado da fronteira, cada módulo de user/ lê a flag por `osConfig`,
# que o Home Manager expõe justamente quando roda como módulo NixOS:
#
#   # user/app/direnv.nix
#   { osConfig, lib, ... }:
#   lib.mkIf osConfig.lcars.user.direnv.enable { ... }
#
# Todas vêm DESLIGADAS, como em system/: nada liga sozinho, quem decide é o
# profile. Para acrescentar um módulo em user/: declare a flag aqui, importe-o
# em user/default.nix, envolva o corpo no mkIf e ligue-o nos profiles.
# --------------------------------------------------------------------
{ lib, ... }:

{
  options.lcars.user = {
    zsh.enable = lib.mkEnableOption "o shell zsh do usuário — autosuggestion, syntax highlighting, histórico compartilhado e aliases";

    atuin.enable = lib.mkEnableOption "o histórico de comandos no atuin — busca no Ctrl+R e sync criptografado entre máquinas, com a chave vinda do 1Password";

    fzf.enable = lib.mkEnableOption "o fzf com integração no zsh — Ctrl+T (arquivos), Alt+C (diretórios) e completion difusa; o Ctrl+R fica com o atuin, não com o fzf";

    zoxide.enable = lib.mkEnableOption "o zoxide com integração no zsh — comandos z/zi pra pular a diretórios visitados antes; não substitui o cd nativo";

    git.enable = lib.mkEnableOption "a configuração do git — identidade vinda do settings.nix, aliases e assinatura por chave SSH";

    direnv.enable = lib.mkEnableOption "o direnv com nix-direnv, para shells por projeto";

    dotfiles.enable = lib.mkEnableOption "os dotfiles puxados de itens Document do 1Password na ativação";

    kitty.enable = lib.mkEnableOption "o terminal — a fonte e as cores vêm do stylix, via lcars.system.theme";

    vivaldi.enable = lib.mkEnableOption "o navegador Vivaldi — com codecs proprietários, Widevine e Wayland nativo; é ele que o \$BROWSER do settings.nix aponta";

    herdr.enable = lib.mkEnableOption "o multiplexador de terminal — workspaces, painéis e sessões persistentes, com os atalhos herdados do tmux (prefixo Ctrl-a)";

    nvim.enable = lib.mkEnableOption "o neovim como editor gráfico do usuário, com o plugin herdr-nvim carregado por init.lua — a sidebar do herdr abre este nvim no painel";

    claudeCode.enable = lib.mkEnableOption "o CLI do Claude Code — só o pacote no PATH; a configuração segue em ~/.claude, fora do store";

    crush.enable = lib.mkEnableOption "o agente CLI do Crush (charm.land) — só o pacote no PATH; um crushrc de bootstrap em ~/.config/crush serve de ponto de partida, sem chaves de API";

    opencode.enable = lib.mkEnableOption "o CLI do OpenCode (sst/opencode, \"OpenCode Go\") — pacote no PATH, provider MiniMax configurado em ~/.config/opencode/opencode.json, e a key puxada do 1Password na ativação (item op://Dotfiles/minimax token/token)";

    beeptui.enable = lib.mkEnableOption "o cliente TUI do Beeper Desktop (beeptui.com) — binário linux-x64 buscado da release do GitHub (não está no nixpkgs), requer o Beeper Desktop rodando localmente";

    niri.enable = lib.mkEnableOption "a configuração do niri — atalhos, forma e cores (o compositor é lcars.system.wm.niri)";

    noctalia.enable = lib.mkEnableOption "o shell do desktop — barra, launcher, notificações, lock e dock numa peça só; substitui waybar, rofi e swaync";

    noctalia.plugins.wallhaven.enable = lib.mkEnableOption "o plugin wallhaven do noctalia — painel de busca em wallhaven.cc que baixa e aplica o papel de parede escolhido";

    noctalia.plugins.nixMonitor.enable = lib.mkEnableOption "o plugin nix-monitor do noctalia — compara a revisão local do nixpkgs com um branch remoto e mostra gerações do NixOS, tamanho do store, tamanho do closure e status de atualização na barra";

    noctalia.plugins.niriDisplays.enable = lib.mkEnableOption "o plugin niri-displays do noctalia — inspeciona os outputs conectados e permite mudanças temporárias de display (resolução, taxa, escala, foco) via IPC do niri";

    noctalia.plugins.niriAnimations.enable = lib.mkEnableOption "o plugin niri-animations do noctalia — gerencia animações do niri por um painel, com presets e velocidade, sem editar configuração manualmente";

    noctalia.plugins.miniDocker.enable = lib.mkEnableOption "o plugin mini-docker do noctalia — gerencia containers, imagens, volumes e redes docker, com status na barra e controles em painel";

    noctalia.plugins.gitCompanion.enable = lib.mkEnableOption "o plugin git_companion do noctalia — monitora repositórios git na barra e dá acesso a pull requests e issues do GitHub e GitLab";

    noctalia.plugins.driveHealth.enable = lib.mkEnableOption "o plugin drive-health do noctalia — descobre SSDs e HDDs, mostra temperatura e uso de espaço montado, com SMART completo opcional";

    noctalia.plugins.aiUsagebar.enable = lib.mkEnableOption "o plugin ai-usagebar do noctalia — mostra a cota do plano de IA na barra, percentual de uso, tempo até reset e taxa de consumo";

    noctalia.plugins.mpvpaper.enable = lib.mkEnableOption "o plugin oficial mpvpaper do noctalia — papéis de parede animados ou em vídeo, mantendo barra e dock acima da camada de fundo";

    noctalia.plugins.notes.enable = lib.mkEnableOption "o plugin oficial notes do noctalia — notas rápidas num painel lateral em tela cheia, guardadas como arquivos de texto simples";

    yazi.enable = lib.mkEnableOption "o yazi (gerenciador de arquivos TUI) com o wrapper `y` no zsh — depois de navegar, o shell já fica dentro do diretório escolhido; o painel dentro do herdr é o plugin herdr-yazi";

    lazygit.enable = lib.mkEnableOption "o lazygit (TUI de git) com config versionado em ~/.config/lazygit/config.yml — painéis de stash, reflog e o command log escondidos; o popup no herdr é `prefix+Shift+g`";

    onedrive.enable = lib.mkEnableOption "o cliente OneDrive (abi-1/onedrive) com sync contínuo em ~/OneDrive — refresh_token materializado na ativação a partir do 1Password (item op://Dotfiles/onedrive/refresh_token)";

    onedrive.syncDir = lib.mkOption {
      type = lib.types.str;
      default = "~/OneDrive";
      description = "Diretório sincronizado pelo cliente OneDrive — vira `sync_dir` em ~/.config/onedrive/config, escrito declarativamente pelo Home Manager.";
    };

    sudoAskpass.enable = lib.mkEnableOption "o diálogo gráfico do sudo (zenity, via SUDO_ASKPASS) para quando um programa pede elevação sem terminal — ex.: o botão Update do plugin nix-monitor do noctalia; a senha continua obrigatória, só muda o canal de entrada";
  };
}
