# O que vem instalado

Inventário do que uma instalação entrega hoje. Cada seção aponta o arquivo que
define aquilo, para você ir direto à fonte quando quiser mudar.

## Como ler esta lista

Nada liga sozinho — nem em `system/`, nem em `user/`. O que decide é o
**profile** que a máquina escolhe, e quem escolhe é você, em `settings.nix`.
O repo vem com `personal`.

| | Flag | `basic` | `personal` |
|---|---|---|---|
| Base do sistema (`system/core`) | `lcars.system.core.enable` | sim | sim |
| ssh e firewall (`system/security`) | `lcars.system.security.enable` | sim | sim |
| Plasma + fontes (`system/wm`) | `lcars.system.wm.plasma.enable` | — | sim |
| Hyprland, compositor (`system/wm`) | `lcars.system.wm.hyprland.enable` | — | sim |
| Config do Hyprland (`user/wm`) | `lcars.user.hyprland.enable` | — | sim |
| Tema unificado (`system/theme`) | `lcars.system.theme.enable` | — | sim |
| Shell noctalia (`user/wm`) | `lcars.user.noctalia.enable` | — | sim |
| Áudio PipeWire (`system/hardware`) | `lcars.system.hardware.audio.enable` | — | sim |
| Teclado, console e gráfico (`system/hardware`) | `lcars.system.hardware.keyboard.enable` | sim | sim |
| 1Password CLI e GUI (`system/app`) | `lcars.system.app.onePassword.enable` | — | sim |
| `ripgrep`, `fd`, `bat`, `eza` | `lcars.system.core.userPackages` | — | sim |
| zsh (`user/shell`) | `lcars.user.zsh.enable` | sim | sim |
| git (`user/app`) | `lcars.user.git.enable` | sim | sim |
| direnv (`user/app`) | `lcars.user.direnv.enable` | — | sim |
| dotfiles do 1Password (`user/app`) | `lcars.user.dotfiles.enable` | — | sim |

Os presets estão em `profiles/basic/default.nix` e
`profiles/personal/default.nix` — e são a lista completa: o que não está ligado
ali (ou na própria máquina) não sobe. Um profile define suas flags com
`mkDefault`, então a máquina pode desligar qualquer item individualmente sem
abandonar o resto do preset.

O caminho da flag espelha o caminho do arquivo: `lcars.system.wm.plasma` é
`system/wm/plasma.nix`, `lcars.user.direnv` é `user/app/direnv.nix`. A
diferença entre os dois prefixos não é cosmética — `system/` e `user/` são
avaliados em árvores de módulos separadas, e é por isso que as flags de `user/`
são declaradas do lado NixOS, em `user/options.nix`, e lidas por `osConfig`.
Sem isso um profile, que é módulo NixOS, não alcançaria o Home Manager.

Ajustes de hardware (`system/hardware`) não dependem do profile, e **não são
detectados**: quem os liga é você, em `machines/<host>/default.nix`. O template
traz `lcars.system.hardware.vm.enable` e `lcars.system.hardware.laptop.enable` em `false`;
num notebook ou numa VM, mude para `true` e rode o rebuild.

---

## Base do sistema — sempre

`system/core/default.nix` · option `lcars.system.core`

**Nix**
- Flakes habilitados (`nix-command flakes`) — sem isto o próximo `nixos-rebuild --flake` falharia
- Coleta de lixo automática, semanal, apagando gerações com mais de 30 dias
- `system.stateVersion = "24.05"`

**Locale**
- Fuso horário e locale vindos de `settings.nix` (default `America/Sao_Paulo`, `pt_BR.UTF-8`)
- Locales gerados: `pt_BR.UTF-8`, `en_US.UTF-8`, `C.UTF-8`
- `LC_MESSAGES` fixo em `pt_BR.UTF-8`
- O teclado e a fonte do console **não** ficam aqui — são `system/hardware/keyboard.nix`

