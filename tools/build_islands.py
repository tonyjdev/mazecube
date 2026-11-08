#!/usr/bin/env python3
"""Generador de niveles de islas de Maze Cube (zona II, «Las tierras salvajes»).

Cada nivel es un archipiélago de islas flotando sobre el vacío ('~'), unidas
por puentes de una casilla de ancho:
- "ruina": isla con muros alrededor y una sala dentro (con algún pilar).
- "laberinto": isla con muros alrededor y un pequeño laberinto dentro.
- "meseta": isla abierta, sin muros, con el borde dando al vacío; puede
  tener las esquinas recortadas, pilares sueltos y grietas (huecos de vacío
  dentro) que obligan a girar a tiempo.
- "islote": meseta diminuta (2x2 o 3x3), normalmente un fondo de saco donde
  esconder una llave.

Las islas ocupan una cuadrícula de huecos; forman un árbol (DFS al azar) y
unos pocos puentes extra crean bucles. Un puente es recto si las dos islas
se solapan; si no, hace zigzag sobre el vacío (hay que girar en el aire a
tiempo o el cubo se cae). Algunos puentes rectos de dos casillas o más se
convierten en puentes colgantes ('=', aguantan tres travesías).

Los mecanismos se colocan como en tools/build_levels.py (casillas de paso
obligado del camino más corto), pero las puertas y los barrotes solo en
casillas con muro a ambos lados (las entradas de las islas amuralladas y los
pasillos de los laberintos). Valida cada candidato con tools/level_solver.py
(solución, botones, patrulleros y puentes) y para cada nivel se queda con el
más cercano al objetivo de giros.

Además de las filas, cada nivel lleva "theme_regions": los puentes de tierra
con el bloque "path" de su especificación y las islas amuralladas con el
bloque "ruin" (el resto del tema sale de Levels.THEMES según la zona).

Uso (desde la raíz del repositorio):
  python3 tools/build_islands.py [primer_nivel] [último_nivel] [intentos] [válidos] > niveles.txt
"""
import random
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_levels as bl  # noqa: E402
import level_solver as ls  # noqa: E402

DIRS = ls.DIRS

# Especificación de cada nivel:
#   grid      islas en horizontal y vertical
#   slot      tamaño máximo de cada isla; gap, casillas de vacío entre islas
#   kinds     peso de cada tipo de isla (ruin, maze, plateau, islet)
#   extra     puentes extra (bucles); hanging, puentes colgantes
#   holes     grietas por meseta grande (huecos de vacío dentro)
#   items     mecanismos en casillas de paso obligado (door, bars, break)
#   patrols, chasers, blockers, speed: enemigos y power ups
#   path, ruin: bloques del suelo de los puentes y de las islas amuralladas
#   turns     objetivo de giros mínimos
#   tries, valid (opcionales) intentos y candidatos válidos para este nivel
#             (por defecto, los de la línea de órdenes)
W_EASY = dict(ruin=3, maze=1, plateau=4, islet=2)
W_MID = dict(ruin=3, maze=2, plateau=4, islet=2)
W_HARD = dict(ruin=3, maze=3, plateau=3, islet=2)

