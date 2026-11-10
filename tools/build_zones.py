#!/usr/bin/env python3
"""Generador de los niveles 69-115 de Maze Cube (zonas III, IV y V).

Parte de los generadores anteriores para el mapa y sus mecanismos clásicos
(llaves y puertas, barrotes y botones, muros destructibles, power ups y
enemigos):
- "maze" y "rooms": tools/build_levels.py (laberintos y salas con pasillos).
- "islands": tools/build_islands.py (archipiélagos sobre el vacío).

Encima coloca los peligros de la zona III en adelante:
- Teletransportes "split": cortan el camino de la salida a la meta tapando
  una casilla de pasillo de paso obligado (o, en las islas, quitando un
  puente entero) y unen las dos partes con una pareja de portales en dos
  fondos de saco, así que el portal es imprescindible.
- Teletransportes "short": atajos entre dos fondos de saco lejanos.
  Los dos portales de una pareja dan a lados opuestos, para que el cubo salga
  por el otro con el mismo rumbo sin quedar encajonado.
- Pinchos ('^'): en casillas libres del camino y fuera de él, lejos de la
  salida, nunca en rutas de patrulla ni junto al vacío.
- Cañones láser ('L'): muros con una sola casilla libre al lado cuyo disparo
  cruza el camino (nunca a lo largo de él) y no pasa por la salida.
- Cañones de bombas ('M'): muros desde los que hay muchas casillas libres a
  su alcance (10 hacia delante y 5 a cada lado) sin que la salida lo esté.
  Se escribe hacia dónde mira cada uno en "mortars".

Valida cada candidato con tools/level_solver.py y para cada nivel se queda
con el más cercano al objetivo de giros. Imprime los niveles listos para
pegar en scripts/levels.gd (y por stderr un resumen de cada uno). Varios
niveles se generan a la vez (un proceso por nivel).

Uso (desde la raíz del repositorio):
  python3 tools/build_zones.py [primer_nivel] [último_nivel] [intentos] [válidos] [lista] > niveles.txt
  (lista: solo esos niveles, separados por comas)
"""
import multiprocessing
import random
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_islands as bi  # noqa: E402
import build_levels as bl  # noqa: E402
import level_solver as ls  # noqa: E402

DIRS = ls.DIRS
Fail = bl.Fail
PAD_SYMBOLS = "6789"
# Alcance de los cañones de bombas (ver MortarCannon) y orden en que el juego
# prueba las direcciones al elegir hacia dónde mira (ver Level._add_mortar).
MORTAR_REACH = ls.MORTAR_RANGE
MORTAR_FACINGS = [(0, 1), (1, 0), (0, -1), (-1, 0)]
# Veces que se prueban los portales de un nivel hasta que tiene solución.
TELEPORT_TRIES = 6
# Parte de los láseres pedidos que hay que poder colocar como mínimo.
LASER_MIN_SHARE = 0.6
# Casillas libres mínimas al alcance de un cañón de bombas.
MORTAR_MIN_CELLS = 18
# Lo que para un láser: muros, cañones, botones, muros destructibles, puertas
# y barrotes cerrados.
LASER_STOP = "#LM" + ls.BUTTON_CHARS + ls.BREAKABLE_CHARS + ls.DOOR_CHARS + ls.BAR_CHARS.upper()
# Casillas que el juego pisa como suelo (para el alcance de los cañones).
NOT_FLOOR = "#~LM" + ls.BUTTON_CHARS

# Pesos de los tipos de isla (ver build_islands).
W_HARD = bi.W_HARD