**Boot** — o hardware-config declara os sistemas de arquivos; aqui só o carregador
- `systemd-boot` (UEFI), limitado a 10 gerações no menu, ou `grub` (BIOS legado)
- Quem escolhe é a **máquina**, em `machines/<host>/default.nix`:
  `lcars.system.core.bootLoader`, mais `grubDevice` em BIOS e `bootMountPath`
  se a partição EFI não for `/boot`. Não está no `settings.nix` de propósito —
  é fato de hardware, e mantê-lo fora é o que faz o `settings.nix` nunca
  divergir entre clones
- Com `grub` e `grubDevice` vazio, a avaliação para numa assertion dizendo o
  que preencher — antes de o instalador do GRUB falhar de forma mais obscura
- Swapfile opcional via `lcars.system.core.swapFileSize` (desligado por padrão, para não colidir com o swap que o `hardware-configuration.nix` já traga)

**Rede**
- NetworkManager

**Usuário**
- Conta normal com o nome de `userSettings.username`
- Grupos: `networkmanager`, `wheel`, `video`, `audio`
- Senha inicial `lcars` — **troque no primeiro login com `passwd`**
- **O shell segue `lcars.user.zsh.enable`**: `zsh` quando ligada (o padrão nos
  dois profiles), `bash` quando não. `programs.zsh` do sistema acompanha a
  mesma flag — é ele que registra o zsh em `/etc/shells`, sem o que a conta
  apontaria para um shell que o sistema não reconhece.

  Os dois andam juntos de propósito: desligar a flag desliga o módulo que
  escreve o `~/.zshrc` (`user/shell/zsh.nix`), e sem ele um zsh como shell de
  login seria pior que o bash — sem aliases, sem histórico compartilhado, sem
  highlighting. `system/core/default.nix` lê a flag por `config`, e não por
  `osConfig`, porque `lcars.user.*` é option NixOS.

**Pacotes de sistema**

`git`, `vim`, `htop`, `curl`, `wget`, `jq`, `rsync`, `gnused`, `gnugrep`, `python3`

Acrescente os seus em `systemSettings.extraPackages` ou `lcars.system.core.extraPackages`.

---

## Acesso e firewall — sempre

`system/security/default.nix` · option `lcars.system.security`

- **sshd apenas por chave**: `PasswordAuthentication` e `KbdInteractiveAuthentication` desligados, `PermitRootLogin = "no"`
- Porta 22 aberta no firewall pelo próprio módulo (`openFirewall`)
- Firewall ligado; portas extras em `lcars.system.security.firewall.allowedTCPPorts`
- Chaves autorizadas em `lcars.system.security.sshKeys` — **vazio por padrão**

Enquanto `sshKeys` estiver vazio não há como entrar por ssh. O acesso é local,
por senha, no console ou no SDDM. Isso é proposital: uma máquina recém-instalada
não fica aberta na rede.

---

## Ambientes gráficos — só no profile `personal`

**Os dois ficam ligados ao mesmo tempo** e aparecem lado a lado na tela de
login. O Plasma abre por padrão; se o Hyprland não subir, há para onde voltar
sem editar o repositório.

### A tela de login · `system/wm/default.nix` · option `lcars.system.wm`

O SDDM e a escolha da sessão não pertencem a nenhum ambiente — se morassem
dentro de um deles, ligar o segundo daria conflito de definição, e uma máquina
só com Hyprland ficaria sem tela de login.

- `defaultSession` — vazio decide sozinho, preferindo o Plasma. Ponha
  `"hyprland"` na máquina para inverter
- `sddm.wayland` — se o próprio SDDM roda em Wayland (independe da sessão que
  você escolhe depois)

### KDE Plasma · `system/wm/plasma.nix` · option `lcars.system.wm.plasma`

- **KDE Plasma 6**, sessão Wayland pré-selecionada
  (`lcars.system.wm.plasma.wayland = false` troca para a X11; as duas
  continuam na tela de login)
- **Fontes**: `noto-fonts`, `noto-fonts-color-emoji`, `liberation_ttf`, `dejavu_fonts`, mais o conjunto padrão do NixOS
- **Aplicativos**: só o que o módulo `plasma6` do NixOS traz. Nada é
  acrescentado por este repo — **nem navegador**. Remova o que não quiser com
  `lcars.system.wm.plasma.excludePackages`
