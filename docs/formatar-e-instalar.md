# Formatar e instalar: checklist do dragon-pc

Este documento existe para ser seguido **no dia** de formatar o dragon-pc
(Ryzen 9 5900X, Radeon RX 6900 XT + Radeon HD 5450 "Cedar", ASUS TUF GAMING
X570-PLUS_BR) e trocar o Garuda atual por este repositório em bare-metal —
levantamento original na issue [#150](https://github.com/insanemor/lcars/issues/150).

Nenhum item aqui é bug de código. São armadilhas do *processo* — coisas que
só aparecem entre apagar o disco atual e o primeiro boot funcionando, quando
não dá mais para consultar o sistema antigo para conferir.

## 1. O hostname não vem mais só do DMI

Resolvido em `scripts/install.sh`: o instalador lê `product_name` do DMI (na
ASUS desta placa, isso responde literalmente `System Product Name` — a
fabricante não preencheu) e também o hostname que a máquina já está usando
*agora*, rodando o Garuda. Antes de criar `machines/<nome>/`, ele mostra os
dois e pergunta qual usar. Esse nome vira o diretório em `machines/` e o
`networking.hostName` para sempre — não é campo que se edita depois sem
renomear o diretório e refazer o `git add -f`.

No dia: responda com atenção quando o prompt aparecer. Se as duas opções
parecerem erradas (por exemplo, o hostname atual também virou algo genérico),
interrompa e crie `machines/<nome>/` à mão a partir do template, como descrito
em [docs/adding-a-host.md](./adding-a-host.md).

## 2. ESP: 300 MB não bastam

A partição EFI atual (`nvme0n1p1`) tem 300 MB, tamanho da instalação Garuda.
`systemd-boot` com `configurationLimit = 10` (`system/core/default.nix`)
enche isso rápido — cada geração do NixOS guarda um kernel e um initrd
próprios ali. **Ao reparticionar, reserve 1 GB para a ESP.**

## 3. Duas GPUs no barramento: Cedar como padrão

A Radeon RX 6900 XT (`07:00.0`) e a Radeon HD 5450 "Cedar" (`0d:00.0`)
convivem no mesmo PC. Na VM, a Cedar servia o host enquanto a Navi ia para o
Windows em passthrough; bare-metal, as duas ficam fisicamente ativas ao mesmo
tempo, e a decisão é a Cedar assumir a sessão por padrão.

**Isto não é uma opção do NixOS.** As duas placas já sobem sozinhas —
`amdgpu` cobre as duas, e `hardware.graphics.enable` já é `true` — mas *qual*
GPU o compositor trata como principal não é algo que o Nix decide: niri (via
smithay, como os demais compositores Wayland) prefere a GPU que o firmware
marcou como `boot_vga` no POST, e essa flag é decidida pela BIOS, não pelo
kernel nem pelo compositor. Não existe uma opção não-documentada de contorno
aqui — foi verificado antes de escrever isto, não assumido
(veja a issue #150, comentário de pesquisa).

No dia, depois de particionar e antes de instalar:

1. Entre na BIOS/UEFI da ASUS TUF GAMING X570-PLUS_BR e procure a opção de
   **vídeo/display primário** (costuma estar em *Advanced → onboard devices*
   ou similar, às vezes nomeada "Initial Display Output" ou "Primary
   Display"). Aponte para o slot PCIe onde a Cedar está instalada — não para
   "Auto" nem para o slot da 6900 XT.
2. Depois do primeiro boot, confirme qual placa ganhou a flag:
   ```
   for c in /sys/class/drm/card*/device; do
     echo "$c: $(cat "$c"/boot_vga 2>/dev/null) — $(lspci -s "$(basename "$(readlink -f "$c")")" 2>/dev/null || true)"
   done
   ```
   A placa com `boot_vga` = `1` é a que o compositor vai preferir. Se for a
   6900 XT em vez da Cedar, o ajuste é na BIOS, não em `machines/dragon-pc/`.
3. Ligue o(s) monitor(es) de uso normal na Cedar. A 6900 XT continua
   disponível como segunda GPU — niri hoje não faz renderização dividida
   entre GPUs (é trabalho futuro do upstream, não uma limitação deste repo),
   então o uso dela nesta configuração fica limitado a saída de vídeo própria
   se algum monitor for ligado nela diretamente.

Não há trabalho de `machines/dragon-pc/default.nix` para isto até a máquina
existir — quando existir, registre aqui se algo além da BIOS foi necessário.

## 4. Wallpaper: nada disso sobrevive à formatação, e está bem assim

`user/wm/noctalia-config.toml` aponta para arquivos em `~/Vídeos` e
`~/Imagens/wallhaven` — nenhum dos dois é versionado, por tamanho (a coleção
de wallpapers hoje passa de meia centena de arquivos, vários vídeos entre 20
e 100 MB cada). Foi decidido não fazer backup deles (item 6): o disco NTFS
secundário não é tocado na formatação, e o essencial (1Password) é online.

Isso significa que, depois da formatação, `[wallpaper.default]` e
`[wallpaper.last]` no `noctalia-config.toml` vão apontar para arquivos que não
existem. Não é um bug a corrigir no repo — a chave `[wallpaper.last]` sequer é
um path literal: é uma chave de cache derivada pelo próprio mpvpaper a partir
do path completo do vídeo em uso, e ela volta a bater assim que um vídeo for
escolhido de novo pela interface.

No dia, depois do primeiro boot: abra o centro de controle do noctalia
(`SUPER+C`) e escolha um wallpaper — o plugin `noctalia/wallhaven` já baixa
direto do wallhaven.cc. Se quiser o efeito de chuva de código de volta, baixe
o vídeo de novo do moewalls.com; não há plugin que automatize isso. A tela de
login (`regreet`) não é afetada — `matrix-login.png` é versionado por máquina
e sobrevive.

## 5. Pastas XDG em português — resolvido

`user/app/xdg-user-dirs.nix` (novo) declara `xdg.userDirs` com os mesmos
nomes que o `xdg-user-dirs-update` já produzia sozinho com o locale
`pt_BR.UTF-8` (`Vídeos`, `Imagens`, `Documentos` etc.), e cria os diretórios
na ativação do Home Manager — antes de qualquer sessão gráfica rodar, então
sem a corrida entre o serviço de sessão e o primeiro app que procura
`~/Vídeos`. Ligado por padrão no profile `personal`
(`lcars.user.xdgUserDirs.enable`).

Nada a fazer no dia — só confirmar depois do primeiro login que as pastas
nasceram em português.

## 6. Backup: descartado, de propósito

Decisão do usuário: não há backup a fazer antes de formatar.

- O disco de 9,1 TB (`ST10000VN000`, hoje montado em `/run/media/ins/Dados`)
  é NTFS, fica num disco **secundário**, e a formatação não toca nele.
- O 1Password é a fonte de verdade para dotfiles, tokens (OneDrive,
  Telegram) e a chave SSH do GitHub — está online, não depende desta máquina.
- O que se perde são os arquivos soltos em `~/Vídeos` e `~/Imagens` (item 4)
  e qualquer coisa fora desses dois guarda-chuvas — aceito como custo da
  formatação, não como pendência.

## 7. Synergy: em aberto

`machines/Standard-PC-Q35-ICH9-2009/default.nix` aponta para `192.168.0.10`
como servidor Synergy — e esse IP é o **próprio dragon-pc**. Hoje ele é
servidor (roda o Synergy 3 de verdade, fora do Nix) e a VM se conecta nele
como cliente via waynergy. Formatando para NixOS, esse papel se inverte: o
Synergy servidor deixa de existir, e o niri não implementa
`org.freedesktop.portal.InputCapture` (cabeçalho de `user/app/waynergy.nix`
detalha por quê) — então este repo não tem como o dragon-pc voltar a ser
servidor.

Isto **não** foi decidido ainda. Fica registrado aqui como consequência direta
da formatação, para ser discutido antes — não durante — o dia de instalar.
Não abrir módulo novo nem tocar `waynergy.nix` até essa conversa acontecer.
