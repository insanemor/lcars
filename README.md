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
3. detecta o hardware — VM (`systemd-detect-virt`), notebook (`/sys/class/power_supply/BAT*`), UEFI vs BIOS — e gera o **`settings.nix`** já preenchido;
4. **abre o `settings.nix` no seu editor** para você revisar; ao salvar e fechar, é o que estiver no arquivo que vale — inclusive se você trocar o hostname ou o profile;
5. gera `machines/<hostname>/` com o `hardware-configuration.nix` real;
6. registra os arquivos no index do git (flakes só leem arquivos rastreados);
7. roda `nixos-rebuild switch --flake .#<hostname>`.

A primeira build de um desktop é longa — ela compila/baixa GNOME, 1Password e o mundo todo.

Ao final, o usuário fica com a senha inicial `lcars`. **Troque com `passwd` no primeiro login** — o sshd deste flake só aceita chave, mas o login local aceita senha.

### Ajustando o comportamento

Tudo por variável de ambiente, antes do `bash`:

| Var | Default | Efeito |
|---|---|---|
| `LCARS_HOST` | `hostname -s` | nome da máquina / diretório em `machines/` |
| `LCARS_USER` | `$SUDO_USER` | usuário Linux a configurar |
| `LCARS_PROFILE` | `auto` | valor inicial do profile no `settings.nix`; `auto` usa `basic` em VM |
| `LCARS_EDIT` | `yes` | `no` pula a abertura do editor |
| `LCARS_EDITOR` | — | editor a usar (default: o do `settings.nix`, senão `nano`/`vim`/`vi`) |
| `LCARS_ACTION` | `switch` | `switch`, `boot`, `test`, `dry-activate` ou `none` |
| `LCARS_DEST` | `~/lcars` | onde clonar |
| `LCARS_REPO` | `github.com/insanemor/lcars` | repo (aceita URL completa) |
| `LCARS_BRANCH` | `main` | branch |
| `LCARS_FORCE` | `no` | `yes` reescreve `settings.nix` e `machines/<host>/` |
| `LCARS_UPDATE` | `no` | `yes` faz fast-forward se o repo já existir |

Para inspecionar sem efeito colateral nenhum, use `LCARS_ACTION=none` — ele para antes do rebuild. (`dry-activate` **compila** o sistema inteiro; só não ativa.)

O instalador é **idempotente**: rodar de novo não sobrescreve nada que você já editou, a não ser com `LCARS_FORCE=yes`.

### Sobre `git add -f`

`settings.nix` e `machines/*/hardware-configuration.nix` estão no `.gitignore` — eles contêm dados da sua máquina. Mas um flake dentro de um repo git **só enxerga arquivos rastreados pelo git**, então o instalador os põe no *index* com `git add -f`. Isso não os commita.

Para você não commitá-los por acidente, o instalador também instala um hook `pre-commit` que aborta se algum deles entrar num commit.

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

**No profile `personal`** — GNOME com GDM, PipeWire, fontes Noto/Liberation/DejaVu,
Firefox, 1Password (CLI + GUI + agente SSH), e `ripgrep`, `fd`, `bat`, `eza`.

**Conforme o hardware** — em notebook, `tlp` com limite de carga 80–90% e
suspensão ao fechar a tampa; em VM, virtio, `qemu-guest-agent` e `spice-vdagent`.

## Como o repo é organizado

A árvore é dividida por **papel**, não por mecanismo do Nix:

```
.
├── flake.nix       # descobre machines/ automaticamente e monta cada uma
│
├── machines/       # uma máquina por diretório — o que ELA é
│   └── template/   # modelo a copiar (ignorado pela auto-descoberta)
│
├── profiles/       # presets: conjuntos nomeados de flags
│   ├── basic/      # headless: base + ssh
│   └── personal/   # desktop completo: GNOME + 1Password + ferramentas
│
├── system/         # módulos NixOS, opt-in via lcars.<caminho>.enable
│   ├── core/       # identidade, locale, boot, usuário
│   ├── security/   # sshd e firewall
│   ├── hardware/   # laptop.nix, vm.nix
│   ├── wm/         # gnome.nix
│   └── app/        # 1password/
│
├── user/           # módulos do Home Manager
│   ├── shell/      # zsh.nix, starship.nix
│   ├── app/        # git.nix, direnv.nix, dotfiles.nix
│   └── personal/   # escape hatch via private.nix em $HOME
│
├── settings.nix         # SUA configuração — o único arquivo que você edita
├── settings.example.nix # template versionado
├── scripts/        # install.sh (one-shot) e bootstrap.sh (gera o settings)
└── docs/
```

O encadeamento é: **a máquina escolhe um profile, o profile liga flags, as flags ativam módulos de `system/`.**

```nix
# machines/meu-pc/default.nix
lcars.profile = "personal";      # desktop completo
lcars.wm.gnome.enable = false;   # …exceto o GNOME
```

Os profiles definem as flags com `mkDefault`, então a máquina tem prioridade e pode sobrescrever qualquer uma **individualmente**, sem copiar o profile inteiro.

## Adicionando outra máquina

Não existe registro manual em `flake.nix`: **todo diretório em `machines/` vira um `nixosConfiguration`** (exceto `template`), e `networking.hostName` recebe o nome do diretório.

A forma mais curta é rodar o instalador na máquina nova — ele cria o diretório sozinho. Para fazer à mão, veja [docs/adding-a-host.md](./docs/adding-a-host.md).

## Fluxo manual (se você prefere ver cada passo)

```bash
git clone https://github.com/insanemor/lcars ~/lcars && cd ~/lcars
nix run .#bootstrap                                   # gera settings.nix
$EDITOR settings.nix                                  # hostname, profile, usuário…
cp -r machines/template machines/meu-laptop
sudo nixos-generate-config --show-hardware-config > machines/meu-laptop/hardware-configuration.nix
git add -f settings.nix machines/meu-laptop           # flakes só leem o que o git rastreia
sudo nixos-rebuild switch --flake .#meu-laptop
```

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