# Especificación de cada nivel: la de su generador base ("kind": maze, rooms
# o islands) más los peligros: split y short (parejas de teletransporte),
# spikes, lasers y mortars.
Z3 = dict(chasers=1, blockers=0, speed=0)
SPECS = {
    # Zona III, «El mundo desconocido»: el desierto (arena y arenisca) y las
    # cuevas de cristal; junta lo que se ha presentado en la zona.
    69: dict(name="El oasis", kind="maze", size=(35, 25), braid=0.08, items=["door", "door"],
             patrols=0, **Z3, split=0, short=1, spikes=6, lasers=3, mortars=0, turns=36),
    70: dict(name="Dunas", kind="rooms", rooms=(5, 3), slot=(7, 6), gap=4, extra=2,
             items=["door", "bars"], patrols=1, **Z3, split=0, short=0, spikes=5, lasers=0, mortars=3,
             turns=38),
    71: dict(name="El templo enterrado", kind="maze", size=(37, 27), braid=0.07,
             items=["door", "break", "door"], patrols=1, chasers=1, blockers=0, speed=1,
             split=1, short=0, spikes=6, lasers=5, mortars=0, turns=40),
    72: dict(name="Cuevas de cristal", kind="rooms", rooms=(5, 3), slot=(7, 6), gap=4, extra=2,
             items=["door", "bars", "door"], patrols=1, chasers=1, blockers=0, speed=0,
             split=0, short=1, spikes=4, lasers=6, mortars=2, turns=42),
    73: dict(name="El eco", kind="maze", size=(39, 27), braid=0.07, items=["door", "door", "break"],
             patrols=1, chasers=1, blockers=1, speed=1, split=1, short=1, spikes=8, lasers=4, mortars=2,
             turns=44),
    74: dict(name="Galerías brillantes", kind="rooms", rooms=(5, 4), slot=(7, 6), gap=4, extra=2,
             items=["door", "bars", "door", "break"], patrols=2, chasers=1, blockers=0, speed=1,
             split=0, short=1, spikes=6, lasers=8, mortars=3, turns=46),
    75: dict(name="El corazón de cristal", kind="rooms", rooms=(5, 4), slot=(7, 6), gap=4, extra=3,
             items=["door", "bars", "door", "door"], patrols=1, chasers=2, blockers=1, speed=1,
             split=1, short=1, spikes=8, lasers=8, mortars=3, turns=48),
}

# Zona IV, «Los territorios corrompidos»: archipiélagos que se deshacen sobre
# el abismo (y algún laberinto y fortaleza), con la corrupción extendiéndose
# sobre la piedra, después la tierra volcánica y al final la corrupción
# total. Los puentes de tierra y las islas amuralladas llevan su propio
# suelo (path, ruin).
_Z4 = [
    # número, nombre, tipo, giros, (path, ruin)
    (76, "La frontera", "islands", 44),
    (77, "Tierra enferma", "islands", 45),
    (78, "Raíces negras", "maze", 47),
    (79, "Las grietas", "islands", 48),
    (80, "El páramo", "islands", 50),
    (81, "Ruinas corrompidas", "rooms", 51),
    (82, "Niebla púrpura", "islands", 53),
    (83, "El último puesto", "islands", 54),
    (84, "Ríos de fuego", "islands", 56),
    (85, "Obsidiana", "maze", 57),
    (86, "La forja", "rooms", 58),
    (87, "Ceniza", "islands", 60),
    (88, "El volcán dormido", "islands", 61),
    (89, "Islas de magma", "islands", 63),
    (90, "Humo negro", "maze", 64),
    (91, "La caldera", "islands", 65),
    (92, "La plaga", "islands", 67),
    (93, "Tierra muerta", "rooms", 68),
    (94, "Torres caídas", "islands", 69),
    (95, "El pantano oscuro", "islands", 70),
    (96, "Ecos del abismo", "rooms", 71),
    (97, "La herida", "islands", 72),
    (98, "Sin retorno", "islands", 73),
    (99, "Las puertas negras", "rooms", 74),
    (100, "El umbral", "islands", 76),
]
_ITEMS = [
    ["door", "bars", "door"], ["door", "door", "break"], ["bars", "door", "door", "break"],
    ["door", "bars", "door", "door"], ["door", "break", "door", "bars", "door"],
    ["door", "bars", "door", "break", "door"], ["bars", "door", "door", "bars", "door"],
    ["door", "door", "bars", "door", "break", "door"],
]


