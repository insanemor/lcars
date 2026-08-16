# lcars — instruções do projeto

Flake NixOS multi-host, forkável, com dotfiles e secrets via 1Password e Home
Manager. Instalação em um comando por `scripts/install.sh`.

## Fluxo de trabalho obrigatório

Todo pedido segue este ciclo, sem exceção e sem o usuário precisar pedir.
Vale inclusive para mudanças de uma linha — o tamanho do diff não dispensa o
registro.

```
pedido → issue (skill nova-issue)
       → tarefas
       → branch local (skill entrega, fase A)
       → trabalho
       → commit (skill entrega, fase B)
       → PERGUNTA: pode mergear?
       → merge --no-ff em main
       → fecha a issue (skill fechar-issue)
```

As três skills vivem em `.claude/skills/`. Invoque-as; não improvise o fluxo
por fora delas.

### As regras que não se negociam

1. **Issue antes de código.** Nenhum arquivo versionado é editado antes de a
   issue existir. Se o pedido é ambíguo o bastante para mudar o escopo,
   pergunte antes de abrir a issue.

2. **Branch local sempre.** Nunca edite estando em `main`. Nome da branch:
   `<prefixo>/<numero-da-issue>-<slug>`, ex. `fix/7-instalacao-one-shot`.

3. **O merge é aprovado pelo usuário.** Ao terminar, commite e faça **uma**
   pergunta: se pode mergear. Então pare e espere.

4. **Merge com `--no-ff`, sempre.** Fast-forward apaga o rastro de que a branch
   existiu. Nunca use `--ff-only`, `--squash` ou `rebase` para integrar uma
   entrega. O merge commit é o histórico.

5. **Nunca fazer push.** Em nenhuma circunstância, nem quando parecer óbvio.
   E nunca avisar que há commits locais não publicados, nem contar quantos, nem
   sugerir `git push`. Publicar é decisão do usuário, que pediu explicitamente
   para não ser lembrado disso.

6. **A issue fecha no fim**, pela skill `fechar-issue`, depois do merge.

### O que fica de fora do ciclo

Não precisa de issue: responder perguntas, ler e explicar código, investigar
sem alterar nada, e mexer em arquivos fora do controle de versão (scratchpad,
metadados de ferramenta).

Na dúvida sobre se algo entra no ciclo: entra.

## Este repositório

- **Rode `./scripts/check.sh` ao mexer em `.nix`, antes de commitar.** Ele
  verifica formato (`nixfmt`), anti-padrões (`statix`) e — o que importa —
  **avalia os dois profiles**, pegando nome de option que não existe, atributo
  mal aninhado e módulo que não avalia. Roda num container `nixos/nix`, sem
  instalar nada na máquina; a primeira execução baixa ~250MB, as seguintes
  levam segundos. `--fmt` pula a avaliação; `--fix` corrige formato e
  anti-padrões.

- **Avaliar não é buildar.** O check para no `drvPath`: nenhum pacote é
  compilado, e ele não prova que o sistema sobe — só que o código está
  correto. Continue dizendo explicitamente o que não foi verificado, e **nunca
  afirme que um módulo builda sem ter buildado**. A máquina local é Garuda
  (Arch), não NixOS: `nixos-rebuild` e o boot real só acontecem na máquina do
  usuário.

- **Flakes só leem arquivos rastreados pelo git.** `machines/*/hardware-configuration.nix`
  está no `.gitignore` e precisa de `git add -f` para o flake enxergá-lo. Se
  algo "sumiu" na avaliação, essa é a primeira suspeita. (`settings.nix` é
  versionado desde a #6, então não precisa disso.)

- **`settings.nix` não descreve hardware, e não pode divergir.** Ele é
  versionado e igual em todas as máquinas do usuário: quem você é, locale,
  profile, 1Password. Tudo que muda de máquina para máquina — bootloader,
  `grubDevice`, VM, notebook, teclado — vai em `machines/<host>/default.nix`.
  Pôr um dado de máquina no `settings.nix` faz todo clone divergir do
  repositório, e cada `git pull` do usuário conflita. Não há campo de hostname
  em lugar nenhum: quem define `networking.hostName` é o nome do diretório.

- **Máquinas são auto-descobertas.** Todo diretório em `machines/` vira um
  `nixosConfiguration`, exceto `template`. Não há registro manual em
  `flake.nix`.

- **A hierarquia é por papel:** `machines/` (o que a máquina é) escolhe um
  `profiles/` (preset de flags, sempre com `mkDefault`), que liga módulos de
  `system/` (NixOS) e de `user/` (Home Manager). Nos dois lados tudo é
  importado sempre e nada liga sozinho: opt-in por `lcars.system.<caminho>` e
  `lcars.user.<módulo>`, e o caminho da flag espelha o do arquivo.
  `lcars.profile` fica na raiz.

- **As flags de `user/` moram no config do NixOS.** São declaradas em
  `user/options.nix` (importado no `nixosSystem`) e lidas pelos módulos do
  Home Manager via `osConfig`. As duas árvores de módulos são separadas: em
  `user/`, `config` é o do Home Manager, onde `lcars.*` não existe — um profile
  não conseguiria escrever lá. Ao criar um módulo em `user/`, declare a flag,
  importe em `user/default.nix`, envolva o corpo em `mkIf` e ligue nos profiles.

- **Antes de pôr algo no `exec-once` do Hyprland, procure um serviço.** Este
  erro já custou três entregas e duas rodadas de VM, nas duas formas que ele
  tem:

  - **#19** — pus `hyprpaper`, `waybar` e `swaync` para subir com a sessão sem
    que estivessem instalados. O Hyprland tenta, falha calado e segue: tela
    preta, e o usuário sem nenhuma pista do motivo.
  - **#24** — o `hyprpaper` estava instalado, mas o stylix já o subia por
    `services.hyprpaper`. A segunda instância morria porque a primeira detinha
    o socket, e o que aparecia era "erro fatal" de um programa que estava
    funcionando.

  A verificação, antes de acrescentar `programa` à lista: existe
  `services.<programa>` ou `programs.<programa>.systemd` no Home Manager, ou
  algum módulo já o configura? Se existir, **use o serviço** — ele reinicia o
  que cai e responde a `systemctl --user status`, enquanto pelo `exec-once`
  qualquer falha é silêncio.

  Na #21 eu tinha escrito no próprio arquivo "nunca ponha aqui algo que o
  módulo não instale". Cobria só a primeira forma, e por isso não me impediu
  de cometer a segunda — a regra tem que ser a de cima, não aquela.

- **Alvo é o nixos-unstable.** Opções do NixOS mudam de nome com frequência
  (`sound.enable`, `hardware.pulseaudio`, `hardware.tlp`,
  `services.xserver.displayManager.*`, `rofi-wayland`, `noto-fonts-emoji` e
  `programs.waybar.systemd.target` já quebraram ou avisaram neste repo).
  Confirme o nome atual antes de usar; não confie na memória de versões
  antigas. O `./scripts/check.sh --eval` pega essa classe em segundos.

- **Commits e docs em português**, com acentuação correta. Identificadores,
  nomes de opção e termos técnicos ficam na forma original.