SPECS = {
    36: dict(name="Islas flotantes", grid=(3, 2), slot=(9, 7), gap=4, kinds=W_EASY, extra=0,
             hanging=0, holes=0, items=["door", "door"], patrols=0, chasers=0, blockers=0, speed=1,
             path="dirt", ruin="mossy_stone", turns=24),
    37: dict(name="El salto", grid=(3, 3), slot=(8, 7), gap=4, kinds=W_EASY, extra=1,
             hanging=1, holes=0, items=["door", "break"], patrols=0, chasers=0, blockers=0, speed=1,
             path="dirt", ruin="mossy_stone", turns=26),
    38: dict(name="Tierra agrietada", grid=(4, 2), slot=(9, 8), gap=4, kinds=W_EASY, extra=1,
             hanging=0, holes=3, items=["door", "door", "break"], patrols=0, chasers=0, blockers=0,
             speed=1, path="dirt", ruin="mossy_stone", turns=28),
    39: dict(name="El cerezo", grid=(3, 3), slot=(9, 7), gap=4, kinds=W_EASY, extra=1,
             hanging=1, holes=1, items=["bars", "door", "door"], patrols=1, chasers=0, blockers=0,
             speed=1, path="dirt", ruin="mossy_stone", turns=30),
    40: dict(name="Cascadas", grid=(4, 3), slot=(8, 7), gap=4, kinds=W_EASY, extra=1,
             hanging=2, holes=1, items=["door", "break", "door"], patrols=0, chasers=1, blockers=0,
             speed=2, path="dirt", ruin="mossy_stone", turns=32),
    41: dict(name="Ruinas en el aire", grid=(4, 3), slot=(9, 7), gap=4, kinds=W_MID, extra=1,
             hanging=1, holes=1, items=["door", "bars", "door"], patrols=1, chasers=0, blockers=0,
             speed=1, path="dirt", ruin="stone_bricks", turns=34),
    42: dict(name="Puentes rotos", grid=(4, 3), slot=(8, 8), gap=5, kinds=W_MID, extra=2,
             hanging=3, holes=1, items=["door", "door", "break"], patrols=1, chasers=1, blockers=0,
             speed=1, path="dirt", ruin="stone_bricks", turns=36),
    43: dict(name="El valle perdido", grid=(5, 3), slot=(8, 7), gap=4, kinds=W_MID, extra=2,
             hanging=1, holes=2, items=["door", "bars", "door", "break"], patrols=1, chasers=1,
             blockers=0, speed=2, path="dirt", ruin="stone_bricks", turns=38),
    44: dict(name="Matorrales", grid=(4, 4), slot=(9, 7), gap=4, kinds=W_MID, extra=2,
             hanging=1, holes=2, items=["door", "door", "bars", "door"], patrols=1, chasers=1,
             blockers=1, speed=1, path="dirt", ruin="wood_planks", turns=40),
    45: dict(name="El templo del bosque", grid=(5, 3), slot=(9, 8), gap=4, kinds=W_HARD, extra=2,
             hanging=2, holes=1, items=["bars", "door", "bars", "door"], patrols=2, chasers=0,
             blockers=1, speed=1, path="dirt", ruin="stone_bricks", turns=42),
    46: dict(name="Hierba seca", grid=(5, 3), slot=(8, 8), gap=5, kinds=W_MID, extra=2,
             hanging=2, holes=3, items=["door", "break", "door", "door"], patrols=1, chasers=2,
             blockers=0, speed=2, path="dirt", ruin="wood_planks", turns=44),
    47: dict(name="Las colinas", grid=(4, 4), slot=(9, 8), gap=4, kinds=W_MID, extra=2,
             hanging=2, holes=2, items=["door", "bars", "door", "break", "door"], patrols=2,
             chasers=1, blockers=0, speed=1, path="dirt", ruin="wood_planks", turns=46),
    48: dict(name="Desfiladero", grid=(6, 3), slot=(8, 7), gap=4, kinds=W_HARD, extra=2,
             hanging=3, holes=2, items=["door", "door", "bars", "door"], patrols=1, chasers=1,
             blockers=1, speed=2, path="dirt", ruin="stone", turns=48),
    49: dict(name="Al pie de la montaña", grid=(5, 4), slot=(8, 7), gap=4, kinds=W_HARD, extra=2,
             hanging=2, holes=2, items=["door", "bars", "door", "break", "door"], patrols=2,
             chasers=1, blockers=1, speed=1, path="dirt", ruin="stone_bricks", turns=50),
    50: dict(name="Paso de montaña", grid=(5, 4), slot=(9, 7), gap=5, kinds=W_HARD, extra=3,
             hanging=3, holes=2, items=["door", "door", "bars", "door", "break"], patrols=2,
             chasers=2, blockers=0, speed=2, path="dirt", ruin="stone_bricks", turns=52),
    51: dict(name="Granito", grid=(5, 4), slot=(9, 8), gap=4, kinds=W_HARD, extra=3,
             hanging=2, holes=2, items=["bars", "door", "bars", "door", "door"], patrols=2,
             chasers=1, blockers=1, speed=1, path="dirt", ruin="stone_bricks", turns=54),
    52: dict(name="La cornisa", grid=(6, 4), slot=(8, 7), gap=4, kinds=W_HARD, extra=3,
             hanging=3, holes=3, items=["door", "break", "door", "bars", "door"], patrols=2,
             chasers=2, blockers=1, speed=2, path="dirt", ruin="stone_bricks", turns=56),
    53: dict(name="Primeras nieves", grid=(5, 4), slot=(9, 8), gap=5, kinds=W_HARD, extra=3,
             hanging=2, holes=2, items=["door", "bars", "door", "door", "break"], patrols=2,
             chasers=2, blockers=1, speed=1, path="stone", ruin="granite", turns=58),
    54: dict(name="El refugio", grid=(6, 4), slot=(9, 7), gap=4, kinds=W_HARD, extra=3,
             hanging=3, holes=2, items=["door", "bars", "door", "bars", "door"], patrols=3,
             chasers=1, blockers=1, speed=2, path="stone", ruin="wood_planks", turns=60),
    55: dict(name="Ventisca", grid=(6, 4), slot=(8, 7), gap=4, kinds=W_HARD, extra=3,
             hanging=3, holes=3, items=["door", "door", "break", "door", "bars", "door"], patrols=2,
             chasers=2, blockers=1, speed=2, path="stone", ruin="granite", turns=62),
    56: dict(name="Lago helado", grid=(6, 4), slot=(9, 7), gap=4, kinds=W_HARD, extra=3,
             hanging=3, holes=3, items=["bars", "door", "door", "bars", "door"], patrols=3,
             chasers=2, blockers=1, speed=2, path="stone", ruin="stone_bricks", turns=64, tries=900, valid=60),
    57: dict(name="Las cumbres", grid=(6, 4), slot=(8, 7), gap=4, kinds=W_HARD, extra=3,
             hanging=3, holes=2, items=["door", "bars", "door", "break", "door", "door"], patrols=3,
             chasers=2, blockers=1, speed=2, path="stone", ruin="granite", turns=66),
    58: dict(name="Glaciar", grid=(6, 4), slot=(9, 7), gap=4, kinds=W_HARD, extra=4,
             hanging=3, holes=3, items=["door", "door", "bars", "door", "bars", "door"], patrols=3,
             chasers=2, blockers=1, speed=2, path="stone", ruin="stone_bricks", turns=68, tries=900, valid=60),
    59: dict(name="El paso helado", grid=(7, 4), slot=(8, 7), gap=4, kinds=W_HARD, extra=4,
             hanging=4, holes=3, items=["door", "bars", "door", "break", "door", "bars", "door"],
             patrols=3, chasers=2, blockers=1, speed=2, path="stone", ruin="granite", turns=70, tries=900, valid=60),
    60: dict(name="El techo del mundo", grid=(7, 4), slot=(9, 7), gap=4, kinds=W_HARD, extra=4,
             hanging=4, holes=3, items=["door", "bars", "door", "break", "door", "bars", "door"],
             patrols=4, chasers=3, blockers=1, speed=3, path="stone", ruin="stone_bricks", turns=72),
}

