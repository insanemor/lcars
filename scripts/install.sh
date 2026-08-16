#!/usr/bin/env bash

# Automated script to install my dotfiles

# Clone dotfiles
# TODO make ~/.dotfiles path arbitrary and make all other scripts conform to this
# using SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
nix-shell -p git --command "git clone https://github.com/insanemor/lcars.git ~/.dotfiles"

# Passo 1: Ler o nome do modelo do dispositivo
model_name=$(cat /sys/devices/virtual/dmi/id/product_name)
# Passo 2: Reduzir ao que um hostname aceita — [a-zA-Z0-9-] e nada mais.
# Trocar só espaços não basta: uma VM QEMU se apresenta como
# "Standard PC (Q35 + ICH9, 2009)", e parênteses, vírgula e + não são válidos
# em networking.hostName. Os dois `tr` viram tudo em hífen e colapsam os
# repetidos; o `sed` apara os das pontas.
model_name=$(printf '%s' "$model_name" | tr -c 'a-zA-Z0-9-' '-' | tr -s '-' | sed 's/^-//; s/-$//')
# Máquinas sem DMI legível (ARM, algumas VMs) não têm modelo: cai em "nixos"
model_name=${model_name:-nixos}
# Passo 3: Definir o diretório de destino
destination="$HOME/.dotfiles/machines/$model_name"
# Passo 4: Criar a máquina a partir do template (traz o default.nix que o flake importa)
cp -r ~/.dotfiles/machines/template "$destination"
# Generate hardware config for new system
# O redirecionamento é feito por você, não pelo sudo — e é o que queremos: o
# arquivo nasce com o seu dono, não do root. (SC2024)
# shellcheck disable=SC2024
sudo nixos-generate-config --show-hardware-config > "$destination/hardware-configuration.nix"
echo "Configuração de hardware salva em: $destination/hardware-configuration.nix"

# Dois arquivos, duas naturezas:
#
#   settings.nix                    quem você é — igual em todas as máquinas
#   machines/<nome>/default.nix     o que ESTA máquina é — boot, VM, notebook
#
# É por isso que o boot não vai para o settings.nix: assim ele nunca diverge
# do repositório, e o `git pull` de quem já instalou não conflita.
settings="$HOME/.dotfiles/settings.nix"
machine="$destination/default.nix"

# Escreve um campo num dos dois arquivos, e AVISA se não achou a linha.
#
# O sed só substitui o que já existe: se o campo for removido do arquivo, ele
# não faz nada e sai com status 0. Foi assim que grubDevice ficou vazio numa VM
# BIOS e o build morreu numa assertion lá adiante, sem pista de onde começou.
set_field() {
    local arquivo="$1" campo="$2" valor="$3" escapado

    if ! grep -qE "^[[:space:]]*${campo}[[:space:]]*=" "$arquivo"; then
        echo "AVISO: campo '$campo' não existe em $(basename "$arquivo") — não foi preenchido." >&2
        echo "       acrescente '$campo = \"$valor\";' à mão antes do rebuild." >&2
        return
    fi

    # Barra, & e contrabarra têm significado na substituição do sed. Sem isto,
    # um valor como "/dev/sda" faz o sed abortar com "opção desconhecida".
    escapado=$(printf '%s' "$valor" | sed 's/[\/&\\]/\\&/g')
    sed -i "0,/^\([[:space:]]*\)${campo}[[:space:]]*=.*/s//\1${campo} = \"${escapado}\";/" "$arquivo"

    # Conferir o resultado, não só a tentativa: é o que separa "o sed rodou" de
    # "o valor está lá". Qualquer forma de falha cai aqui.
    if ! grep -qF "${campo} = \"${valor}\";" "$arquivo"; then
        echo "AVISO: não consegui escrever '$campo' em $(basename "$arquivo")." >&2
        echo "       ajuste '$campo = \"$valor\";' à mão antes do rebuild." >&2
    fi
}

# --- o que ESTA máquina é: vai para machines/<nome>/default.nix -------
# Check if uefi or bios
if [ -d /sys/firmware/efi/efivars ]; then
    set_field "$machine" lcars.system.core.bootLoader systemd-boot
else
    set_field "$machine" lcars.system.core.bootLoader grub
    # O DISCO da raiz, não a partição: /dev/sda, não /dev/sda1.
    #
    # `findmnt -no SOURCE` devolve a partição direto, sem cabeçalho; o sed tira
    # o subvolume que btrfs acrescenta ("[/@]"). O disco sai do `lsblk` com a
    # partição como ARGUMENTO — antes ela ia por pipe, que o lsblk ignora, e
    # ele listava todos os discos do sistema para o `tail -n 1` pegar o último.
    # Numa máquina de um disco só isso acerta por acaso; com dois, instalaria
    # o GRUB no disco errado.
    root_part=$(findmnt -no SOURCE / | sed 's/\[.*\]//')
    root_disk=$(lsblk -no pkname "$root_part" 2>/dev/null | head -n 1)
    if [ -n "$root_disk" ]; then
        set_field "$machine" lcars.system.core.grubDevice "/dev/$root_disk"
    else
        echo "AVISO: não consegui descobrir o disco de '$root_part'." >&2
        echo "       preencha lcars.system.core.grubDevice em $machine." >&2
    fi
