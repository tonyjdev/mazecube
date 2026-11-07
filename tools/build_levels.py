#!/usr/bin/env python3
"""Generador de niveles grandes de Maze Cube (los niveles 17 en adelante).

Construye dos tipos de mapa:
- "rooms": salas rectangulares (con algún pilar dentro) unidas por pasillos
  de una casilla de ancho, rectos o en zigzag. Las salas forman un árbol y
  unos pocos pasillos extra crean bucles.
- "maze": laberinto (ver level_solver.generate) con pocos bucles.

Sobre el mapa coloca los mecanismos en casillas de paso obligado ("cortes":
casillas de pasillo recto del camino más corto entre A y B cuya eliminación
deja B incomunicada), así que cada puerta, barrote cerrado y muro
destructible es imprescindible:
- puerta: su llave se coloca entre el corte anterior y el suyo, a ser posible
  en un fondo de saco apartado del camino.
- barrotes cerrados: su botón se coloca a pocas casillas (BUTTON_REACH) del
  lado de la salida, para que se vean juntos.
- muro destructible: un dígito de 2 a 4 golpes.
Después añade power ups y enemigos (patrulleros que rodean salas o recorren
pasillos rectos, perseguidores lejos de la salida y obstáculos) y valida el
nivel con level_solver (solución, botones y rutas de patrulla).

Para cada nivel prueba varias semillas y se queda con el candidato cuyo
mínimo de giros se acerca más al objetivo. Imprime los niveles listos para
pegar en scripts/levels.gd.

Uso (desde la raíz del repositorio):
  python3 tools/build_levels.py [primer_nivel] [último_nivel] [intentos] [válidos] > niveles.txt
"""
import random
import sys
import time
from collections import deque
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import level_solver as ls  # noqa: E402

DIRS = ls.DIRS
KEY_COLORS = "yourg"
BAR_GROUPS = "cdefh"
BUTTONS = "pqtvw"
PATROLS = "ijkmn"
BUTTON_REACH = 6

# Especificación de cada nivel: tipo de mapa y tamaño, mecanismos y objetivo
# de giros (el candidato elegido es el más cercano).
SPECS = {
    17: dict(name="Pasillos", kind="rooms", rooms=(4, 2), slot=(7, 5), gap=4, extra=1,
             items=["door"], patrols=1, chasers=0, blockers=0, speed=0, turns=28),
    18: dict(name="Laberinto de piedra", kind="maze", size=(27, 19), braid=0.06,
             items=["door", "door", "break"], patrols=1, chasers=0, blockers=0, speed=0, turns=30),
    19: dict(name="La celda", kind="rooms", rooms=(3, 3), slot=(7, 6), gap=4, extra=1,
             items=["bars", "door"], patrols=1, chasers=1, blockers=0, speed=0, turns=33),
    20: dict(name="Velocidad punta", kind="maze", size=(29, 21), braid=0.07,
             items=["door", "door", "break"], patrols=2, chasers=0, blockers=0, speed=2, turns=35),
    21: dict(name="Los aposentos", kind="rooms", rooms=(4, 3), slot=(7, 5), gap=4, extra=2,
             items=["door", "bars", "door"], patrols=1, chasers=0, blockers=1, speed=0, turns=38),
    22: dict(name="Rejas", kind="maze", size=(33, 23), braid=0.06,
             items=["bars", "break", "bars", "door"], patrols=1, chasers=1, blockers=0, speed=0, turns=40),
    23: dict(name="La cacería", kind="rooms", rooms=(4, 3), slot=(7, 6), gap=4, extra=2,
             items=["door", "door", "bars"], patrols=1, chasers=2, blockers=0, speed=1, turns=43),
    24: dict(name="Las catacumbas", kind="maze", size=(31, 23), braid=0.05,
             items=["door", "break", "door", "door"], patrols=2, chasers=0, blockers=1, speed=1, turns=45),
    25: dict(name="El vigilante", kind="rooms", rooms=(4, 4), slot=(7, 5), gap=4, extra=2,
             items=["bars", "door", "bars", "door"], patrols=2, chasers=0, blockers=1, speed=0, turns=48),
    26: dict(name="Persecución", kind="maze", size=(35, 25), braid=0.08,
             items=["door", "door", "bars", "door"], patrols=1, chasers=2, blockers=0, speed=1, turns=50),
    27: dict(name="La ronda", kind="rooms", rooms=(5, 3), slot=(7, 6), gap=4, extra=2,
             items=["door", "bars", "door", "break"], patrols=3, chasers=1, blockers=0, speed=1, turns=53),
    28: dict(name="El bastión", kind="maze", size=(37, 27), braid=0.04,
             items=["door", "bars", "door", "break", "door"], patrols=2, chasers=1, blockers=1, speed=1,
             turns=56),
    29: dict(name="El palacio", kind="rooms", rooms=(5, 4), slot=(7, 5), gap=4, extra=3,
             items=["door", "bars", "door", "bars", "door"], patrols=3, chasers=1, blockers=1, speed=1,
             turns=60),
    30: dict(name="El gran laberinto", kind="rooms", rooms=(6, 4), slot=(7, 5), gap=4, extra=3,
             items=["door", "bars", "break", "door", "bars", "door"], patrols=3, chasers=2, blockers=1,
             speed=2, turns=64),
}


