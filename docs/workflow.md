# Fluxo de trabalho

Como mudanças entram neste repo. O processo é executado pelas skills em
`.claude/skills/`, mas vale por si — a regra não depende de ferramenta.

```
pedido → issue → tarefas → branch → trabalho → commit
       → aprovação do merge → merge --no-ff → fecha a issue
```

## As regras

### 1. Issue antes de código

Nenhum arquivo versionado é editado antes de a issue existir, mesmo para
mudanças de uma linha. O commit registra *o que* mudou; a issue registra *por
quê*, e é isso que se perde primeiro.

A issue tem Contexto, Problema, Escopo, Critérios de aceite e Tarefas. O escopo
declara também o que **não** entra — é o que impede a issue de crescer sem
controle enquanto o trabalho acontece.

### 2. Uma branch por issue

Nome: `<prefixo>/<numero>-<slug>`, por exemplo `fix/7-instalacao-one-shot`.

| Tipo de mudança | Label | Prefixo |
|---|---|---|
| Algo quebrado | `bug` | `fix/` |
| Funcionalidade nova | `enhancement` | `feat/` |
| Documentação | `documentation` | `docs/` |
| Reorganização | `enhancement` | `refactor/` |

Não se edita nada estando em `main`.

### 3. O merge é aprovado, o push não

Terminado o trabalho, vem o commit — referenciando a issue com `Refs #<n>` — e
uma pergunta: *pode mergear?* Nada acontece até a resposta.

**O push nunca é feito automaticamente.** Publicar é decisão do dono do repo, e
não há lembrete sobre commits locais pendentes.

### 4. Merge sempre com `--no-ff`

```bash
git merge --no-ff <branch> -m "Merge branch '<branch>'

<resumo>

Closes #<numero>"
```

Um fast-forward transplanta os commits para `main` e apaga o registro de que a
branch existiu. O merge commit **é** o histórico: é ele que mostra onde a linha
de trabalho começou e terminou.

`--ff-only`, `--squash` e `rebase` não são usados para integrar uma entrega.

A branch local é apagada logo após o merge. Isso não perde nada — o merge commit
grava o nome dela e todos os seus commits seguem alcançáveis no grafo:

```
*   37b49b8 Merge branch 'feat/1-fluxo-de-trabalho'
|\
| * 8f15b37 feat: formaliza o fluxo de trabalho do repo em skills e CLAUDE.md
|/
* d355c73 crush
```

### 5. A issue fecha no fim

Com um comentário registrando o que mudou, **o que foi verificado** e o que
ficou de fora. Essa última parte importa: um comentário que afirma verificação
que não houve é pior do que um comentário sem a seção.

## O que fica de fora do ciclo

Responder perguntas, ler e explicar código, investigar sem alterar nada, e
mexer em arquivos fora do controle de versão.

## Uma restrição deste repo

A máquina de desenvolvimento **não tem `nix`**. Não é possível rodar
`nix flake check` nem avaliar os módulos localmente. O que dá para verificar são
sintaxe, estrutura e consistência entre options declaradas e usadas — e o que
não foi verificado precisa ser dito explicitamente, tanto no relato quanto no
comentário de fechamento da issue.

Na prática: a primeira coisa a fazer com uma máquina NixOS à mão é avaliar o
flake de verdade. O instalador não tem modo de simulação — ele vai até o
`switch` —, então para validar sem ativar, monte os arquivos na mão e pare
antes do último passo:

```bash
git clone https://github.com/insanemor/lcars ~/.dotfiles && cd ~/.dotfiles
git checkout <a-branch-em-teste>
$EDITOR settings.nix                            # já vem versionado
cp -r machines/template machines/teste
sudo nixos-generate-config --show-hardware-config > machines/teste/hardware-configuration.nix
git add -f machines/teste

nix flake check                                 # avalia todas as máquinas
sudo nixos-rebuild dry-activate --flake .#teste # compila tudo, não ativa
```

`dry-activate` **compila o sistema inteiro** — é lento, mas é o que prova que a
mudança builda. `nix flake check` é mais rápido e já pega erro de avaliação:
nome de option errado, enum inválido, arquivo faltando no index.