Fail = bl.Fail


# --- Islas ---------------------------------------------------------------------

class Island:
    def __init__(self, kind, ox, oz, w, h):
        self.kind, self.ox, self.oz, self.w, self.h = kind, ox, oz, w, h

    @property
    def walled(self):
        return self.kind in ("ruin", "maze")

    def attach_rows(self, side):
        """Coordenadas (z si side es horizontal, x si es vertical) por las que
        puede salir un puente por ese lado."""
        if side in ("L", "R"):
            lo, hi, origin = self.oz, self.oz + self.h - 1, self.oz
        else:
            lo, hi, origin = self.ox, self.ox + self.w - 1, self.ox
        if self.walled:
            lo, hi = lo + 1, hi - 1
        elif self.w > 2 and self.h > 2:
            lo, hi = lo + 1, hi - 1  # sin las esquinas (pueden estar recortadas)
        options = list(range(lo, hi + 1))
        if self.kind == "maze":
            options = [v for v in options if (v - origin) % 2 == 1]
        return options

    def edge(self, side, v):
        """Casilla del borde de la isla por la que sale el puente en v."""
        if side == "L":
            return (self.ox, v)
        if side == "R":
            return (self.ox + self.w - 1, v)
        if side == "U":
            return (v, self.oz)
        return (v, self.oz + self.h - 1)


def odd_at_most(n):
    return n if n % 2 else n - 1