- `dconf` habilitado

### Hyprland · `system/wm/hyprland.nix` + `user/wm/hyprland.nix`

Compositor Wayland com tiling. Dividido nos dois lados do repo: o compositor é
do sistema, o `hyprland.conf` é seu.

**Sistema** (`lcars.system.wm.hyprland.enable`) — o compositor, XWayland,
portais XDG (sem eles um "salvar como" de aplicativo GTK não abre) e o agente
polkit (sem ele, pedidos de senha de programa gráfico falham em silêncio).

Mais os utilitários que o Hyprland **não** traz e sem os quais a sessão sobe
inutilizável: `wl-clipboard`, `brightnessctl`, `pamixer`, `playerctl`,
`hyprpicker`, `grim`, `slurp`, `hyprpaper`.

**Usuário** (`lcars.user.hyprland.enable`) — atalhos, regras de janela, o que
sobe com a sessão, e o pacote `kitty`. O layout do teclado vem de
`lcars.system.hardware.keyboard`, o mesmo do console e do SDDM.

| Atalho | O que faz |
|---|---|
| `SUPER+Enter` | terminal (kitty) |
| `SUPER+D` | lançador (painel do noctalia) |
| `SUPER+N` | notificações |
| `SUPER+C` | centro de controle |
| `SUPER+V` | histórico da área de transferência |
| `SUPER+ESC` | menu de sessão (desligar, reiniciar, bloquear) |
| `SUPER+Q` | fecha a janela |
| `SUPER+SHIFT+E` | sai da sessão |
| `SUPER+F` | tela cheia |
| `SUPER+setas` ou `hjkl` | move o foco |
| `SUPER+1..9` | troca de workspace (com `SHIFT`, leva a janela) |
| `SUPER+SHIFT+S` | captura de região para a área de transferência |
| teclas de mídia | volume, brilho, play/pause |

Os cinco primeiros painéis são comandos de IPC para o shell que já está no ar
(`noctalia msg panel-toggle <id>`), não programas separados que abrem e fecham.