fi

# --- quem você é: vai para o settings.nix -----------------------------
# Só o username, e por necessidade: é ele que decide de quem é a conta criada
# pelo NixOS. Se o repo disser "ins" e quem instala for "maria", a maria fica
# sem home configurada.
#
# fullName NÃO é escrito. O campo GECOS costuma vir vazio ou truncado num
# NixOS recém-instalado, e sobrescrever um nome correto do settings.nix por um
# pior é o oposto de ajudar — além de fazer o arquivo divergir do repositório
# à toa. Quem preenche é você, no editor que abre logo abaixo.
#
# Não há hostname aqui: quem define networking.hostName é o nome do diretório
# em machines/, e um campo separado só criaria chance de divergirem.
set_field "$settings" username "$(whoami)"

# Open up editor to manually edit both files before install.
#
# O arquivo da máquina vem primeiro de propósito: é lá que estão as duas flags
# que NENHUMA detecção preenche — vm e laptop. Num notebook, deixá-las em false
# significa subir sem tlp, sem limite de carga da bateria e sem suspender ao
# fechar a tampa, tudo em silêncio.
if [ -z "$EDITOR" ]; then
    EDITOR=nano;
fi
echo
echo "Abrindo $machine — confira 'vm' e 'laptop', que ninguém detecta por você."
$EDITOR "$machine";
echo "Abrindo settings.nix — usuário, profile, chaves ssh, pacotes."
$EDITOR "$settings";

# Daqui para baixo tudo precisa do git, inclusive o rebuild — e numa máquina
# recém-instalada ele ainda não existe: só chega DEPOIS deste build, por
# system/core. Por isso o bloco inteiro roda dentro do nix-shell.
#
#   add -f          flakes só enxergam arquivos rastreados, e o
#                   hardware-configuration está no .gitignore. Põe no index,
#                   não é commit.
#   --elevate=sudo  NÃO use `sudo nixos-rebuild`: sob sudo é o root que lê a
#                   árvore pelo git, e ele escreve em .git/objects deixando os
#                   objetos com dono dele. O repositório fica travado para
#                   você no primeiro fetch que precise escrever. Com esta flag
#                   a avaliação roda como você e o root só ativa.
#
#                   Isso também dispensa o `safe.directory` que existia aqui:
#                   sem root lendo o repositório, não há "dubious ownership".
#
#                   O nome antigo, --use-remote-sudo, serve de reserva em
#                   versões mais velhas do nixos-rebuild.
#
# O home-manager entra como módulo neste mesmo rebuild — não há passo separado.
nix-shell -p git --command "
  set -e
  git -C $HOME/.dotfiles add -f machines/$model_name
  if nixos-rebuild --help 2>&1 | grep -q -- --elevate; then
    nixos-rebuild switch --flake $HOME/.dotfiles#$model_name --elevate=sudo
  else
    nixos-rebuild switch --flake $HOME/.dotfiles#$model_name --use-remote-sudo
  fi
"

# O clone lá em cima é HTTPS de propósito: numa máquina recém-instalada não
# existe chave SSH nenhuma, e clonar por SSH quebraria antes de tudo. Só que num
# remote HTTPS o git pede usuário e token a cada push, e o agente do 1Password
# nunca é consultado — ele só atende git@github.com. Agora que o sistema subiu,
# a troca vale.
#
# Derivado do remote atual, e não escrito à mão, para o fork de qualquer um
# continuar apontando para o repositório dele.
#
# Fora do nix-shell acima e sem `set -e`: a instalação já terminou, e falhar
# aqui não é motivo para o script sair com erro.
ssh_url=$(git -C "$HOME/.dotfiles" remote get-url origin | sed 's#https://github.com/#git@github.com:#')
git -C "$HOME/.dotfiles" remote set-url origin "$ssh_url"

cat <<AVISO

===============================================================
 Falta uma coisa, e ela é no 1Password — não dá para automatizar.

 O remote agora é SSH:

     $ssh_url

 Até você ligar o agente, nem 'nupdate' nem 'nsave' conseguem
 falar com o GitHub. São três passos:

   1. Abra o 1Password e entre na sua conta.

   2. Settings -> Developer -> ligue 'Use the SSH agent'.
      Se ainda não tiver uma chave, crie um item do tipo SSH Key.

   3. Copie a chave publica do item e adicione em
      github.com/settings/keys

 Depois, teste:

     ssh -T git@github.com

 Deve responder "Hi <voce>! You've successfully authenticated".

 Se precisar voltar ao HTTPS por qualquer motivo:

     git -C ~/.dotfiles remote set-url origin \\
       $(git -C "$HOME/.dotfiles" remote get-url origin | sed 's#git@github.com:#https://github.com/#')

===============================================================
AVISO
