# lcars

Um flake NixOS multi-host, pensado para ser **forkável** — sem dados pessoais no repositório, mas pronto para lidar com identidade, secrets e dotfiles por máquina via **1Password** e Home Manager.

## Instalação — um comando

Numa máquina que já tem NixOS bootado:

```bash
curl -fsSL https://raw.githubusercontent.com/insanemor/lcars/main/scripts/install.sh | bash
```

**Sem `sudo` na chamada.** O repositório fica no seu `$HOME` e precisa pertencer a você; o script pede sudo sozinho onde precisa dele.

O que ele faz, em ordem — [`scripts/install.sh`](./scripts/install.sh) tem 50 linhas e dá para ler inteiro antes de rodar:

1. **clona o repositório em `~/.dotfiles`**, usando `nix-shell -p git` — a máquina não precisa ter `git` instalado, e daqui em diante tudo acontece dentro do clone;
2. lê o **modelo do hardware** em `/sys/devices/virtual/dmi/id/product_name` e troca espaços por hífens: esse é o nome da máquina;
3. cria `machines/<modelo>/` copiando `machines/template/`, e grava ali o `hardware-configuration.nix` real (`nixos-generate-config`);
4. copia `settings.example.nix` para **`settings.nix`** e preenche o que dá para descobrir: o nome da máquina, o seu usuário, o seu nome completo (do GECOS), e UEFI vs BIOS — com o disco do grub, quando for BIOS legado;
5. **abre o `settings.nix` no seu editor** — é a sua chance de mexer em profile, chaves SSH, pacotes e 1Password antes de qualquer build;
6. registra `settings.nix` e `machines/<modelo>/` no index do git (flakes só leem arquivos rastreados);
7. roda `nixos-rebuild switch --flake ~/.dotfiles#<modelo>`.

Não há passo separado para o Home Manager: ele entra como módulo NixOS no mesmo rebuild.

A primeira build de um desktop é longa — ela compila/baixa o Plasma, o 1Password e o mundo todo.

Ao final, o usuário fica com a senha inicial `lcars`. **Troque com `passwd` no primeiro login** — o sshd deste flake só aceita chave, mas o login local aceita senha.

### O nome da máquina é o modelo do hardware

O diretório criado em `machines/` recebe o modelo relatado pelo DMI — `20BE0048BR`, `MS-7C56`, `OptiPlex-7070`. Como o `flake.nix` deriva `networking.hostName` do nome do diretório, é também assim que a máquina passa a se chamar, e é o alvo do rebuild:

```bash
sudo nixos-rebuild switch --flake ~/.dotfiles#20BE0048BR
```

Não gostou? Renomeie o diretório e ajuste o `hostname` no `settings.nix` para não divergirem:

```bash
cd ~/.dotfiles
git mv machines/20BE0048BR machines/thinkpad
sudo nixos-rebuild switch --flake .#thinkpad
```

### O instalador é para a primeira vez

Ele não foi feito para rodar duas vezes: o `git clone` falha se `~/.dotfiles` já existir, e um segundo `settings.nix` sobrescreveria o que você editou. Depois da instalação o ciclo é outro — editar `settings.nix` e rodar `nixos-rebuild`:

```bash
cd ~/.dotfiles
$EDITOR settings.nix
sudo nixos-rebuild switch --flake .#<modelo>
```