def make_island(rng, kind, slot_x, slot_z, sw, sh):
    if kind == "islet":
        w, h = rng.choice([(2, 2), (3, 2), (2, 3), (3, 3)])
    elif kind == "maze":
        w = rng.choice(range(5, odd_at_most(sw) + 1, 2))
        h = rng.choice(range(5, odd_at_most(sh) + 1, 2))
    elif kind == "ruin":
        w, h = rng.randint(max(5, sw - 2), sw), rng.randint(max(5, sh - 2), sh)
    else:
        w, h = rng.randint(max(4, sw - 3), sw), rng.randint(max(4, sh - 3), sh)
    ox = slot_x + rng.randint(0, sw - w)
    oz = slot_z + rng.randint(0, sh - h)
    return Island(kind, ox, oz, w, h)


def paint_island(rng, grid, isl, seed):
    if isl.kind == "maze":
        rows = ls.generate(isl.w, isl.h, seed, braid=rng.choice([0.0, 0.08, 0.15]))
        for z in range(isl.h):
            for x in range(isl.w):
                grid[isl.oz + z][isl.ox + x] = rows[z][x]
        return
    for z in range(isl.oz, isl.oz + isl.h):
        for x in range(isl.ox, isl.ox + isl.w):
            border = x in (isl.ox, isl.ox + isl.w - 1) or z in (isl.oz, isl.oz + isl.h - 1)
            grid[z][x] = "#" if isl.kind == "ruin" and border else "."
    if isl.kind == "ruin":
        # Un tabique con hueco en las salas grandes.
        if isl.w >= 7 and isl.h >= 6 and rng.random() < 0.6:
            if rng.random() < 0.5:
                x = isl.ox + rng.randint(3, isl.w - 4)
                gap = rng.randint(isl.oz + 1, isl.oz + isl.h - 2)
                for z in range(isl.oz + 1, isl.oz + isl.h - 1):
                    if z != gap and rng.random() < 0.85:
                        grid[z][x] = "#"
            else:
                z = isl.oz + rng.randint(3, isl.h - 4) if isl.h >= 7 else isl.oz + 2
                gap = rng.randint(isl.ox + 1, isl.ox + isl.w - 2)
                for x in range(isl.ox + 1, isl.ox + isl.w - 1):
                    if x != gap and rng.random() < 0.85:
                        grid[z][x] = "#"
        _pillars(rng, grid, isl, rng.randint(0, 2))
    elif isl.kind == "plateau":
        # Esquinas recortadas para que no parezca una caja.
        for cx, cz in ((isl.ox, isl.oz), (isl.ox + isl.w - 1, isl.oz),
                       (isl.ox, isl.oz + isl.h - 1), (isl.ox + isl.w - 1, isl.oz + isl.h - 1)):
            if rng.random() < 0.5:
                grid[cz][cx] = "~"
        _pillars(rng, grid, isl, rng.randint(0, 2))


def _pillars(rng, grid, isl, count):
    if isl.w < 5 or isl.h < 5:
        return
    for _ in range(count):
        x = rng.randint(isl.ox + 2, isl.ox + isl.w - 3)
        z = rng.randint(isl.oz + 2, isl.oz + isl.h - 3)
        if grid[z][x] == ".":
            grid[z][x] = "#"
            if not _island_connected(grid, isl):
                grid[z][x] = "."


def _island_connected(grid, isl):
    free = {(x, z) for z in range(isl.oz, isl.oz + isl.h) for x in range(isl.ox, isl.ox + isl.w)
            if grid[z][x] not in "#~"}
    return not free or len(bl.reach(free, next(iter(free)))) == len(free)


def carve_bridge(rng, grid, a, b, horizontal):
    """Puente de a a b (a a la izquierda o arriba). Devuelve sus casillas
    sobre el vacío (en orden) y si es recto."""
    if horizontal:
        ra, rb = a.attach_rows("R"), b.attach_rows("L")
    else:
        ra, rb = a.attach_rows("D"), b.attach_rows("U")
    common = sorted(set(ra) & set(rb))
    if common and rng.random() < 0.8:
        va = vb = rng.choice(common)
    else:
        va, vb = rng.choice(ra), rng.choice(rb)
    if horizontal:
        sa, sb = a.edge("R", va), b.edge("L", vb)
        cells = _zigzag(rng, sa, sb, horizontal=True)
    else:
        sa, sb = a.edge("D", va), b.edge("U", vb)
        cells = _zigzag(rng, sa, sb, horizontal=False)
    if cells is None:
        raise Fail("puente imposible")
    for end in (sa, sb):
        grid[end[1]][end[0]] = "."
    for x, z in cells:
        grid[z][x] = "."
    # La casilla de dentro de una isla amurallada, junto a la entrada, libre.
    for isl, end in ((a, sa), (b, sb)):
        if isl.walled:
            # Hacia dentro de la isla: al revés del puente.
            if horizontal:
                inner = (end[0] + 1, end[1]) if isl is b else (end[0] - 1, end[1])
            else:
                inner = (end[0], end[1] + 1) if isl is b else (end[0], end[1] - 1)
            grid[inner[1]][inner[0]] = "."
    return cells, va == vb


