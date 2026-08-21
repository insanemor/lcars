#!/usr/bin/env python3
"""Injeta os glifos do logo da SimbioIT numa Nerd Font.

É o mesmo padrão dos ícones que ela já traz — a casinha que o p10k mostra no
diretório é o U+F015, 'fa-house', um glifo como qualquer outro dentro do
arquivo da fonte.

E É POR ISSO QUE PRECISA SER ASSIM. Uma fonte separada, só com os glifos do
logo, não funciona: o Konsole não faz fallback para ela. O `fc-match` aponta
para a fonte certa e mesmo assim saem caixinhas, porque o processo abre outro
arquivo — conferido em /proc/<pid>/maps. Os glifos têm que estar dentro da
fonte que o terminal carrega.

As métricas são lidas da fonte alvo, então isto funciona em qualquer Nerd
Font, não só na que o repositório usa hoje.

Uso:  python3 patch.py <fonte.ttf> [<fonte.ttf> ...]
"""
import sys
from fontTools.ttLib import TTFont
from fontTools.pens.ttGlyphPen import TTGlyphPen
import logo as L

CODEPOINTS = [0xF8F0, 0xF8F1, 0xF8F2, 0xF8F3]
NOMES = [f"simbioit-logo{i}" for i in range(4)]

def runs(pixels):
    out = []
    for y in sorted({p[1] for p in pixels}):
        xs = sorted(x for (x, yy) in pixels if yy == y)
        ini = ant = xs[0]
        for x in xs[1:]:
            if x == ant + 1: ant = x; continue
            out.append((ini, ant, y)); ini = ant = x
        out.append((ini, ant, y))
    return out

def patch(caminho):
    f = TTFont(caminho)
    upem = f["head"].unitsPerEm
    avanco = f["hmtx"]["M"][0]
    asc, desc = f["hhea"].ascent, f["hhea"].descent
    px = avanco // L.COL_POR_CELULA
    altura = L.LINS * px
    base = desc + (asc - desc - altura) // 2
    topo = base + altura

    glyf, hmtx, cmap_t = f["glyf"], f["hmtx"], f["cmap"]
    novos = [n for n in NOMES if n not in f.getGlyphOrder()]

    # SOBRA NAS BORDAS DA CELULA
    #
    # O glifo tem 1200 unidades de largura, que no corpo 8 dao 6.56 pixels --
    # e o terminal arredonda a celula para pixel inteiro (7). Sem sobra, cada
    # junção entre celulas abre uma fresta, e como o D atravessa duas delas,
    # ele parte no meio. Meio pixel de grade em cada borda encosta as peças.
    # Só vale para quem toca a borda, e as duas celulas do D sao da mesma cor,
    # entao a sobreposicao nao aparece.
    sobra = px // 2

    for nome, (pixels, _cor) in zip(NOMES, L.desenho()):
        pen = TTGlyphPen(None)
        for (x0, x1, y) in runs(pixels):
            ex0, ex1 = x0 * px, (x1 + 1) * px
            if x0 == 0: ex0 -= sobra
            if x1 == L.COL_POR_CELULA - 1: ex1 += sobra
            ey0, ey1 = topo - (y + 1) * px, topo - y * px
            pen.moveTo((ex0, ey0)); pen.lineTo((ex0, ey1))
            pen.lineTo((ex1, ey1)); pen.lineTo((ex1, ey0)); pen.closePath()
        glyf[nome] = pen.glyph()
        hmtx[nome] = (avanco, 0)

    # glyf[nome] = ... ja registra o glifo na glyphOrder e no maxp; mexer
    # nisso a mao duplica os nomes e a fonte nao compila.

    tabelas = 0
    for sub in cmap_t.tables:
        if sub.isUnicode():
            for cp, nome in zip(CODEPOINTS, NOMES):
                sub.cmap[cp] = nome
            tabelas += 1

    f.save(caminho)
    print(f"{caminho}: upem {upem}, avanço {avanco}, {px} un/pixel, "
          f"{len(novos)} glifos novos, {tabelas} subtabelas de cmap")

if __name__ == "__main__":
    L.confere()
    for c in sys.argv[1:]:
        patch(c)
