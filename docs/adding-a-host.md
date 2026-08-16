# Adicionando uma nova máquina

Não há registro manual no `flake.nix`. **Todo diretório dentro de `machines/`
vira uma entrada em `nixosConfigurations`**, com uma exceção ignorada pela
auto-descoberta: `template`, que é o modelo a copiar.

O nome do diretório também define `networking.hostName`, via `mkDefault` — a
máquina pode sobrescrever se quiser.

## O encadeamento

```
machines/<host>/   escolhe um profile e ajusta o que é só dela
      ↓
profiles/<nome>/   liga um conjunto de flags (com mkDefault)
      ↓            ↓
system/<área>/     user/<módulo>.nix
lcars.system.…     lcars.user.…
módulos NixOS      módulos do Home Manager
```

O profile governa os **dois** lados, e em ambos o caminho da flag espelha o
caminho do arquivo:

| Flag | Módulo |
|---|---|
| `lcars.system.wm.plasma.enable` | `system/wm/plasma.nix` |
| `lcars.system.hardware.laptop.enable` | `system/hardware/laptop.nix` |
| `lcars.system.hardware.audio.enable` | `system/hardware/audio.nix` |
| `lcars.system.wm.hyprland.enable` | `system/wm/hyprland.nix` |
| `lcars.user.hyprland.enable` | `user/wm/hyprland.nix` |
| `lcars.user.direnv.enable` | `user/app/direnv.nix` |
| `lcars.user.dotfiles.enable` | `user/app/dotfiles.nix` |

`lcars.profile` fica na raiz, por não pertencer a nenhum dos dois lados.

Como o profile usa `mkDefault`, a máquina tem prioridade normal e sobrescreve
qualquer flag individualmente:

```nix
lcars.profile = "personal";             # quero o preset de desktop
lcars.system.wm.plasma.enable = false;  # …mas sem interface gráfica nesta aqui
lcars.user.dotfiles.enable = false;     # …e sem puxar dotfiles do 1Password
```

### Por que `lcars.user.*` é declarada do lado NixOS

`system/` e `user/` são avaliados em **árvores de módulos separadas**: em
`user/`, `config` é o config do Home Manager, onde `lcars.*` não existe. Um
profile é módulo NixOS, então não conseguiria escrever numa option declarada lá
dentro.

Por isso as cinco flags nascem em `user/options.nix`, que é importado no
`nixosSystem` (`flake.nix`), e cada módulo de `user/` as lê por `osConfig` — o
config do sistema, que o Home Manager expõe quando roda como módulo NixOS:

```nix
# user/app/direnv.nix
{ osConfig, lib, ... }:

lib.mkIf osConfig.lcars.user.direnv.enable {
  programs.direnv.enable = true;
}
```

Ao acrescentar um módulo em `user/`: declare a flag em `user/options.nix`,
importe-o em `user/default.nix`, envolva o corpo no `mkIf` e ligue-o nos
profiles que fizerem sentido. Sem a flag ligada, ele fica inerte.

## Caminho curto: rodar o instalador na máquina nova

```bash
curl -fsSL https://raw.githubusercontent.com/insanemor/lcars/main/scripts/install.sh | bash
```

Sem `sudo` na chamada — o repo tem que ser seu, e o script pede sudo sozinho
onde precisa.

Ele clona o repo em `~/.dotfiles` (via `nix-shell -p git`, então a máquina não
precisa ter git), dá à máquina o nome do **modelo do hardware**
(`/sys/devices/virtual/dmi/id/product_name`, com espaços virando hífens), cria
`machines/<modelo>/` completo, abre o `settings.nix` para você revisar e ativa.

Ele serve para a **primeira** máquina: o `git clone` falha se `~/.dotfiles` já
existir. Para acrescentar uma segunda máquina a um clone que você já tem — ou
para escolher o nome em vez de aceitar o modelo — use o caminho manual.

## Caminho manual

### 1. Clone o repo

```bash
git clone https://github.com/insanemor/lcars ~/.dotfiles
cd ~/.dotfiles
```

### 2. Edite o settings.nix

```bash
$EDITOR settings.nix
```

Ele **vem versionado** com o default básico — não há nada a gerar. Contém seu
usuário, nome completo, email, locale, profile e preferências do 1Password.
Editá-lo deixa o clone sujo; é o esperado.

O que está no arquivo é o mínimo que o flake precisa. Estes campos são
**opcionais** — sem eles, cada módulo usa o próprio default:

| Campo | Default | Para quê |
|---|---|---|
| `systemSettings.extraPackages` | `[ ]` | pacotes nixpkgs no sistema, por nome |
| `systemSettings.swapFileSize` | `null` | MiB de `/swapfile`, se o hardware-config não trouxer swap |
| `userSettings.packages` | `[ ]` | pacotes só para o seu usuário |
| `userSettings.sshKeys` | `[ ]` | chaves autorizadas — o sshd só aceita chave |
| `userSettings.initialPassword` | `"lcars"` | senha da primeira criação da conta |
| `userSettings.gpgKey` | `null` | chave SSH para assinar commits do git |