def _zigzag(rng, sa, sb, horizontal):
    if horizontal:
        (xa, za), (xb, zb) = sa, sb
        x0, x1 = xa + 1, xb - 1
        if x1 < x0:
            return None
        if za == zb:
            return [(x, za) for x in range(x0, x1 + 1)]
        if x1 - x0 < 2:
            return None
        xm = rng.randint(x0 + 1, x1 - 1)
        cells = [(x, za) for x in range(x0, xm + 1)]
        step = 1 if zb > za else -1
        cells += [(xm, z) for z in range(za + step, zb + step, step)]
        cells += [(x, zb) for x in range(xm + 1, x1 + 1)]
        return cells
    (xa, za), (xb, zb) = sa, sb
    z0, z1 = za + 1, zb - 1
    if z1 < z0:
        return None
    if xa == xb:
        return [(xa, z) for z in range(z0, z1 + 1)]
    if z1 - z0 < 2:
        return None
    zm = rng.randint(z0 + 1, z1 - 1)
    cells = [(xa, z) for z in range(z0, zm + 1)]
    step = 1 if xb > xa else -1
    cells += [(x, zm) for x in range(xa + step, xb + step, step)]
    cells += [(xb, z) for z in range(zm + 1, z1 + 1)]
    return cells


def islands_layout(rng, spec, seed):
    nx, ny = spec["grid"]
    sw, sh = spec["slot"]
    gap = spec["gap"]
    width = nx * sw + (nx - 1) * gap + 4
    height = ny * sh + (ny - 1) * gap + 4
    grid = [["~"] * width for _ in range(height)]
    kinds, weights = zip(*spec["kinds"].items())
    islands = {}
    for i in range(nx):
        for j in range(ny):
            kind = rng.choices(kinds, weights)[0]
            if (i, j) == (0, 0) and kind == "islet":
                kind = "ruin"
            # Dos islotes juntos podrían quedar sin puente.
            if kind == "islet" and any(islands.get(n) and islands[n].kind == "islet"
                                       for n in ((i - 1, j), (i, j - 1))):
                kind = "plateau"
            islands[(i, j)] = make_island(rng, kind, 2 + i * (sw + gap), 2 + j * (sh + gap), sw, sh)
    for k, isl in enumerate(islands.values()):
        paint_island(rng, grid, isl, seed * 37 + k)
    # Árbol de islas más algunos puentes extra.
    start = (0, 0)
    seen, stack, edges = {start}, [start], []
    while stack:
        i, j = stack[-1]
        options = [(i + di, j + dj) for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1))
                   if (i + di, j + dj) in islands and (i + di, j + dj) not in seen]
        # Los islotes no siguen el árbol: quedan como hojas (fondos de saco).
        if islands[(i, j)].kind == "islet" and (i, j) != start:
            stack.pop()
            continue
        if not options:
            stack.pop()
            continue
        n = rng.choice(options)
        edges.append(tuple(sorted([(i, j), n])))
        seen.add(n)
        stack.append(n)
    if len(seen) < len(islands):
        # Islotes aislados: los colgamos de un vecino ya unido.
        for c in islands:
            if c in seen:
                continue
            nbs = [(c[0] + di, c[1] + dj) for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1))
                   if (c[0] + di, c[1] + dj) in seen and islands[(c[0] + di, c[1] + dj)].kind != "islet"]
            if not nbs:
                raise Fail("islote sin vecinos")
            edges.append(tuple(sorted([c, rng.choice(nbs)])))
            seen.add(c)
    tree = set(edges)
    all_edges = [tuple(sorted([(i, j), (i + di, j + dj)])) for (i, j) in islands
                 for di, dj in ((1, 0), (0, 1)) if (i + di, j + dj) in islands]
    spare = [e for e in all_edges if e not in tree
             and islands[e[0]].kind != "islet" and islands[e[1]].kind != "islet"]
    rng.shuffle(spare)
    edges += spare[:spec["extra"]]
    bridges = []
    for a, b in edges:
        cells, straight_bridge = carve_bridge(rng, grid, islands[a], islands[b], horizontal=a[1] == b[1])
        bridges.append(dict(cells=cells, straight=straight_bridge, tree=(a, b) in tree,
                            horizontal=a[1] == b[1]))
    # Grietas: huecos de vacío dentro de las mesetas grandes.
    for isl in islands.values():
        if isl.kind != "plateau" or isl.w < 6 or isl.h < 5:
            continue
        for _ in range(spec["holes"]):
            x = rng.randint(isl.ox + 2, isl.ox + isl.w - 3)
            z = rng.randint(isl.oz + 2, isl.oz + isl.h - 3)
            if grid[z][x] != ".":
                continue
            grid[z][x] = "~"
            if not _all_connected(grid):
                grid[z][x] = "."
    if not _all_connected(grid):
        raise Fail("mapa partido")
    return grid, islands, bridges


