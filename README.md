# lcars

Um flake NixOS multi-host, pensado para ser **forkável** — sem dados pessoais no repositório, mas pronto para lidar com identidade, secrets e dotfiles por máquina via **1Password** e Home Manager.

## Instalação — um comando

Numa máquina que já tem NixOS bootado:

```bash
curl -fsSL https://raw.githubusercontent.com/insanemor/lcars/main/scripts/install.sh | sudo bash
```

É só isso. O instalador não faz perguntas e cuida de tudo:

1. habilita flakes só para esta execução (o sistema atual não precisa já tê-los);
2. clona o repo em `~/lcars` do seu usuário — se `git` faltar, ele se reexecuta dentro de `nix shell nixpkgs#git`;
3. gera `vars/local.nix` com defaults derivados da máquina;
4. detecta o hardware — VM (`systemd-detect-virt`), notebook (`/sys/class/power_supply/BAT*`), UEFI vs BIOS legado — e escreve `hosts/<hostname>/default.nix` com os módulos certos ligados;
5. gera o `hardware-configuration.nix` real com `nixos-generate-config`;
6. registra os arquivos no index do git (flakes só leem arquivos rastreados);
7. roda `nixos-rebuild switch --flake .#<hostname>`.

A primeira build é longa — ela compila/baixa GNOME, 1Password e o mundo todo.

Ao final, o usuário fica com a senha inicial `lcars`. **Troque com `passwd` no primeiro login** — o sshd deste flake só aceita chave, mas o login local aceita senha.

### Ajustando o comportamento

Tudo por variável de ambiente, antes do `bash`:

| Var | Default | Efeito |
|---|---|---|
| `LCARS_HOST` | `hostname -s` | nome do host / diretório em `hosts/` |
| `LCARS_USER` | `$SUDO_USER` | usuário Linux a configurar |
| `LCARS_PROFILE` | `auto` | `auto`, `desktop` ou `minimal` (sem GNOME) |
| `LCARS_ACTION` | `switch` | `switch`, `boot`, `test`, `dry-activate` ou `none` |
| `LCARS_DEST` | `~/lcars` | onde clonar |
| `LCARS_REPO` | `github.com/insanemor/lcars` | repo (aceita URL completa) |
| `LCARS_BRANCH` | `main` | branch |
| `LCARS_FORCE` | `no` | `yes` reescreve `vars/local.nix` e `hosts/<host>/` |
| `LCARS_UPDATE` | `no` | `yes` faz fast-forward se o repo já existir |

Exemplo — ver o que aconteceria, sem ativar nada:

```bash
curl -fsSL https://raw.githubusercontent.com/insanemor/lcars/main/scripts/install.sh \
  | sudo LCARS_ACTION=dry-activate bash
```

O instalador é **idempotente**: rodar de novo não sobrescreve nada que você já editou, a não ser com `LCARS_FORCE=yes`.

### Sobre `git add -f`

`vars/local.nix` e `hosts/*/hardware-configuration.nix` estão no `.gitignore` — eles contêm dados da sua máquina. Mas um flake dentro de um repo git **só enxerga arquivos rastreados pelo git**, então o instalador os põe no *index* com `git add -f`. Isso não os commita.

Para você não commitá-los por acidente, o instalador também instala um hook `pre-commit` que aborta se algum deles entrar num commit.

## Por que um repo público-amigável?

Você não deveria precisar remover usuário, hostnames e dicas de SSH antes de dar `push` no GitHub. Cada pedaço específico de máquina vive num destes três lugares que nunca são commitados:

1. **`vars/local.nix`** — gerado automaticamente por `nix run .#bootstrap`
2. **1Password** — secrets e dotfiles pessoais (`.zshrc`, `.gitconfig`, …)
3. **`~/.config/home-manager/private.nix`** — overrides locais do Home Manager (escape hatch opcional)

## O que está aqui

```
.
├── flake.nix                # descobre hosts/ automaticamente e monta cada máquina
├── modules/                 # módulos NixOS genéricos, todos opt-in via lcars.<x>.enable
│   ├── default.nix          # agregador — importado em todo host
│   ├── common/              # locale, usuários, bootloader, pacotes base, ssh
│   ├── desktop/             # GNOME, pipewire, fontes
│   ├── laptop/              # tlp ou power-profiles-daemon, energia, suspensão
│   ├── vm/                  # ajustes para guest QEMU
│   └── onePassword/         # CLI + GUI + socket do agente SSH
├── hosts/                   # uma máquina por diretório
│   ├── common/              # aplicado em todo host
│   └── template/            # modelo (ignorado pela auto-descoberta)
├── home/                    # config do home-manager (zsh, git, starship, direnv)
│   ├── common/              # público, forkável
│   └── modules/personal/    # escape hatch via private.nix em $HOME
├── vars/
│   ├── example.nix          # template (valores padrão)
│   └── local.nix            # ignorado pelo git, com os seus valores
├── scripts/
│   ├── install.sh           # instalador one-shot
│   └── bootstrap.sh         # gerador de vars (interativo ou não)
└── docs/                    # adding-a-host.md, secrets.md
```

## Adicionando outra máquina

Não existe registro manual em `flake.nix`: **todo diretório em `hosts/` vira um `nixosConfiguration`** (exceto `common` e `template`), e `networking.hostName` recebe o nome do diretório.

A forma mais curta é rodar o instalador na máquina nova — ele cria o diretório sozinho. Para fazer à mão, veja [docs/adding-a-host.md](./docs/adding-a-host.md).

## Fluxo manual (se você prefere ver cada passo)

```bash
git clone https://github.com/insanemor/lcars ~/lcars && cd ~/lcars
nix run .#bootstrap                                   # preenche vars/local.nix
cp -r hosts/template hosts/meu-laptop
$EDITOR hosts/meu-laptop/default.nix                  # liga os módulos
sudo nixos-generate-config --show-hardware-config > hosts/meu-laptop/hardware-configuration.nix
git add -f vars/local.nix hosts/meu-laptop            # flakes só leem o que o git rastreia
sudo nixos-rebuild switch --flake .#meu-laptop
```

## 1Password

Depois do switch, o CLI e a GUI estão instalados. Abra `1password`, entre com email ou pareie via QR code, e ligue o agente SSH em **Settings → Developer**. O socket aparece em `~/.1password/agent.sock`, que o `ssh` do sistema já procura via `IdentityAgent`.

Não existe módulo NixOS para esse agente — ele é um recurso do próprio app. O que o flake faz é apontar o ssh para o socket.

## Por que 1Password e não um repo privado?

- Fonte única da verdade: secrets e dotfiles vivem no seu vault.
- Nada em texto plano — até caminhos locais referenciando secrets permanecem simbólicos.
- Forks continuam limpos.
- Se você sair desse modelo e quiser um repo privado sobreposto, a fiação já existe em `flake.nix` (basta descomentar `inputs.lcars-private`).

## Documentação

- [docs/adding-a-host.md](./docs/adding-a-host.md) — como adicionar outra máquina.
- [docs/secrets.md](./docs/secrets.md) — integração de secrets com 1Password e SOPS.

## Licença

Público-amigável: este repo foi feito pra ser **forkado**, então qualquer texto ou estrutura aqui pode ser adaptado. Licença MIT (veja `LICENSE`).