class Fail(Exception):
    pass


# --- Mapas -------------------------------------------------------------------

def rooms_layout(rng, nx, ny, slot_w, slot_h, gap, extra):
    width = nx * slot_w + (nx - 1) * gap + 2
    height = ny * slot_h + (ny - 1) * gap + 2
    grid = [["#"] * width for _ in range(height)]
    rooms = {}
    for i in range(nx):
        for j in range(ny):
            rw = rng.randint(max(3, slot_w - 2), slot_w)
            rh = rng.randint(max(3, slot_h - 2), slot_h)
            ox = 1 + i * (slot_w + gap) + rng.randint(0, slot_w - rw)
            oz = 1 + j * (slot_h + gap) + rng.randint(0, slot_h - rh)
            rooms[(i, j)] = (ox, oz, rw, rh)
            for z in range(oz, oz + rh):
                for x in range(ox, ox + rw):
                    grid[z][x] = "."
    # Árbol de salas (DFS al azar) más algunos pasillos extra.
    start = (0, 0)
    seen, stack, edges = {start}, [start], set()
    while stack:
        i, j = stack[-1]
        options = [(i + di, j + dj) for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1))
                   if (i + di, j + dj) in rooms and (i + di, j + dj) not in seen]
        if not options:
            stack.pop()
            continue
        n = rng.choice(options)
        edges.add(tuple(sorted([(i, j), n])))
        seen.add(n)
        stack.append(n)
    all_edges = [tuple(sorted([(i, j), (i + di, j + dj)])) for (i, j) in rooms
                 for di, dj in ((1, 0), (0, 1)) if (i + di, j + dj) in rooms]
    spare = [e for e in all_edges if e not in edges]
    rng.shuffle(spare)
    edges.update(spare[:extra])
    for a, b in sorted(edges):
        _carve_corridor(rng, grid, rooms[a], rooms[b], horizontal=a[1] == b[1])
    # Pilares sueltos dentro de las salas grandes (sin cortar el paso).
    for ox, oz, rw, rh in rooms.values():
        if rw < 5 or rh < 4:
            continue
        for _ in range(rng.randint(1, 2)):
            x = rng.randint(ox + 1, ox + rw - 2)
            z = rng.randint(oz + 1, oz + rh - 2)
            if grid[z][x] != ".":
                continue
            grid[z][x] = "#"
            if not _connected(grid):
                grid[z][x] = "."
    return ["".join(r) for r in grid], rooms


def _carve_corridor(rng, grid, a, b, horizontal):
    ax, az, aw, ah = a
    bx, bz, bw, bh = b
    if horizontal:
        sx, ex = ax + aw, bx - 1
        za = rng.randint(az, az + ah - 1)
        zb = rng.randint(bz, bz + bh - 1)
        xm = rng.randint(sx + 1, ex - 1) if ex - sx >= 2 else sx
        if za == zb:
            for x in range(sx, ex + 1):
                grid[za][x] = "."
            return
        for x in range(sx, xm + 1):
            grid[za][x] = "."
        for z in range(min(za, zb), max(za, zb) + 1):
            grid[z][xm] = "."
        for x in range(xm, ex + 1):
            grid[zb][x] = "."
    else:
        sz, ez = az + ah, bz - 1
        xa = rng.randint(ax, ax + aw - 1)
        xb = rng.randint(bx, bx + bw - 1)
        zm = rng.randint(sz + 1, ez - 1) if ez - sz >= 2 else sz
        if xa == xb:
            for z in range(sz, ez + 1):
                grid[z][xa] = "."
            return
        for z in range(sz, zm + 1):
            grid[z][xa] = "."
        for x in range(min(xa, xb), max(xa, xb) + 1):
            grid[zm][x] = "."
        for z in range(zm, ez + 1):
            grid[z][xb] = "."