Acrescente ao `settings.nix` só o que for usar.

**O que NÃO fica aqui:** nada que descreva hardware. Bootloader, disco do GRUB,
VM, notebook e teclado moram em `machines/<host>/default.nix` — é o passo
seguinte. A divisão existe para o `settings.nix` nunca divergir entre clones:
se ele tivesse o que muda de máquina para máquina, todo `git pull` daria
conflito.

### 3. Crie o diretório da máquina

```bash
cp -r machines/template machines/meu-laptop
```

O nome do diretório é livre — só precisa ser um hostname válido (letras,
números e hífen). Ele vira `networking.hostName` e o alvo do rebuild, e é a
**única** fonte desse nome: não existe campo de hostname em lugar nenhum. O
instalador usa o modelo do DMI; na mão, use o que fizer sentido para você.

Profile, bootloader, locale e identidade vêm do `settings.nix`. Em
`machines/<host>/default.nix` fica só o que é desta máquina — e é aqui que
você diz o que ela é fisicamente, porque **nada disso é detectado**: o
template vem com as duas em `false`, tanto na mão quanto pelo instalador.

```nix
lcars.system.hardware.vm.enable     = false;  # true numa VM: virtio, qemu-guest-agent
lcars.system.hardware.laptop.enable = false;  # true num notebook: tlp, tampa, bateria
```

Áudio e teclado também vivem em `system/hardware/`, mas quem os liga é o
profile — eles não dependem da máquina física ser isto ou aquilo. O que muda de
máquina para máquina é o **layout**, e esse você declara aqui:

```nix
lcars.system.hardware.keyboard.layout  = "br";     # default: "us"
lcars.system.hardware.keyboard.variant = "abnt2";  # default: "intl"
```

Vale de uma vez no console e na sessão gráfica.

E os overrides, quando o mesmo repo serve mais de uma máquina — tudo que vem do
settings é aplicado com `mkDefault`, então declarar aqui vence:

```nix
lcars.profile         = "basic";   # esta máquina foge do settings
lcars.system.wm.plasma.enable = false;
```

### O boot também é declarado aqui

O bootloader **não** vem do `nixos-generate-config`: ele depende de a máquina
ter bootado em UEFI ou BIOS legado. O instalador detecta e preenche; na mão,
confira com `[ -d /sys/firmware/efi ] && echo uefi || echo bios`.

```nix
lcars.system.core.bootLoader = "systemd-boot";  # UEFI
# lcars.system.core.bootLoader = "grub";        # BIOS legado
# lcars.system.core.grubDevice = "/dev/sda";    # …e o DISCO, não a partição
```

O disco você descobre com `lsblk -no pkname "$(findmnt -no SOURCE /)"`. Com
`bootLoader = "grub"` e `grubDevice` vazio, a avaliação para numa assertion de
`system/core` dizendo exatamente isso — antes de o instalador do GRUB falhar de
um jeito mais obscuro.

Estas linhas **vêm descomentadas** no template, de propósito: o instalador as
reescreve com `sed`, que só substitui linha já presente.

Outras opções úteis:

| Opção | Para quê |
|---|---|
| `lcars.system.security.sshKeys` | chaves públicas autorizadas (o sshd só aceita chave) |
| `lcars.system.core.initialPassword` | senha inicial do usuário, default `"lcars"` |
| `lcars.system.core.swapFileSize` | MiB de `/swapfile`, se o hardware-config não trouxer swap |
| `lcars.system.core.extraPackages` | nomes de pacotes nixpkgs, a nível de sistema |
| `lcars.system.core.userPackages` | idem, no usuário — **somado** a `userSettings.packages` |
| `lcars.system.hardware.laptop.powerManager` | `"tlp"` ou `"ppd"` |
| `lcars.system.wm.defaultSession` | qual sessão abre por padrão: `"plasma"`, `"hyprland"`… |
| `lcars.system.hardware.keyboard.layout` / `.variant` | layout XKB, valendo no console e no gráfico |
| `lcars.system.hardware.audio.jack` | emulação JACK, para software de áudio profissional |

### 4. Gere a configuração de hardware

Na máquina **alvo**:

```bash
sudo nixos-generate-config --show-hardware-config > machines/<host>/hardware-configuration.nix
```

É este arquivo que declara `fileSystems`, `swapDevices` e `boot.initrd` — nada
disso é definido pelos módulos de `system/`.

O `cp -r` do passo anterior trouxe o `hardware-configuration.nix` de
`machines/template/`, que é só um placeholder — este comando o substitui pelo
real. Sobrescrever é o esperado.

### 5. Torne os arquivos visíveis para o flake

```bash
git add -f machines/<host>
```

Um flake dentro de um repo git só lê arquivos **rastreados**. O `settings.nix`
já é, mas `machines/<host>/hardware-configuration.nix` está no `.gitignore` —
sem o `-f`, o flake falha ao achar o hardware-config.

