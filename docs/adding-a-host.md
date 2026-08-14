# Adicionando um novo host

Não há registro manual no `flake.nix`. **Todo diretório dentro de `hosts/` vira
uma entrada em `nixosConfigurations`**, com duas exceções ignoradas pela
auto-descoberta: `common` (compartilhado por todos) e `template` (o modelo).

O nome do diretório também define `networking.hostName`, via `mkDefault` — o
host pode sobrescrever se quiser.

## Caminho curto: rodar o instalador na máquina nova

```bash
curl -fsSL https://raw.githubusercontent.com/insanemor/lcars/main/scripts/install.sh | sudo bash
```

Ele detecta o hardware, cria `hosts/<hostname>/` completo e ativa. Veja o
README para as variáveis de ambiente aceitas.

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

Para não responder nada:

```bash
LCARS_NONINTERACTIVE=yes ./scripts/bootstrap.sh
```

### 3. Crie o diretório do host

```bash
cp -r hosts/template hosts/$(hostname -s)
```

Em `hosts/<host>/default.nix`, ligue o que a máquina precisa:

| Opção | Quando ligar |
|---|---|
| `lcars.common.enable` | sempre |
| `lcars.desktop.enable` | GNOME, pipewire, fontes |
| `lcars.laptop.enable` | tem bateria |
| `lcars.vm.enable` | é guest QEMU/KVM |

E escolha o bootloader — isto **não** vem do `nixos-generate-config`:

```nix
lcars.common.bootLoader = "systemd-boot";   # UEFI
# lcars.common.bootLoader = "grub";         # BIOS legado
# lcars.common.grubDevice = "/dev/sda";
```

Outras opções úteis de `lcars.common`:

- `sshKeys` — chaves públicas autorizadas (o sshd só aceita chave)
- `initialPassword` — senha inicial do usuário, default `"lcars"`
- `swapFileSize` — MiB de `/swapfile`, se o hardware-config não trouxer swap
- `extraPackages` — nomes de pacotes nixpkgs, a nível de sistema

### 4. Gere a configuração de hardware

Na máquina **alvo**:

```bash
sudo nixos-generate-config --show-hardware-config > hosts/<host>/hardware-configuration.nix
```

É este arquivo que declara `fileSystems`, `swapDevices` e `boot.initrd` — os
módulos `lcars` não definem nada disso (o `modules/common` já definiu
`fileSystems."/"` fixo no passado, e isso colidia com o hardware real).

### 5. Torne os arquivos visíveis para o flake

```bash
git add -f vars/local.nix hosts/<host>
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

Dry-run primeiro:

```bash
sudo nixos-rebuild dry-activate --flake .#<host>
```

## Registrando um host com módulos extras

A auto-descoberta monta cada host sem extras. Se você quiser um host com
módulos adicionais fora da árvore, `mkHost` está exposto no flake:

```nix
nixosConfigurations.meu-pc = self.mkHost "meu-pc" [ ./algo-extra.nix ];
```

## Resolução de problemas

| Sintoma | Causa |
|---|---|
| `flake ... does not provide attribute nixosConfigurations.<host>` | O diretório `hosts/<host>` não existe, ou não foi adicionado ao index do git |
| Config sobe com usuário `your-username` | `vars/local.nix` não está rastreado pelo git — rode `git add -f vars/local.nix` |
| `path ... does not exist` no hardware-config | Mesma causa: falta `git add -f hosts/<host>/hardware-configuration.nix` |
| `detected dubious ownership in repository` | Rebuild como root num repo de outro dono: `sudo git config --global --add safe.directory ~/lcars` |
| `experimental Nix feature 'nix-command' is disabled` | `export NIX_CONFIG="experimental-features = nix-command flakes"` antes do rebuild |
| tlp e power-profiles-daemon em conflito | Escolha um: `lcars.laptop.powerManager = "tlp"` ou `"ppd"` |
