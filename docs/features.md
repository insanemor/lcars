# O que vem instalado

Inventário do que uma instalação entrega hoje. Cada seção aponta o arquivo que
define aquilo, para você ir direto à fonte quando quiser mudar.

## Como ler esta lista

Nada em `system/` liga sozinho. O que decide é o **profile** que a máquina
escolhe, e ele é escolhido por você em `settings.nix` — o `bootstrap.sh` só
propõe um default: `basic` em VM, `personal` fora dela.

| | `basic` | `personal` |
|---|---|---|
| Base do sistema (`system/core`) | sim | sim |
| ssh e firewall (`system/security`) | sim | sim |
| Ambiente do usuário (`user/`) | sim | sim |
| Plasma + áudio + fontes (`system/wm`) | — | sim |
| 1Password CLI e GUI (`system/app`) | — | sim |
| `ripgrep`, `fd`, `bat`, `eza` | — | sim |

Os presets estão em `profiles/basic/default.nix` e
`profiles/personal/default.nix`. Um profile define suas flags com `mkDefault`,
então a máquina pode desligar qualquer item individualmente sem abandonar o
resto do preset.

Ajustes de hardware (`system/hardware`) não dependem do profile, e **não são
detectados**: quem os liga é você, em `machines/<host>/default.nix`. O template
traz `lcars.hardware.vm.enable` e `lcars.hardware.laptop.enable` em `false`;
num notebook ou numa VM, mude para `true` e rode o rebuild.

---

## Base do sistema — sempre

`system/core/default.nix` · option `lcars.core`

**Nix**
- Flakes habilitados (`nix-command flakes`) — sem isto o próximo `nixos-rebuild --flake` falharia
- Coleta de lixo automática, semanal, apagando gerações com mais de 30 dias
- `system.stateVersion = "24.05"`

**Locale e console**
- Fuso horário e locale vindos de `settings.nix` (default `America/Sao_Paulo`, `pt_BR.UTF-8`)
- Locales gerados: `pt_BR.UTF-8`, `en_US.UTF-8`, `C.UTF-8`
- `LC_MESSAGES` fixo em `pt_BR.UTF-8`
- Console: fonte `Lat2-Terminus16`, teclado `us-acentos`, pacote `terminus_font`

**Boot** — o hardware-config declara os sistemas de arquivos; aqui só o carregador
- `systemd-boot` (UEFI), limitado a 10 gerações no menu, ou `grub` (BIOS legado)
- Swapfile opcional via `lcars.core.swapFileSize` (desligado por padrão, para não colidir com o swap que o `hardware-configuration.nix` já traga)

**Rede**
- NetworkManager

**Usuário**
- Conta normal com o nome de `userSettings.username`, shell `zsh`
- Grupos: `networkmanager`, `wheel`, `video`, `audio`
- Senha inicial `lcars` — **troque no primeiro login com `passwd`**
- `programs.zsh` habilitado no sistema (necessário para o zsh ser shell de login válido)

**Pacotes de sistema**

`git`, `vim`, `htop`, `curl`, `wget`, `jq`, `rsync`, `gnused`, `gnugrep`, `python3`

Acrescente os seus em `systemSettings.extraPackages` ou `lcars.core.extraPackages`.

---

## Acesso e firewall — sempre

`system/security/default.nix` · option `lcars.security`

- **sshd apenas por chave**: `PasswordAuthentication` e `KbdInteractiveAuthentication` desligados, `PermitRootLogin = "no"`
- Porta 22 aberta no firewall pelo próprio módulo (`openFirewall`)
- Firewall ligado; portas extras em `lcars.security.firewall.allowedTCPPorts`
- Chaves autorizadas em `lcars.security.sshKeys` — **vazio por padrão**

Enquanto `sshKeys` estiver vazio não há como entrar por ssh. O acesso é local,
por senha, no console ou no SDDM. Isso é proposital: uma máquina recém-instalada
não fica aberta na rede.

---

## Ambiente gráfico — só no profile `personal`

`system/wm/plasma.nix` · option `lcars.wm.plasma`

- **KDE Plasma 6** com **SDDM**, sessão padrão Wayland (a sessão X11 continua
  disponível na tela de login; `lcars.wm.plasma.wayland = false` inverte isso)
- **PipeWire** com compatibilidade ALSA (inclusive 32 bits) e PulseAudio; `rtkit` para prioridade de tempo real
- PulseAudio desligado explicitamente — hoje quem faz o trabalho é o PipeWire
- **Fontes**: `noto-fonts`, `noto-fonts-emoji`, `liberation_ttf`, `dejavu_fonts`, mais o conjunto padrão do NixOS
- **Aplicativos**: só o que o módulo `plasma6` do NixOS traz. Nada é
  acrescentado por este repo — **nem navegador**. Remova o que não quiser com
  `lcars.wm.plasma.excludePackages`