def _zone4_spec(k, number, name, kind, turns):
    t = k / (len(_Z4) - 1)  # 0..1 a lo largo de la zona
    if number <= 83:
        path, ruin = "stone", "stone_bricks"
    elif number <= 91:
        path, ruin = "magma", "stone"
    else:
        path, ruin = "magma", "obsidian"
    items = _ITEMS[min(len(_ITEMS) - 1, int(t * len(_ITEMS)))]
    common = dict(name=name, kind=kind, items=items, patrols=1 + int(t * 2.5), chasers=1 + int(t * 1.8),
                  blockers=int(t > 0.3), speed=1 + int(t > 0.5), turns=turns,
                  spikes=4 + int(t * 8), lasers=3 + int(t * 7), mortars=2 + int(t * 3),
                  short=1 + int(t > 0.6), split=int(k % 3 == 1))
    if kind == "islands":
        gx = 5 + int(t * 2.4)
        common.update(grid=(min(gx, 7), 4 if t < 0.75 else 5), slot=(9, 7) if k % 2 else (8, 8), gap=4,
                      kinds=W_HARD, extra=3 + int(t * 1.5), hanging=2 + int(t * 2), holes=2 + int(t * 1.5),
                      path=path, ruin=ruin, tries=900, valid=30)
    elif kind == "maze":
        w = 41 + 2 * int(t * 6)
        common.update(size=(w, w - 12), braid=0.06)
    else:
        common.update(rooms=(5 + int(t * 2), 4 + int(t > 0.5)), slot=(7, 6), gap=4, extra=3)
    return common


for _k, (_n, _name, _kind, _turns) in enumerate(_Z4):
    SPECS[_n] = _zone4_spec(_k, _n, _name, _kind, _turns)

# Zona V, «El núcleo enemigo»: la fortaleza de metal y obsidiana. Salas y
# pasillos vigilados por cañones, portales imprescindibles y muchos enemigos.
_Z5 = [
    (101, "La muralla exterior", "rooms", 70),
    (102, "Los barracones", "rooms", 71),
    (103, "Pasillos de acero", "rooms", 73),
    (104, "La sala de máquinas", "rooms", 74),
    (105, "Centinelas", "rooms", 76),
    (106, "El arsenal", "rooms", 77),
    (107, "La fundición", "rooms", 79),
    (108, "Fuego cruzado", "rooms", 80),
    (109, "El laboratorio", "rooms", 82),
    (110, "La prisión", "rooms", 83),
    (111, "Las torres de vigía", "rooms", 85),
    (112, "El reactor", "rooms", 86),
    (113, "La cámara acorazada", "rooms", 88),
    (114, "El trono vacío", "rooms", 90),
    (115, "El núcleo", "rooms", 92),
]


def _zone5_spec(k, number, name, kind, turns):
    t = k / (len(_Z5) - 1)
    items = _ITEMS[min(len(_ITEMS) - 2, 3 + int(t * 4))]
    common = dict(name=name, kind=kind, items=items, patrols=2 + int(t * 2), chasers=2 + int(t * 1.5),
                  blockers=1, speed=1 + int(t > 0.5), turns=turns,
                  spikes=8 + int(t * 8), lasers=8 + int(t * 8), mortars=3 + int(t * 3),
                  short=1, split=1 + int(t > 0.5))
    # Salas de la fortaleza: unas con salas grandes y pasillos largos y otras
    # con salas pequeñas y muy juntas.
    if k % 2 == 0:
        common.update(rooms=(6 + int(t * 2), 5 + int(t > 0.5)), slot=(7, 6), gap=4, extra=3)
    else:
        common.update(rooms=(7 + int(t * 2), 5 + int(t > 0.5)), slot=(6, 5), gap=3, extra=4)
    return common


for _k, (_n, _name, _kind, _turns) in enumerate(_Z5):
    SPECS[_n] = _zone5_spec(_k, _n, _name, _kind, _turns)

