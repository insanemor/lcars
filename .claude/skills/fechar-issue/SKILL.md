---
name: fechar-issue
description: Fecha uma issue no GitHub depois que a entrega foi mergeada, comentando o que foi feito e o merge commit. Use ao final do ciclo de entrega, logo após o merge em main, ou quando o usuário disser "fecha a issue", "encerra o ticket".
---

# Fechar a issue

Último passo do ciclo. Só rode **depois** que o merge em `main` aconteceu — o
merge é o que dá direito de fechar.

## 1. Confirme que a entrega está em `main`

```bash
git log --oneline --graph -8
```

Você deve ver o merge commit. Se a entrega ainda está só na branch, pare e
volte para a skill `entrega`.

## 2. Comente e feche

O comentário é o registro de encerramento: quem for ler a issue daqui a seis
meses precisa entender o que mudou sem abrir o diff.

```bash
gh issue close <numero> --comment "$(cat <<'EOF'
Entregue em `<sha-do-merge>` (branch `<nome-da-branch>`).

**O que mudou**
- Mudança 1, com arquivo:linha quando ajudar
- Mudança 2

**Verificado**
- O que foi testado e como

**Não coberto**
- O que ficou de fora, e por quê (se aplicável)
EOF
)"
```

Seja honesto na seção **Verificado**: se algo não pôde ser testado no ambiente
(faltava uma ferramenta, exigia outra máquina), escreva isso. Uma issue que
afirma verificação que não houve é pior que uma issue sem a seção.

Se sobrou trabalho que vale rastrear, abra uma issue de follow-up com a skill
`nova-issue` e linke-a no comentário, em vez de deixar a pendência solta.

## 3. Feche as tasks locais

Marque as tasks correspondentes como `completed` com `TaskUpdate`.

## 4. Reporte

Diga ao usuário, em duas ou três linhas: issue fechada (número e URL), o que
foi entregue, e o estado de `main`.

Não mencione push. Não diga que há commits locais aguardando publicação, não
sugira `git push` — publicar é decisão do usuário e ele pediu explicitamente
para não ser lembrado.