- `dconf` habilitado

---

## 1Password — só no profile `personal`

`system/app/1password/default.nix` · option `lcars.apps.onePassword`

- **CLI** (`op`) e **GUI**, ambos com o wrapper e os grupos que o NixOS exige
- Regra polkit para o usuário dono da GUI (`polkitPolicyOwners`)
- Chave pública do `github.com` pré-registrada em `programs.ssh.knownHosts`, para não haver prompt de host desconhecido no primeiro clone
- `ssh` do sistema apontando para `~/.1password/agent.sock` via `IdentityAgent`
- Software proprietário liberado por `allowUnfreePredicate` restrito aos pacotes do 1Password — `allowUnfree` global **não** é ligado

O agente SSH em si é um recurso do aplicativo, ligado em **Settings →
Developer**. Não existe módulo NixOS para ele; o que o repo faz é apontar o ssh
para o socket que o app cria.

---

## Ajustes por hardware — por detecção

### Notebook

`system/hardware/laptop.nix` · option `lcars.hardware.laptop`

- `thermald`
- Tampa fechada: suspende na bateria, ignora na tomada
- Gerenciamento de energia à sua escolha (`powerManager`):
  - **`tlp`** (padrão) — carga limitada a 80–90% para preservar a bateria, governor `performance` na tomada e `powersave` na bateria
  - **`ppd`** — power-profiles-daemon, que integra melhor com o Plasma

Os dois nunca ficam ligados juntos: o NixOS aborta a avaliação se isso acontecer.

### Máquina virtual

`system/hardware/vm.nix` · option `lcars.hardware.vm`

- Módulos virtio no initrd (`blk`, `net`, `pci`, `scsi`, `input`, `gpu`, `balloon`)
- `qemu-guest-agent` e `spice-vdagent` (clipboard e redimensionamento com o host)

---

## Ambiente do usuário — sempre

Módulos do Home Manager, aplicados no mesmo `nixos-rebuild`.

### zsh · `user/shell/zsh.nix`

- Autosuggestion, syntax highlighting e completion
- Histórico de 50 000 linhas, compartilhado entre sessões, sem duplicatas
- Aliases: `ll`, `la`, `l`, `gs` (git status), `gp` (push), `gpl` (pull)
- `zsh-completions`

### starship · `user/shell/starship.nix`

Prompt com integração zsh e bash. A integração é injetada pelo próprio módulo —
não há `source` manual no `.zshrc`.

### git · `user/app/git.nix`

- Nome e email vindos de `settings.nix`
- `init.defaultBranch = main`, `pull.rebase`, `rerere`, `push.autoSetupRemote`
- Aliases: `co`, `br`, `ci`, `st`, `lg`
- Assinatura por chave SSH **apenas se** `userSettings.gpgKey` estiver preenchida

### direnv · `user/app/direnv.nix`

`direnv` com `nix-direnv`, para shells por projeto.

### dotfiles do 1Password · `user/app/dotfiles.nix`

Arquivos listados em `userSettings.dotfilesFrom1Password` são puxados de itens
**Document** do seu vault na ativação, e aparecem em `~/.config/dotfiles/<nome>`.

Vazio por padrão. Se o `op` não estiver no PATH ou não houver sessão aberta, a
ativação avisa e segue — não falha o rebuild.

### Escape hatch · `user/personal/default.nix`

Ponto de extensão para `~/.config/home-manager/private.nix`, um arquivo fora do
repo para o que você não quer publicar. Vem desabilitado (import comentado).

### Ferramentas de linha de comando · profile `personal`

`ripgrep`, `fd`, `bat`, `eza` — definidos em `profiles/personal/default.nix`.

---

## O que **não** vem

Para não haver surpresa:

- **Nenhum secret do opnix está declarado.** O input existe e o módulo é
  carregado, mas o repo não define secret algum. Veja [secrets.md](./secrets.md).
- **Nenhuma chave SSH autorizada.** `lcars.security.sshKeys` começa vazio.
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

O `settings.example.nix` traz `userPackages = [ "zsh" "starship" ]`. Os dois já são
instalados pelo `programs.zsh` do sistema e pelo módulo starship do Home
Manager, então a lista é redundante — inofensiva, mas você pode esvaziá-la.

Essa lista é **somada** a `lcars.core.userPackages`, que é o que os profiles
usam. Um não apaga o outro.