As cores vêm do tema (abaixo) — não há paleta escrita no módulo do Hyprland.
Estrutura e atalhos inspirados em
[Sly-Harvey/NixOS](https://github.com/Sly-Harvey/NixOS) (MIT).

### Shell · `user/wm/noctalia.nix` · `lcars.user.noctalia.enable`

Barra, lançador, servidor de notificações, centro de controle, histórico de
área de transferência, menu de sessão, OSD de volume e brilho e papel de
parede — uma peça só, em vez de waybar + rofi + swaync, que eram três módulos
com três formatos de configuração e nenhuma interface de ajuste.

Sobe por unidade systemd (`programs.noctalia.systemd.enable`), não pelo
`exec-once` do Hyprland: assim reinicia se cair e `systemctl --user status
noctalia` diz o que houve. Pelo `exec-once`, falha é silêncio.

Sem ele o Hyprland não tem servidor de notificação, e aí nada avisa bateria
fraca nem download concluído — quem tentou notificar não recebe erro, então o
silêncio parece normal.

#### O ciclo GUI → export → commit

É o motivo de ele estar aqui. O noctalia tem centro de controle gráfico, e o
que você ajusta ali dá para exportar e versionar:

```bash
# 1. ajuste no centro de controle (SUPER+C), veja o resultado na hora
# 2. exporte por cima do arquivo versionado
noctalia config export merged > ~/.dotfiles/user/wm/noctalia-config.toml
# 3. confira e aplique
cd ~/.dotfiles && git diff
nupdate
```

Sem o passo 2, o ajuste vive só no state-dir daquela máquina e some num clone
novo. Com ele, a configuração entra no fluxo normal do repositório — issue,
branch, commit.

O arquivo começa quase vazio de propósito: o que não está nele usa o default do
noctalia, e um despejo de centenas de linhas de defaults tornaria ilegível o
diff da primeira coisa que você mudar.

**As chaves do tema são podadas na leitura.** Paleta, fonte, modo claro/escuro,
caminho do papel de parede e as três opacidades são escritas pelo stylix. Como
`export merged` despeja a configuração inteira, inclusive essas, os dois lados
definiriam a mesma chave — o que o sistema de módulos trata como conflito e
aborta. `user/wm/noctalia.nix` remove esses oito caminhos do que lê do arquivo,
e por isso o ciclo acima funciona sem você editar nada à mão. O efeito prático:
mudar cor ou fonte pela GUI não gruda. Para trocar, mexa em
`lcars.system.theme.scheme` e `lcars.system.theme.fonts`.

---

## Tema — só no profile `personal`

`system/theme/default.nix` · option `lcars.system.theme`

Um esquema [base16](https://github.com/tinted-theming/schemes) declarado uma
vez, aplicado pelo [stylix](https://github.com/danth/stylix) em: **Hyprland,
noctalia, kitty, hyprlock, GTK, Qt, Plasma e o console TTY**.

| Option | Padrão | Para quê |
|---|---|---|
| `scheme` | `"catppuccin-mocha"` | nome de um esquema do pacote `base16-schemes` |
| `polarity` | `"dark"` | diz aos programas se o esquema é claro ou escuro |
| `wallpaper` | `null` | `null` = cor sólida pintada pelo compositor, **sem daemon**; uma imagem liga o hyprpaper |
| `fonts.monospace` | `"JetBrainsMono Nerd Font"` | Nerd Font porque a barra usa ícones que só existem nelas |
| `fonts.size` | `11` | corpo da fonte de interface |
| `rice` | `true` | a **geometria** das janelas do Hyprland: gradiente, cantos, blur. `false` deixa a forma padrão, ainda pintada pelo esquema |

**Por que fica em `system/theme/` e não em `system/wm/`:** tema é transversal.
Ele pinta o console TTY, o GTK e o Qt, que existem independentemente de qual
ambiente gráfico está ligado. Amarrá-lo a um WM faria a cor do console depender
do desktop.

**Por que stylix e não cor à mão.** O repo de referência fia a paleta em cada
programa — 17 arquivos `.rasi` só para o lançador, CSS próprio para a barra,
218 arquivos ao todo em `desktop/hyprland`. Aqui, trocar de esquema é uma
linha, e nenhum programa fica para trás.

### O papel de parede, e por que ele é uma cor

Sem `wallpaper` definido, **não há daemon de papel de parede**. O fundo do
Hyprland é `misc.background_color`, que o stylix deriva de `base00` e o
compositor pinta sozinho.

Isso não é economia de código, é robustez: o `hyprpaper` carrega a imagem como
textura por EGL/OpenGL, e numa VM QEMU sem GPU ele **segfaultava**
(`Signal: 11 (SEGV)`, com `libdrm_intel` e `libxcb-dri3` no coredump). Um
daemon com pilha gráfica para desenhar um fundo chapado é desproporcional, e
era a única peça do desktop que não sobrevivia à VM.

Apontar `wallpaper` para uma imagem religa o hyprpaper — quem quer ver uma foto
aceita o custo:

```nix
lcars.system.theme.wallpaper = ./caminho/imagem.png;
```

Houve aqui um gradiente gerado com ImageMagick a partir do esquema. Saiu junto
com o daemon: entre `base00` e `base01` a diferença para a cor sólida é
imperceptível, e não pagava a dependência de build nem a superfície de falha.
O repo de referência versiona 18 imagens; este continua sem nenhuma.

### A forma, com `rice = true`

A geometria das janelas vem do mesmo repo de referência, mas **sem nenhum valor
de cor**: borda em gradiente 45° (`base0E` → `base0C`), cantos em 10, blur
`size 6 passes 2`, sombra desligada, `gaps_out` em 9.

A forma da barra e dos painéis **não** está aqui. Era CSS da waybar e um tema
`.rasi` do rofi; hoje é o noctalia que a define, e você a ajusta pelo centro de
controle, exportando o resultado (veja o ciclo acima). A flag `rice` só governa
o Hyprland.

Um detalhe que vale saber para quem for mexer: **a borda em gradiente precisa
de `mkForce`.** O stylix declara `col.active_border` sem `mkDefault`
(`modules/hyprland/hm.nix`); sem forçar, as duas definições colidem. Se ele
passar a usar `mkDefault`, o `mkForce` pode sair.

---

## 1Password — só no profile `personal`

`system/app/1password/default.nix` · option `lcars.system.app.onePassword`

- **CLI** (`op`) e **GUI**, ambos com o wrapper e os grupos que o NixOS exige
- Regra polkit para o usuário dono da GUI (`polkitPolicyOwners`)
- Chave pública do `github.com` pré-registrada em `programs.ssh.knownHosts`, para não haver prompt de host desconhecido no primeiro clone
- `ssh` do sistema apontando para `~/.1password/agent.sock` via `IdentityAgent`
- Software proprietário liberado por `allowUnfreePredicate` restrito aos pacotes do 1Password — `allowUnfree` global **não** é ligado

O agente SSH em si é um recurso do aplicativo, ligado em **Settings →
Developer**. Não existe módulo NixOS para ele; o que o repo faz é apontar o ssh
para o socket que o app cria.

---

## Áudio — flag própria

`system/hardware/audio.nix` · option `lcars.system.hardware.audio`

- **PipeWire** falando ALSA, PulseAudio e (opcionalmente) JACK
- `security.rtkit` para prioridade de tempo real — sem isso há falhas audíveis sob carga
- PulseAudio desligado explicitamente: os dois disputam o mesmo socket
- `support32Bit` ligado por padrão (jogos, binários proprietários antigos);
  `jack` desligado, para quem não usa Ardour ou Carla

Ligado no profile `personal`. Morava dentro de `system/wm/plasma.nix`, o que
tornava impossível ter som sem KDE — um servidor de mídia precisaria ligar o
desktop inteiro. Agora são flags independentes, e é o profile que junta as
duas: o módulo do Plasma **não** liga o áudio por trás.

---

## Teclado — console e sessão gráfica, de uma fonte só

`system/hardware/keyboard.nix` · option `lcars.system.hardware.keyboard`

- `layout` (default `"us"`) e `variant` (default `"intl"`) — US internacional,
  com acentuação por dead keys
- `consoleFont` (default `Lat2-Terminus16`), com o pacote `terminus_font`
- Ligado nos **dois** profiles: mesmo numa máquina headless alguém acaba no TTY

Os dois contextos saem da mesma declaração. O console fala keymaps do kernel
(`us-acentos`, `br-abnt2`) e o X/Wayland fala XKB (`us`+`intl`, `br`+`abnt2`);
declarar ambos à mão convida a divergirem — e era o que acontecia: o TTY tinha
`us-acentos` e a sessão gráfica, sem nenhuma configuração no repo, subia em
`us` puro, **sem acentuação**. Agora só o XKB é declarado, e
`console.useXkbConfig` compila o keymap do console a partir dele com `ckbcomp`.
Isso não exige o xserver habilitado.

Num teclado ABNT2, na máquina:

```nix
lcars.system.hardware.keyboard.layout  = "br";
lcars.system.hardware.keyboard.variant = "abnt2";
```

Para `model` e `options` (trocar layout por atalho, por exemplo), declare
`services.xserver.xkb.model` / `.options` direto — são casos raros e não valem
um espelho de option.

---

## Ajustes por hardware — ligados à mão

### Notebook

`system/hardware/laptop.nix` · option `lcars.system.hardware.laptop`

- `thermald`
- Tampa fechada: suspende na bateria, ignora na tomada
- Gerenciamento de energia à sua escolha (`powerManager`):
  - **`tlp`** (padrão) — carga limitada a 80–90% para preservar a bateria, governor `performance` na tomada e `powersave` na bateria
  - **`ppd`** — power-profiles-daemon, que integra melhor com o Plasma

Os dois nunca ficam ligados juntos: o NixOS aborta a avaliação se isso acontecer.

### Máquina virtual

`system/hardware/vm.nix` · option `lcars.system.hardware.vm`

- Módulos virtio no initrd (`blk`, `net`, `pci`, `scsi`, `input`, `gpu`, `balloon`)
- `qemu-guest-agent` e `spice-vdagent` (clipboard e redimensionamento com o host)

---

## Ambiente do usuário — conforme o profile

Módulos do Home Manager, aplicados no mesmo `nixos-rebuild`. Cada um é opt-in
por `lcars.user.<módulo>.enable`, declarada em `user/options.nix` e ligada no
profile — os títulos abaixo trazem a flag de cada um.

### zsh · `user/shell/zsh.nix` · `lcars.user.zsh.enable` · basic + personal

- Autosuggestion, syntax highlighting e completion
- Histórico de 50 000 linhas, compartilhado entre sessões, sem duplicatas
- Aliases: `ll`, `la`, `l`, `gs` (git status), `gp` (push), `gpl` (pull)
- **`nupdate`** — sincroniza `~/.dotfiles` com o repositório, avalia e aplica
  (`scripts/update.sh`). Aceita `--inputs` para atualizar o nixpkgs junto e
  `--no-check` para pular a avaliação. Em conflito, o repositório vence e o
  que você editou vai para um `git stash`; `machines/<host>/` nunca é tocado
- `zsh-completions`

Esta flag é a única de `user/` que mexe também no sistema: ela decide o shell
de login da conta (`bash` quando desligada). Veja "Base do sistema" acima.

### git · `user/app/git.nix` · `lcars.user.git.enable` · basic + personal

- Nome e email vindos de `settings.nix`
- `init.defaultBranch = main`, `pull.rebase`, `rerere`, `push.autoSetupRemote`
- Aliases: `co`, `br`, `ci`, `st`, `lg`
- Assinatura por chave SSH **apenas se** `userSettings.gpgKey` estiver preenchida

### direnv · `user/app/direnv.nix` · `lcars.user.direnv.enable` · só personal

`direnv` com `nix-direnv`, para shells por projeto.

### dotfiles do 1Password · `user/app/dotfiles.nix` · `lcars.user.dotfiles.enable` · só personal

Arquivos listados em `userSettings.dotfilesFrom1Password` são puxados de itens
**Document** do seu vault na ativação, e aparecem em `~/.config/dotfiles/<nome>`.

Vazio por padrão. Se o `op` não estiver no PATH ou não houver sessão aberta, a
ativação avisa e segue — não falha o rebuild.

### Escape hatch · `user/personal/default.nix` · sem flag

Ponto de extensão para `~/.config/home-manager/private.nix`, um arquivo fora do
repo para o que você não quer publicar. Vem desabilitado (import comentado).

Entra por `sharedModules` (`flake.nix`), fora da lista de `user/default.nix`, e
por isso não tem flag: é a sua porta dos fundos, não parte do preset.

### Ferramentas de linha de comando · profile `personal`

`ripgrep`, `fd`, `bat`, `eza` — definidos em `profiles/personal/default.nix`.

---

## O que **não** vem

Para não haver surpresa:

- **Nenhum secret do opnix está declarado.** O input existe e o módulo é
  carregado, mas o repo não define secret algum. Veja [secrets.md](./secrets.md).
- **Nenhuma chave SSH autorizada.** `lcars.system.security.sshKeys` começa vazio.
- **Nenhum tema.** Não há `themes/` nem stylix.
- **Nenhum profile além de `basic` e `personal`.**
- **Nenhum container, VPN, impressora ou bluetooth** configurado.
- **Nenhum editor além do `vim`**, e nenhuma IDE.
- **Nenhum navegador.** O Plasma vem puro, e nada é acrescentado. `browser` no
  `settings.nix` só define `$BROWSER` — não instala nada. Ponha o seu em
  `userSettings.packages`:

  ```nix
  userSettings.packages = [ "firefox" ];
  ```
- **Nenhum aplicativo KDE além dos que o módulo `plasma6` traz.** Kate, Okular,
  Ark e Spectacle são `kdePackages.<nome>` em `userSettings.packages`.

## Nota sobre `userSettings.packages`

O campo é **opcional**: o `settings.nix` versionado não o traz, e sem ele a
lista é vazia. Acrescente-o quando quiser pacotes só no seu usuário.

Quando existe, é **somado** a `lcars.system.core.userPackages`, que é o que os
profiles usam. Um não apaga o outro.
