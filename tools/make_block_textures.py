#!/usr/bin/env python3
"""Genera las texturas de los bloques del laberinto (suelo y muros) en
textures/blocks/.

Estilo casi plano: cada cara es un color liso con una variación mínima y
solo los rasgos grandes que identifican el material (juntas de ladrillos y
tablones, unas pocas grietas, el césped o la nieve que cuelga por los lados,
las vetas que brillan). Las caras de arriba llevan un marco algo más oscuro
y los lados una línea de luz en el borde de arriba, para que se lean los
cubos. Todo se pinta aquí (no hay imágenes externas).

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

# Ajuste final de la paleta de todos los bloques: SATURATION < 1 apaga los
# colores (los acerca a su gris) y LIGHTEN aclara (acerca a blanco), para un
# acabado más suave. CONTRAST < 1 reduce algo la diferencia entre claros y
# oscuros.
SATURATION = 0.72
LIGHTEN = 0.12
CONTRAST = 0.9
# Variación de tono dentro de una cara (manchas muy grandes y suaves).
VARIATION = 0.035


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


BLACK = (0.0, 0.0, 0.0)


class Noise:
    """Ruido de valor periódico (se repite cada S píxeles): n x n nodos."""

    def __init__(self, seed, n):
        rng = random.Random(seed)
        self.n = n
        self.g = [rng.random() for _ in range(n * n)]

    def at(self, x, y):
        n = self.n
        fx, fy = x / S * n, y / S * n
        ix, iy = math.floor(fx), math.floor(fy)
        tx, ty = fx - ix, fy - iy
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        i0, i1, j0, j1 = ix % n, (ix + 1) % n, (iy % n) * n, ((iy + 1) % n) * n
        g = self.g
        return lerp(lerp(g[j0 + i0], g[j0 + i1], tx), lerp(g[j1 + i0], g[j1 + i1], tx), ty)


def wrap_d(a, b):
    d = abs(a - b) % S
    return min(d, S - d)


# --- Capas --------------------------------------------------------------------
# Una cara (Face) tiene S*S colores (r, g, b) en 0-1 y, si brilla, otra lista
# igual con la luz propia (emisión). Las capas la modifican en el sitio.

class Face:
    def __init__(self, color, seed, variation=VARIATION, glow=None):
        n = Noise(seed, 2)
        self.c = [mul(color, 1 + variation * (2 * n.at(i % S, i // S) - 1)) for i in range(S * S)]
        self.e = None if glow is None else [glow] * (S * S)


def paint(face, mask, color, glow=None):
    """Pinta `color` donde mask(x, y) > 0 (0-1, con borde suave) y, si se da
    `glow`, también la luz propia (la cara pasa a brillar)."""
    if glow is not None and face.e is None:
        face.e = [BLACK] * (S * S)
    for i in range(S * S):
        k = mask(i % S, i // S)
        if k > 0:
            face.c[i] = mix(face.c[i], color, k)
            if glow is not None:
                face.e[i] = mix(face.e[i], glow, k)


def seams_mask(rows, cols, seed, width=3.0, offset=0.5, jitter=0.0):
    """Juntas de ladrillos, losas o tablones: rows filas de cols piezas, cada
    fila desplazada `offset` de pieza respecto a la anterior."""
    rng = random.Random(seed)
    bh, bw = S / rows, S / cols
    shifts = [(r * offset + rng.uniform(-0.5, 0.5) * jitter) % 1.0 for r in range(rows)]

    def mask(x, y):
        r = int(y / bh)
        ly = y - r * bh
        lx = (x + shifts[r] * bw) % bw
        d = min(ly, bh - ly, lx, bw - lx)
        return 1 - smooth(width * 0.5 - 0.7, width * 0.5 + 0.7, d)
    return mask


def spots_mask(seed, count, rmin, rmax, keep=None):
    """Unas pocas manchas redondas (con borde suave), periódicas. `keep`
    filtra las manchas (x, y, radio)."""
    rng = random.Random(seed)
    spots = [(rng.random() * S, rng.random() * S, rng.uniform(rmin, rmax)) for _ in range(count)]
    if keep:
        spots = [s for s in spots if keep(s)]

    def mask(x, y):
        k = 0.0
        for cx, cy, r in spots:
            d = math.hypot(wrap_d(x, cx), wrap_d(y, cy))
            k = max(k, 1 - smooth(r - 1, r + 1, d))
        return k
    return mask


def cracks_mask(seed, n, width):
    """Grietas: bordes de unas pocas celdas de Voronoi periódicas (n x n)."""
    rng = random.Random(seed)
    pts = []
    for j in range(n):
        for i in range(n):
            px = (i + 0.5 + rng.uniform(-0.4, 0.4)) * S / n
            py = (j + 0.5 + rng.uniform(-0.4, 0.4)) * S / n
            pts += [(px + ox, py + oy) for ox in (-S, 0, S) for oy in (-S, 0, S)]

    def mask(x, y):
        d1 = d2 = 1e9
        for px, py in pts:
            d = math.hypot(x - px, y - py)
            if d < d1:
                d1, d2 = d, d1
            elif d < d2:
                d2 = d
        # (d2 - d1) / 2 es aproximadamente la distancia al borde entre celdas.
        return 1 - smooth(width * 0.5 - 0.7, width * 0.5 + 0.7, (d2 - d1) * 0.5)
    return mask


def add_fringe(face, seed, color, base=30, wave=4, drips=5, drip_depth=20):
    """Borde que cuelga desde arriba de una cara lateral (césped, nieve,
    musgo): color liso con una línea algo más oscura abajo y una sombra
    suave sobre lo de debajo. Periódico en horizontal."""
    rng = random.Random(seed)
    phases = [rng.random() * math.tau for _ in range(2)]
    drops = [(rng.random() * S, rng.uniform(10, 18), rng.uniform(0.6, 1.0) * drip_depth) for _ in range(drips)]
    depth = []
    for x in range(S):
        d = base + wave * math.sin(math.tau * 3 * x / S + phases[0]) \
            + wave * 0.4 * math.sin(math.tau * 7 * x / S + phases[1])
        for cx, w, a in drops:
            dx = wrap_d(x, cx)
            if dx < w:
                d += a * math.sqrt(1 - (dx / w) ** 2)
        depth.append(d)
    edge = mul(color, 0.82)
    for i in range(S * S):
        x, y = i % S, i // S
        d = depth[x]
        col = mix(color, edge, smooth(d - 4, d - 2, y))
        face.c[i] = mix(face.c[i], col, 1 - smooth(d - 0.7, d + 0.7, y))
        if y > d:
            face.c[i] = mul(face.c[i], 1 - 0.12 * (1 - smooth(d, d + 10, y)))


def finish(face, side):
    """Borde del cubo: en la cara de arriba un marco algo más oscuro (separa
    las casillas) y en los lados una línea de luz en el borde de arriba."""
    for i in range(S * S):
        x, y = i % S, i // S
        if side:
            k = 1.0 + 0.10 * (1 - smooth(1, 5, y))
        else:
            e = min(x, y, S - 1 - x, S - 1 - y)
            k = 0.9 + 0.1 * smooth(1, 7, e)
        face.c[i] = mul(face.c[i], k)


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


# --- Bloques ------------------------------------------------------------------
# Cada receta recibe una semilla y devuelve (top, side) como Face.

GRASS = hexc("#6dbb45")
GRASS_DRY = hexc("#cfae4a")
DIRT = hexc("#9a6a42")
STONE = hexc("#9ba2aa")
STONE_BRICK = hexc("#a5adb6")
MOSS = hexc("#5f9e3a")
SAND = hexc("#ecd08a")
SANDSTONE = hexc("#dcaa66")
SNOW = hexc("#f4f7fb")
ICE = hexc("#a9dcf2")
WOOD = hexc("#c48d55")
BARK = hexc("#6e4728")


def dirt_face(seed):
    f = Face(DIRT, seed)
    paint(f, spots_mask(seed + 1, 5, 9, 15), mul(DIRT, 0.9))
    return f


def stone_face(seed):
    f = Face(STONE, seed)
    paint(f, cracks_mask(seed + 1, 3, 3), mul(STONE, 0.82))
    return f


def grass_like(color, flowers=0):
    def recipe(seed):
        top = Face(color, seed)
        if flowers:
            for k, fc in enumerate((hexc("#ffffff"), hexc("#ffd84a"), hexc("#ff8cc0"))):
                paint(top, spots_mask(seed + 10 + k, flowers, 4.5, 6), fc)
        side = dirt_face(seed + 50)
        add_fringe(side, seed + 60, color)
        return top, side
    return recipe


def dirt(seed):
    return dirt_face(seed), dirt_face(seed + 50)


def stone(seed):
    return stone_face(seed), stone_face(seed + 50)


def slabs(color, seed, top_grid, side_grid, width=4, dark=0.8, offset=0.0):
    """Losas arriba y sillares en los lados (rejillas (filas, columnas))."""
    top = Face(color, seed)
    paint(top, seams_mask(*top_grid, seed, width, offset=offset), mul(color, dark))
    side = Face(color, seed + 50)
    paint(side, seams_mask(*side_grid, seed + 50, width), mul(color, dark))
    return top, side


def stone_bricks(seed):
    return slabs(STONE_BRICK, seed, (2, 2), (4, 2))


def mossy_stone(seed):
    top, side = stone_bricks(seed)
    paint(top, spots_mask(seed + 5, 4, 26, 44), MOSS)
    paint(side, spots_mask(seed + 6, 4, 14, 24, keep=lambda s: s[1] > 90), MOSS)
    add_fringe(side, seed + 60, MOSS, base=14, wave=3, drips=4, drip_depth=22)
    return top, side


def granite(seed):
    return slabs(hexc("#bba9a2"), seed, (2, 2), (2, 1), width=3, dark=0.84)


def sand(seed):
    return Face(SAND, seed), Face(mul(SAND, 0.96), seed + 50)


def sandstone(seed):
    return slabs(SANDSTONE, seed, (2, 2), (4, 1), width=3, dark=0.85)


def snow(seed):
    top = Face(SNOW, seed, variation=0.02)
    side = stone_face(seed + 50)
    add_fringe(side, seed + 60, SNOW, base=36, wave=5, drips=5, drip_depth=24)
    return top, side


def ice(seed):
    faces = []
    for s in (seed, seed + 50):
        f = Face(ICE, s)
        paint(f, cracks_mask(s + 1, 2, 2.5), hexc("#e6f7fd"))
        faces.append(f)
    return tuple(faces)


def lava(seed):
    """Lava brillante con unas pocas costras oscuras."""
    glow = hexc("#ff8a1a")
    faces = []
    for s in (seed, seed + 50):
        f = Face(glow, s, glow=glow)
        paint(f, spots_mask(s + 1, 4, 22, 34), hexc("#5a2c22"), BLACK)
        faces.append(f)
    return tuple(faces)


def cracked_glow(base, line, seed, base_glow=None):
    """Roca de color liso con unas pocas grietas que brillan."""
    faces = []
    for s in (seed, seed + 50):
        f = Face(base, s, glow=base_glow or BLACK)
        paint(f, cracks_mask(s + 1, 2, 3), line, line)
        faces.append(f)
    return tuple(faces)


def magma(seed):
    return cracked_glow(hexc("#3f373b"), hexc("#ff7a1a"), seed)


def fire(seed):
    faces = []
    for s in (seed, seed + 50):
        f = Face(hexc("#ff7a1a"), s, glow=hexc("#ff7a1a"))
        paint(f, spots_mask(s + 1, 5, 18, 32), hexc("#ffc845"), hexc("#ffc845"))
        faces.append(f)
    return tuple(faces)


def wood_planks(seed):
    top = Face(WOOD, seed)
    paint(top, seams_mask(4, 1, seed, 3, offset=0.37, jitter=0.6), mul(WOOD, 0.74))
    side = Face(WOOD, seed + 50)
    paint(side, seams_mask(4, 1, seed + 50, 3), mul(WOOD, 0.74))
    return top, side


def wood_log(seed):
    wood = hexc("#e0b075")
    top = Face(wood, seed)
    c = S / 2

    def rings(x, y):
        d = math.hypot(x - c, y - c)
        return max(1 - smooth(1.0, 2.4, abs(d - 40)), 1 - smooth(1.0, 2.4, abs(d - 80)))
    paint(top, rings, mul(wood, 0.84))
    paint(top, lambda x, y: 1 - smooth(13, 15, min(x, y, S - 1 - x, S - 1 - y)), BARK)
    side = Face(BARK, seed + 50)
    paint(side, seams_mask(1, 4, seed + 50, 3, jitter=0.4), mul(BARK, 0.8))
    return top, side


def brick(seed):
    c = hexc("#c0634a")
    mortar = hexc("#e6d6c0")
    top = Face(c, seed)
    paint(top, seams_mask(4, 2, seed, 5), mortar)
    side = Face(c, seed + 50)
    paint(side, seams_mask(6, 3, seed + 50, 5), mortar)
    return top, side


def metal(seed):
    c = hexc("#a2acb6")
    marks = (14, S / 2 - 14, S / 2 + 14, S - 14)
    rivets = [(x, y) for x in marks for y in marks]

    def rivet(x, y):
        return max(1 - smooth(4, 5.5, math.hypot(x - rx, y - ry)) for rx, ry in rivets)
    faces = []
    for s in (seed, seed + 50):
        f = Face(c, s)
        paint(f, seams_mask(2, 2, s, 3, offset=0.0), mul(c, 0.78))
        paint(f, rivet, mul(c, 1.15))
        faces.append(f)
    return tuple(faces)


def obsidian(seed):
    c = hexc("#2e2439")
    faces = []
    for s in (seed, seed + 50):
        f = Face(c, s)
        paint(f, cracks_mask(s + 1, 2, 2.5), hexc("#54426a"))
        faces.append(f)
    return tuple(faces)


def crystal(seed):
    base = hexc("#9a62d8")
    return cracked_glow(base, hexc("#dcbcff"), seed, base_glow=mul(base, 0.25))


def corrupted(seed):
    return cracked_glow(hexc("#45345a"), hexc("#ff4af0"), seed)


RECIPES = {
    "grass": grass_like(GRASS),
    "grass_flowers": grass_like(GRASS, flowers=4),
    "grass_dry": grass_like(GRASS_DRY),
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
    """Hoja de revisión: por bloque, la cara de arriba, la lateral y un muro
    de media altura visto desde arriba y de frente."""
    cell = 200
    sheet = Image.new("RGB", (cell * 4, cell * ((len(names) + 1) // 2)), (40, 40, 46))
    draw = ImageDraw.Draw(sheet)
    for k, name in enumerate(names):
        top = Image.open(OUT / f"{name}_top.png")
        side = Image.open(OUT / f"{name}_side.png")
        ox, oy = (k % 2) * cell * 2, (k // 2) * cell
        sheet.paste(top.resize((90, 90)), (ox + 5, oy + 20))
        sheet.paste(side.resize((90, 90)), (ox + 100, oy + 20))
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
        top, side = RECIPES[name](1000 + idx * 97)
        for face, part in ((top, "top"), (side, "side")):
            finish(face, part == "side")
            save(face.c, f"{name}_{part}.png")
            if face.e is not None:
                save(face.e, f"{name}_{part}_emit.png", adjust=False)
        print("ok", name)
    if sheet:
        contact_sheet(sheet, [n for n in RECIPES if (OUT / f"{n}_top.png").exists()])


if __name__ == "__main__":
    main()
