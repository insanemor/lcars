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

- **Sem `nix` na máquina de desenvolvimento.** O ambiente local é Garuda
  (Arch), não NixOS. Não é possível rodar `nix flake check` nem avaliar os
  módulos aqui. Ao mexer em `.nix`, valide o que der (sintaxe, balanceamento,
  nomes de opção contra a documentação do nixpkgs) e **diga explicitamente ao
  usuário o que não pôde ser verificado**. Nunca afirme que um módulo builda
  sem ter buildado.

- **Flakes só leem arquivos rastreados pelo git.** `vars/local.nix` e
  `machines/*/hardware-configuration.nix` estão no `.gitignore` e precisam de
  `git add -f` para o flake enxergá-los. Se algo "sumiu" na avaliação, essa é
  a primeira suspeita.

- **Máquinas são auto-descobertas.** Todo diretório em `machines/` vira um
  `nixosConfiguration`, exceto `template`. Não há registro manual em
  `flake.nix`.

- **A hierarquia é por papel:** `machines/` (o que a máquina é) escolhe um
  `profiles/` (preset de flags, sempre com `mkDefault`), que liga módulos de
  `system/`; `user/` são os módulos do Home Manager. Módulos de `system/` são
  todos importados sempre e opt-in por `lcars.<caminho>.enable`.

- **Alvo é o nixos-unstable.** Opções do NixOS mudam de nome com frequência
  (`sound.enable`, `hardware.pulseaudio`, `hardware.tlp` e
  `services.xserver.displayManager.*` já quebraram este repo). Confirme o nome
  atual antes de usar; não confie na memória de versões antigas.

- **Commits e docs em português**, com acentuação correta. Identificadores,
  nomes de opção e termos técnicos ficam na forma original.
