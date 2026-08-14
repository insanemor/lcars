---
name: entrega
description: Ciclo de trabalho em código deste repo — abre branch local a partir da issue, commita ao final da entrega, pede aprovação do merge e mergeia com --no-ff preservando o rastro da branch. Use SEMPRE antes de editar qualquer arquivo versionado, e de novo ao terminar a entrega. Também dispara em "pode mergear", "finaliza a entrega", "abre a branch".
---

# Ciclo de entrega

Toda alteração de código nasce numa branch local e volta para `main` por merge
explícito. O usuário aprova o merge; ele nunca aprova o push.

A skill cobre duas fases. Descubra em qual você está:

```bash
git branch --show-current && git status --short
```

- Em `main` → **Fase A**, abrir a branch.
- Numa branch de trabalho → **Fase B**, fechar a entrega.

---

## Fase A — abrir a branch

Pré-requisito: existe uma issue. Se não existe, pare e use a skill
`nova-issue` primeiro.

1. Confirme que `main` está limpo. Se houver trabalho não commitado que não é
   seu, **pergunte** antes de mexer — nunca faça `stash` ou `checkout` por cima
   de alterações do usuário.

2. Crie a branch a partir de `main`, nomeada pela issue:

   ```bash
   git checkout main
   git checkout -b <prefixo>/<numero-da-issue>-<slug-curto>
   ```

   O prefixo vem da tabela em `nova-issue` (`fix/`, `feat/`, `docs/`,
   `refactor/`). O slug é o assunto em 2–4 palavras, minúsculas, com hífen.
   Exemplo: `fix/7-instalacao-one-shot`.

3. Agora sim, trabalhe. Vá marcando as tasks com `TaskUpdate` conforme avança.

---

## Fase B — fechar a entrega

Só entre aqui quando o trabalho estiver **completo e verificado**. Se algum
teste falha ou uma parte ficou pela metade, diga isso ao usuário em vez de
commitar como se estivesse pronto.

### B1. Commit

Um commit por entrega, salvo quando a issue tem etapas de verdade separáveis.

```bash
git add <arquivos específicos>
```

Adicione arquivos por nome. `git add -A` varre lixo de ferramenta para dentro
do commit.

Mensagem: assunto imperativo curto, corpo explicando **por que**, e a
referência à issue:

```
<tipo>: <assunto no imperativo>

Por que a mudança era necessária e o que ela muda de fato.
Cite arquivo:linha quando ajudar a entender.

Refs #<numero>

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

Use `Refs #<n>`, não `Closes #<n>`: quem fecha a issue é a skill
`fechar-issue`, e como não há push, a palavra-chave do GitHub não dispararia
mesmo.

### B2. Peça aprovação

Mostre ao usuário, de forma compacta:

- a branch e o SHA do commit
- `git diff main...HEAD --stat`
- o que foi verificado e o que não foi

E faça **uma** pergunta: se pode mergear em `main`. Nada de push na pergunta.

Então pare. Não mergeie sem resposta.

### B3. Merge — sempre `--no-ff`

Com a aprovação:

```bash
git checkout main
git merge --no-ff <branch> -m "Merge branch '<branch>'

<resumo de uma linha da entrega>

Closes #<numero>"
```

**`--no-ff` é obrigatório.** Um fast-forward transplanta os commits para `main`
e apaga o rastro de que a branch existiu — é exatamente o que este fluxo
existe para evitar. Nunca use `--ff-only`, `--squash` ou `rebase` para trazer
a entrega.

Depois do merge, remova a ref local:

```bash
git branch -d <branch>
```

Isso não apaga histórico nenhum: o merge commit registra o nome da branch e
todos os commits dela seguem alcançáveis no grafo. Confirme com:

```bash
git log --oneline --graph -8
```

### B4. Feche a issue

Invoque a skill `fechar-issue` com o número da issue e o SHA do merge commit.

---

## Push

Não pushe. Nunca, em nenhuma fase, nem quando parecer óbvio.

E não avise o usuário de que existem commits locais não publicados, não conte
quantos, não sugira `git push`. Publicar é decisão dele e ele não quer o
lembrete.
