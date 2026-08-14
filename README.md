# lcars

Um flake NixOS multi-host, pensado para ser **forkável** — sem dados pessoais no repositório, mas pronto para lidar com identidade, secrets e dotfiles por máquina via **1Password** e Home Manager.

## Por que um repo público-amigável?

Você não deveria precisar remover usuário, hostnames e dicas de SSH antes de dar `push` no GitHub. Cada pedaço específico de máquina vive num destes três lugares que nunca são commitados:

1. **`vars/local.nix`** — gerado automaticamente por `nix run .#bootstrap`
2. **1Password** — secrets e dotfiles pessoais (`.zshrc`, `.gitconfig`, …)
3. **`~/.config/home-manager/private.nix`** — overrides locais do Home Manager (escape hatch opcional)

## O que está aqui

```
.
├── flake.nix                # fábrica: `mkHost` monta qualquer host a partir de common + per-host + extras
├── modules/                 # módulos NixOS genéricos e compartilháveis
│   ├── common/              # locale, usuários, pacotes base, integração 1Password
│   ├── desktop/             # GNOME, fontes, áudio
│   ├── laptop/              # tlp, energia, suspensão
│   ├── vm/                  # ajustes para guest QEMU
│   └── onePassword/         # CLI + GUI + agente SSH
├── hosts/                   # configuração por máquina (você adiciona um por máquina)
│   ├── common/              # aplicado em todo host
│   └── template/            # copie este ao adicionar uma nova máquina
├── home/                    # config do home-manager (zsh, git, starship, direnv)
│   ├── common/              # público, forkável
│   └── modules/personal/    # escape hatch via private.nix em $HOME
├── vars/
│   ├── example.nix          # template (valores padrão)
│   └── local.nix            # ignorado pelo git, com os seus valores
├── scripts/bootstrap.sh     # gerador interativo de vars
├── docs/                    # adding-a-host.md, secrets.md
├── renovate.json            # atualização automática dos inputs do flake
└── .gitignore
```

## Início rápido (máquina nova)

```bash
# 1. clona
git clone https://github.com/insanemor/lcars ~/lcars
cd ~/lcars

# 2. preenche suas variáveis (interativo)
nix run .#bootstrap

# 3. copia o template e ajusta
cp -r hosts/template hosts/meu-laptop
$EDITOR hosts/meu-laptop/default.nix

# 4. gera a config de hardware na máquina alvo
nixos-generate-config --show-hardware-config > hosts/meu-laptop/hardware-configuration.nix

# 5. registra no flake.nix
#    nixosConfigurations.meu-laptop = self.mkHost "meu-laptop" [ ./modules/laptop ./modules/desktop ];

# 6. builda e ativa
sudo nixos-rebuild switch --flake .#meu-laptop
```

### One-shot (opcional)

Se quiser pular o clone manual em uma VM fresca (que já tenha NixOS mínimo + curl):

```bash
curl -fsSL https://raw.githubusercontent.com/insanemor/lcars/main/scripts/install.sh | LCARS_HOST=meu-laptop LCARS_NIXOS=yes bash
```

Variáveis reconhecidas:

| Var | Default | Efeito |
|---|---|---|
| `LCARS_REPO` | `github.com/insanemor/lcars` | URL ou `git+https://...` |
| `LCARS_BRANCH` | `main` | branch |
| `LCARS_HOST` | `""` | nome do host a ativar (vazio = só bootstrapa vars) |
| `LCARS_NIXOS` | `no` | `yes` para `nixos-rebuild switch` no fim |
| `LCARS_BATCH` | `no` | `yes` para pular o prompt interativo |
| `LCARS_DEST` | `~/lcars` | onde clonar |

O instalador cobre: detecção de ambiente, clone, bootstrap de vars e ativação da config. Use-o na **primeira** máquina para validar o fluxo; depois siga o `quick start` padrão.

Após o passo 6, o 1Password CLI/GUI está instalado. Abra `1password`, entre com email ou pareie via QR code, depois desbloqueie — o agente SSH em `~/.1password/agent.sock` fica disponível.

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
