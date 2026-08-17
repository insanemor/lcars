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
| niri, compositor (`system/wm`) | `lcars.system.wm.niri.enable` | — | sim |
| Config do niri (`user/wm`) | `lcars.user.niri.enable` | — | sim |
| Tema unificado (`system/theme`) | `lcars.system.theme.enable` | — | sim |
| Shell noctalia (`user/wm`) | `lcars.user.noctalia.enable` | — | sim |
| Terminal kitty (`user/app`) | `lcars.user.kitty.enable` | — | sim |
| Multiplexador herdr (`user/app`) | `lcars.user.herdr.enable` | — | sim |
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

O caminho da flag espelha o caminho do arquivo: `lcars.system.wm.niri` é
`system/wm/niri.nix`, `lcars.user.direnv` é `user/app/direnv.nix`. A
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

**Firmware** — o que faz o hardware existir para o kernel
- `hardware.enableRedistributableFirmware` — os blobs de GPU, Wi-Fi, bluetooth
  e placas de rede. Sem eles o driver não fica "sem aceleração": ele **aborta**,
  e o dispositivo não aparece no sistema
- Microcode de CPU ligado para AMD **e** Intel. Os dois porque o repo não sabe
  em que máquina vai rodar, e isso não é descobrível em tempo de avaliação; o
  kernel carrega o que serve à CPU que encontrar
- Ficou de fora o `services.fwupd` — atualizar firmware de placa-mãe é decisão
  de máquina, não de base

  Isto está aqui, e não no `hardware-configuration.nix`, por um motivo que
  custou uma tarde: aquele arquivo é gerado por máquina e está no `.gitignore`.
  O `nixos-generate-config` escreve as três options nele, então elas existiam
  por acidente em quem gerou o arquivo com elas — e faltavam no resto. O caso
  concreto foi uma Radeon RX 6900 XT passada a uma VM: instalação sem um erro,
  sessão do niri de pé, monitor preto, e no journal
  `amdgpu: Direct firmware load for amdgpu/sienna_cichlid_smc.bin failed with
  error -2` seguido de `Fatal error during GPU init`. A placa nunca virou
  `/dev/dri/card*`

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