def _connected(grid):
    free = {(x, z) for z, row in enumerate(grid) for x, c in enumerate(row) if c != "#"}
    if not free:
        return True
    first = next(iter(free))
    return len(reach(free, first)) == len(free)


# --- Utilidades de grafo -------------------------------------------------------

def free_cells(rows):
    return {(x, z) for z, row in enumerate(rows) for x, c in enumerate(row) if c == "."}


def reach(free, origin, blocked=()):
    blocked = set(blocked)
    if origin in blocked:
        return set()
    seen, queue = {origin}, deque([origin])
    while queue:
        x, z = queue.popleft()
        for dx, dz in DIRS:
            n = (x + dx, z + dz)
            if n in free and n not in seen and n not in blocked:
                seen.add(n)
                queue.append(n)
    return seen


def distances(free, origin, blocked=()):
    blocked = set(blocked)
    dist, queue = {origin: 0}, deque([origin])
    while queue:
        x, z = queue.popleft()
        for dx, dz in DIRS:
            n = (x + dx, z + dz)
            if n in free and n not in dist and n not in blocked:
                dist[n] = dist[(x, z)] + 1
                queue.append(n)
    return dist


def shortest_path(free, a, b):
    prev, queue = {a: None}, deque([a])
    while queue:
        c = queue.popleft()
        if c == b:
            break
        for dx, dz in DIRS:
            n = (c[0] + dx, c[1] + dz)
            if n in free and n not in prev:
                prev[n] = c
                queue.append(n)
    if b not in prev:
        return []
    path, c = [], b
    while c is not None:
        path.append(c)
        c = prev[c]
    return path[::-1]


def straight(free, cell):
    """Pasillo recto: pared a ambos lados y libre delante y detrás."""
    x, z = cell
    horiz = (x - 1, z) in free and (x + 1, z) in free and (x, z - 1) not in free and (x, z + 1) not in free
    vert = (x, z - 1) in free and (x, z + 1) in free and (x - 1, z) not in free and (x + 1, z) not in free
    return horiz or vert


# --- Colocación ---------------------------------------------------------------