`git add` não é `git commit`. Mas o index é meio caminho: com o arquivo ali, um
`git commit` distraído o leva junto. Confira o `git status` antes de commitar
qualquer coisa neste repo.

### 6. Builde e ative

```bash
nixos-rebuild switch --flake .#<host> --elevate=sudo
```

## Criando um profile novo

1. `mkdir profiles/devops` e escreva o `default.nix`:

   ```nix
   { config, lib, ... }:
   with lib;
   {
     config = mkIf (config.lcars.profile == "devops") {
       # sistema
       lcars.system.core.enable      = mkDefault true;
       lcars.system.security.enable  = mkDefault true;
       lcars.system.wm.plasma.enable = mkDefault true;

       # ambiente do usuário
       lcars.user.zsh.enable      = mkDefault true;
       lcars.user.git.enable      = mkDefault true;
       lcars.user.direnv.enable   = mkDefault true;
       lcars.user.dotfiles.enable = mkDefault false;
     };
   }
   ```

2. Importe-o em `profiles/default.nix` e **acrescente o nome ao enum** de
   `lcars.profile` — sem isso a avaliação falha com um erro de tipo.

Declare **todas** as flags, inclusive as que ficam `false`. Como o default de
cada uma já é `false`, omitir funcionaria — mas o valor do profile está em ser
a lista completa: quem lê o arquivo vê o que a máquina tem e o que não tem, sem
precisar cruzar com os defaults.

Use sempre `mkDefault`. Sem ele, a máquina não consegue sobrescrever e os dois
viram um conflito de definição.

## Registrando uma máquina com módulos extras

A auto-descoberta monta cada máquina sem extras. Se quiser módulos adicionais
fora da árvore, `mkMachine` está exposto no flake:

```nix
nixosConfigurations.meu-pc = self.mkMachine "meu-pc" [ ./algo-extra.nix ];
```

## Resolução de problemas

| Sintoma | Causa |
|---|---|
| `does not provide attribute nixosConfigurations.<host>` | `machines/<host>` não existe, ou não foi adicionado ao index do git. Confira o nome exato com `ls machines/` — depois do instalador ele é o modelo do hardware, não o hostname antigo |
| `error: getting status of '/nix/store/…/settings.nix'` | O `settings.nix` foi apagado ou renomeado. Ele é obrigatório e versionado: recupere com `git checkout settings.nix` |
| `attribute 'sshKeys' missing` (ou outro campo) | Um módulo passou a exigir um campo que o seu `settings.nix` não tem. Acrescente-o, ou dê um default ao módulo com `user.<campo> or <valor>` |
| `path ... does not exist` no hardware-config | Falta `git add -f machines/<host>/hardware-configuration.nix` |
| Assertion `bootLoader = "grub" exige grubDevice` | Máquina em BIOS legado sem o disco declarado. Preencha `lcars.system.core.grubDevice` em `machines/<host>/default.nix` — descubra com `lsblk -no pkname "$(findmnt -no SOURCE /)"` |
| Conflito no `settings.nix` a cada `git pull` | Algum dado de máquina foi parar nele. Ele deve ficar **idêntico** ao do repositório; o que varia entre máquinas vai em `machines/<host>/default.nix` |
| `value is not a valid value of enum` em `lcars.profile` | Profile novo não foi acrescentado ao enum em `profiles/default.nix` |
| A máquina ignora o que declarei | O profile definiu a mesma flag; ele usa `mkDefault`, então declarar na máquina deve vencer — confira se não escreveu `mkDefault` na máquina também |
| `detected dubious ownership in repository` | Rebuild como root num repo de outro dono. Use `nixos-rebuild --elevate=sudo`, que avalia como você; o paliativo é `sudo git config --global --add safe.directory ~/.dotfiles` |
| `insufficient permission for adding an object to repository database` | Um `sudo nixos-rebuild` anterior deixou objetos do root em `.git/objects`. Destrave com `sudo chown -R "$USER" ~/.dotfiles` e passe a usar `--elevate=sudo` |
| `experimental Nix feature 'nix-command' is disabled` | `export NIX_CONFIG="experimental-features = nix-command flakes"` |
| tlp e power-profiles-daemon em conflito | `lcars.system.hardware.laptop.powerManager = "tlp"` ou `"ppd"` |
| O repo em `~/.dotfiles` pertence ao root e você não consegue editá-lo | O instalador foi chamado com `sudo`. Ele deve rodar como você: `curl … \| bash`, sem sudo. Conserte com `sudo chown -R "$USER" ~/.dotfiles` |
| A máquina virou `nixos` em vez do modelo | O DMI não expôs `product_name` (ARM, algumas VMs) e o instalador caiu no default. Renomeie `machines/nixos` para o nome que quiser e rode o rebuild apontando para ele |
| `git clone` falha com "already exists" | O instalador é só para a primeira máquina. Com o clone já no disco, siga o caminho manual acima |