# Ajustes de tamaño de los niveles que salían con muchos menos giros de los
# previstos (los portales acortan el camino más o menos según dónde caen).
SIZE_FIXES = {
    79: dict(grid=(6, 4)), 83: dict(grid=(6, 4)), 86: dict(rooms=(6, 4)), 87: dict(grid=(7, 4)),
    89: dict(grid=(7, 4), split=0), 92: dict(grid=(7, 4), split=0), 95: dict(grid=(8, 5), split=0),
    100: dict(grid=(8, 5)), 103: dict(rooms=(7, 5)), 107: dict(rooms=(7, 5)), 110: dict(rooms=(9, 6)),
    114: dict(rooms=(10, 6), split=1),
    115: dict(rooms=(10, 6), turns=105),
}
for _n, _fix in SIZE_FIXES.items():
    SPECS[_n].update(_fix)


# --- Utilidades ---------------------------------------------------------------

def at(grid, c):
    x, z = c
    if 0 <= z < len(grid) and 0 <= x < len(grid[z]):
        return grid[z][x]
    return "~"


def free_of(grid):
    """Casillas por las que se puede ir (el obstáculo 'z' cuenta como libre:
    se mueve)."""
    free, _, _ = ls.parse(["".join(r) for r in grid])
    return free | {(x, z) for z, row in enumerate(grid) for x, c in enumerate(row) if c == "z"}


def find(grid, ch):
    for z, row in enumerate(grid):
        for x, c in enumerate(row):
            if c == ch:
                return (x, z)
    return None


def patrol_cells(level):
    cells = set()
    grid = level["grid"]
    for symbol, route in level["patrols"].items():
        origin = find(grid, symbol)
        if origin:
            cells.update(ls.route_cells(origin, route))
    return cells


def tp_pairs(grid):
    """Casilla de portal -> su pareja."""
    cells = {}
    for z, row in enumerate(grid):
        for x, c in enumerate(row):
            if c in PAD_SYMBOLS:
                cells.setdefault(c, []).append((x, z))
    pairs = {}
    for group in cells.values():
        if len(group) == 2:
            pairs[group[0]], pairs[group[1]] = group[1], group[0]
    return pairs


def tp_path(free, pairs, a, b, blocked=()):
    """Camino más corto de a a b contando los portales como casillas
    contiguas a su pareja (o [] si no hay)."""
    blocked = set(blocked)
    prev, queue = {a: None}, [a]
    for c in queue:
        if c == b:
            break
        nbrs = [(c[0] + d[0], c[1] + d[1]) for d in DIRS]
        if c in pairs:
            nbrs.append(pairs[c])
        for n in nbrs:
            if n in free and n not in prev and n not in blocked:
                prev[n] = c
                queue.append(n)
    if b not in prev:
        return []
    path, c = [], b
    while c is not None:
        path.append(c)
        c = prev[c]
    return path[::-1]


def tp_reach(free, pairs, origin, blocked=()):
    blocked = set(blocked)
    seen, queue = {origin}, [origin]
    for c in queue:
        nbrs = [(c[0] + d[0], c[1] + d[1]) for d in DIRS]
        if c in pairs:
            nbrs.append(pairs[c])
        for n in nbrs:
            if n in free and n not in seen and n not in blocked:
                seen.add(n)
                queue.append(n)
    return seen


def dead_ends(grid, free):
    """Fondos de saco libres ('.') con muro (no vacío) alrededor: casilla ->
    dirección de su única salida."""
    out = {}
    for c in free:
        if at(grid, c) != ".":
            continue
        opens = [d for d in DIRS if (c[0] + d[0], c[1] + d[1]) in free]
        if len(opens) != 1:
            continue
        if any(at(grid, (c[0] + d[0], c[1] + d[1])) == "~" for d in DIRS):
            continue
        out[c] = opens[0]
    return out


def path_dirs(path):
    """Casilla del camino -> dirección del camino en ella (eje)."""
    dirs = {}
    for i, c in enumerate(path):
        n = path[i + 1] if i + 1 < len(path) else path[i - 1]
        d = (abs(n[0] - c[0]), abs(n[1] - c[1]))
        dirs.setdefault(c, set()).add(d)
    return dirs