def build(spec, seed):
    rng = random.Random(seed)
    rooms = {}
    if spec["kind"] == "rooms":
        nx, ny = spec["rooms"]
        rows, rooms = rooms_layout(rng, nx, ny, *spec["slot"], spec["gap"], spec["extra"])
    else:
        w, h = spec["size"]
        rows = ls.generate(w, h, seed, spec["braid"], rooms=2)
    grid = [list(r) for r in rows]
    free = free_cells(rows)

    # Salida y meta: la salida en una esquina de arriba a la izquierda y la
    # meta en la casilla más lejana.
    corner = min(free, key=lambda c: c[0] + c[1] + rng.random() * 3)
    start = corner
    dist = distances(free, start)
    far = sorted(dist, key=dist.get)[-max(3, len(dist) // 25):]
    goal = rng.choice(far)
    path = shortest_path(free, start, goal)
    if not path:
        raise Fail("sin camino")

    # Cortes: casillas de pasillo recto del camino que lo cortan.
    cuts = []
    for i, c in enumerate(path[3:-3], start=3):
        if straight(free, c) and goal not in reach(free, start, {c}):
            cuts.append((i, c))
    items = list(spec["items"])
    if len(cuts) < len(items):
        raise Fail("pocos cortes")
    # Repartidos a lo largo del camino.
    chosen = []
    span = len(cuts) / len(items)
    for k in range(len(items)):
        lo, hi = int(k * span), max(int(k * span) + 1, int((k + 1) * span))
        options = [cuts[j] for j in range(lo, min(hi, len(cuts)))
                   if all(abs(cuts[j][0] - c[0]) > 3 for c in chosen)]
        if not options:
            raise Fail("cortes muy juntos")
        chosen.append(rng.choice(options))
    chosen.sort()
    cut_cells = [c for _, c in chosen]

    taken = {start, goal}
    used_colors, used_groups = [], []
    buttons = {}
    prev_region = set()
    for k, (kind, cell) in enumerate(zip(items, cut_cells)):
        region = reach(free, start, {cell})
        new_area = region - prev_region if prev_region else region
        if kind == "door":
            color = KEY_COLORS[len(used_colors)]
            used_colors.append(color)
            key = _pick_far_cell(rng, free, new_area - taken - set(cut_cells), path)
            if key is None:
                raise Fail("sin sitio para la llave")
            grid[cell[1]][cell[0]] = color.upper()
            grid[key[1]][key[0]] = color
            taken.update({cell, key})
        elif kind == "bars":
            group = BAR_GROUPS[len(used_groups)]
            symbol = BUTTONS[len(used_groups)]
            used_groups.append(group)
            button = _pick_button(rng, grid, free, region, cell, taken)
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

    # Power ups de velocidad en tramos rectos del camino.
    straight_path = [c for c in path[4:-4] if straight(free, c) and c not in taken]
    rng.shuffle(straight_path)
    for c in straight_path[:spec["speed"]]:
        grid[c[1]][c[0]] = "s"
        taken.add(c)

    patrols = _place_patrols(rng, grid, free, rooms, spec["patrols"], start, goal, taken, path)
    dist = distances(free, start)
    deep = [c for c in free if dist.get(c, 0) >= 12 and c not in taken and grid[c[1]][c[0]] == "."]
    rng.shuffle(deep)
    for _ in range(spec["chasers"]):
        if not deep:
            raise Fail("sin sitio para perseguidores")
        c = deep.pop()
        grid[c[1]][c[0]] = "x"
        taken.add(c)
    for _ in range(spec["blockers"]):
        options = [c for c in deep if not straight(free, c) and c not in taken
                   and grid[c[1]][c[0]] == "." and dist.get(c, 0) >= 10]
        if not options:
            raise Fail("sin sitio para el obstáculo")
        c = rng.choice(options)
        grid[c[1]][c[0]] = "z"
        taken.add(c)

    grid[start[1]][start[0]] = "A"
    grid[goal[1]][goal[0]] = "B"
    layout = ["".join(r) for r in grid]
    heading = next(h for h in DIRS if (start[0] + h[0], start[1] + h[1]) in free
                   and layout[start[1] + h[1]][start[0] + h[0]] not in "#pqtvw")
    problems = ls.check_buttons(layout, buttons) + ls.check_enemies(layout, patrols)
    if problems:
        raise Fail("; ".join(problems))
    result = ls.solve(layout, heading, buttons=buttons)
    if result is None:
        raise Fail("sin solución")
    return dict(layout=layout, heading=heading, buttons=buttons, patrols=patrols,
                turns=result[0], steps=result[1])


def _pick_far_cell(rng, free, area, path):
    """Casilla del área lejos del camino (a ser posible en un fondo de saco)."""
    if not area:
        return None
    on_path = set(path)
    dist = {}
    queue = deque()
    for c in on_path:
        dist[c] = 0
        queue.append(c)
    while queue:
        x, z = queue.popleft()
        for dx, dz in DIRS:
            n = (x + dx, z + dz)
            if n in free and n not in dist:
                dist[n] = dist[(x, z)] + 1
                queue.append(n)
    ranked = sorted(area, key=lambda c: dist.get(c, 0), reverse=True)
    top = ranked[:max(1, len(ranked) // 4)]
    return rng.choice(top)


def _pick_button(rng, grid, free, region, bars, taken):
    """Muro con una sola casilla libre al lado, cerca de los barrotes y del
    lado de la salida, al que el cubo puede llegar de frente."""
    near = distances(free & region, next(n for n in
                                         ((bars[0] + dx, bars[1] + dz) for dx, dz in DIRS)
                                         if n in region))
    options = []
    height, width = len(grid), len(grid[0])
    for front, d in near.items():
        if d > BUTTON_REACH or front in taken:
            continue
        for dx, dz in DIRS:
            w = (front[0] + dx, front[1] + dz)
            back = (front[0] - dx, front[1] - dz)
            if not (0 <= w[0] < width and 0 <= w[1] < height) or grid[w[1]][w[0]] != "#":
                continue
            if back not in free or back in taken:
                continue
            frees = [(w[0] + ex, w[1] + ez) for ex, ez in DIRS if (w[0] + ex, w[1] + ez) in free]
            if len(frees) != 1:
                continue
            options.append(w)
    if not options:
        return None
    return rng.choice(options)


def _place_patrols(rng, grid, free, rooms, count, start, goal, taken, path):
    patrols = {}
    candidates = []
    # Vueltas alrededor de salas sin la salida ni la meta.
    for ox, oz, rw, rh in rooms.values():
        ring = ([(x, oz) for x in range(ox, ox + rw)] + [(ox + rw - 1, z) for z in range(oz, oz + rh)]
                + [(x, oz + rh - 1) for x in range(ox, ox + rw)] + [(ox, z) for z in range(oz, oz + rh)])
        if all(c in free and c not in taken and grid[c[1]][c[0]] == "." for c in ring):
            candidates.append(((ox, oz), f"R{rw - 1} D{rh - 1} L{rw - 1} U{rh - 1}"))
    # Tramos rectos de pasillo (ida y vuelta).
    for z, row in enumerate(grid):
        for x in range(len(row)):
            for (dx, dz), letter in (((1, 0), "R"), ((0, 1), "D")):
                run = 0
                while (x + dx * (run + 1), z + dz * (run + 1)) in free and run < 7:
                    run += 1
                cells = [(x + dx * i, z + dz * i) for i in range(run + 1)]
                if run >= 4 and all(c not in taken and grid[c[1]][c[0]] == "." for c in cells) \
                        and (x - dx, z - dz) not in free:
                    candidates.append(((x, z), f"{letter}{run}"))
    rng.shuffle(candidates)
    near_start = distances(free, start)
    used = set()
    for origin, route in candidates:
        if len(patrols) >= count:
            break
        cells = _route_cells(origin, route)
        if used & set(cells) or any(near_start.get(c, 99) < 6 for c in cells):
            continue
        symbol = PATROLS[len(patrols)]
        patrols[symbol] = route
        grid[origin[1]][origin[0]] = symbol
        used.update(cells)
        # Una casilla de margen alrededor para que no se pisen entre ellos.
        for c in cells:
            for dx, dz in DIRS:
                used.add((c[0] + dx, c[1] + dz))
        taken.update(cells)
    if len(patrols) < count:
        raise Fail("sin sitio para patrulleros")
    return patrols


def _route_cells(origin, route):
    cells = [origin]
    c = origin
    for part in route.split():
        d = ls.ROUTE_DIRS[part[0]]
        for _ in range(int(part[1:])):
            c = (c[0] + d[0], c[1] + d[1])
            cells.append(c)
    return cells


# --- Salida -------------------------------------------------------------------

def to_gdscript(spec, level):
    lines = ["\t{", f'\t\t"name": "{spec["name"]}",', f'\t\t"turns": {level["turns"]},',
             f'\t\t"start_heading": Vector2i({level["heading"][0]}, {level["heading"][1]}),',
             '\t\t"layout": [']
    lines += [f'\t\t\t"{row}",' for row in level["layout"]]
    lines.append("\t\t],")
    if level["buttons"]:
        inner = ", ".join(f'"{k}": "{v}"' for k, v in sorted(level["buttons"].items()))
        lines.append(f'\t\t"buttons": {{{inner}}},')
    if level["patrols"]:
        inner = ", ".join(f'"{k}": "{v}"' for k, v in sorted(level["patrols"].items()))
        lines.append(f'\t\t"patrols": {{{inner}}},')
    lines.append("\t},")
    return "\n".join(lines)


def main():
    first = int(sys.argv[1]) if len(sys.argv) > 1 else min(SPECS)
    last = int(sys.argv[2]) if len(sys.argv) > 2 else max(SPECS)
    attempts = int(sys.argv[3]) if len(sys.argv) > 3 else 400
    max_valid = int(sys.argv[4]) if len(sys.argv) > 4 else 40
    for number in range(first, last + 1):
        spec = SPECS[number]
        best = None
        tried = valid = 0
        t0 = time.time()
        seed = number * 1000
        while valid < max_valid and tried < attempts:
            seed += 1
            tried += 1
            try:
                level = build(spec, seed)
            except Fail:
                continue
            valid += 1
            if best is None or abs(level["turns"] - spec["turns"]) < abs(best["turns"] - spec["turns"]):
                best = level
        size = f'{len(best["layout"][0])}x{len(best["layout"])}' if best else "-"
        print(f"# Nivel {number}: {spec['name']}  {size}  giros={best and best['turns']} "
              f"(objetivo {spec['turns']})  válidos={valid}/{tried}  {time.time() - t0:.0f}s",
              file=sys.stderr)
        if best:
            print(to_gdscript(spec, best))
        sys.stdout.flush()


if __name__ == "__main__":
    main()
