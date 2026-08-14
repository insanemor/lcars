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
      ↓
system/<área>/     módulos NixOS, cada um opt-in por lcars.<caminho>.enable
```

Como o profile usa `mkDefault`, a máquina tem prioridade normal e sobrescreve
qualquer flag individualmente:

```nix
lcars.profile = "personal";      # quero o preset de desktop
lcars.wm.gnome.enable = false;   # …mas sem o GNOME nesta aqui
```

## Caminho curto: rodar o instalador na máquina nova

```bash
curl -fsSL https://raw.githubusercontent.com/insanemor/lcars/main/scripts/install.sh | sudo bash
```

Ele detecta o hardware, escolhe o profile, cria `machines/<hostname>/` completo
e ativa. Veja o README para as variáveis de ambiente aceitas.

## Caminho manual

### 1. Clone o repo

```bash
git clone https://github.com/insanemor/lcars ~/lcars
cd ~/lcars
```

### 2. Gere suas vars privadas

```bash
nix run .#bootstrap
# ou: ./scripts/bootstrap.sh
```

Isso escreve `vars/local.nix`, que está no `.gitignore`. Contém seu usuário,
nome completo, email, locale e preferências do 1Password.

Para não responder nada: `LCARS_NONINTERACTIVE=yes ./scripts/bootstrap.sh`

### 3. Crie o diretório da máquina

```bash
cp -r machines/template machines/$(hostname -s)
```

Em `machines/<host>/default.nix`, escolha o profile e ajuste o hardware:

```nix
lcars.profile = "personal";            # ou "basic"

lcars.hardware.vm.enable     = false;
lcars.hardware.laptop.enable = false;

lcars.core.bootLoader = "systemd-boot"; # UEFI
# lcars.core.bootLoader = "grub";       # BIOS legado
# lcars.core.grubDevice = "/dev/sda";
```

O bootloader **não** vem do `nixos-generate-config` — ele depende de a máquina
ter bootado em UEFI ou BIOS, e é você quem informa.

Outras opções úteis:

| Opção | Para quê |
|---|---|
| `lcars.security.sshKeys` | chaves públicas autorizadas (o sshd só aceita chave) |
| `lcars.core.initialPassword` | senha inicial do usuário, default `"lcars"` |
| `lcars.core.swapFileSize` | MiB de `/swapfile`, se o hardware-config não trouxer swap |
| `lcars.core.extraPackages` | nomes de pacotes nixpkgs, a nível de sistema |
| `lcars.core.userPackages` | idem, no usuário — **somado** a `vars.userPackages` |
| `lcars.hardware.laptop.powerManager` | `"tlp"` ou `"ppd"` |

### 4. Gere a configuração de hardware

Na máquina **alvo**:

```bash
sudo nixos-generate-config --show-hardware-config > machines/<host>/hardware-configuration.nix
```

É este arquivo que declara `fileSystems`, `swapDevices` e `boot.initrd` — nada
disso é definido pelos módulos de `system/`.

### 5. Torne os arquivos visíveis para o flake

```bash
git add -f vars/local.nix machines/<host>
```

Um flake dentro de um repo git só lê arquivos **rastreados**. Como
`vars/local.nix` e `hardware-configuration.nix` estão no `.gitignore`, sem o
`-f` o flake silenciosamente cai no `vars/example.nix` e falha ao achar o
hardware-config.

`git add` não é `git commit` — revise antes de dar push. O instalador coloca um
hook `pre-commit` que barra esses arquivos num commit.

### 6. Builde e ative

```bash
sudo nixos-rebuild switch --flake .#<host>
```

## Criando um profile novo

1. `mkdir profiles/devops` e escreva o `default.nix`:

   ```nix
   { config, lib, ... }:
   with lib;
   {
     config = mkIf (config.lcars.profile == "devops") {
       lcars.core.enable     = mkDefault true;
       lcars.security.enable = mkDefault true;
       lcars.wm.gnome.enable = mkDefault true;
     };
   }
   ```

2. Importe-o em `profiles/default.nix` e **acrescente o nome ao enum** de
   `lcars.profile` — sem isso a avaliação falha com um erro de tipo.

Use sempre `mkDefault` nas flags do profile. Sem ele, a máquina não consegue
sobrescrever e os dois viram um conflito de definição.

## Registrando uma máquina com módulos extras

A auto-descoberta monta cada máquina sem extras. Se quiser módulos adicionais
fora da árvore, `mkMachine` está exposto no flake:

```nix
nixosConfigurations.meu-pc = self.mkMachine "meu-pc" [ ./algo-extra.nix ];
```

## Resolução de problemas

| Sintoma | Causa |
|---|---|
| `does not provide attribute nixosConfigurations.<host>` | `machines/<host>` não existe, ou não foi adicionado ao index do git |
| Config sobe com usuário `your-username` | `vars/local.nix` não está rastreado — `git add -f vars/local.nix` |
| `path ... does not exist` no hardware-config | Falta `git add -f machines/<host>/hardware-configuration.nix` |
| `value is not a valid value of enum` em `lcars.profile` | Profile novo não foi acrescentado ao enum em `profiles/default.nix` |
| A máquina ignora o que declarei | O profile definiu a mesma flag; ele usa `mkDefault`, então declarar na máquina deve vencer — confira se não escreveu `mkDefault` na máquina também |
| `detected dubious ownership in repository` | Rebuild como root num repo de outro dono: `sudo git config --global --add safe.directory ~/lcars` |
| `experimental Nix feature 'nix-command' is disabled` | `export NIX_CONFIG="experimental-features = nix-command flakes"` |
| tlp e power-profiles-daemon em conflito | `lcars.hardware.laptop.powerManager = "tlp"` ou `"ppd"` |