def pad_spots(rng, grid, free, taken, limit=160):
    """Casillas libres ('.') con un muro o el borde al lado donde puede ir un
    portal: sin ella el mapa no queda partido (un portal en un pasillo de
    paso obligado no deja pasar: al entrar, el cubo se va). Como mucho
    `limit`, al azar."""
    cands = [c for c in free if at(grid, c) == "." and c not in taken
             and any(at(grid, (c[0] + d[0], c[1] + d[1])) in "#~LM" for d in DIRS)]
    rng.shuffle(cands)
    out = []
    for c in cands:
        if len(out) >= limit:
            break
        nbrs = [(c[0] + d[0], c[1] + d[1]) for d in DIRS if (c[0] + d[0], c[1] + d[1]) in free]
        if len(nbrs) <= 1:
            out.append(c)
            continue
        seen = bl.reach(free, nbrs[0], {c})
        if all(n in seen for n in nbrs[1:]):
            out.append(c)
    return out


def pair_ok(free, a, b):
    """Por cada lado por el que se entra en un portal, el cubo puede salir
    (o rebotar) en el otro: no queda encajonado."""
    for p, q in ((a, b), (b, a)):
        for d in DIRS:
            if (p[0] - d[0], p[1] - d[1]) in free and (q[0] + d[0], q[1] + d[1]) not in free \
                    and (q[0] - d[0], q[1] - d[1]) not in free:
                return False
    return True


def pick_pair(rng, grid, free, side_a, side_b, min_apart=0):
    """Pareja de casillas para portales (una de side_a y otra de side_b):
    mejor dos fondos de saco que dan a lados opuestos; si no, dos casillas
    junto a un muro en las que el cubo no queda encajonado."""
    ends = dead_ends(grid, free)
    pairs = [(a, b) for a in side_a if a in ends for b in side_b if b in ends
             and ends[a] == (-ends[b][0], -ends[b][1]) and a != b
             and abs(a[0] - b[0]) + abs(a[1] - b[1]) >= min_apart]
    if pairs:
        return rng.choice(pairs)
    side_a, side_b = list(side_a), list(side_b)
    if not side_a or not side_b:
        return None
    for _ in range(200):
        a, b = rng.choice(side_a), rng.choice(side_b)
        if a != b and abs(a[0] - b[0]) + abs(a[1] - b[1]) >= min_apart and pair_ok(free, a, b):
            return a, b
    return None


# --- Peligros -----------------------------------------------------------------

def add_split(rng, level, symbol):
    """Corta el camino y une las dos partes con una pareja de portales."""
    grid = level["grid"]
    free = free_of(grid)
    start, goal = find(grid, "A"), find(grid, "B")
    pairs = tp_pairs(grid)
    path = tp_path(free, pairs, start, goal)
    if not path:
        raise Fail("split: sin camino")
    islands = level["kind"] == "islands"
    options = []
    for c in path[8:-8]:
        if at(grid, c) != "." or not bl.straight(free, c):
            continue
        if any(at(grid, (c[0] + d[0], c[1] + d[1])) not in ".#~" for d in DIRS):
            continue
        if islands:
            run = _bridge_run(grid, free, c)
            if run is None:
                continue
            cut = run
        else:
            cut = [c]
        if goal in tp_reach(free, pairs, start, set(cut)):
            continue
        options.append(cut)
    rng.shuffle(options)
    for cut in options:
        blocked = set(cut)
        side_s = tp_reach(free, pairs, start, blocked)
        side_g = tp_reach(free, pairs, goal, blocked)
        trial = [r[:] for r in grid]
        for c in cut:
            trial[c[1]][c[0]] = "~" if islands else "#"
        rest = free - blocked
        taken = patrol_cells(level) | level["taken"]
        spots = pad_spots(rng, trial, rest, taken)
        spots_s = [c for c in spots if c in side_s and abs(c[0] - start[0]) + abs(c[1] - start[1]) > 4]
        spots_g = [c for c in spots if c in side_g and abs(c[0] - goal[0]) + abs(c[1] - goal[1]) > 3]
        pair = pick_pair(rng, trial, rest, spots_s, spots_g)
        if pair is None:
            continue
        a, b = pair
        trial[a[1]][a[0]] = symbol
        trial[b[1]][b[0]] = symbol
        level["grid"] = trial
        level["taken"].update({a, b})
        return
    raise Fail("split: sin fondos de saco para los portales")


