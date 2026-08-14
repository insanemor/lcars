# =====================================================================
# lcars — configuração desta instalação
#
# Este é o ÚNICO arquivo que você precisa editar. Copie para `settings.nix`
# (o instalador faz isso por você) e ajuste o que quiser.
#
#   cp settings.example.nix settings.nix
#   $EDITOR settings.nix
#   sudo nixos-rebuild switch --flake .#<hostname>
#
# `settings.nix` está no .gitignore — ele tem os seus dados. Como flakes só
# leem arquivos rastreados pelo git, use `git add -f settings.nix` (o
# instalador também faz isso).
# =====================================================================

{
  # -------------------------------------------------------------------
  # SISTEMA
  # -------------------------------------------------------------------
  systemSettings = {
    # Nome desta máquina — registro de qual diretório de machines/ é o seu.
    #
    # Quem define networking.hostName e o alvo do rebuild é o NOME DO DIRETÓRIO
    # em machines/ (veja flake.nix), não este campo. O instalador escreve aqui
    # o mesmo nome que deu ao diretório: o modelo do hardware.
    # Para renomear a máquina, renomeie o diretório — e atualize isto aqui para
    # os dois não divergirem.
    hostname = "nixos";

    # Preset de flags. Veja profiles/ para o que cada um liga:
    #   "basic"    headless — base + ssh, sem interface gráfica
    #   "personal" desktop  — KDE Plasma, 1Password, ferramentas de linha de comando
    profile = "personal";

    timezone = "America/Sao_Paulo";
    locale   = "pt_BR.UTF-8";

    # "uefi" ou "bios". Se a máquina bootou por UEFI existe /sys/firmware/efi;
    # o instalador detecta isso sozinho. Em "bios", preencha grubDevice.
    bootMode = "uefi";

    # Só usado quando bootMode = "uefi".
    bootMountPath = "/boot";

    # Só usado quando bootMode = "bios". O DISCO, não a partição:
    # "/dev/sda", não "/dev/sda1".
    grubDevice = "";

    # Arquitetura. Mude só se não for PC de 64 bits.
    system = "x86_64-linux";

    # Pacotes extras no sistema (visíveis a todos os usuários).
    # Nomes de pacotes nixpkgs, como strings. Caminho aninhado funciona:
    # "kdePackages.kate".
    extraPackages = [
      # "tcpdump"
      # "nmap"
    ];

    # Tamanho em MiB de um /swapfile. null = não criar.
    # Só precisa se o hardware-configuration.nix não trouxer swap nenhum.
    swapFileSize = null;
  };

  # -------------------------------------------------------------------
  # USUÁRIO
  # -------------------------------------------------------------------
  userSettings = {
    username = "ins";
    fullName = "Seu Nome";
    email    = "voce@example.com";

    # Chave SSH para assinar commits do git. null = não assinar.
    # Formato: o conteúdo da chave pública, ou o caminho dela.
    gpgKey = null;

    # Senha inicial da conta, aplicada só na primeira criação.
    # TROQUE COM `passwd` NO PRIMEIRO LOGIN. null = não definir senha.
    initialPassword = "lcars";

    # Chaves públicas autorizadas a entrar por ssh. O sshd deste repo NÃO
    # aceita senha — enquanto esta lista estiver vazia, o acesso é só local.
    sshKeys = [
      # "ssh-ed25519 AAAA... voce@maquina"
    ];

    # Preferências. Viram variáveis de ambiente ($EDITOR, $BROWSER, $TERMINAL)
    # e são o que o instalador usa para abrir este arquivo.
    editor   = "vim";
    terminal = "konsole";
    browser  = "firefox";

    # Pacotes extras só para você (não aparecem para outros usuários).
    #
    # ATENÇÃO: o repo instala o Plasma "puro" — o que o módulo plasma6 do NixOS
    # traz, e mais nada. Não há navegador por padrão. Descomente o firefox
    # abaixo (ou ponha o seu) para não ficar sem, e lembre que `browser` acima
    # só define $BROWSER: ele não instala programa nenhum.
    packages = [
      # "firefox"
      # "kdePackages.kate"      # editor
      # "kdePackages.okular"    # leitor de PDF
      # "kdePackages.ark"       # compactador
      # "kdePackages.spectacle" # captura de tela
    ];

    # ---------------------------------------------------------------
    # 1Password
    # ---------------------------------------------------------------
    onePassword = {
      enableCli      = true;
      enableGui      = true;
      enableSshAgent = true;

      # Vault onde os itens Document dos dotfiles vivem.
      vault = "Personal";
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
