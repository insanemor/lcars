"""O logo da SimbioIT desenhado para o tamanho de uma linha de terminal.

A arte abaixo é o desenho de verdade — 24 colunas por 11 linhas, quatro
células de terminal de 6 colunas cada. Editar estas onze linhas muda o glifo;
depois é só reconstruir.

  A  o traço do D
  Q  um quadrado
  .  vazio

A COR NÃO ESTÁ NA ARTE, ESTÁ NA CÉLULA

O terminal pinta uma cor por célula, e quem pinta é o prompt, não a fonte: o
glifo é monocromático e recebe a cor do `%F{}` que o zsh.nix escreve. Por isso
a cor é uma propriedade da célula inteira — CORES_CELULA, abaixo — e não do
símbolo. Antes ela era inferida do símbolo mais comum de cada célula, o que
podia divergir do zsh.nix sem ninguém notar.

Ao mudar CORES_CELULA aqui, mude também o CONTENT_EXPANSION do os_icon em
user/shell/zsh.nix, que é quem de fato aplica as cores.

POR QUE UM DESENHO À MÃO, E NÃO O PNG REDUZIDO

Reduzir logo-original.png para esta grade produz uma mancha: os quadrados do
logo têm menos de um pixel nesse tamanho. Testado em 13x11, 20x11 e 26x11.

O TRAÇO É UM "D", NÃO UM ANEL

Isolando o ciano do PNG original: topo e base retos apontando para a
esquerda, uma curva grande fechando a direita, e uma fenda cortando essa curva
no meio. A fenda mede 0,7 pixel nesta escala, ou seja, não existe aqui — e a
primeira versão, que a reproduzia com uma linha vazia inteira, cortava o D ao
meio e não lia como logo.

NENHUM QUADRADO PODE CRUZAR A FRONTEIRA ENTRE CÉLULAS

As colunas 6, 12 e 18 começam uma célula nova: um quadrado a cavalo sai
metade numa cor e metade na outra. O traço do D atravessa a fronteira 12|18
de propósito — as duas células são da mesma cor, e patch.py estende as bordas
para que ele não parta ali.
"""

# fronteiras de célula:  |     |     |
ARTE = [
    "..QQ..........AAAAAA....",
    "..QQ.....QQ...AAAAAAA...",
    "QQ.......QQ.........AA..",
    "QQ.QQ................AA.",
    "...QQ..........QQ....AA.",
    ".QQ............QQ....AA.",
    ".QQ....QQ............AA.",
    ".......QQ............AA.",
    "...QQ...............AA..",
    "........QQ....AAAAAAA...",
    "..............AAAAAA....",
]

# uma cor por célula, em nomes base16 — o gradiente do logo, da esquerda para
# a direita, terminando no ciano da marca nas duas células do D
CORES_CELULA = ["base0A", "base0C", "base0D", "base0D"]

LINS = len(ARTE)
COLS = len(ARTE[0])
CELULAS = len(CORES_CELULA)
COL_POR_CELULA = COLS // CELULAS


def desenho():
    """(pixels, cor base16) por célula, com os pixels já relativos a ela."""
    celulas = []
    for c in range(CELULAS):
        x0, x1 = c * COL_POR_CELULA, (c + 1) * COL_POR_CELULA
        pixels = {
            (x - x0, y)
            for y, linha in enumerate(ARTE)
            for x in range(x0, x1)
            if linha[x] != "."
        }
        celulas.append((pixels, CORES_CELULA[c]))
    return celulas


def confere():
    """Erra alto se a arte violar as regras do cabeçalho."""
    assert all(len(l) == COLS for l in ARTE), "linhas com larguras diferentes"
    assert COLS % CELULAS == 0, "as colunas não dividem em células inteiras"
    for y, linha in enumerate(ARTE):
        for b in range(COL_POR_CELULA, COLS, COL_POR_CELULA):
            if linha[b - 1] == "Q" and linha[b] == "Q":
                raise AssertionError(
                    f"quadrado cruza a fronteira de célula na coluna {b}, linha {y}"
                )


if __name__ == "__main__":
    confere()
    for y, linha in enumerate(ARTE):
        print(" ", "|".join(
            linha[i * COL_POR_CELULA:(i + 1) * COL_POR_CELULA]
            for i in range(CELULAS)
        ))
    print()
    for c, (px, cor) in enumerate(desenho()):
        print(f"  célula {c}: {len(px):>2} pixels, {cor}")
