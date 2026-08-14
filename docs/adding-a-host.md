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
lcars.wm.plasma.enable = false;  # …mas sem interface gráfica nesta aqui
```

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

### 2. Gere o settings.nix

```bash
./scripts/bootstrap.sh
# com o repo já clonado, `nix run .#bootstrap` é equivalente
```

Isso escreve `settings.nix`, que está no `.gitignore`. Contém seu usuário,
nome completo, email, locale e preferências do 1Password.

Ele pergunta cada campo, oferecendo um default detectado da máquina. Para não
responder nada: `LCARS_NONINTERACTIVE=yes ./scripts/bootstrap.sh`. Para
recomeçar um `settings.nix` que já existe: `LCARS_FORCE=yes`.

### 3. Crie o diretório da máquina

```bash
cp -r machines/template machines/meu-laptop
```

O nome do diretório é livre — só precisa ser um hostname válido (letras,
números e hífen). Ele vira `networking.hostName` e o alvo do rebuild. O
instalador usa o modelo do DMI; na mão, use o que fizer sentido para você. Vale
apontar `systemSettings.hostname` para o mesmo nome, para os dois não
divergirem.

Profile, bootloader, locale e identidade vêm do `settings.nix`. Em
`machines/<host>/default.nix` fica só o que é desta máquina — e é aqui que
você diz o que ela é fisicamente, porque **nada disso é detectado**: o
template vem com as duas em `false`, tanto na mão quanto pelo instalador.

```nix
lcars.hardware.vm.enable     = false;  # true numa VM: virtio, qemu-guest-agent
lcars.hardware.laptop.enable = false;  # true num notebook: tlp, tampa, bateria
```

E os overrides, quando o mesmo repo serve mais de uma máquina — tudo que vem do
settings é aplicado com `mkDefault`, então declarar aqui vence:

```nix
lcars.profile         = "basic";   # esta máquina foge do settings
lcars.wm.plasma.enable = false;
```

O bootloader **não** vem do `nixos-generate-config` — ele depende de a máquina
ter bootado em UEFI ou BIOS. É o campo `bootMode` do settings, e tanto o
instalador quanto o `bootstrap.sh` o detectam, junto com o `grubDevice` quando
o boot é BIOS legado.

Outras opções úteis:

| Opção | Para quê |
|---|---|
| `lcars.security.sshKeys` | chaves públicas autorizadas (o sshd só aceita chave) |
| `lcars.core.initialPassword` | senha inicial do usuário, default `"lcars"` |
| `lcars.core.swapFileSize` | MiB de `/swapfile`, se o hardware-config não trouxer swap |
| `lcars.core.extraPackages` | nomes de pacotes nixpkgs, a nível de sistema |
| `lcars.core.userPackages` | idem, no usuário — **somado** a `userSettings.packages` |
| `lcars.hardware.laptop.powerManager` | `"tlp"` ou `"ppd"` |

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
git add -f settings.nix machines/<host>
```

Um flake dentro de um repo git só lê arquivos **rastreados**. Como
`settings.nix` e `hardware-configuration.nix` estão no `.gitignore`, sem o
`-f` o flake silenciosamente cai no `settings.example.nix` e falha ao achar o
hardware-config.

`git add` não é `git commit`. Mas o index é meio caminho: com os dois arquivos
ali, um `git commit` distraído os leva junto. Confira o `git status` antes de
commitar qualquer coisa neste repo.

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
       lcars.wm.plasma.enable = mkDefault true;
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
| `does not provide attribute nixosConfigurations.<host>` | `machines/<host>` não existe, ou não foi adicionado ao index do git. Confira o nome exato com `ls machines/` — depois do instalador ele é o modelo do hardware, não o hostname antigo |
| Config sobe com o usuário `ins` e hostname `nixos` | `settings.nix` não está rastreado, e o flake caiu no `settings.example.nix` — `git add -f settings.nix` |
| `path ... does not exist` no hardware-config | Falta `git add -f machines/<host>/hardware-configuration.nix` |
| `value is not a valid value of enum` em `lcars.profile` | Profile novo não foi acrescentado ao enum em `profiles/default.nix` |
| A máquina ignora o que declarei | O profile definiu a mesma flag; ele usa `mkDefault`, então declarar na máquina deve vencer — confira se não escreveu `mkDefault` na máquina também |
| `detected dubious ownership in repository` | Rebuild como root num repo de outro dono: `sudo git config --global --add safe.directory ~/.dotfiles` |
| `experimental Nix feature 'nix-command' is disabled` | `export NIX_CONFIG="experimental-features = nix-command flakes"` |
| tlp e power-profiles-daemon em conflito | `lcars.hardware.laptop.powerManager = "tlp"` ou `"ppd"` |
| O repo em `~/.dotfiles` pertence ao root e você não consegue editá-lo | O instalador foi chamado com `sudo`. Ele deve rodar como você: `curl … \| bash`, sem sudo. Conserte com `sudo chown -R "$USER" ~/.dotfiles` |
| A máquina virou `nixos` em vez do modelo | O DMI não expôs `product_name` (ARM, algumas VMs) e o instalador caiu no default. Renomeie `machines/nixos` para o nome que quiser e rode o rebuild apontando para ele |
| `git clone` falha com "already exists" | O instalador é só para a primeira máquina. Com o clone já no disco, siga o caminho manual acima |
