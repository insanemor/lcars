# lcars

Um flake NixOS multi-host, pensado para ser **forkável** — sem dados pessoais no repositório, mas pronto para lidar com identidade, secrets e dotfiles por máquina via **1Password** e Home Manager.

## Instalação — um comando

Numa máquina que já tem NixOS bootado:

```bash
curl -fsSL https://raw.githubusercontent.com/insanemor/lcars/main/scripts/install.sh | bash
```

**Sem `sudo` na chamada.** O repositório fica no seu `$HOME` e precisa pertencer a você; o script pede sudo sozinho onde precisa dele.

O que ele faz, em ordem — [`scripts/install.sh`](./scripts/install.sh) é curto de propósito e dá para ler inteiro antes de rodar:

1. **clona o repositório em `~/.dotfiles`**, usando `nix-shell -p git` — a máquina não precisa ter `git` instalado, e daqui em diante tudo acontece dentro do clone;
2. lê o **modelo do hardware** em `/sys/devices/virtual/dmi/id/product_name` e o reduz ao que um hostname aceita: esse é o nome da máquina;
3. cria `machines/<modelo>/` copiando `machines/template/`, e grava ali o `hardware-configuration.nix` real (`nixos-generate-config`);
4. preenche o que dá para descobrir, cada coisa no seu arquivo: **UEFI vs BIOS** e o disco do GRUB em `machines/<modelo>/default.nix`, e o **usuário** no `settings.nix`;
5. **abre os dois no seu editor** — primeiro o da máquina, onde estão `vm` e `laptop`, que nenhuma detecção preenche; depois o `settings.nix`, para profile, nome, chaves SSH e pacotes;
6. registra `machines/<modelo>/` no index do git (flakes só leem arquivos rastreados);
7. roda `nixos-rebuild switch --flake ~/.dotfiles#<modelo>`.

Não há passo separado para o Home Manager: ele entra como módulo NixOS no mesmo rebuild.

A primeira build de um desktop é longa — ela compila/baixa o niri, o 1Password e o mundo todo.

Ao final, o usuário fica com a senha inicial `lcars`. **Troque com `passwd` no primeiro login** — o sshd deste flake só aceita chave, mas o login local aceita senha.

### O nome da máquina é o modelo do hardware

O diretório criado em `machines/` recebe o modelo relatado pelo DMI — `20BE0048BR`, `MS-7C56`, `OptiPlex-7070`. Como o `flake.nix` deriva `networking.hostName` do nome do diretório, é também assim que a máquina passa a se chamar, e é o alvo do rebuild:

```bash
nixos-rebuild switch --flake ~/.dotfiles#20BE0048BR --elevate=sudo
```

O nome é reduzido ao que um hostname aceita: tudo que não for letra, número ou hífen vira hífen, e os repetidos colapsam. **Em máquina virtual isso costuma dar um nome feio** — uma VM QEMU/KVM se apresenta como `Standard PC (Q35 + ICH9, 2009)`, que sai como `Standard-PC-Q35-ICH9-2009`. É válido, mas você provavelmente vai querer trocar.

Renomeie o diretório — é só isso, não há campo de hostname em lugar nenhum:

```bash
cd ~/.dotfiles
git mv machines/Standard-PC-Q35-ICH9-2009 machines/vm-teste
nixos-rebuild switch --flake .#vm-teste --elevate=sudo
```

### O instalador é para a primeira vez

