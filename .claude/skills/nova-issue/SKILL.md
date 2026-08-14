---
name: nova-issue
description: Registra um pedido de trabalho como issue documentada no GitHub e quebra em tarefas antes de qualquer código. Use SEMPRE que chegar um pedido novo — feature, bug, refactor, documentação, dúvida ou chore — inclusive quando o pedido parecer pequeno o bastante para fazer direto. Também use quando o usuário disser "abre uma issue", "documenta isso", "registra esse pedido".
---

# Registrar pedido como issue

Nada entra em código sem uma issue registrada. Isto vale mesmo para pedidos de
uma linha: a issue é o registro do *porquê*, que o commit sozinho não guarda.

## 1. Entenda antes de escrever

Investigue o suficiente para descrever o problema de verdade — leia os arquivos
envolvidos, confirme que o bug existe, veja se já não há issue aberta:

```bash
gh issue list --state open
```

Se já existir uma issue cobrindo o pedido, use ela e não abra outra.

Se o pedido for ambíguo a ponto de mudar o escopo do trabalho, pergunte ao
usuário **antes** de abrir a issue. Uma issue vaga vira trabalho errado.

## 2. Escolha o tipo e a label

| Pedido | Label | Prefixo de branch |
|---|---|---|
| Algo está quebrado | `bug` | `fix/` |
| Funcionalidade nova | `enhancement` | `feat/` |
| README, docs/, comentários | `documentation` | `docs/` |
| Reorganização sem mudar comportamento | `enhancement` | `refactor/` |
| Dúvida a investigar | `question` | — |

O prefixo é usado depois pela skill `entrega`.

## 3. Escreva a issue

Corpo obrigatório, nesta ordem. Seja concreto: cite arquivo e linha
(`system/core/default.nix:20`), cole a mensagem de erro real.

```markdown
## Contexto
Por que isto importa agora. O que o usuário estava tentando fazer.

## Problema
O que está errado ou faltando hoje, com evidência: arquivo:linha, erro, comando
que falha.

## Escopo
O que entra nesta issue. E, explicitamente, o que **não** entra — é isso que
impede a issue de crescer sem controle.

## Critérios de aceite
- [ ] Condição verificável 1
- [ ] Condição verificável 2

## Tarefas
- [ ] Passo de implementação 1
- [ ] Passo de implementação 2
```

Critério de aceite é o que dá para **conferir**; tarefa é o que dá para
**fazer**. Não repita um no outro.

## 4. Crie a issue

Use um heredoc — o corpo tem markdown e quebras de linha:

```bash
gh issue create --title "<tipo>: <resumo imperativo e curto>" --label "<label>" --body "$(cat <<'EOF'
## Contexto
...
EOF
)"
```

O comando devolve a URL. **Guarde o número** — a branch, o commit e o
fechamento todos dependem dele.

## 5. Espelhe as tarefas localmente

Para cada item de `## Tarefas`, crie uma task com `TaskCreate`. É assim que o
progresso fica visível durante o desenvolvimento.

## 6. Siga para o código

Reporte ao usuário: número da issue, URL, e as tarefas criadas. Em seguida
invoque a skill `entrega` para abrir a branch — não comece a editar arquivos
estando em `main`.

## Limites

- Nunca feche a issue aqui. Quem fecha é a skill `fechar-issue`, no fim.
- Nunca faça `git push`. Publicar é decisão do usuário, e ele não quer ser
  lembrado disso.