Para uma máquina nova a partir de um clone que já existe, siga o [caminho manual](./docs/adding-a-host.md#caminho-manual).

### Sobre `git add -f`

`settings.nix` e `machines/*/hardware-configuration.nix` estão no `.gitignore` — eles contêm dados da sua máquina. Mas um flake dentro de um repo git **só enxerga arquivos rastreados pelo git**, então o instalador os põe no *index* com `git add -f`. Isso não os commita — mas deixa os dois prontos para entrar num commit distraído, então confira o `git status` antes de commitar.

## O que vem instalado

Resumo. O inventário completo, com o arquivo que define cada item, está em
[docs/features.md](./docs/features.md).

**Em toda máquina** — flakes habilitados e coleta de lixo semanal, locale
`pt_BR.UTF-8`, NetworkManager, usuário com `zsh`, sshd **somente por chave** com
firewall ligado, e a base de linha de comando (`git`, `vim`, `htop`, `curl`,
`wget`, `jq`, `rsync`, `python3`).

**No ambiente do usuário** (Home Manager, no mesmo rebuild) — zsh com
autosuggestion, syntax highlighting e histórico compartilhado; prompt starship;
git com aliases e `pull.rebase`; direnv com nix-direnv; e o gancho para puxar
dotfiles de itens Document do 1Password.

**No profile `personal`** — KDE Plasma 6 com SDDM, PipeWire, fontes
Noto/Liberation/DejaVu, 1Password (CLI + GUI + agente SSH), e `ripgrep`, `fd`,
`bat`, `eza`. O Plasma vem "puro", sem aplicativos extras — **inclusive sem
navegador**; acrescente o seu em `userSettings.packages`.

**Conforme o hardware** — em notebook, `tlp` com limite de carga 80–90% e
suspensão ao fechar a tampa; em VM, virtio, `qemu-guest-agent` e `spice-vdagent`.

## Como o repo é organizado

A árvore é dividida por **papel**, não por mecanismo do Nix:

```
.
├── flake.nix       # descobre machines/ automaticamente e monta cada uma
│
├── machines/       # uma máquina por diretório — o que ELA é
│   └── template/   # modelo que o instalador copia (fora da auto-descoberta)
│
├── profiles/       # presets: conjuntos nomeados de flags
│   ├── basic/      # headless: base + ssh
│   └── personal/   # desktop completo: Plasma + 1Password + ferramentas
│
├── system/         # módulos NixOS, opt-in via lcars.<caminho>.enable
│   ├── core/       # identidade, locale, boot, usuário
│   ├── security/   # sshd e firewall
│   ├── hardware/   # laptop.nix, vm.nix
│   ├── wm/         # plasma.nix
│   └── app/        # 1password/
│
├── user/           # módulos do Home Manager
│   ├── shell/      # zsh.nix, starship.nix
│   ├── app/        # git.nix, direnv.nix, dotfiles.nix
│   └── personal/   # escape hatch via private.nix em $HOME
│
├── settings.nix         # SUA configuração — o único arquivo que você edita
├── settings.example.nix # template versionado
├── scripts/        # install.sh (clona e instala) e bootstrap.sh (settings.nix na mão)
└── docs/
```

O encadeamento é: **a máquina escolhe um profile, o profile liga flags, as flags ativam módulos de `system/`.**

```nix
# machines/meu-pc/default.nix
lcars.profile = "personal";      # desktop completo
lcars.wm.plasma.enable = false;  # …exceto o Plasma
```

Os profiles definem as flags com `mkDefault`, então a máquina tem prioridade e pode sobrescrever qualquer uma **individualmente**, sem copiar o profile inteiro.

## Adicionando outra máquina

Não existe registro manual em `flake.nix`: **todo diretório em `machines/` vira um `nixosConfiguration`** (exceto `template`), e `networking.hostName` recebe o nome do diretório.

A forma mais curta é rodar o instalador na máquina nova — ele clona o repo e cria o diretório sozinho, com o modelo do hardware por nome. Para fazer à mão, veja [docs/adding-a-host.md](./docs/adding-a-host.md).

## Fluxo manual (se você prefere ver cada passo)

O instalador não faz nada que você não possa fazer na mão. Aqui, escolhendo o nome da máquina em vez de aceitar o modelo do DMI:

```bash
git clone https://github.com/insanemor/lcars ~/.dotfiles && cd ~/.dotfiles
./scripts/bootstrap.sh                                # gera settings.nix, perguntando
$EDITOR settings.nix                                  # profile, usuário, chaves ssh…
cp -r machines/template machines/meu-laptop
sudo nixos-generate-config --show-hardware-config > machines/meu-laptop/hardware-configuration.nix
git add -f settings.nix machines/meu-laptop           # flakes só leem o que o git rastreia
sudo nixos-rebuild switch --flake .#meu-laptop
```

A diferença para o instalador: aqui você escolhe o nome da máquina, e o `bootstrap.sh` **pergunta** cada campo em vez de preencher direto — inclusive o profile, que ele propõe como `basic` em VM e `personal` fora dela. Com o repo já clonado, `nix run .#bootstrap` faz o mesmo que `./scripts/bootstrap.sh`.

## 1Password

No profile `personal`, o CLI e a GUI vêm instalados. Abra `1password`, entre com email ou pareie via QR code, e ligue o agente SSH em **Settings → Developer**. O socket aparece em `~/.1password/agent.sock`, que o `ssh` do sistema já procura via `IdentityAgent`.

Não existe módulo NixOS para esse agente — ele é um recurso do próprio app. O que o flake faz é apontar o ssh para o socket.

## Por que 1Password e não um repo privado?

- Fonte única da verdade: secrets e dotfiles vivem no seu vault.
- Nada em texto plano — até caminhos locais referenciando secrets permanecem simbólicos.
- Forks continuam limpos.
- Se você sair desse modelo e quiser um repo privado sobreposto, a fiação já existe em `flake.nix` (basta descomentar `inputs.lcars-private`).

## Documentação

Índice completo em [docs/](./docs/README.md).

- [docs/features.md](./docs/features.md) — inventário do que vem instalado.
- [docs/adding-a-host.md](./docs/adding-a-host.md) — adicionar outra máquina e criar profiles.
- [docs/secrets.md](./docs/secrets.md) — 1Password, dotfiles e opnix.
- [docs/workflow.md](./docs/workflow.md) — como mudanças entram no repo.

## Licença

Público-amigável: este repo foi feito pra ser **forkado**, então qualquer texto ou estrutura aqui pode ser adaptado. Licença MIT (veja `LICENSE`).
