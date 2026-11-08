#!/usr/bin/env python3
"""Genera las texturas de los bloques del laberinto (suelo y muros) en
textures/blocks/.

Estilo de dibujo animado: colores planos y saturados, formas grandes
(piedras, ladrillos, tablones) con un relieve suave iluminado desde arriba a
la izquierda, contornos oscuros y bordes de cubo marcados. Todo se pinta aquí
con ruido y formas simples (no hay imágenes externas).

Por cada bloque <id> se escriben:
  <id>_top.png        cara de arriba (se ve entera en cada casilla)
  <id>_side.png       caras de los lados. Se repite en horizontal; en vertical
                      la fila 0 es el borde de arriba del bloque y cada casilla
                      de altura ocupa la textura entera, así que un muro de 0,5
                      enseña la mitad de arriba y una baldosa de 0,1 solo la
                      franja superior (el césped que cuelga, la nieve...).
  <id>_top_emit.png   (solo los que brillan: lava, fuego...) zonas que emiten
  <id>_side_emit.png  luz, en negro lo que no brilla.

La lista de bloques y sus propiedades en el juego están en
scripts/blocks/block_catalog.gd: si se añade un bloque aquí hay que darlo de
alta también allí.

Uso (desde la raíz del repositorio):
  python3 tools/make_block_textures.py            todos los bloques
  python3 tools/make_block_textures.py lava ice   solo esos
  python3 tools/make_block_textures.py --sheet hoja.png   además, una hoja
      con todos los bloques para revisarlos de un vistazo
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

S = 256
OUT = Path(__file__).resolve().parent.parent / "textures" / "blocks"


# --- Utilidades ---------------------------------------------------------------

def clamp(v, a=0.0, b=1.0):
    return a if v < a else b if v > b else v


def smooth(e0, e1, x):
    t = clamp((x - e0) / (e1 - e0))
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c1, c2, t):
    return (lerp(c1[0], c2[0], t), lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t))


def mul(c, k):
    return (c[0] * k, c[1] * k, c[2] * k)


def hexc(h):
    return tuple(int(h[i:i + 2], 16) / 255 for i in (1, 3, 5))


def ramp(stops, t):
    """Color en un degradado [(t0, color), (t1, color)...]."""
    if t <= stops[0][0]:
        return stops[0][1]
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        if t <= t1:
            return mix(c0, c1, (t - t0) / (t1 - t0) if t1 > t0 else 1.0)
    return stops[-1][1]


def tones(t, colors, soft=0.035):
    """Posteriza t (0-1) en len(colors) tonos con transiciones suaves: el
    aspecto de pintura plana de dibujo animado."""
    n = len(colors)
    c = colors[0]
    for i in range(1, n):
        c = mix(c, colors[i], smooth(i / n - soft, i / n + soft, t))
    return c


def field(fn):
    return [fn(x, y) for y in range(S) for x in range(S)]


class Noise:
    """Ruido de valor periódico (se repite cada S píxeles): nx por ny nodos."""

    def __init__(self, seed, nx, ny=None):
        rng = random.Random(seed)
        self.nx, self.ny = nx, ny or nx
        self.g = [rng.random() for _ in range(self.nx * self.ny)]

    def at(self, x, y):
        nx, ny = self.nx, self.ny
        fx, fy = x / S * nx, y / S * ny
        ix, iy = math.floor(fx), math.floor(fy)
        tx, ty = fx - ix, fy - iy
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        i0, i1, j0, j1 = ix % nx, (ix + 1) % nx, (iy % ny) * nx, ((iy + 1) % ny) * nx
        g = self.g
        return lerp(lerp(g[j0 + i0], g[j0 + i1], tx), lerp(g[j1 + i0], g[j1 + i1], tx), ty)


def fbm(seed, base=4, octaves=4, base_y=None, gain=0.5):
    """Ruido fractal periódico, normalizado a 0-1."""
    layers = [Noise(seed * 31 + o, base * 2 ** o, (base_y or base) * 2 ** o) for o in range(octaves)]
    amps = [gain ** o for o in range(octaves)]
    total = sum(amps)
    vals = field(lambda x, y: sum(a * n.at(x, y) for a, n in zip(amps, layers)) / total)
    lo, hi = min(vals), max(vals)
    return [(v - lo) / (hi - lo) for v in vals]


def voronoi(seed, n, jitter=0.85):
    """Celdas de Voronoi periódicas sobre una rejilla n x n con un punto por
    celda. Devuelve (f1, f2, id, ox, oy) por píxel: distancia al punto más
    cercano y al segundo (en celdas), celda a la que pertenece y desplazamiento
    del píxel respecto a su punto."""
    rng = random.Random(seed)
    pts = [(i + 0.5 + (rng.random() - 0.5) * jitter, j + 0.5 + (rng.random() - 0.5) * jitter)
           for j in range(n) for i in range(n)]
    f1s, f2s, ids, oxs, oys = [], [], [], [], []
    for y in range(S):
        py = y / S * n
        cj = int(py)
        for x in range(S):
            px = x / S * n
            ci = int(px)
            d1 = d2 = 9.0
            best = 0
            bx = by = 0.0
            for dj in (-1, 0, 1):
                jj = cj + dj
                wj = jj % n
                for di in (-1, 0, 1):
                    ii = ci + di
                    wi = ii % n
                    p = pts[wj * n + wi]
                    qx = p[0] + (ii - wi) - px
                    qy = p[1] + (jj - wj) - py
                    d = math.sqrt(qx * qx + qy * qy)
                    if d < d1:
                        d2 = d1
                        d1 = d
                        best = wj * n + wi
                        bx, by = -qx, -qy
                    elif d < d2:
                        d2 = d
            f1s.append(d1)
            f2s.append(d2)
            ids.append(best)
            oxs.append(bx)
            oys.append(by)
    return f1s, f2s, ids, oxs, oys


def cell_rand(seed, count):
    rng = random.Random(seed)
    return [rng.random() for _ in range(count)]


def emboss(h, d=2, gain=1.0):
    """Luz de un relieve h (0-1) iluminado desde arriba a la izquierda:
    positivo en las pendientes que miran a la luz, negativo en las otras."""
    out = []
    for y in range(S):
        ya, yb = ((y - d) % S) * S, ((y + d) % S) * S
        for x in range(S):
            out.append((h[ya + (x - d) % S] - h[yb + (x + d) % S]) * gain)
    return out


def bricks(rows, cols, mortar, seed, offset=0.5, jitter=0.0):
    """Ladrillos: por píxel (id del ladrillo, distancia en píxeles al borde
    del ladrillo, coordenadas 0-1 dentro del ladrillo)."""
    rng = random.Random(seed)
    bh = S / rows
    bw = S / cols
    shifts = [(r * offset + (rng.random() - 0.5) * jitter) % 1.0 for r in range(rows)]
    ids, dist, us, vs = [], [], [], []
    for y in range(S):
        r = int(y / bh)
        ly = y - r * bh
        for x in range(S):
            sx = (x + shifts[r] * bw) % S
            c = int(sx / bw)
            lx = sx - c * bw
            ids.append(r * cols + c)
            dist.append(min(lx, bw - lx, ly, bh - ly) - mortar * 0.5)
            us.append(lx / bw)
            vs.append(ly / bh)
    return ids, dist, us, vs


def finish(colors, light=None, light_amount=0.35, rim=True, side=False):
    """Aplica la luz del relieve y el borde del cubo: en la cara de arriba un
    marco algo más oscuro (separa las casillas) y en los lados una línea de
    luz en el borde superior."""
    out = []
    for i, c in enumerate(colors):
        k = 1.0
        if light is not None:
            k += clamp(light[i], -1.0, 1.0) * light_amount
        x, y = i % S, i // S
        if rim:
            if side:
                k *= 1.0 + 0.22 * (1.0 - smooth(0, 5, y))
            else:
                e = min(x, y, S - 1 - x, S - 1 - y)
                k *= 0.84 + 0.16 * smooth(0, 9, e)
                k *= 1.0 + 0.10 * (1.0 - smooth(0, 3, min(x, y)))
        out.append(mul(c, k))
    return out


# Ajuste final de la paleta de todos los bloques: SATURATION < 1 apaga los
# colores (los acerca a su gris) y LIGHTEN aclara (acerca a blanco), para un
# acabado más suave. CONTRAST < 1 reduce algo la diferencia entre claros y
# oscuros.
SATURATION = 0.72
LIGHTEN = 0.12
CONTRAST = 0.9


def soften(c):
    g = 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
    out = []
    for v in c:
        v = g + (v - g) * SATURATION
        v = 0.5 + (v - 0.5) * CONTRAST
        out.append(v + (1.0 - v) * LIGHTEN)
    return out


def save(pixels, name, adjust=True):
    if adjust:
        pixels = [soften(c) for c in pixels]
    img = Image.new("RGB", (S, S))
    img.putdata([(int(clamp(c[0]) * 255 + 0.5), int(clamp(c[1]) * 255 + 0.5), int(clamp(c[2]) * 255 + 0.5))
                 for c in pixels])
    img.save(OUT / name, optimize=True)
    return img


# --- Elementos comunes ----------------------------------------------------------

def speckle(seed, chance):
    rng = random.Random(seed)
    return [rng.random() < chance for _ in range(S * S)]


def fringe(seed, base, wave, drips, drip_depth):
    """Borde irregular que cuelga desde arriba (césped, nieve, musgo): para
    cada columna, cuántos píxeles baja. Periódico en horizontal."""
    rng = random.Random(seed)
    phases = [rng.random() * math.tau for _ in range(3)]
    freqs = [3, 7, 13]
    drops = [(rng.random() * S, rng.uniform(8, 18), rng.uniform(0.5, 1.0) * drip_depth) for _ in range(drips)]
    depth = []
    for x in range(S):
        d = base
        for f, p, a in zip(freqs, phases, (1.0, 0.45, 0.25)):
            d += wave * a * math.sin(math.tau * f * x / S + p)
        for cx, w, a in drops:
            dx = min(abs(x - cx), S - abs(x - cx))
            # Gota redondeada: semicírculo estirado.
            if dx < w:
                d += a * math.sqrt(1 - (dx / w) ** 2)
        depth.append(d)
    return depth


def apply_fringe(colors, light, depth, palette, seed, outline=hexc("#2b1d14")):
    """Pinta el borde colgante sobre una cara lateral ya hecha: relleno con
    su propio relieve, contorno oscuro y sombra sobre lo de debajo."""
    detail = fbm(seed, 6, 3)
    out_c, out_l = [], []
    for i, c in enumerate(colors):
        x, y = i % S, i // S
        d = depth[x]
        if y < d:
            t = y / max(d, 1)
            col = tones(clamp(1.0 - t * 0.8 + (detail[i] - 0.5) * 0.35), palette)
            l = 0.25 * (1 - t) - 0.15 * smooth(d - 6, d, y)
            out_c.append(col)
            out_l.append(l)
        elif y < d + 2.2:
            out_c.append(mix(outline, palette[0], 0.25))
            out_l.append(0.0)
        else:
            shadow = 1.0 - 0.35 * (1.0 - smooth(d + 2, d + 12, y))
            out_c.append(mul(c, shadow))
            out_l.append(light[i] if light else 0.0)
    return out_c, out_l


# --- Bloques ------------------------------------------------------------------
# Cada receta devuelve (top, side, top_emit, side_emit); los dos últimos pueden
# ser None. top y side son listas de colores (r, g, b) en 0-1.

def dirt_face(seed, palette=None):
    pal = palette or [hexc("#6e4427"), hexc("#8c5a33"), hexc("#a46c3e")]
    pebble_cols = [hexc("#c09065"), hexc("#5a3820"), hexc("#b07d52")]
    n = fbm(seed, 4, 4)
    f1, f2, ids, _, _ = voronoi(seed + 1, 9, 0.9)
    rnd = cell_rand(seed + 2, 81)
    rnd2 = cell_rand(seed + 3, 81)
    cols, h = [], []
    for i in range(S * S):
        base = tones(n[i], pal)
        cid = ids[i]
        r = 0.16 + 0.14 * rnd2[cid]
        if rnd[cid] < 0.55 and f1[i] < r:
            k = smooth(r, r - 0.07, f1[i])
            base = mix(base, pebble_cols[int(rnd2[cid] * 3) % 3], k)
            h.append(0.5 * n[i] + 0.8 * k)
        else:
            h.append(0.5 * n[i])
        cols.append(base)
    return cols, emboss(h, 2, 1.6)


def dirt(seed):
    top, lt = dirt_face(seed)
    side, ls = dirt_face(seed + 50)
    return finish(top, lt), finish(side, ls, side=True), None, None


GRASS = [hexc("#3d8a2c"), hexc("#58ad37"), hexc("#79cc47"), hexc("#9be35f")]
GRASS_DRY = [hexc("#9a7a23"), hexc("#bf9a2f"), hexc("#d9b544"), hexc("#ecd27a")]


def grass_top(seed, pal, flowers=0):
    n1 = fbm(seed, 3, 3)
    n2 = fbm(seed + 1, 10, 3)
    f1, _, ids, _, _ = voronoi(seed + 2, 14, 0.9)
    rnd = cell_rand(seed + 3, 196)
    if flowers:
        ff1, _, fids, fox, foy = voronoi(seed + 4, 7, 0.8)
        frnd = cell_rand(seed + 5, 49)
    flower_cols = [hexc("#ffffff"), hexc("#ffd84a"), hexc("#ff7ab8"), hexc("#8ec5ff")]
    cols, h = [], []
    for i in range(S * S):
        t = clamp(n1[i] + 0.3 * (n2[i] - 0.5))
        c = tones(t, pal)
        hh = t
        cid = ids[i]
        # Briznas: manchitas más claras repartidas.
        if rnd[cid] < 0.45 and f1[i] < 0.13:
            c = mix(c, mul(pal[-1], 1.05), 0.7)
            hh += 0.25
        if flowers:
            fid = fids[i]
            fr = 0.2
            if frnd[fid] < flowers and ff1[i] < fr:
                # Flor de cinco pétalos con el centro de otro color.
                ang = math.atan2(foy[i], fox[i])
                petal = fr * (0.62 + 0.38 * abs(math.cos(ang * 2.5 + frnd[fid] * 9)))
                if ff1[i] < petal:
                    fc = flower_cols[int(frnd[fid] * 1000) % len(flower_cols)]
                    c = mix(c, fc, smooth(petal, petal - 0.03, ff1[i]))
                    if ff1[i] < 0.07:
                        c = hexc("#ffcf3a") if fc != hexc("#ffd84a") else hexc("#e07b1a")
                    hh += 0.5
        cols.append(c)
        h.append(hh)
    return cols, emboss(h, 2, 1.3)


def grass_like(seed, pal, flowers=0, under=None):
    top, lt = grass_top(seed, pal, flowers)
    side, ls = under(seed + 50) if under else dirt_face(seed + 50)
    depth = fringe(seed + 60, 30, 5, 7, 22)
    side, ls = apply_fringe(side, ls, depth, pal, seed + 61)
    return finish(top, lt), finish(side, ls, side=True), None, None


def grass(seed):
    return grass_like(seed, GRASS)


def grass_flowers(seed):
    return grass_like(seed, GRASS, flowers=0.45)


def grass_dry(seed):
    return grass_like(seed, GRASS_DRY)


STONE = [hexc("#7b8189"), hexc("#8f969e"), hexc("#a3aab2"), hexc("#b6bdc4")]


def cobble_face(seed, pal=STONE, n=5, mortar=hexc("#4a4e55")):
    f1, f2, ids, _, _ = voronoi(seed, n, 0.8)
    nz = fbm(seed + 1, 8, 3)
    rnd = cell_rand(seed + 2, n * n)
    cols, h = [], []
    for i in range(S * S):
        e = f2[i] - f1[i]
        k = smooth(0.02, 0.16, e)
        stone = pal[int(rnd[ids[i]] * len(pal)) % len(pal)]
        stone = mul(stone, 0.94 + 0.12 * nz[i])
        cols.append(mix(mortar, stone, smooth(0.015, 0.04, e)))
        h.append(k * (0.8 + 0.2 * nz[i]))
    return cols, emboss(h, 3, 1.4)


def stone(seed):
    top, lt = cobble_face(seed)
    side, ls = cobble_face(seed + 50)
    return finish(top, lt), finish(side, ls, side=True), None, None


def brick_face(seed, rows, cols_n, pal, mortar, mortar_w=6, offset=0.5, chips=True, bevel=9):
    ids, dist, us, vs = bricks(rows, cols_n, mortar_w, seed, offset)
    nz = fbm(seed + 1, 8, 3)
    rnd = cell_rand(seed + 2, rows * cols_n)
    out, h = [], []
    for i in range(S * S):
        d = dist[i]
        b = pal[int(rnd[ids[i]] * len(pal)) % len(pal)]
        b = mul(b, 0.93 + 0.14 * nz[i])
        if chips and nz[i] < 0.18:
            b = mul(b, 0.85)
        out.append(mix(mortar, b, smooth(-0.5, 1.5, d)))
        h.append(smooth(0, bevel, d) * (0.85 + 0.15 * nz[i]))
    return out, emboss(h, 2, 1.5)


STONE_BRICK = [hexc("#7f8791"), hexc("#909aa4"), hexc("#a2abb5")]


def stone_bricks(seed):
    top, lt = brick_face(seed, 2, 2, STONE_BRICK, hexc("#4b5059"), 7, offset=0.0)
    side, ls = brick_face(seed + 50, 4, 2, STONE_BRICK, hexc("#4b5059"))
    return finish(top, lt), finish(side, ls, side=True), None, None


MOSS = [hexc("#356b26"), hexc("#4c8a30"), hexc("#68a83e")]


def mossy_stone(seed):
    top, lt = brick_face(seed, 2, 2, STONE_BRICK, hexc("#4b5059"), 7, offset=0.0)
    side, ls = brick_face(seed + 50, 4, 2, STONE_BRICK, hexc("#4b5059"))
    m = fbm(seed + 5, 4, 4)
    m2 = fbm(seed + 6, 4, 4)

    def moss(cols, light, mask, amount):
        oc, ol = [], []
        for i, c in enumerate(cols):
            k = smooth(amount, amount + 0.06, mask[i])
            if k > 0:
                oc.append(mix(c, tones(mask[i], MOSS), k))
                ol.append(lerp(light[i], (mask[i] - amount) * 1.5, k))
            else:
                oc.append(c)
                ol.append(light[i])
        return oc, ol

    top, lt = moss(top, lt, m, 0.6)
    side, ls = moss(side, ls, m2, 0.74)
    depth = fringe(seed + 60, 14, 4, 6, 26)
    side, ls = apply_fringe(side, ls, depth, MOSS, seed + 61)
    return finish(top, lt), finish(side, ls, side=True), None, None


def granite_face(seed, rows, cols_n):
    ids, dist, _, _ = bricks(rows, cols_n, 3, seed, 0.5)
    rng = random.Random(seed + 3)
    nz = fbm(seed + 1, 5, 3)
    rnd = cell_rand(seed + 2, rows * cols_n)
    pal = [hexc("#b49c94"), hexc("#a68d86"), hexc("#bfa9a1")]
    dots = [hexc("#efe4de"), hexc("#4f403f"), hexc("#8a6a62"), hexc("#d6b3a8")]
    out, h = [], []
    for i in range(S * S):
        c = mul(pal[int(rnd[ids[i]] * 3) % 3], 0.95 + 0.1 * nz[i])
        r = rng.random()
        if r < 0.10:
            c = mix(c, dots[int(r * 400) % 4], 0.75)
        c = mix(hexc("#5d4c49"), c, smooth(-0.5, 1.0, dist[i]))
        out.append(c)
        h.append(smooth(0, 4, dist[i]))
    return out, emboss(h, 1, 1.2)


def granite(seed):
    top, lt = granite_face(seed, 2, 2)
    side, ls = granite_face(seed + 50, 2, 1)
    return finish(top, lt), finish(side, ls, side=True), None, None


SAND = [hexc("#d9b061"), hexc("#e6c274"), hexc("#f0d48b"), hexc("#f7e3a8")]


def sand(seed):
    n = fbm(seed, 3, 4)
    n2 = fbm(seed + 1, 4, 3)
    sp = speckle(seed + 2, 0.05)
    rng = random.Random(seed + 3)
    top, lt_h = [], []
    for i in range(S * S):
        x, y = i % S, i // S
        w = math.sin(math.tau * (6 * (y + x * 0.25) / S + 0.9 * n2[i]))
        hh = 0.5 + 0.5 * w
        c = tones(clamp(0.25 + 0.45 * n[i] + 0.25 * hh), SAND)
        if sp[i]:
            c = mul(c, 0.82 if rng.random() < 0.6 else 1.12)
        top.append(c)
        lt_h.append(hh * 0.6 + n[i] * 0.4)
    lt = emboss(lt_h, 3, 0.9)
    side = []
    bands = fbm(seed + 4, 2, 3, base_y=12)
    for i in range(S * S):
        c = tones(clamp(0.3 + 0.55 * bands[i]), SAND)
        if sp[(i * 7) % (S * S)]:
            c = mul(c, 0.85)
        side.append(c)
    ls = emboss(bands, 2, 0.8)
    return finish(top, lt), finish(side, ls, side=True), None, None


SANDSTONE = [hexc("#c78d4a"), hexc("#d9a35d"), hexc("#e8b874")]


def sandstone(seed):
    top, lt = brick_face(seed, 2, 2, SANDSTONE, hexc("#9a6a35"), 5, offset=0.0, bevel=12)
    bands = fbm(seed + 1, 2, 3, base_y=10)
    nz = fbm(seed + 2, 8, 3)
    side, h = [], []
    for i in range(S * S):
        y = i // S
        t = clamp(bands[i] * 0.7 + 0.3 * (0.5 + 0.5 * math.sin(math.tau * y / 64.0)))
        c = tones(t, [hexc("#b97d3e")] + SANDSTONE + [hexc("#f2cc8c")])
        side.append(mul(c, 0.95 + 0.1 * nz[i]))
        h.append(t)
    ls = emboss(h, 2, 1.3)
    return finish(top, lt), finish(side, ls, side=True), None, None


SNOW = [hexc("#b9cde6"), hexc("#d6e4f4"), hexc("#ecf3fb"), hexc("#ffffff")]


def snow(seed):
    n = fbm(seed, 3, 4)
    sp = speckle(seed + 1, 0.012)
    top = []
    for i in range(S * S):
        c = tones(clamp(0.35 + 0.65 * n[i]), SNOW[1:])
        if sp[i]:
            c = (1.0, 1.0, 1.0)
        top.append(c)
    lt = emboss(n, 3, 2.2)
    side, ls = cobble_face(seed + 50)
    depth = fringe(seed + 60, 34, 6, 6, 30)
    side, ls = apply_fringe(side, ls, depth, SNOW, seed + 61, outline=hexc("#6f8fb5"))
    return finish(top, lt, 0.3), finish(side, ls, side=True), None, None


ICE = [hexc("#7cc6e8"), hexc("#9ad6f0"), hexc("#bde6f7"), hexc("#dcf4fc")]


def ice_face(seed):
    f1, f2, ids, _, _ = voronoi(seed, 3, 0.9)
    n = fbm(seed + 1, 3, 3)
    rnd = cell_rand(seed + 2, 9)
    out, h = [], []
    for i in range(S * S):
        x, y = i % S, i // S
        e = f2[i] - f1[i]
        t = clamp(0.25 + 0.4 * n[i] + 0.25 * rnd[ids[i]])
        c = tones(t, ICE)
        # Reflejos en diagonal.
        s = ((x + y) % 128) / 128
        if 0.12 < s < 0.18 or 0.24 < s < 0.26:
            c = mix(c, (1, 1, 1), 0.45)
        # Grietas blancas con su sombra.
        c = mix(c, hexc("#5aa7cf"), 1 - smooth(0.012, 0.03, e))
        c = mix(c, (1, 1, 1), 1 - smooth(0.0, 0.014, e))
        out.append(c)
        h.append(smooth(0.0, 0.2, e) * 0.6 + 0.4 * n[i])
    return out, emboss(h, 2, 1.0)


def ice(seed):
    top, lt = ice_face(seed)
    side, ls = ice_face(seed + 50)
    return finish(top, lt, 0.3), finish(side, ls, 0.3, side=True), None, None


GLOW = [(0.0, hexc("#8a1500")), (0.35, hexc("#e83a00")), (0.65, hexc("#ff8a12")), (1.0, hexc("#ffe066"))]


def lava_face(seed, n_cells, crust_w, crust_pal, glow=GLOW, crack_only=False):
    f1, f2, ids, _, _ = voronoi(seed, n_cells, 0.85)
    n = fbm(seed + 1, 6, 3)
    rnd = cell_rand(seed + 2, n_cells * n_cells)
    out, emit, h = [], [], []
    for i in range(S * S):
        e = f2[i] - f1[i] + (n[i] - 0.5) * 0.05
        crust = smooth(crust_w * 0.6, crust_w, e)
        g = ramp(glow, clamp(1 - e / crust_w))
        rock = mul(crust_pal[int(rnd[ids[i]] * len(crust_pal)) % len(crust_pal)], 0.85 + 0.3 * n[i])
        if crack_only:
            # Grietas finas en la roca, más brillantes en el centro.
            rock_h = smooth(crust_w, crust_w * 4, e)
        else:
            rock_h = smooth(crust_w, crust_w * 3, e)
        c = mix(g, rock, crust)
        out.append(c)
        emit.append(mul(g, (1 - crust)))
        h.append(rock_h * crust)
    return out, emboss(h, 2, 1.4), emit


def lava(seed):
    crust = [hexc("#3b2622"), hexc("#4a2e27"), hexc("#2f1f1c")]
    top, lt, te = lava_face(seed, 3, 0.14, crust)
    side, ls, se = lava_face(seed + 50, 3, 0.14, crust)
    return finish(top, lt), finish(side, ls, side=True), te, se


def magma(seed):
    crust = [hexc("#2f2a30"), hexc("#3a343a"), hexc("#26222a")]
    top, lt, te = lava_face(seed, 5, 0.035, crust, crack_only=True)
    side, ls, se = lava_face(seed + 50, 5, 0.035, crust, crack_only=True)
    return finish(top, lt), finish(side, ls, side=True), te, se


CORRUPT_GLOW = [(0.0, hexc("#3a0a4a")), (0.4, hexc("#a01fc2")), (0.75, hexc("#ff3df0")), (1.0, hexc("#ffc2fb"))]


def corrupted(seed):
    soil = [hexc("#3a2a4a"), hexc("#46325a"), hexc("#30233f")]
    top, lt, te = lava_face(seed, 4, 0.04, soil, CORRUPT_GLOW, crack_only=True)
    side, ls, se = lava_face(seed + 50, 4, 0.04, soil, CORRUPT_GLOW, crack_only=True)
    return finish(top, lt), finish(side, ls, side=True), te, se


FIRE = [(0.0, hexc("#5e1206")), (0.25, hexc("#c4260c")), (0.5, hexc("#ff6a14")), (0.75, hexc("#ffa82a")),
        (1.0, hexc("#fff09a"))]


FIRE_TONES = [c for _, c in FIRE]


def fire(seed):
    n = fbm(seed, 4, 4)
    n2 = fbm(seed + 1, 3, 3)
    # Arriba: brasas arremolinadas.
    top = []
    for i in range(S * S):
        x, y = i % S, i // S
        t = 0.5 + 0.5 * math.sin(math.tau * (2 * n2[i] + 3 * n[i] * 0.5))
        top.append(tones(clamp(0.15 + 0.85 * t * (0.6 + 0.4 * n[i])), FIRE_TONES, 0.02))
    # Lados: llamas que suben, como vetas verticales que se retuercen (se
    # repite en vertical, así que cualquier altura de bloque las enseña).
    side = []
    q = fbm(seed + 2, 7, 4, base_y=1)
    q2 = fbm(seed + 3, 3, 3)
    for i in range(S * S):
        x, y = i % S, i // S
        w = 0.5 + 0.5 * math.sin(math.tau * (2 * y / S + 1.5 * q2[i]) + q[i] * 4)
        t = clamp(1.3 * q[i] - 0.2 + 0.35 * (w - 0.5))
        side.append(tones(t, FIRE_TONES, 0.02))
    top_c = finish(top, None, rim=True)
    side_c = finish(side, None, side=True)
    return top_c, side_c, [mul(c, 0.9) for c in top], [mul(c, 0.9) for c in side]


WOOD = [hexc("#9a6234"), hexc("#b0753f"), hexc("#c48a4f")]


def planks_face(seed, rows):
    rng = random.Random(seed)
    grain = fbm(seed + 1, 2, 3, base_y=20)
    ph = S / rows
    seams = [rng.random() * S for _ in range(rows)]
    tint = [rng.choice(WOOD) for _ in range(rows * 2)]
    out, h = [], []
    for i in range(S * S):
        x, y = i % S, i // S
        r = int(y / ph)
        ly = y - r * ph
        sx = (x - seams[r]) % S
        half = 0 if sx < S / 2 else 1
        lx = sx % (S / 2)
        d = min(ly, ph - ly, lx, S / 2 - lx)
        g = 0.5 + 0.5 * math.sin(math.tau * (grain[i] * 3 + ly / ph * 0.6))
        c = mul(tint[r * 2 + half], 0.88 + 0.18 * g)
        # Clavos cerca de los extremos.
        for nx_ in (8, S / 2 - 8):
            if abs(lx - nx_) < 2.6 and abs(ly - ph / 2) < 2.6:
                c = hexc("#3b2a1e")
        c = mix(hexc("#4a2e18"), c, smooth(0.5, 2.5, d))
        out.append(c)
        h.append(smooth(0, 6, d) * (0.9 + 0.1 * g))
    return out, emboss(h, 2, 1.5)


def wood_planks(seed):
    top, lt = planks_face(seed, 4)
    side, ls = planks_face(seed + 50, 4)
    return finish(top, lt), finish(side, ls, side=True), None, None


def wood_log(seed):
    n = fbm(seed, 4, 3)
    top, h = [], []
    for i in range(S * S):
        x, y = i % S, i // S
        dx, dy = (x - S / 2) / (S / 2), (y - S / 2) / (S / 2)
        r = math.sqrt(dx * dx + dy * dy) + (n[i] - 0.5) * 0.08
        a = max(abs(dx), abs(dy))
        if a > 0.88:
            c = mul(hexc("#5b3a1e"), 0.85 + 0.3 * n[i])
            hh = 0.3
        elif a > 0.84:
            c = hexc("#3e2814")
            hh = 0.0
        else:
            ring = 0.5 + 0.5 * math.sin(r * 38)
            c = mix(hexc("#c08a4f"), hexc("#e0b075"), smooth(0.3, 0.7, ring))
            if r < 0.05:
                c = hexc("#9a6234")
            hh = 0.6 + 0.1 * ring
        top.append(c)
        h.append(hh)
    lt = emboss(h, 2, 1.2)
    bark = fbm(seed + 1, 14, 3, base_y=2)
    side = []
    for i in range(S * S):
        t = bark[i]
        side.append(tones(t, [hexc("#3e2814"), hexc("#5b3a1e"), hexc("#74502b"), hexc("#8a6236")]))
    ls = emboss(bark, 2, 1.8)
    return finish(top, lt, rim=False), finish(side, ls, side=True), None, None


def obsidian_face(seed):
    f1, f2, ids, ox, oy = voronoi(seed, 3, 0.9)
    rnd = cell_rand(seed + 1, 9)
    out = []
    for i in range(S * S):
        e = f2[i] - f1[i]
        a = rnd[ids[i]] * math.tau
        facet = clamp(0.5 + 0.9 * (ox[i] * math.cos(a) + oy[i] * math.sin(a)))
        c = ramp([(0.0, hexc("#140d1c")), (0.6, hexc("#2a1d3a")), (1.0, hexc("#5b3d7a"))], facet)
        c = mix(hexc("#a888d6"), c, smooth(0.0, 0.02, e))
        out.append(c)
    return out


def obsidian(seed):
    return finish(obsidian_face(seed)), finish(obsidian_face(seed + 50), side=True), None, None


def crystal_face(seed):
    f1, f2, ids, ox, oy = voronoi(seed, 4, 0.9)
    rnd = cell_rand(seed + 1, 16)
    out, emit = [], []
    for i in range(S * S):
        e = f2[i] - f1[i]
        a = rnd[ids[i]] * math.tau
        facet = clamp(0.5 + 1.1 * (ox[i] * math.cos(a) + oy[i] * math.sin(a)))
        c = ramp([(0.0, hexc("#4b2386")), (0.45, hexc("#7f43c9")), (0.8, hexc("#b77cf0")), (1.0, hexc("#e6c8ff"))],
                 facet)
        line = 1 - smooth(0.0, 0.025, e)
        c = mix(c, hexc("#f4e6ff"), line)
        out.append(c)
        emit.append(mul(hexc("#c58bff"), 0.15 + 0.6 * line + 0.15 * facet))
    return out, emit


def crystal(seed):
    top, te = crystal_face(seed)
    side, se = crystal_face(seed + 50)
    return finish(top), finish(side, side=True), te, se


def metal_face(seed, rows, cols_n):
    ids, dist, us, vs = bricks(rows, cols_n, 4, seed, 0.0)
    brushed = fbm(seed + 1, 32, 2, base_y=2)
    rnd = cell_rand(seed + 2, rows * cols_n)
    out, h = [], []
    pw, ph = S / cols_n, S / rows
    for i in range(S * S):
        c = mul(mix(hexc("#7d8792"), hexc("#97a1ab"), rnd[ids[i]]), 0.92 + 0.12 * brushed[i])
        lx, ly = us[i] * pw, vs[i] * ph
        hh = smooth(0, 5, dist[i])
        for rx in (12, pw - 12):
            for ry in (12, ph - 12):
                dd = math.hypot(lx - rx, ly - ry)
                if dd < 5:
                    c = mix(hexc("#c9d1d9"), hexc("#5c6570"), dd / 5)
                    hh = 1.0 + (5 - dd) / 5
        c = mix(hexc("#3c434b"), c, smooth(-0.5, 1.0, dist[i]))
        out.append(c)
        h.append(hh)
    return out, emboss(h, 1, 1.0)


def metal(seed):
    top, lt = metal_face(seed, 2, 2)
    side, ls = metal_face(seed + 50, 2, 2)
    return finish(top, lt), finish(side, ls, side=True), None, None


RED_BRICK = [hexc("#a84a34"), hexc("#bb5a3f"), hexc("#c96c4c"), hexc("#94402e")]


def brick(seed):
    top, lt = brick_face(seed, 4, 2, RED_BRICK, hexc("#d9c8b2"), 6)
    side, ls = brick_face(seed + 50, 6, 3, RED_BRICK, hexc("#d9c8b2"), 6)
    return finish(top, lt), finish(side, ls, side=True), None, None


RECIPES = {
    "grass": grass,
    "grass_flowers": grass_flowers,
    "grass_dry": grass_dry,
    "dirt": dirt,
    "stone": stone,
    "stone_bricks": stone_bricks,
    "mossy_stone": mossy_stone,
    "granite": granite,
    "sand": sand,
    "sandstone": sandstone,
    "snow": snow,
    "ice": ice,
    "lava": lava,
    "magma": magma,
    "fire": fire,
    "wood_planks": wood_planks,
    "wood_log": wood_log,
    "brick": brick,
    "metal": metal,
    "obsidian": obsidian,
    "crystal": crystal,
    "corrupted": corrupted,
}


def contact_sheet(path, names):
    """Hoja de revisión: por bloque, la cara de arriba, la lateral y un cubo
    en perspectiva caballera con ambas."""
    cell = 200
    sheet = Image.new("RGB", (cell * 4, cell * ((len(names) + 1) // 2)), (40, 40, 46))
    draw = ImageDraw.Draw(sheet)
    for k, name in enumerate(names):
        top = Image.open(OUT / f"{name}_top.png")
        side = Image.open(OUT / f"{name}_side.png")
        ox, oy = (k % 2) * cell * 2, (k // 2) * cell
        sheet.paste(top.resize((90, 90)), (ox + 5, oy + 20))
        sheet.paste(side.resize((90, 90)), (ox + 100, oy + 20))
        # Muro de media altura visto de frente y desde arriba.
        t = top.resize((150, 150)).transform((150, 60), Image.AFFINE, (1, 0, 0, 0, 2.5, 0))
        s = side.crop((0, 0, S, S // 2)).resize((150, 75))
        sheet.paste(t, (ox + 210, oy + 20))
        sheet.paste(s, (ox + 210, oy + 80))
        draw.text((ox + 5, oy + 4), name, fill=(240, 240, 240))
    sheet.save(path)


def main():
    args = sys.argv[1:]
    sheet = None
    if "--sheet" in args:
        i = args.index("--sheet")
        sheet = args[i + 1]
        del args[i:i + 2]
    names = args or list(RECIPES)
    OUT.mkdir(parents=True, exist_ok=True)
    for idx, name in enumerate(RECIPES):
        if name not in names:
            continue
        top, side, top_emit, side_emit = RECIPES[name](1000 + idx * 97)
        save(top, f"{name}_top.png")
        save(side, f"{name}_side.png")
        if top_emit:
            save(top_emit, f"{name}_top_emit.png", adjust=False)
            save(side_emit, f"{name}_side_emit.png", adjust=False)
        print("ok", name)
    if sheet:
        contact_sheet(sheet, [n for n in RECIPES if (OUT / f"{n}_top.png").exists()])


if __name__ == "__main__":
    main()
