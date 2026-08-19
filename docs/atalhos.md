# Atalhos e comandos do dia a dia

Referência rápida — não é o help completo de nenhum programa, só o que mais
se usa. Assume o profile `personal`, com tudo ligado.

## herdr — navegação (prefixo `Ctrl-a`)

| Atalho | Ação |
|---|---|
| `prefix` + `\|` | split vertical |
| `prefix` + `-` | split horizontal |
| `prefix` + `h`/`j`/`k`/`l`, ou `Alt`+setas (sem prefixo) | foco entre painéis |
| `prefix` + `Shift` + `h`/`j`/`k`/`l` | mover/trocar painel de lugar |
| `prefix` + `z` | zoom no painel |
| `prefix` + `r` | modo resize (`hjkl` redimensiona, `Esc` sai) |
| `prefix` + `x` | fechar painel |
| `prefix` + `c` | nova aba |
| `prefix` + `Shift` + `x` | fechar aba |
| `Shift` + `←`/`→` (sem prefixo) | trocar de aba |
| `prefix` + `Shift` + `n` | nova workspace |
| `prefix` + `Shift` + `d` | fechar workspace |
| `prefix` + `Shift` + `w` | renomear workspace |
| `prefix` + `g` | ir para workspace (por nome) |
| `Ctrl` + `↑`/`↓` (sem prefixo) | trocar de workspace |
| `prefix` + `Shift` + `r` | recarregar config.toml |
| `prefix` + `?` | tabela completa de atalhos, dentro do programa |

## herdr — plugins

| Atalho | O que abre |
|---|---|
| `prefix` + `Shift` + `g` | lazygit, num popup |
| `prefix` + `b` | browser (Chromium num painel), em split |
| `prefix` + `Shift` + `b` | browser, em overlay |
| `prefix` + `e` | sidebar do nvim (toggle) |
| `prefix` + `o` | abrir na sidebar um arquivo que um agente tocou |
| `prefix` + `f` | file viewer git-aware, em split |
| `prefix` + `Shift` + `f` | file viewer, em aba |
| `prefix` + `v` | reviewr — comentar no diff de um agente (abre/fecha) |
| `prefix` + `u` | usage bar — painel de limites por provedor |
| `prefix` + `Shift` + `u` | usage bar — força atualização dos medidores |
| `prefix` + `Shift` + `a` | desfaz nome manual de aba, volta pro automático |
| `prefix` + `p` | busca fuzzy por aba ou agente |
| `prefix` + `y` | yazi (file explorer), em split |
| `prefix` + `Shift` + `y` | yazi, em aba |
| `prefix` + `n` | notas do workspace, num popup pequeno (`Esc` fecha; sem toggle) |
| `Ctrl+Alt+a` | anota o texto selecionado no terminal |
| `Ctrl+Alt+v` | cola e limpa as anotações coletadas |
| Ctrl+clique num link | abre no painel (browser) ou no ghzinga (issue/PR do GitHub) |

Sidebar dos agentes mostra `$provider`/`$limit` (conta) e `$context` (uso da
janela por painel), sempre visíveis — vêm do usage bar.

As notas de cada workspace ficam em `~/Notas/workspaces/<id>.md` — Markdown
de verdade, editável fora do herdr.

## zsh — aliases

| Comando | O que faz |
|---|---|
| `nupdate` | atualiza o repo e aplica no sistema (`--inputs` atualiza nixpkgs junto, `--no-check` pula a avaliação) |
| `nsave` | exporta o ajuste do noctalia, mostra o diff, commita e publica |
| `ll` / `la` / `l` | listagem longa / oculta / curta (via `eza`, com ícones e git) |
| `ls` / `lt` | listagem / árvore (via `eza`) |
| `cat` | via `bat`, com highlight e número de linha (vira `cat` puro em pipe) |
| `lg` | `lazygit` |
| `gs` / `gp` / `gpl` | `git status` / `push` / `pull` |

## git — aliases

| Comando | Equivale a |
|---|---|
| `git co` | `checkout` |
| `git br` | `branch` |
| `git ci` | `commit` |
| `git st` | `status` |
| `git lg` | `log --oneline --graph --decorate` |

## Busca e navegação no shell

| Tecla/comando | O que faz |
|---|---|
| `Ctrl+R` | busca fuzzy no histórico (atuin — global, sincronizado entre máquinas) |
| `Ctrl+T` | busca fuzzy de arquivos, insere o caminho na linha (fzf) |
| `Alt+C` | busca fuzzy de diretórios, dá `cd` neles (fzf) |
| `z <parte-do-nome>` | pula pra um diretório visitado antes, por frequência/recência (zoxide) |
| `zi <parte-do-nome>` | mesmo que `z`, mas com seleção interativa quando há mais de um candidato |
| `rg <padrão>` | grep rápido (ripgrep), já usado pelo fzf por baixo |
| `fd <padrão>` | find rápido |
| `mtr <host>` | traceroute + ping contínuo, num programa só |
| `gh issue create` / `gh pr create` | abrir issue/PR sem sair do terminal |

## niri (compositor) — `Mod` = tecla Super

| Atalho | Ação |
|---|---|
| `Mod` + `Enter` | novo terminal (kitty → herdr) |
| `Mod` + `Shift` + `Enter` | terminal SEM o herdr (saída de emergência) |
| `Mod` + `Q` | fechar janela |
| `Mod` + `D` | launcher (noctalia) |
| `Mod` + `C` | centro de controle |
| `Mod` + `V` | histórico de área de transferência |
| `Mod` + `N` | notificações |
| `Mod` + `Escape` | menu de sessão (logout/lock/etc.) |
| `Mod` + `h`/`l`, ou `←`/`→` | foco entre COLUNAS |
| `Mod` + `j`/`k`, ou `↑`/`↓` | foco entre janelas empilhadas na mesma coluna |
| `Mod` + `Shift` + `h`/`j`/`k`/`l` | mover coluna/janela |
| `Mod` + `,` / `.` | juntar janela à coluna ao lado / tirar pra coluna própria |
| `Mod` + `R` | cicla largura da coluna (33% / 50% / 66%) |
| `Mod` + `F` | maximizar coluna |
| `Mod` + `Shift` + `F` | tela cheia |
| `Mod` + `W` | alternar exibição em abas da coluna |
| `Mod` + `1`–`9` | trocar de workspace |
| `Mod` + `Shift` + `1`–`9` | mover coluna pro workspace N |
| `Mod` + `Page Up`/`Page Down` | workspace anterior/próximo |
| `Mod` + `Shift` + `S` | captura de tela, com seleção de região |
| `Print` | captura da tela inteira |
| `Mod` + `Shift` + `E` | sair da sessão |

## kitty

`Ctrl+V` e `Ctrl+Insert` colam (além do `Ctrl+Shift+V` de fábrica) — inclusive
dentro do nvim, onde por padrão `Ctrl+V` entraria em modo visual-block.