def _bridge_run(grid, free, c):
    """Puente de tierra entero (tramo recto con vacío a los lados) que pasa
    por c, si acaba en suelo de isla por los dos extremos; si no, None."""
    for axis in ((1, 0), (0, 1)):
        side = (axis[1], axis[0])
        def bridge(p):
            return p in free and at(grid, (p[0] + side[0], p[1] + side[1])) == "~" \
                and at(grid, (p[0] - side[0], p[1] - side[1])) == "~"
        if not bridge(c):
            continue
        run = [c]
        for sign in (1, -1):
            p = (c[0] + axis[0] * sign, c[1] + axis[1] * sign)
            while bridge(p):
                run.append(p)
                p = (p[0] + axis[0] * sign, p[1] + axis[1] * sign)
            if p not in free:
                return None  # el puente sigue en zigzag o se corta
        return run
    return None


def add_short(rng, level, symbol):
    """Atajo: pareja de portales en dos fondos de saco lejanos."""
    grid = level["grid"]
    free = free_of(grid)
    start = find(grid, "A")
    taken = patrol_cells(level) | level["taken"]
    spots = [c for c in pad_spots(rng, grid, free, taken) if abs(c[0] - start[0]) + abs(c[1] - start[1]) > 4]
    pair = pick_pair(rng, grid, free, spots, spots, min_apart=14)
    if pair is None:
        raise Fail("short: sin sitio para los portales")
    a, b = pair
    grid[a[1]][a[0]] = symbol
    grid[b[1]][b[0]] = symbol
    level["taken"].update({a, b})


def add_blockers(rng, level, count):
    """Obstáculos en casillas que no son de pasillo recto, lejos de la salida,
    sin las que el mapa no queda partido."""
    if count <= 0:
        return
    grid = level["grid"]
    free = free_of(grid)
    start = find(grid, "A")
    dist = bl.distances(free, start)
    taken = patrol_cells(level) | level["taken"]
    spots = [c for c in pad_spots(rng, grid, free, taken, limit=400)
             if dist.get(c, 0) >= 10 and not bl.straight(free, c)
             and not any(at(grid, (c[0] + d[0], c[1] + d[1])) in PAD_SYMBOLS + "~=" for d in DIRS)]
    # pad_spots pide un muro al lado: también valen las del centro de las salas.
    if len(spots) < count:
        raise Fail("sin sitio para el obstáculo")
    for c in rng.sample(spots, count):
        grid[c[1]][c[0]] = "z"
        level["taken"].add(c)