Ele não foi feito para rodar duas vezes: o `git clone` falha se `~/.dotfiles` já existir. Para uma máquina nova a partir de um clone que já existe, siga o [caminho manual](./docs/adding-a-host.md#caminho-manual).

## Depois de instalado: `nupdate` e `nsave`

Dois comandos, um em cada sentido.

```bash
nupdate               # traz o que mudou no repositório e aplica
nupdate --inputs      # …e também atualiza o nixpkgs (build longo)
nupdate --no-check    # pula a avaliação, vai direto ao rebuild

nsave                 # publica o que você ajustou nesta máquina
nsave -n              # mostra o que faria, sem alterar nada
```

Os aliases vêm do próprio repo (`user/shell/zsh.nix`) e chamam
[`scripts/update.sh`](./scripts/update.sh) e
[`scripts/save.sh`](./scripts/save.sh). Ambos descobrem a máquina pelo
`hostname`, então não há nome para decorar, e rodam de qualquer diretório.

O `nupdate` faz: sincroniza → (opcional) atualiza inputs → **avalia** →
`nixos-rebuild switch`. A avaliação leva segundos e evita descobrir um erro de
código depois de meio sistema compilado; se ela falhar, o rebuild não roda.

O `nsave` faz o contrário: exporta a configuração do noctalia, valida, mostra o
diff, pergunta e publica em `main`. Ele **não** publica `machines/`, e se o
rebase conflitar ele desfaz e explica, em vez de escolher um lado. Existe
porque o `nupdate` faz `git reset --hard` — um ajuste feito aqui e não
publicado some no próximo `nupdate`.

Para editar a configuração antes de aplicar, o caminho continua o de sempre:

```bash
cd ~/.dotfiles
$EDITOR settings.nix                          # quem você é
$EDITOR machines/<máquina>/default.nix        # o que a máquina é
nixos-rebuild switch --flake .#<máquina> --elevate=sudo
```

### Por que `--elevate=sudo` e não `sudo nixos-rebuild`

Um flake `git+file://` faz o Nix ler a árvore pelo git. Sob `sudo`, quem faz
isso é o **root** — e ele escreve em `.git/objects`, deixando os objetos com
dono dele dentro de um repositório seu. Enquanto só há leitura, ninguém nota;
no primeiro `git fetch` que precise escrever, o git para:

```
error: insufficient permission for adding an object to repository database
```

`--elevate=sudo` inverte: a avaliação e o build rodam como você, e o root só
entra na ativação, que não toca no repositório. O `nupdate` já faz isso; ao
rodar o `nixos-rebuild` à mão, use a flag também.

Se você já pegou o erro acima, uma vez só:

```bash
sudo chown -R "$USER" ~/.dotfiles
```

### Arquivos `.hm-bak` no seu `$HOME`

Quando um módulo de `user/` passa a gerenciar um dotfile que já existia, o Home
Manager renomeia o antigo para `<nome>.hm-bak` em vez de apagá-lo — nada é
perdido.

Acontece na primeira vez que o tema é aplicado: o stylix gerencia
`~/.gtkrc-2.0` e `~/.config/gtk-{3,4}.0/settings.ini`, que outro programa já havia
escrito. Compare e apague quando não precisar mais:

```bash
diff ~/.gtkrc-2.0 ~/.gtkrc-2.0.hm-bak
```

Sem esse backup configurado, a ativação **falharia** em vez de renomear, e o
rebuild terminaria com o sistema atualizado e o `$HOME` no estado anterior.

### O `nupdate` descarta o que você editou

Em caso de conflito, **o repositório sempre vence** — sem perguntar, sem parar. É deliberado: o comando existe para rodar sem exigir atenção.

Nada some para sempre. O que estava fora de um commit vai para um `git stash` nomeado (`git stash list`), e commits locais descartados ficam no `git reflog`. Mas são rede de segurança, não confirmação: o comando não espera você olhar.

Duas coisas nunca são tocadas:

- **`machines/<máquina>/`** — a configuração desta máquina, que não existe no repositório. É copiada para fora do git antes da sincronização e devolvida depois, esteja ela commitada, no index ou solta no disco.
- O que você editou **e o repositório não** — isso nem chega a ser conflito, e sobrevive normalmente.

Se você mantém edições em `settings.nix` que quer preservar, vale movê-las para `machines/<máquina>/default.nix`, que o `nupdate` respeita.

E se a edição é para valer em todas as máquinas, publique-a com **`nsave`** antes do próximo `nupdate` — é exatamente o buraco que ele fecha.

### O `settings.nix` é versionado; o hardware-config não

`settings.nix` vem no repo com o **default básico** — é o arquivo que você edita, e editá-lo deixa o clone sujo. Nada além dele é obrigatório: os campos avançados (`sshKeys`, `packages`, `swapFileSize`, `gpgKey`, `initialPassword`, `extraPackages`) podem simplesmente não estar lá, e cada módulo usa o próprio default. A lista completa está em [docs/adding-a-host.md](./docs/adding-a-host.md).

### Dois arquivos, duas naturezas

| Arquivo | O que descreve | Diverge entre máquinas? |
|---|---|---|
| `settings.nix` | **quem você é** — usuário, locale, profile, 1Password | não |
| `machines/<nome>/default.nix` | **o que a máquina é** — bootloader, disco do GRUB, VM, notebook, teclado | sempre |

A divisão existe para o `git pull` ser limpo. Se o bootloader morasse no `settings.nix`, todo clone divergiria do repositório e cada atualização daria conflito.

Por isso, depois de instalar, o ciclo é só:

```bash
cd ~/.dotfiles && git pull
nixos-rebuild switch --flake .#<máquina> --elevate=sudo
```

As linhas de `machines/<nome>/default.nix` **existem descomentadas de propósito**: o instalador as reescreve com `sed`, que só substitui linha já presente. Apagá-las o faria falhar em silêncio.

Já `machines/*/hardware-configuration.nix` está no `.gitignore` — ele pode vazar números de série. Mas um flake dentro de um repo git **só enxerga arquivos rastreados**, então o instalador o põe no *index* com `git add -f`. Isso não o commita, mas deixa o arquivo pronto para entrar num commit distraído: confira o `git status` antes de commitar.

## O que vem instalado

Resumo. O inventário completo, com o arquivo que define cada item, está em
[docs/features.md](./docs/features.md).

**Em toda máquina** — flakes habilitados e coleta de lixo semanal, locale
`pt_BR.UTF-8`, NetworkManager, usuário com `zsh` (ou `bash`, se você desligar
`lcars.user.zsh.enable`), sshd **somente por chave** com
firewall ligado, e a base de linha de comando (`git`, `vim`, `htop`, `curl`,
`wget`, `jq`, `rsync`, `python3`).

**No ambiente do usuário** (Home Manager, no mesmo rebuild) — zsh com
autosuggestion, syntax highlighting e histórico compartilhado; git com aliases
e `pull.rebase`; direnv com nix-direnv; e o gancho para puxar dotfiles de itens
Document do 1Password.

**No profile `personal`** — [niri](https://github.com/YaLTeR/niri) com SDDM, o
shell [noctalia](https://github.com/noctalia-dev/noctalia-shell), o terminal
kitty com o multiplexador [herdr](https://herdr.dev) (workspaces e painéis
persistentes, com os atalhos do tmux), áudio PipeWire, fontes
Noto/Liberation/DejaVu, 1Password (CLI + GUI + agente SSH), e `ripgrep`, `fd`,
`bat`, `eza`. **Não há navegador** nem suíte de aplicativos; acrescente o que
quiser em `userSettings.packages`.

O herdr é o único programa que **compila na sua máquina**: ele não está no
nixpkgs, vem do flake do upstream, e não há cache binário. Se isso não lhe
serve, desligue com `lcars.user.herdr.enable = false`.

O áudio é flag separada (`lcars.system.hardware.audio.enable`), não parte do
desktop: dá para ter som sem ambiente gráfico. O teclado também é módulo
próprio, ligado nos dois profiles — layout US internacional por padrão,
valendo de uma vez no console, na tela de login e na sessão.

### O niri, e por que ele é diferente

**Tiling scrollable.** As janelas formam uma fita horizontal que se estende sem
limite, e a tela rola por ela. Abrir uma janela nova **não** redivide o espaço
das que já estão abertas, como fazem os tiling tradicionais — as outras
continuam do tamanho que estavam, e saem de vista pela lateral.

Isso é arquitetura, não modo de layout: nenhum ajuste de Hyprland ou de Plasma
produz esse comportamento.

A unidade de navegação é a **coluna**, não a janela. Uma coluna pode ter várias
janelas empilhadas na vertical, e é isso que explica a divisão dos atalhos:

| Atalho | O que faz |
|---|---|
| `SUPER+Enter` | terminal (kitty) |
| `SUPER+D` | lançador |
| `SUPER+N` | notificações |
| `SUPER+C` | centro de controle |
| `SUPER+V` | histórico da área de transferência |
| `SUPER+ESC` | menu de sessão |
| `SUPER+H` / `SUPER+L` | **rola entre colunas** (ou `←` `→`) |
| `SUPER+J` / `SUPER+K` | move o foco **dentro** da coluna (ou `↓` `↑`) |
| `SUPER+SHIFT+H/J/K/L` | move a janela ou a coluna |
| `SUPER+,` / `SUPER+.` | junta a janela vizinha à coluna, ou a expulsa |
| `SUPER+R` | cicla a largura da coluna: ⅓, ½, ⅔ |
| `SUPER+F` | maximiza a coluna |
| `SUPER+SHIFT+F` | tela cheia |
| `SUPER+W` | empilha a coluna em abas |
| `SUPER+Q` | fecha a janela |
| `SUPER+1…9` | workspace (com `SHIFT`, leva a coluna) |
| `SUPER+PgUp` / `PgDn` | workspace acima / abaixo |
| `SUPER+SHIFT+S` | captura de região |
| `Print` / `SUPER+Print` | captura da tela / da janela |
| `SUPER+SHIFT+E` | sai da sessão |
| teclas de mídia | volume, brilho, play/pause |

Três coisas que mudam de hábito vindo de um tiling tradicional: os workspaces
são uma **pilha vertical** dinâmica, não uma grade fixa; a captura de tela é
**nativa** do compositor, sem grim nem slurp; e não se redimensiona janela
arrastando a borda — usa-se `SUPER+R` para escolher entre larguras
predefinidas.

**Só há uma sessão na tela de login.** Plasma e Hyprland saíram
([#34](https://github.com/insanemor/lcars/issues/34)), então se o niri não
subir, a volta é pelo TTY:

```bash
# Ctrl+Alt+F2, e depois
cd ~/.dotfiles
$EDITOR machines/<máquina>/default.nix   # lcars.system.wm.niri.enable = false;
nupdate
```

O SDDM não pertence ao compositor: mora em `system/wm/default.nix` e sobe com
qualquer ambiente que esteja ligado.

Barra, lançador, notificações, centro de controle e menu de sessão são painéis
do **noctalia**, um shell só no lugar de waybar + rofi + swaync. Ele tem centro
de controle gráfico, e o que você ajustar ali dá para versionar:

```bash
nsave                       # exporta, mostra o diff, pergunta e publica
```

Detalhes em [docs/features.md](./docs/features.md#o-ciclo-gui--export--commit).

### Um esquema de cores para tudo

O tema não é configurado programa por programa. Um esquema
[base16](https://github.com/tinted-theming/schemes) é declarado uma vez e o
[stylix](https://github.com/danth/stylix) o aplica em noctalia, kitty, GTK, Qt
e no console TTY. O niri é a exceção: o stylix não tem alvo para ele, e
`user/wm/niri.nix` lê as mesmas cores de `lib.stylix.colors` e as escreve à
mão — trocar de esquema continua repintando tudo junto.

Padrão: **`simbiot-dark`**, as cores do site da SimbioIT — fundo azul-petróleo
`#111d23`, o ciano do logo `#29b6bf` como cor primária da interface, e o lime
`#bad350` fechando o gradiente das bordas. Sete das dezesseis cores foram
amostradas da página; as outras nove, derivadas na mesma família. Detalhes e a
tabela completa em
[docs/features.md](./docs/features.md#simbiot-dark-a-paleta-padr%C3%A3o).

O `scheme` procura primeiro em `system/theme/schemes/`, neste repositório, e só
depois no pacote `base16-schemes` — então a mesma option serve para a paleta
própria e para qualquer esquema pronto. Para trocar:

```nix
# machines/<máquina>/default.nix, ou no profile
lcars.system.theme.scheme = "gruvbox-dark-hard";
lcars.system.theme.polarity = "dark";
```

Os nomes disponíveis saem de `ls $(nix eval --raw nixpkgs#base16-schemes)/share/themes/`.

**Não há papel de parede por padrão** — o fundo é uma cor sólida derivada do
esquema, pintada pelo próprio compositor. É deliberado: o daemon de papel de
parede carrega a imagem por OpenGL e não sobrevive a uma VM sem aceleração 3D.

Para usar uma imagem, aí sim com daemon:

```nix
lcars.system.theme.wallpaper = ./caminho/para/imagem.png;
```

### A forma, separada da cor

Além da paleta, o repo traz a **geometria** do rice de
[Sly-Harvey/NixOS](https://github.com/Sly-Harvey/NixOS): borda de janela em
gradiente a 45°, cantos em 10, blur ajustado e sombra desligada. (A forma da
barra e dos painéis não vem daí — quem a define é o noctalia, e você a ajusta
pela GUI.)

O que foi copiado é só a forma — **nenhum valor de cor**. No repo de origem a
paleta Catppuccin está fixa em 30 linhas de `@define-color` dentro do CSS, e
trocar de esquema exige reescrevê-las. Aqui o gradiente é `base0D → base0A`,
então mudar `scheme` repinta a borda junto.

Para ficar só com o stylix, sem a geometria:

```nix
lcars.system.theme.rice = false;
```

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
│   └── personal/   # desktop completo: niri + noctalia + 1Password
│
├── flake.lock      # versões dos inputs, pinadas — commitado de propósito
├── system/         # módulos NixOS, opt-in via lcars.system.<caminho>.enable
│   ├── core/       # identidade, locale, boot, usuário
│   ├── security/   # sshd e firewall
│   ├── hardware/   # laptop.nix, vm.nix
│   ├── theme/      # o esquema de cores, via stylix
│   ├── wm/         # niri.nix e a tela de login (SDDM, fontes, dconf)
│   └── app/        # 1password/
│
├── user/           # módulos do Home Manager, opt-in via lcars.user.<módulo>.enable
│   ├── options.nix # as flags acima — declaradas do lado NixOS, veja abaixo
│   ├── wm/         # niri.nix, noctalia.nix (+ noctalia-config.toml)
│   ├── shell/      # zsh.nix
│   ├── app/        # git.nix, direnv.nix, dotfiles.nix
│   └── personal/   # escape hatch via private.nix em $HOME (sem flag)
│
├── settings.nix    # SUA configuração — o único arquivo que você edita
├── scripts/        # install.sh, update.sh (nupdate), save.sh (nsave), check.sh
└── docs/
```

O encadeamento é: **a máquina escolhe um profile, o profile liga flags, as flags ativam módulos.** Vale para os dois lados — `lcars.system.*` para `system/`, `lcars.user.*` para `user/` — e em ambos o caminho da flag espelha o caminho do arquivo.

```nix
# machines/meu-pc/default.nix
lcars.profile = "personal";             # desktop completo
lcars.system.wm.niri.enable = false;    # …exceto o ambiente gráfico
lcars.user.dotfiles.enable = false;     # …e sem puxar dotfiles do 1Password
```

Os profiles definem as flags com `mkDefault`, então a máquina tem prioridade e pode sobrescrever qualquer uma **individualmente**, sem copiar o profile inteiro.

As flags de `user/` são declaradas em `user/options.nix`, do lado NixOS, e lidas pelos módulos do Home Manager via `osConfig`. Isso não é capricho: as duas árvores de módulos são separadas, e um profile — que é módulo NixOS — não alcançaria uma option declarada dentro do Home Manager. O detalhe está em [docs/adding-a-host.md](./docs/adding-a-host.md#por-que-lcarsuser-é-declarada-do-lado-nixos).

## Adicionando outra máquina

Não existe registro manual em `flake.nix`: **todo diretório em `machines/` vira um `nixosConfiguration`** (exceto `template`), e `networking.hostName` recebe o nome do diretório.

A forma mais curta é rodar o instalador na máquina nova — ele clona o repo e cria o diretório sozinho, com o modelo do hardware por nome. Para fazer à mão, veja [docs/adding-a-host.md](./docs/adding-a-host.md).

## Fluxo manual (se você prefere ver cada passo)

O instalador não faz nada que você não possa fazer na mão. Aqui, escolhendo o nome da máquina em vez de aceitar o modelo do DMI:

```bash
git clone https://github.com/insanemor/lcars ~/.dotfiles && cd ~/.dotfiles
$EDITOR settings.nix                                  # profile, usuário, chaves ssh…
cp -r machines/template machines/meu-laptop
$EDITOR machines/meu-laptop/default.nix               # é VM? é notebook?
sudo nixos-generate-config --show-hardware-config > machines/meu-laptop/hardware-configuration.nix
git add -f machines/meu-laptop                        # flakes só leem o que o git rastreia
nixos-rebuild switch --flake .#meu-laptop --elevate=sudo
```

A diferença para o instalador: aqui você escolhe o nome da máquina em vez de aceitar o modelo do DMI.

## 1Password

No profile `personal`, o CLI e a GUI vêm instalados, e o `ssh` do sistema já
está apontado para o socket do agente. **Falta o que só dá para fazer no app** —
o instalador imprime estes passos ao terminar:

1. Abra `1password` e entre com email, ou pareie via QR code.
2. **Settings → Developer** → ligue *Use the SSH agent*. Se ainda não tiver uma
   chave, crie um item do tipo *SSH Key*.
3. Copie a chave pública do item e adicione em
   [github.com/settings/keys](https://github.com/settings/keys).

Teste com:

```bash
ssh -T git@github.com     # "Hi <você>! You've successfully authenticated"
```

Não existe módulo NixOS para esse agente — ele é um recurso do próprio app. O
socket aparece em `~/.1password/agent.sock`, e o que o flake faz é apontar o
ssh para lá (`IdentityAgent`), além de já trazer a chave do host `github.com`
para não haver prompt de host desconhecido.

### Por que o remote vira SSH no fim da instalação

O `install.sh` clona por **HTTPS**: numa máquina recém-instalada não existe
chave SSH nenhuma, e clonar por SSH quebraria antes de tudo. Mas num remote
HTTPS o git pede usuário e token a cada push, e **o agente do 1Password nunca é
consultado** — ele só atende `git@github.com`.

Por isso, depois do rebuild, o instalador troca o remote para SSH (derivado do
remote atual, então o seu fork continua apontando para o seu repositório).

**A consequência:** até você completar os três passos acima, nem `nupdate` nem
`nsave` conseguem falar com o GitHub — o `git fetch` também passa por ali. Se
precisar voltar ao HTTPS enquanto isso:

```bash
git -C ~/.dotfiles remote set-url origin https://github.com/<você>/<repo>.git
```

### Se o SSH falhar com "REMOTE HOST IDENTIFICATION HAS CHANGED"

```
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
Offending ED25519 key in /etc/ssh/ssh_known_hosts:1
Host key verification failed.
```

Quer dizer que a chave de host gravada não bate com a que o GitHub apresentou.
Antes de qualquer coisa, **confira a fingerprint que apareceu na tela** contra as
[publicadas pelo GitHub](https://docs.github.com/authentication/keeping-your-account-secure/githubs-ssh-key-fingerprints):

```
3072 SHA256:uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s (RSA)
 256 SHA256:p2QAMXNIC1TJYWeIOttrVc98/R1BUFWu3/LiyKgUfQM (ECDSA)
 256 SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU (ED25519)
```

Se **não** bater com nenhuma, pare: aí o aviso está certo e alguém está no meio
do caminho.

Se bater, é o repositório que está desatualizado — as chaves ficam em
`system/app/1password/default.nix`, e o `/etc/ssh/ssh_known_hosts` é gerado a
partir delas. A saída tem um nó: o `nupdate` traria a correção, mas ele precisa
de `git fetch`, que passa pelo SSH que está quebrado. Contorne por HTTPS:

```bash
git -C ~/.dotfiles remote set-url origin https://github.com/<você>/<repo>.git
nupdate
git -C ~/.dotfiles remote set-url origin git@github.com:<você>/<repo>.git
ssh -T git@github.com
```

Foi exatamente o que aconteceu na
[#30](https://github.com/insanemor/lcars/issues/30): a chave ED25519 do
repositório estava errada. A verificação falhou fechada — recusou a conexão em
vez de aceitar um host não verificado —, mas travou o acesso ao GitHub por
completo.

### Assinatura de commits

Opcional, e desligada por padrão. Preenchendo `gpgKey` no `settings.nix` com a
chave **pública**, o git passa a assinar todo commit — e, com a GUI do
1Password instalada, `gpg.ssh.program` aponta sozinho para o `op-ssh-sign`.

Esse detalhe não é enfeite: a chave vive dentro do cofre e nunca vira arquivo
em disco, então o `ssh-keygen -Y sign` padrão não a encontraria e todo commit
falharia. Para o GitHub mostrar os commits como *Verified*, a mesma chave
precisa estar cadastrada lá **como Signing Key**, não só como Authentication
Key.

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