def _all_connected(grid):
    free = {(x, z) for z, row in enumerate(grid) for x, c in enumerate(row) if c not in "#~"}
    if not free:
        return False
    return len(bl.reach(free, next(iter(free)))) == len(free)


def trim(grid):
    """Quita filas y columnas de vacío de sobra (deja una de margen)."""
    rows = ["".join(r) for r in grid]
    used_z = [z for z, r in enumerate(rows) if r.strip("~")]
    used_x = [x for x in range(len(rows[0])) if any(r[x] != "~" for r in rows)]
    z0, z1 = max(0, used_z[0] - 1), min(len(rows) - 1, used_z[-1] + 1)
    x0, x1 = max(0, used_x[0] - 1), min(len(rows[0]) - 1, used_x[-1] + 1)
    return [r[x0:x1 + 1] for r in rows[z0:z1 + 1]], x0, z0


# --- Nivel completo -------------------------------------------------------------

def walled_sides(grid, cell):
    """Muro a ambos lados del pasillo (para puertas y barrotes)."""
    x, z = cell
    return (grid[z][x - 1] == "#" and grid[z][x + 1] == "#") or \
        (grid[z - 1][x] == "#" and grid[z + 1][x] == "#")


def build(spec, seed):
    rng = random.Random(seed)
    grid, islands, bridges = islands_layout(rng, spec, seed)
    rows = ["".join(r) for r in grid]
    free = bl.free_cells(rows)

    # Puentes colgantes: tramos rectos (vacío a ambos lados) de puentes
    # rectos; mejor los del árbol (de paso obligado).
    straight_bridges = [b for b in bridges if b["straight"] and len(b["cells"]) >= 2]
    straight_bridges.sort(key=lambda b: (not b["tree"], rng.random()))
    hanging = straight_bridges[:spec["hanging"]]
    if len(hanging) < spec["hanging"]:
        raise Fail("pocos puentes para colgar")
    hanging_cells = set()
    for b in hanging:
        hanging_cells.update(b["cells"])

    start_isl = islands[(0, 0)]
    start_cells = [c for c in free if start_isl.ox <= c[0] < start_isl.ox + start_isl.w
                   and start_isl.oz <= c[1] < start_isl.oz + start_isl.h]
    start = min(start_cells, key=lambda c: c[0] + c[1] + rng.random() * 2)
    dist = bl.distances(free, start)
    far = sorted(dist, key=dist.get)[-max(3, len(dist) // 25):]
    far = [c for c in far if c not in hanging_cells] or far
    goal = rng.choice(far)
    path = bl.shortest_path(free, start, goal)
    if not path:
        raise Fail("sin camino")

    cuts = []
    for i, c in enumerate(path[3:-3], start=3):
        if c in hanging_cells or not bl.straight(free, c):
            continue
        if goal not in bl.reach(free, start, {c}):
            cuts.append((i, c))
    items = list(spec["items"])
    # Las puertas y los barrotes necesitan muro a los lados.
    walled = [(i, c) for i, c in cuts if walled_sides(grid, c)]
    if len(walled) < sum(1 for k in items if k != "break") or len(cuts) < len(items):
        raise Fail("pocos cortes")
    chosen = []
    span = len(cuts) / len(items)
    for k, kind in enumerate(items):
        lo, hi = int(k * span), max(int(k * span) + 1, int((k + 1) * span))
        window = cuts[lo:min(hi, len(cuts))]
        pool = window if kind == "break" else [c for c in window if walled_sides(grid, c[1])]
        if not pool:  # se busca en todo el camino, por orden
            pool = [c for c in cuts if kind == "break" or walled_sides(grid, c[1])]
        options = [c for c in pool if all(abs(c[0] - o[0]) > 3 for o, _ in chosen)]
        if not options:
            raise Fail("cortes muy juntos")
        chosen.append((rng.choice(options), kind))
    chosen.sort()
    items = [kind for _, kind in chosen]
    cut_cells = [c for (_, c), _ in chosen]
    if len(set(cut_cells)) < len(cut_cells):
        raise Fail("corte repetido")

    taken = {start, goal} | hanging_cells
    used_colors, used_groups, buttons = [], [], {}
    prev_region = set()
    for kind, cell in zip(items, cut_cells):
        region = bl.reach(free, start, {cell})
        new_area = region - prev_region if prev_region else region
        if kind == "door":
            color = bl.KEY_COLORS[len(used_colors)]
            used_colors.append(color)
            key = bl._pick_far_cell(rng, free, new_area - taken - set(cut_cells), path)
            if key is None:
                raise Fail("sin sitio para la llave")
            grid[cell[1]][cell[0]] = color.upper()
            grid[key[1]][key[0]] = color
            taken.update({cell, key})
        elif kind == "bars":
            group = bl.BAR_GROUPS[len(used_groups)]
            symbol = bl.BUTTONS[len(used_groups)]
            used_groups.append(group)
            button = bl._pick_button(rng, grid, free, region, cell, taken)
            if button is None:
                raise Fail("sin sitio para el botón")
            grid[cell[1]][cell[0]] = group.upper()
            grid[button[1]][button[0]] = symbol
            buttons[symbol] = group
            taken.add(cell)
        else:
            grid[cell[1]][cell[0]] = str(rng.randint(2, 4))
            taken.add(cell)
        prev_region = region
    taken.update(cut_cells)

    # Power ups: mejor sobre los puentes de tierra largos del camino.
    on_path = [c for c in path[4:-4] if bl.straight(free, c) and c not in taken]
    over_void = [c for c in on_path if grid[c[1] - 1][c[0]] == "~" or grid[c[1]][c[0] - 1] == "~"]
    rng.shuffle(over_void)
    rest = [c for c in on_path if c not in over_void]
    rng.shuffle(rest)
    for c in (over_void + rest)[:spec["speed"]]:
        grid[c[1]][c[0]] = "s"
        taken.add(c)

    plateaus = {k: (isl.ox + 1, isl.oz + 1, isl.w - 2, isl.h - 2) for k, isl in islands.items()
                if isl.kind in ("plateau", "ruin") and isl.w >= 6 and isl.h >= 5}
    patrols = bl._place_patrols(rng, grid, free - hanging_cells, plateaus, spec["patrols"], start, goal,
                                taken, path)
    dist = bl.distances(free, start)
    in_plateau = {c for isl in islands.values() if isl.kind == "plateau"
                  for c in free if isl.ox <= c[0] < isl.ox + isl.w and isl.oz <= c[1] < isl.oz + isl.h}
    deep = [c for c in free if dist.get(c, 0) >= 12 and c not in taken and grid[c[1]][c[0]] == "."]
    rng.shuffle(deep)
    deep.sort(key=lambda c: c in in_plateau)  # los de meseta al final (se sacan antes)
    for _ in range(spec["chasers"]):
        if not deep:
            raise Fail("sin sitio para perseguidores")
        c = deep.pop()
        grid[c[1]][c[0]] = "x"
        taken.add(c)
    for _ in range(spec["blockers"]):
        options = [c for c in deep if not bl.straight(free, c) and c not in taken
                   and grid[c[1]][c[0]] == "." and dist.get(c, 0) >= 10]
        if not options:
            raise Fail("sin sitio para el obstáculo")
        c = rng.choice(options)
        grid[c[1]][c[0]] = "z"
        taken.add(c)

    for c in hanging_cells:
        grid[c[1]][c[0]] = "="
    grid[start[1]][start[0]] = "A"
    grid[goal[1]][goal[0]] = "B"
    layout, x0, z0 = trim(grid)
    start = (start[0] - x0, start[1] - z0)
    patrols = {k: v for k, v in patrols.items()}
    headings = [h for h in DIRS if layout[start[1] + h[1]][start[0] + h[0]] not in "#~=pqtvw"]
    if not headings:
        raise Fail("salida encerrada")
    heading = headings[0]
    problems = ls.check_buttons(layout, buttons) + ls.check_enemies(layout, patrols) \
        + ls.check_bridges(layout)
    if problems:
        raise Fail("; ".join(problems))
    result = ls.solve(layout, heading, buttons=buttons)
    if result is None:
        raise Fail("sin solución")

    # Zonas de bloques: islas amuralladas y puentes de tierra.
    regions = []
    for isl in islands.values():
        if isl.walled:
            regions.append(((isl.ox - x0, isl.oz - z0, isl.w, isl.h), "floor", spec["ruin"]))
    for b in bridges:
        if b in hanging:
            continue
        for seg in _segments(b["cells"]):
            (ax, az), (bx, bz) = seg[0], seg[-1]
            rx, rz = min(ax, bx) - x0, min(az, bz) - z0
            regions.append(((rx, rz, abs(bx - ax) + 1, abs(bz - az) + 1), "floor", spec["path"]))
    return dict(layout=layout, heading=heading, buttons=buttons, patrols=patrols,
                turns=result[0], steps=result[1], regions=regions)


def _segments(cells):
    """Tramos rectos de una lista de casillas seguidas."""
    segs, cur = [], [cells[0]]
    for c in cells[1:]:
        if len(cur) >= 2:
            d0 = (cur[1][0] - cur[0][0], cur[1][1] - cur[0][1])
            d1 = (c[0] - cur[-1][0], c[1] - cur[-1][1])
            if d0 != d1:
                segs.append(cur)
                cur = [cur[-1]]
        cur.append(c)
    segs.append(cur)
    return segs


def to_gdscript(spec, level):
    text = bl.to_gdscript(spec, level)
    if not level["regions"]:
        return text
    lines = ['\t\t"theme_regions": [']
    for (x, z, w, h), part, block in level["regions"]:
        lines.append(f'\t\t\t{{"rect": Rect2i({x}, {z}, {w}, {h}), "{part}": "{block}"}},')
    lines.append("\t\t],")
    head, tail = text.rsplit("\n\t},", 1)
    return head + "\n" + "\n".join(lines) + "\n\t}," + tail


def main():
    first = int(sys.argv[1]) if len(sys.argv) > 1 else min(SPECS)
    last = int(sys.argv[2]) if len(sys.argv) > 2 else max(SPECS)
    attempts = int(sys.argv[3]) if len(sys.argv) > 3 else 300
    max_valid = int(sys.argv[4]) if len(sys.argv) > 4 else 25
    for number in range(first, last + 1):
        spec = SPECS[number]
        best, tried, valid = None, 0, 0
        reasons = {}
        t0 = time.time()
        seed = number * 1000
        limit, enough = spec.get("tries", attempts), spec.get("valid", max_valid)
        while valid < enough and tried < limit:
            seed += 1
            tried += 1
            try:
                level = build(spec, seed)
            except Fail as e:
                key = str(e).split(" en ")[0][:40]
                reasons[key] = reasons.get(key, 0) + 1
                continue
            valid += 1
            if best is None or abs(level["turns"] - spec["turns"]) < abs(best["turns"] - spec["turns"]):
                best = level
        size = f'{len(best["layout"][0])}x{len(best["layout"])}' if best else "-"
        top = sorted(reasons.items(), key=lambda kv: -kv[1])[:3]
        print(f"# Nivel {number}: {spec['name']}  {size}  giros={best and best['turns']} "
              f"(objetivo {spec['turns']})  válidos={valid}/{tried}  {time.time() - t0:.0f}s  {top}",
              file=sys.stderr)
        if best:
            print(to_gdscript(spec, best))
        sys.stdout.flush()


if __name__ == "__main__":
    main()