def add_spikes(rng, level, count):
    if count <= 0:
        return
    grid = level["grid"]
    free = free_of(grid)
    start, goal = find(grid, "A"), find(grid, "B")
    path = tp_path(free, tp_pairs(grid), start, goal)
    near = bl.distances(free, start)
    taken = patrol_cells(level) | level["taken"]

    def ok(c):
        if at(grid, c) != "." or c in taken or near.get(c, 99) < 5:
            return False
        if any(at(grid, (c[0] + d[0], c[1] + d[1])) in "~=" + PAD_SYMBOLS for d in DIRS):
            return False
        return all(abs(c[0] - o[0]) + abs(c[1] - o[1]) > 2 for o in placed)

    placed = []
    on_path = [c for c in path if c in free]
    rng.shuffle(on_path)
    rest = [c for c in free if c not in set(path)]
    rng.shuffle(rest)
    # La mitad en el camino y el resto fuera.
    for pool, want in ((on_path, (count + 1) // 2), (rest, count)):
        for c in pool:
            if len(placed) >= want:
                break
            if ok(c):
                placed.append(c)
    if len(placed) < count:
        raise Fail("pocos sitios para pinchos")
    for c in placed:
        grid[c[1]][c[0]] = "^"
        level["taken"].add(c)


def add_lasers(rng, level, count):
    if count <= 0:
        return
    grid = level["grid"]
    free = free_of(grid)
    start, goal = find(grid, "A"), find(grid, "B")
    path = tp_path(free, tp_pairs(grid), start, goal)
    pdirs = path_dirs(path)
    options = []
    for z, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch != "#":
                continue
            sides = [d for d in DIRS if (x + d[0], z + d[1]) in free]
            if len(sides) != 1:
                continue
            d = sides[0]
            ray, p = [], (x + d[0], z + d[1])
            while 0 <= p[1] < len(grid) and 0 <= p[0] < len(grid[0]) and at(grid, p) not in LASER_STOP:
                if at(grid, p) != "~":
                    ray.append(p)
                p = (p[0] + d[0], p[1] + d[1])
            if start in ray or len(ray) < 2:
                continue
            axis = (abs(d[0]), abs(d[1]))
            crossing = sum(1 for c in ray if c in pdirs and axis not in pdirs[c])
            along = sum(1 for c in ray if c in pdirs and axis in pdirs[c])
            if crossing < 1 or along > 1:
                continue
            options.append(((x, z), crossing))
    rng.shuffle(options)
    options.sort(key=lambda o: -min(o[1], 3))
    placed = []
    for c, _ in options:
        if len(placed) >= count:
            break
        if all(abs(c[0] - o[0]) + abs(c[1] - o[1]) > 2 for o in placed):
            placed.append(c)
    if len(placed) < max(1, round(count * LASER_MIN_SHARE)):
        raise Fail("pocos sitios para láseres")
    for c in placed:
        grid[c[1]][c[0]] = "L"


def _in_reach(cell, facing, target):
    ox, oz = target[0] - cell[0], target[1] - cell[1]
    forward = ox * facing[0] + oz * facing[1]
    side = ox * facing[1] - oz * facing[0]
    return 1 <= forward <= MORTAR_REACH[0] and abs(side) <= MORTAR_REACH[1]


def add_mortars(rng, level, count):
    if count <= 0:
        return
    grid = level["grid"]
    floor = {(x, z) for z, row in enumerate(grid) for x, c in enumerate(row) if c not in NOT_FLOOR}
    start = find(grid, "A")
    options = []
    for z, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch != "#":
                continue
            walls = sum(1 for d in DIRS if at(grid, (x + d[0], z + d[1])) in "#LM")
            border = x in (0, len(row) - 1) or z in (0, len(grid) - 1)
            if walls < 2 and not border:
                continue
            # Hacia dónde mira, como lo elige el juego.
            best, facing = -1, None
            for f in MORTAR_FACINGS:
                n = sum(1 for c in floor if _in_reach((x, z), f, c))
                if n > best:
                    best, facing = n, f
            if best < MORTAR_MIN_CELLS or _in_reach((x, z), facing, start):
                continue
            options.append(((x, z), facing))
    rng.shuffle(options)
    placed = []
    for c, f in options:
        if len(placed) >= count:
            break
        if all(abs(c[0] - o[0]) + abs(c[1] - o[1]) > 7 for o, _ in placed):
            placed.append((c, f))
    if len(placed) < count:
        raise Fail("pocos sitios para cañones de bombas")
    for c, f in placed:
        grid[c[1]][c[0]] = "M"
        level["mortars"][c] = f


# --- Nivel --------------------------------------------------------------------

def build(spec, seed):
    rng = random.Random(seed * 7 + 3)
    if spec["kind"] == "maze":
        # En los laberintos grandes casi no hay muros con una sola casilla
        # libre al lado para el botón: los barrotes pasan a ser muros
        # destructibles.
        # Y con más de dos puertas casi nunca tienen solución (el cubo no se
        # para): las demás también pasan a ser muros destructibles.
        items, doors = [], 0
        for k in spec["items"]:
            if k == "door":
                doors += 1
            items.append("break" if k == "bars" or (k == "door" and doors > 2) else k)
        spec = dict(spec, items=items)
    # El obstáculo cuenta como muro para el resolvedor: lo coloca add_blockers
    # donde no parte el mapa (los generadores base a veces lo ponen en un
    # cruce imprescindible).
    base_spec = dict(spec, blockers=0)
    if spec["kind"] == "islands":
        base = bi.build(base_spec, seed)
    else:
        base = bl.build(base_spec, seed)
    level = dict(kind=spec["kind"], grid=[list(r) for r in base["layout"]], patrols=base["patrols"],
                 buttons=base["buttons"], heading=base["heading"], regions=base.get("regions", []),
                 mortars={}, taken=set())
    # Lo que ya hay en el mapa no se toca (llaves, enemigos, power ups...).
    for z, row in enumerate(level["grid"]):
        for x, c in enumerate(row):
            if c not in ".#~":
                level["taken"].add((x, z))
    # Los portales cambian por dónde se puede ir: se prueban varias veces
    # hasta que el nivel sigue teniendo solución. El resto de peligros no lo
    # cambia (los cañones van en muros y los pinchos cuentan como libres).
    result = None
    saved = ([r[:] for r in level["grid"]], set(level["taken"]))
    for _ in range(TELEPORT_TRIES):
        level["grid"], level["taken"] = [r[:] for r in saved[0]], set(saved[1])
        pads = iter(PAD_SYMBOLS)
        for _ in range(spec["split"]):
            add_split(rng, level, next(pads))
        for _ in range(spec["short"]):
            add_short(rng, level, next(pads))
        add_blockers(rng, level, spec["blockers"])
        result = ls.solve(["".join(r) for r in level["grid"]], level["heading"], buttons=level["buttons"])
        if result is not None:
            break
    if result is None:
        raise Fail("sin solución con portales")
    add_spikes(rng, level, spec["spikes"])
    add_lasers(rng, level, spec["lasers"])
    add_mortars(rng, level, spec["mortars"])
    layout = ["".join(r) for r in level["grid"]]
    problems = (ls.check_buttons(layout, level["buttons"]) + ls.check_enemies(layout, level["patrols"])
                + ls.check_bridges(layout) + ls.check_teleports(layout) + ls.check_lasers(layout)
                + ls.check_mortars(layout, {c: {"facing": f} for c, f in level["mortars"].items()}))
    if problems:
        raise Fail("; ".join(problems))
    return dict(layout=layout, heading=level["heading"], buttons=level["buttons"], patrols=level["patrols"],
                regions=level["regions"], mortars=level["mortars"], turns=result[0], steps=result[1])


def to_gdscript(spec, level):
    text = bi.to_gdscript(spec, level) if level["regions"] else bl.to_gdscript(spec, level)
    if level["mortars"]:
        inner = ", ".join(f'Vector2i({x}, {z}): {{"facing": Vector2i({f[0]}, {f[1]})}}'
                          for (x, z), f in sorted(level["mortars"].items(), key=lambda kv: (kv[0][1], kv[0][0])))
        head, tail = text.rsplit("\n\t},", 1)
        text = head + f'\n\t\t"mortars": {{{inner}}},' + "\n\t}," + tail
    return text


def make_level(args):
    number, attempts, max_valid = args
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
        if abs(best["turns"] - spec["turns"]) <= 1 and valid >= 3:
            break
    size = f'{len(best["layout"][0])}x{len(best["layout"])}' if best else "-"
    top = sorted(reasons.items(), key=lambda kv: -kv[1])[:3]
    summary = (f"# Nivel {number}: {spec['name']}  {size}  giros={best and best['turns']} "
               f"(objetivo {spec['turns']})  válidos={valid}/{tried}  {time.time() - t0:.0f}s  {top}")
    return number, summary, to_gdscript(spec, best) if best else None


def main():
    first = int(sys.argv[1]) if len(sys.argv) > 1 else min(SPECS)
    last = int(sys.argv[2]) if len(sys.argv) > 2 else max(SPECS)
    attempts = int(sys.argv[3]) if len(sys.argv) > 3 else 1200
    max_valid = int(sys.argv[4]) if len(sys.argv) > 4 else 30
    only = [int(n) for n in sys.argv[5].split(",")] if len(sys.argv) > 5 else None
    jobs = [(n, attempts, max_valid) for n in range(first, last + 1) if only is None or n in only]
    with multiprocessing.Pool() as pool:
        results = sorted(pool.imap_unordered(make_level, jobs))
    for _, summary, text in results:
        print(summary, file=sys.stderr)
        if text:
            print(text)


if __name__ == "__main__":
    main()