**Só há um, e é o niri.** Plasma e Hyprland saíram na
[#34](https://github.com/insanemor/lcars/issues/34) — a tela de login tem uma
sessão só, e se ela não subir a volta é pelo TTY (veja o fim desta seção).

### A tela de login · `system/wm/default.nix` · option `lcars.system.wm`

O SDDM, a escolha da sessão, as **fontes** e o **dconf** não pertencem a
nenhum compositor. Se morassem dentro de um, ligar um segundo daria conflito
de definição — e, pior, desligar aquele levaria as fontes do sistema junto,
que foi o que quase aconteceu ao remover o Plasma.

- `defaultSession` — vazio decide sozinho; hoje só existe `"niri"`
- `sddm.wayland` — se o próprio SDDM roda em Wayland
- **Fontes**: `noto-fonts`, `noto-fonts-color-emoji`, `liberation_ttf`,
  `dejavu_fonts`, mais o conjunto padrão do NixOS. O stylix acrescenta a Nerd
  Font do terminal
- `dconf` habilitado, para aplicativos GTK guardarem preferência

### niri · `system/wm/niri.nix` + `user/wm/niri.nix`

Compositor Wayland com **tiling scrollable**. Dividido nos dois lados do repo:
o compositor é do sistema, o `config.kdl` é seu.

#### O que "scrollable" muda

As janelas formam uma fita horizontal que se estende sem limite, e a tela rola
por ela. Abrir uma janela nova **não redivide** o espaço das que já estão
abertas — elas continuam do tamanho que estavam e saem de vista pela lateral.

Isso é arquitetura, não modo de layout: nenhum ajuste de Hyprland produz esse
comportamento, e foi o motivo da troca.

A unidade de navegação é a **coluna**, não a janela. Uma coluna pode ter várias
janelas empilhadas na vertical.

#### Sistema · `lcars.system.wm.niri.enable`

O módulo do nixpkgs resolve bastante: registra a sessão em
`displayManager.sessionPackages`, liga o `gnome-keyring` e monta os portais XDG
na combinação que o upstream recomenda (gnome para screencast e captura, gtk
para o resto).

- `useNautilus` (padrão `true`) — o Nautilus como seletor de arquivos do
  portal. Sem Plasma não há mais Dolphin, e este é o gerenciador de arquivos
  que sobra: o portal o abre em todo "salvar como"
- Utilitários que o niri não traz: `wl-clipboard`, `brightnessctl`, `pamixer`,
  `playerctl`

**`grim` e `slurp` não estão aqui**, ao contrário do que havia no Hyprland: a
captura de tela é nativa do niri, com seleção de região, janela e monitor.

**XWayland** não vem do módulo NixOS, que monta a sessão com
`enableXWayland = false` — o niri não embute servidor X, usa o
`xwayland-satellite`, um processo à parte que sobe sob demanda. Quem o põe no
PATH é o home-manager (`xwaylandSatellitePackage`, ligado por padrão). Sem ele,
aplicativos X11 não abrem.

**Agente polkit**: não há serviço aqui, ao contrário do Hyprland. Quem atende é
o do noctalia (`polkit_agent = true`). Um agente por vez — dois disputando o
mesmo serviço é conflito, não redundância.

#### Usuário · `lcars.user.niri.enable`

| Atalho | O que faz |
|---|---|
| `SUPER+Enter` | terminal (kitty) |
| `SUPER+D` | lançador |
| `SUPER+N` | notificações |
| `SUPER+C` | centro de controle |
| `SUPER+V` | histórico da área de transferência |
| `SUPER+ESC` | menu de sessão |
| `SUPER+H` / `SUPER+L` | **rola entre colunas** (ou `←` `→`) |
| `SUPER+J` / `SUPER+K` | foco **dentro** da coluna (ou `↓` `↑`) |
| `SUPER+SHIFT+H/J/K/L` | move a janela ou a coluna |
| `SUPER+,` / `SUPER+.` | junta a janela vizinha à coluna, ou a expulsa |
| `SUPER+R` | cicla a largura: ⅓, ½, ⅔ |
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

Os painéis são comandos de IPC para o shell que já está no ar
(`noctalia msg panel-toggle <id>`), não programas que abrem e fecham. As teclas
de mídia levam `allow-when-locked`, porque volume e brilho fazem sentido com a
tela bloqueada.

O layout do teclado vem de `lcars.system.hardware.keyboard`, o mesmo do console
e do SDDM — não é redefinido aqui.

#### A cor, e por que ela é manual

**O stylix não tem alvo para niri** (`modules/` traz hyprland, kde, gtk e qt).
Então nada é pintado sozinho: `user/wm/niri.nix` lê `config.lib.stylix.colors`
e escreve as cores explicitamente. O anel de foco sai como gradiente
`base0D → base0A` — com o `simbiot-dark`, o ciano do logo indo ao lime, herdeiro
direto da borda que o Hyprland tinha. Trocar `scheme` continua repintando
junto; a diferença é que é este arquivo que faz, não o stylix.

#### A configuração é validada no build

`checkConfig` está ligado, e o `niri validate` roda ao construir o
`config.kdl`. Um atalho para uma ação inexistente derruba o build com a linha
e a mensagem exatas, em vez de virar tela preta:

```
Error:   x error parsing KDL
Error:   x expected `quit`, `suspend`, or one of 133 others
 148 |         acao-que-nao-existe
     :                  `-- invalid value
```

Isso exige `package` não-nulo no módulo do home-manager — é o mesmo derivation
que o sistema instala, então não há segunda cópia no store.

#### Se o niri não subir

Não há segunda sessão na tela de login:

```bash
# Ctrl+Alt+F2
cd ~/.dotfiles
$EDITOR machines/<máquina>/default.nix   # lcars.system.wm.niri.enable = false;
nupdate
```

### Shell · `user/wm/noctalia.nix` · `lcars.user.noctalia.enable`

Barra, lançador, servidor de notificações, centro de controle, histórico de
área de transferência, menu de sessão, OSD de volume e brilho e papel de
parede — uma peça só, em vez de waybar + rofi + swaync, que eram três módulos
com três formatos de configuração e nenhuma interface de ajuste.

Sobe por unidade systemd (`programs.noctalia.systemd.enable`), não pelo
`spawn-at-startup` do niri: assim reinicia se cair e `systemctl --user status
noctalia` diz o que houve. Pelo `exec-once`, falha é silêncio.

Sem ele o niri não tem servidor de notificação, e aí nada avisa bateria
fraca nem download concluído — quem tentou notificar não recebe erro, então o
silêncio parece normal.

#### O ciclo GUI → export → commit

É o motivo de ele estar aqui. O noctalia tem centro de controle gráfico, e o
que você ajusta ali dá para exportar e versionar:

Ajuste no centro de controle (`SUPER+C`) e veja o resultado na hora. Quando
gostar, um comando faz o resto:

```bash
nsave
```

O `nsave` (`scripts/save.sh`) exporta, valida o TOML, mostra o diff, pergunta e
publica. É o [`nupdate` ao contrário](#nsave--publicar-o-que-voc%C3%AA-ajustou-aqui).

À mão, se preferir ver cada passo:

```bash
noctalia config export merged > ~/.dotfiles/user/wm/noctalia-config.toml
cd ~/.dotfiles && git diff && git commit -am "config: barra no topo" && git push
```

Sem o export, o ajuste vive só no state-dir daquela máquina e some num clone
novo — e some **mais rápido** do que parece: o `nupdate` faz
`git reset --hard`, então rodá-lo antes de salvar apaga o que você exportou. É
justamente o que o `nsave` evita.

O arquivo fica pequeno por conta do `merged`, que exporta **a sua**
configuração e não os defaults embutidos do noctalia (esse é o `full`). O diff
mostra o que você mudou, não centenas de linhas de valores padrão.

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
vez, aplicado pelo [stylix](https://github.com/danth/stylix) em: **noctalia,
kitty, GTK, Qt e o console TTY**. O niri fica de fora — não há alvo para ele,
e `user/wm/niri.nix` aplica as mesmas cores à mão.

| Option | Padrão | Para quê |
|---|---|---|
| `scheme` | `"simbiot-dark"` | nome de um esquema — deste repositório ou do pacote `base16-schemes` |
| `polarity` | `"dark"` | diz aos programas se o esquema é claro ou escuro |
| `wallpaper` | `null` | `null` = cor sólida pintada pelo compositor, **sem daemon**; uma imagem liga o hyprpaper |
| `fonts.monospace` | `"JetBrainsMono Nerd Font"` | terminal e editor |
| `fonts.sansSerif` | `"JetBrainsMono Nerd Font"` | **interface**: menus, diálogos, barra e painéis do noctalia |
| `fonts.size` | `11` | corpo da fonte de interface |
| `rice` | `true` | a **geometria** do compositor: anel de foco em gradiente e espaçamento maior. `false` deixa o anel sólido e discreto, ainda pintado pelo esquema |
| `animations` | `true` | transições, sombras e blur. `false` remove **só o custo de GPU**, sem mudar funcionalidade |

**Por que fica em `system/theme/` e não em `system/wm/`:** tema é transversal.
Ele pinta o console TTY, o GTK e o Qt, que existem independentemente de qual
ambiente gráfico está ligado. Amarrá-lo a um WM faria a cor do console depender
do desktop.

**Por que stylix e não cor à mão.** O repo de referência fia a paleta em cada
programa — 17 arquivos `.rasi` só para o lançador, CSS próprio para a barra,
218 arquivos ao todo. Aqui, trocar de esquema é uma
linha, e nenhum programa fica para trás.

### `simbiot-dark`, a paleta padrão

`system/theme/schemes/simbiot-dark.yaml`. As cores do site da SimbioIT,
amostradas por região da página e não escolhidas a olho:

| base | Hex | De onde veio | Onde aparece |
|---|---|---|---|
| `base00` | `#111d23` | fundo da página | fundo de tudo |
| `base05` | `#b4c4c3` | texto do parágrafo | texto padrão |
| `base07` | `#eef3f3` | títulos | texto de destaque |
| `base0A` | `#bad350` | quadrados do arco | classe, aviso, e o fim do gradiente da borda |
| `base0B` | `#6ad3a1` | palavra "Inovadoras" | string, sucesso |
| `base0C` | `#4accbc` | botão e "Soluções" | suporte, escape |
| `base0D` | `#29b6bf` | **logo e arco** | a primária — barra, foco, botões do noctalia, início do gradiente |

As outras nove são derivadas: a escala de fundo (`base01`-`base04`, `base06`) e
os acentos que o site não tem (`base08` vermelho, `base09` laranja, `base0E`
violeta, `base0F` rosa), que o base16 exige para sintaxe e erro. Ficaram na
mesma família das extraídas — S 38-62, V 74-85, com os fundos presos ao
azul-petróleo do site.

Contraste medido em WCAG contra o fundo: texto 9.50:1 e títulos 15.32:1, os
dois AAA; o acento mais fraco é 4.61:1, nenhum abaixo de AA. O `base03`
(comentários) fica em 3.12:1, que é o piso do próprio base16 — ele reserva essa
cor justamente para o que deve recuar.

**`base0D` é o ciano do logo, e não o verde-água, de propósito.** O stylix passa
`base0D` como `mPrimary` para o noctalia e é ela que abre o gradiente da borda
do niri — é a cor que dá a cara do sistema. Verificado: o noctalia recebe
`mPrimary = #29b6bf` e o anel de foco sai como
`active-gradient from="#29b6bf" to="#bad350" angle=45`, que é o arco da direita
do site.

### Usando outro esquema, ou criando o seu

`scheme` procura primeiro em `system/theme/schemes/<nome>.yaml`, neste
repositório, e só depois no pacote. A mesma option serve aos dois:

```nix
lcars.system.theme.scheme = "simbiot-dark";       # daqui
lcars.system.theme.scheme = "gruvbox-dark-hard";  # do pacote
```

Para criar o seu, ponha um `.yaml` em `schemes/` — e leia o cabeçalho do
`simbiot-dark.yaml` antes: o parser YAML que o stylix usa é em Nix puro e tem
duas armadilhas que **não** dão erro no lugar certo (comentário indentado dentro
de `palette:`, e dois-pontos seguido de espaço em comentário inline, que faz a
cor sumir da paleta em silêncio).

Nada no repositório escreve cor fixa. O gradiente da borda é `base0D → base0A`,
então trocar de esquema troca o gradiente junto — com `gruvbox-dark-hard` ele
vira `rgb(83a598) rgb(fabd2f)`, verificado.

### A mesma fonte em tudo

`sansSerif` aponta para a **mesma** Nerd Font da `monospace`, e isso é
deliberado. Ela é monoespaçada, então a interface inteira fica com largura
fixa — em troca, os ícones existem em toda superfície, sem depender de o
fontconfig achar um fallback.

Onde a fonte chega, verificado por avaliação:

| Superfície | De onde vem |
|---|---|
| terminal (kitty) | `monospace` |
| barra e painéis do noctalia | `sansSerif` |
| menus e diálogos GTK | `sansSerif` |
| Qt | `sansSerif` |

Para o visual convencional, `lcars.system.theme.fonts.sansSerif = "Noto Sans"` —
que já está instalado por `system/wm/default.nix`.

**Uma limitação a saber:** o *pacote* declarado ao stylix é fixo
(`nerd-fonts.jetbrains-mono`), e só o *nome* é configurável. Trocar o nome
funciona para fontes já instaladas — Noto, Liberation e DejaVu estão —, mas não
puxa pacote novo. Uma fonte de fora exige acrescentá-la a `fonts.packages`.

Houve um caso concreto que motivou tudo isto: o `font_family` que o usuário
tinha escolhido na GUI do noctalia era a Nerd Font, e a poda que evita conflito
com o stylix a substituía por `Noto Sans` — porque o stylix usa `sansSerif`
para o shell. Com as duas apontando para a mesma fonte, a escolha volta a
valer.

### `animations = false`, para GPU fraca

Separada da `rice` de propósito, porque são eixos diferentes de custo:

| | O que é | Custa |
|---|---|---|
| `rice` | forma — gradiente, espaçamento | desenhado uma vez |
| `animations` | transição, sombra, blur | redesenha a tela a cada quadro |

Quem tem GPU fraca quer desligar o segundo sem abrir mão do primeiro. As quatro
combinações são válidas e independentes.

Com `animations = false`:

- **niri** ganha `animations { off }` — a janela aparece no lugar em vez de
  deslizar, o workspace troca instantaneamente;
- **noctalia** perde `shell.animation.enabled`, `shell.shadow.alpha`,
  `bar.shadow`, `dock.shadow`, `backdrop.blur_intensity` e
  `lockscreen.blurred_desktop`.

**Nada de funcionalidade muda.** Painéis, janelas e o scroll do niri continuam
iguais; some a transição, não o comportamento.

O caso que motivou a flag: uma VM cuja aceleração 3D é traduzida por VirGL
sobre uma Radeon de 2010. Ali, redesenhar a tela a cada movimento do mouse é o
gargalo, e nenhum aumento de CPU ou RAM resolve.

As chaves do noctalia entram pela mesma mecânica de poda que as do stylix — o
TOML e o Nix não podem definir a mesma chave, então quem vai sobrescrever poda
antes. A fusão é `recursiveUpdate`, e não `//`, porque os efeitos vivem a dois
níveis: uma fusão rasa apagaria as outras chaves de `shell` vindas do seu
export.

### O papel de parede, e por que ele é uma cor

Sem `wallpaper` definido, **não há daemon de papel de parede**. O fundo é a
cor que o compositor pinta sozinho, derivada de `base00`.

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

**Sem nenhum valor de cor escrito**: anel de foco em gradiente 45°
(`base0D` → `base0A`) e `gaps` em 9. Com `rice = false`, o anel fica sólido em
`base0D` e os gaps caem para 4 — mais discreto, mesma paleta.

A forma da barra e dos painéis **não** está aqui: quem a define é o noctalia, e
você a ajusta pelo centro de controle, exportando o resultado (veja o ciclo
acima). A flag `rice` governa só o compositor.

---

## 1Password — só no profile `personal`

`system/app/1password/default.nix` · option `lcars.system.app.onePassword`

- **CLI** (`op`) e **GUI**, ambos com o wrapper e os grupos que o NixOS exige
- Regra polkit para o usuário dono da GUI (`polkitPolicyOwners`)
- As **três** chaves de host do `github.com` (RSA, ECDSA, ED25519) em `programs.ssh.knownHosts`, para não haver prompt de host desconhecido no primeiro clone — e para recusar quem não for o GitHub
- `ssh` do sistema apontando para `~/.1password/agent.sock` via `IdentityAgent`
- `gpg.ssh.program` do git apontando para o `op-ssh-sign`, quando há chave de assinatura (`user/app/git.nix`)
- Software proprietário liberado por `allowUnfreePredicate` restrito aos pacotes do 1Password — `allowUnfree` global **não** é ligado

O agente SSH em si é um recurso do aplicativo, ligado em **Settings →
Developer**. Não existe módulo NixOS para ele; o que o repo faz é apontar o ssh
para o socket que o app cria.

### Por que três chaves, e não uma

Quem escolhe o algoritmo é a negociação entre cliente e servidor. Com só a
ED25519 no arquivo, um cliente que negocie RSA cai em
`REMOTE HOST IDENTIFICATION HAS CHANGED` — o mesmo erro de uma chave errada.

E elas **não se escrevem de memória**. A primeira versão deste bloco tinha uma
ED25519 inventada, com o prefixo correto e o final fabricado
([#30](https://github.com/insanemor/lcars/issues/30)). O efeito foi curioso: a
verificação falhou *fechada* — recusou a conexão em vez de aceitar um host não
verificado, que é o comportamento seguro — mas quebrou todo SSH para o GitHub, e
de forma circular, porque o `nupdate` precisa de `git fetch` para trazer a
própria correção. O comentário no módulo traz o comando de reconferência e as
fingerprints publicadas; o README traz a saída do impasse.

### O que só pode ser feito à mão

Três cliques que nenhum módulo cobre, e sem os quais o `nsave` não publica:
ligar *Use the SSH agent* em **Settings → Developer**, ter um item do tipo *SSH
Key* no cofre, e cadastrar a chave pública em
[github.com/settings/keys](https://github.com/settings/keys). O `install.sh`
imprime esses passos ao terminar; o README os detalha.

### `IdentityAgent` depende da GUI, não só do agente

`programs.ssh.extraConfig` é escrito quando `enableSshAgent` **e** `enableGui`
estão ligados. Quem cria o socket é o app gráfico: numa máquina headless, ou no
profile `basic`, a linha apontaria para um caminho que nunca vai existir, e todo
`ssh` da máquina passaria por um agente ausente antes de cair nas chaves do
disco.

### Assinatura de commits · `user/app/git.nix`

Desligada por padrão — sem `gpgKey` no `settings.nix`, o bloco inteiro sai da
configuração, em vez de declarar `format = "ssh"` sem chave nenhuma.

Com `gpgKey` preenchido **e** a GUI instalada, entra também:

```
[gpg "ssh"]
	program = …/bin/op-ssh-sign
```

Sem essa linha a assinatura falharia: a chave vive dentro do cofre e nunca vira
arquivo em disco, e o `ssh-keygen -Y sign` padrão espera um caminho de chave
privada. Com `enableGui = false` ela não é escrita — aí a chave é de disco e o
comportamento padrão do git serve.

O aninhamento importa. `programs.git.extraConfig` é tipado como
`attrsOf (attrsOf (either valor seção))` (home-manager,
`modules/programs/git.nix:41-49`), então `gpg.ssh.program` em três níveis vira a
subseção `[gpg "ssh"]`. Escrito como `"gpg.ssh".program`, sairia uma seção de
nome literal `gpg.ssh` e o git não leria a chave.

---

## Áudio — flag própria

`system/hardware/audio.nix` · option `lcars.system.hardware.audio`

- **PipeWire** falando ALSA, PulseAudio e (opcionalmente) JACK
- `security.rtkit` para prioridade de tempo real — sem isso há falhas audíveis sob carga
- PulseAudio desligado explicitamente: os dois disputam o mesmo socket
- `support32Bit` ligado por padrão (jogos, binários proprietários antigos);
  `jack` desligado, para quem não usa Ardour ou Carla

Ligado no profile `personal`. Morava dentro do módulo do Plasma, o que
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
  - **`ppd`** — power-profiles-daemon, que integra melhor com ambientes GNOME/KDE

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

- **oh-my-zsh**, com três plugins: `git`, `sudo` (ESC ESC repete com sudo) e `systemd`
- **powerlevel10k** como prompt, do preset *rainbow*
- Autosuggestion, syntax highlighting e completion
- Histórico de 50 000 linhas, compartilhado entre sessões, sem duplicatas
- Aliases: `ll`, `la`, `l`, `gs` (git status), `gp` (push), `gpl` (pull)

#### A ordem de carga, que é o que pode quebrar

Três camadas precisam entrar em sequência: o framework, o tema, e a
configuração do tema. O home-manager carrega `programs.zsh.plugins` **depois**
do oh-my-zsh e na ordem da lista, então o p10k e o `p10k.zsh` são declarados
ali — e não em `initContent`, que roda no fim e leria a configuração antes de o
tema existir.

Conferido no `.zshrc` gerado:

```
35: source $ZSH/oh-my-zsh.sh
39: powerlevel10k/…/powerlevel10k.zsh-theme
40: p10k-config/p10k.zsh
```

**`oh-my-zsh.theme` fica vazio**, e não `"powerlevel10k"`: o p10k não é um tema
do framework, é um plugin próprio. Apontá-lo ali faria o oh-my-zsh procurar um
arquivo no diretório de temas dele, não achar, e cair no prompt padrão sem
avisar.

**A lista de plugins do oh-my-zsh não repete o que já vem por option.**
`autosuggestion` e `syntaxHighlighting` são options do módulo, e acrescentá-los
à lista do framework carregaria os mesmos plugins duas vezes. Verificado: cada
um aparece uma única vez no `.zshrc`.

#### O prompt · `user/shell/p10k.zsh`

O preset *rainbow*, copiado do pacote para o repositório para poder ser
editado. Para mudar: rode `p10k configure`, que escreve em `~/.p10k.zsh` — um
arquivo que o Nix **não** gerencia —, copie por cima de
`user/shell/p10k.zsh` e publique com `nsave`.

**A cor do prompt vem do tema, mas por um caminho próprio.** O preset traz 232
variáveis de cor, todas em índices de terminal (0-255) — e um índice é "o azul
do terminal, seja qual for", não uma cor escolhida.

O que resolve isso: o p10k **aceita hexadecimal**, o que está no código dele
(`internal/p10k.zsh:535`). Então `user/shell/zsh.nix` gera um bloco de
sobreposição a partir de `lib.stylix.colors` e o injeta com `mkAfter`, depois
do preset:

| Segmento | Cor |
|---|---|
| diretório | `base0D` — o ciano do logo |
| git limpo | `base0B` |
| git modificado | `base0A` — lime |
| git com arquivo novo | `base0C` |
| git em conflito, erro | `base08` |
| tempo de execução, relógio | `base02` e `base01` |

Trocar `scheme` repinta o prompt junto com o resto do sistema.

**Sem tema, o prompt fica com as cores do próprio preset.** A sobreposição só
é gerada quando `lcars.system.theme.enable` está ligada — que é o caso do
profile `personal`, e não do `basic`, onde um esquema de cores em máquina
headless seria peso morto.

A guarda não é cosmética: `config.lib.stylix` **não existe** quando o módulo do
stylix está desligado, e ler esse atributo aborta a avaliação inteira com
`attribute 'stylix' missing`. Como o `nupdate` avalia os dois profiles antes de
aplicar, o profile `basic` quebrado bloqueava o rebuild também de quem usa o
`personal` — que é exatamente o que aconteceu entre a #39 e a #42.

**Por que sobrepor em vez de gerar o `p10k.zsh` inteiro:** o ciclo daquele
arquivo é rodar `p10k configure` e copiar o resultado por cima. Se ele fosse um
template, o assistente o sobrescreveria com índices numéricos no primeiro uso.
Assim o preset continua seu, e a cor continua do tema.

Os segmentos raros — ícone de sistema, bateria, versões de linguagem, nuvens —
ficam com os índices do preset. Aparecem pouco e não valem a manutenção.

### Terminal · `user/app/kitty.nix` · `lcars.user.kitty.enable` · só personal

O kitty já era instalado antes, por `home.packages` no módulo do compositor — e
rodava com os defaults de fábrica, porque **instalar o pacote não é configurar
o programa**. O stylix tem alvo para kitty, mas age sobre `programs.kitty`; sem
o módulo habilitado, nenhum `kitty.conf` era gerado.

Era por isso que a paleta pintava o sistema inteiro menos o terminal, e a Nerd
Font não aparecia justamente onde os ícones do prompt precisam dela.

Com o módulo, o `kitty.conf` sai assim:

```
font_family JetBrainsMono Nerd Font
font_size 11
include …/base16-simbioit-dark.conf     # background #111d23, color4 #29b6bf
```

Fonte, tamanho e todas as cores vêm de `lcars.system.theme` — nada disso está
escrito no módulo. O que ele define é só comportamento: 10 000 linhas de
histórico de rolagem, sem confirmação ao fechar, e sem decoração de janela
(quem desenha a moldura é o compositor, por `prefer-no-csd`).
- **`nupdate`** e **`nsave`** — os dois sentidos, descritos logo abaixo
- `zsh-completions`

Esta flag é a única de `user/` que mexe também no sistema: ela decide o shell
de login da conta (`bash` quando desligada). Veja "Base do sistema" acima.

#### `nupdate` — trazer o repositório para esta máquina

`scripts/update.sh`. Sincroniza `~/.dotfiles`, avalia os `.nix` e roda o
`nixos-rebuild`. Aceita `--inputs` para atualizar o nixpkgs junto e
`--no-check` para pular a avaliação.

**Em conflito, o repositório vence** — sem perguntar, sem parar. O que você
editou vai para um `git stash` nomeado e commits locais descartados ficam no
`reflog`; as duas coisas são rede de segurança, não confirmação.
`machines/<host>/` é preservado sempre, porque não existe no repositório.

#### `nsave` — publicar o que você ajustou aqui

`scripts/save.sh`. O caminho de volta, e o par natural do ciclo do noctalia:

```bash
nsave                       # exporta, valida, mostra o diff, pergunta, publica
nsave -m "barra no topo"    # com a sua mensagem de commit
nsave -n                    # mostra tudo que faria, sem alterar nada
nsave -y                    # sem perguntar
nsave --no-export           # não roda o export do noctalia
```

Na ordem: exporta a configuração do noctalia por cima do arquivo versionado,
**valida o TOML** (inválido para aqui, antes de qualquer commit), consulta o
remoto, mostra o que mudou aqui e o que ainda não subiu, espera você confirmar,
commita em `main` e publica.

Quatro decisões que valem saber:

- **`machines/` não é publicado.** É o único diretório que descreve hardware, e
  cada máquina tem o seu — levá-lo junto num comando que roda sem atenção faria
  uma máquina sobrescrever a configuração da outra. Se você mexeu lá, o script
  lista os arquivos e segue sem eles.

  O commit usa `--only` com os caminhos, e não é detalhe: **o index deste
  repositório nunca está limpo.** O `nupdate` faz `git add -f machines/<host>`
  a cada execução, porque flakes só leem arquivos rastreados — então um
  `git commit` seco levaria a máquina junto, que foi o que aconteceu na
  [#33](https://github.com/insanemor/lcars/issues/33). Vale para você também:
  um `git commit -m` à mão dentro de `~/.dotfiles` carrega `machines/` sem
  avisar. Use `git commit -- <arquivo>`.
- **Ter o que commitar e ter o que publicar são coisas diferentes.** Um commit
  feito à mão deixa a árvore limpa e o remoto desatualizado ao mesmo tempo; o
  `nsave` publica esse commit sem criar um vazio por cima. A primeira versão
  olhava só a árvore e saía dizendo que estava tudo em dia sem ter consultado o
  remoto ([#31](https://github.com/insanemor/lcars/issues/31)) — por isso o
  `fetch` acontece antes de decidir se há trabalho.
- **Conflito não é adivinhado.** Se o remoto estiver à frente, ele rebaseia; se
  o rebase parar, desfaz o rebase e sai explicando, com o seu commit intacto e
  nada pela metade. Ao contrário do `nupdate`, aqui não há lado que sempre
  vence — os dois são trabalho seu.
- **Ele não aplica nada.** Publicar e aplicar são coisas diferentes; aplicar é
  o `nupdate`.

Sem rede, ou com o SSH ainda por configurar, o `fetch` falha — e aí ele avisa e
segue com a referência em cache, em vez de abortar. Dá para commitar offline; o
`push` é que vai falhar no fim.

Se o noctalia não estiver no PATH, o script avisa e segue sem exportar — o que
o torna útil para publicar qualquer ajuste feito na máquina, não só o do shell.

### Multiplexador · `user/app/herdr.nix` · `lcars.user.herdr.enable` · só personal

O [herdr](https://herdr.dev) ocupa o lugar do tmux: workspaces, painéis lado a
lado e sessões que continuam de pé depois de o terminal fechar. Os atalhos são
os do tmux de propósito — prefixo `Ctrl-a`, `|` e `-` para dividir, `hjkl` para
andar entre painéis — para a memória muscular atravessar a troca.

| Atalho | O que faz |
|---|---|
| `prefix + \|` / `prefix + -` | divide o painel na vertical / na horizontal |
| `prefix + hjkl` ou `Alt+setas` | move o foco entre painéis |
| `prefix + SHIFT+HJKL` | troca os painéis de lugar |
| `prefix + z` | zoom no painel atual |
| `prefix + r` | modo resize (`hjkl` redimensiona, `Esc` sai) |
| `prefix + c` / `prefix + SHIFT+X` | nova aba / fecha a aba |
| `SHIFT+←` / `SHIFT+→` | troca de aba, sem prefixo |
| `prefix + 1..9` | vai direto para a aba |
| `prefix + SHIFT+N` / `SHIFT+D` / `SHIFT+W` | nova workspace / fecha / renomeia |
| `CTRL+↑` / `CTRL+↓` | troca de workspace, sem prefixo |
| `prefix + g` | picker de workspace |
| `prefix + SHIFT+G` | lazygit num popup de 90% |
| `prefix + b` / `prefix + SHIFT+B` | painel de browser em split / em overlay |
| `prefix + SHIFT+R` | recarrega a configuração |
| `prefix + ?` | a tabela completa, dentro do programa |

**O pacote vem de fora do nixpkgs**, onde o herdr não existe: o input `herdr`
do flake aponta para o repositório do upstream, que mantém o próprio
`packages.<system>.default`. Isso quer dizer **compilar** — Rust, mais o
libghostty-vt pelo zig, sem cache binário — no primeiro rebuild depois de ligar
a flag e a cada `nupdate --inputs` que mexa neste input. O `herdr update` do
próprio programa não funciona aqui, e nem deveria: quem manda na versão é o
`flake.lock`.

O `config.toml` é gerado pelo módulo, com as cores tiradas do esquema base16 do
stylix — os 19 tokens de tema do herdr são sobrescritos, então trocar
`lcars.system.theme.scheme` repinta o multiplexador junto com o resto.

Duas consequências de o arquivo ser gerado, que valem conhecer:

- ele nasce com `onboarding = false`. Não é preferência: sem isso o herdr
  tentaria gravar essa linha no arquivo, que é um link read-only para o store,
  na primeira vez que subisse;
- `herdr config reset-keys` e a tela de settings **vão falhar** ao tentar
  salvar. O caminho é editar `user/app/herdr.nix` e rodar `nupdate`, como em
  todo dotfile gerado deste repo.

Os **plugins** do herdr (browser, file viewer, claude-usage) são baixados em
tempo de execução por `herdr plugin`, num diretório que o Nix não gerencia. Os
atalhos `prefix + b` já apontam para o `official.browser` com o chromium do
nixpkgs, mas ficam inertes até o plugin ser instalado uma vez, à mão — o mesmo
vale para o token `$claude_usage` da sidebar.

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
- **Nenhum navegador.** `browser` no `settings.nix` só define `$BROWSER` — não
  instala nada. (O módulo do herdr traz um chromium para o closure, mas ele
  fica fora do PATH: serve de motor ao painel de browser, não de navegador.)
  Ponha o seu em `userSettings.packages`:

  ```nix
  userSettings.packages = [ "firefox" ];
  ```
- **Nenhuma suíte de aplicativos.** Sem Plasma não há Dolphin, Kate, Okular nem
  Configurações do Sistema. O que sobra de gerenciador de arquivos é o
  **Nautilus**, que vem pelo `useNautilus` do niri como seletor do portal e
  serve como aplicativo. O resto é `userSettings.packages`.

## Nota sobre `userSettings.packages`

O campo é **opcional**: o `settings.nix` versionado não o traz, e sem ele a
lista é vazia. Acrescente-o quando quiser pacotes só no seu usuário.

Quando existe, é **somado** a `lcars.system.core.userPackages`, que é o que os
profiles usam. Um não apaga o outro.
