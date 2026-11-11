#!/usr/bin/env python3
"""Coloca en cada nivel la tienda, los cofres y las casillas de inicio extra.
Escribe en scripts/levels.gd, en cada nivel (tras "star_turns"):

    "shop": Vector2i(x, z),          # muro de la tienda (solo cada SHOP_EVERY niveles)
    "shop_front": Vector2i(x, z),    # casilla libre desde la que se entra
    "chests": [Vector2i(x, z), ...], # cofres (obstáculos que se abren con dash o pisotón)
    "checkpoints": [Vector2i(x, z), ...],  # casillas de inicio extra (mapas grandes)

Todo se calcula con las reglas reales del cubo (los estados alcanzables del
resolvedor de level_solver.py, desde la salida y sin pasar por la meta):

- Tienda (niveles SHOP_EVERY, 2·SHOP_EVERY...): un muro '#' contra el que el
  cubo puede chocar de frente desde una casilla '.' alcanzable (llegando a
  ella con ese rumbo; los giros hacia un muro se descartan, así que no basta
  con poder pisarla). Mejor al fondo de un callejón y a SHOP_MIN_STEPS
  pasos o más de la salida. La zona de entrada (la casilla de delante y las
  que están a SHOP_GUARD_STEPS pasos o menos) es protegida: los enemigos no
  la pisan (ver Level.enemy_can_pass), así que no puede tocar la ruta de un
  patrullero ni un punto de origen de enemigos.
- Casillas de inicio (CHECKPOINT_EVERY casillas pisables o más): en el
  recorrido óptimo, repartidas a partes iguales entre la salida y la meta, en
  casillas '.' que no están junto a un teletransporte, ni en la ruta de un
  patrullero ni cerca de un punto de origen de enemigos. Mejor con tres o
  más casillas libres al lado (los enemigos no las pisan y así no cortan un
  pasillo).
- Cofres (CHEST_MIN_CELLS casillas pisables o más; uno más cada
  CHEST_EVERY, hasta CHEST_MAX): en casillas '.' alcanzables fuera del
  recorrido óptimo, mejor en fondos de saco, a las que el cubo puede llegar
  de frente (para el dash) y repartidos por el mapa. Son obstáculos como un
  muro: se comprueba que con ellos el nivel sigue necesitando los mismos
  giros (también cogiendo el cubito dorado).

Es determinista. Ejecutarlo tras place_collectibles.py (los cofres no deben
caer en el cubito) y después "level_solver.py validate".

Uso (desde la raíz del repositorio): python3 tools/place_extras.py [primer_nivel último_nivel]
"""
import re
import sys
from collections import deque

from level_solver import (DIRS, ENEMY_CHARS, LEVELS_GD, PATROL_CHARS, TELEPORT_CHARS, BRIDGE_CHAR,
                          SPIKE_CHAR, Board, read_levels, route_cells, solve, step)

SHOP_EVERY = 10
SHOP_MIN_STEPS = 6
SHOP_GUARD_STEPS = 2
CHECKPOINT_EVERY = 300
CHECKPOINT_MAX = 3
CHEST_MIN_CELLS = 40
CHEST_EVERY = 250
CHEST_MAX = 4
# Distancia (pasos) mínima de los cofres y casillas de inicio a la salida, la
# meta y los puntos de origen de enemigos.
KEEP_AWAY = 2
# Tope de estados del resolvedor al explorar lo alcanzable.
STATE_CAP = 4_000_000


def walkable(rows, cell):
    x, z = cell
    if z < 0 or z >= len(rows) or x < 0 or x >= len(rows[z]):
        return False
    return rows[z][x] not in "#~MLpqtvwz"


def at(rows, cell):
    x, z = cell
    if z < 0 or z >= len(rows) or x < 0 or x >= len(rows[z]):
        return "~"
    return rows[z][x]


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def exits(rows, cell):
    return sum(walkable(rows, add(cell, d)) for d in DIRS)


def distances(rows, sources, limit=None):
    dist = {c: 0 for c in sources}
    queue = deque(sources)
    while queue:
        c = queue.popleft()
        if limit is not None and dist[c] >= limit:
            continue
        for d in DIRS:
            n = add(c, d)
            if n not in dist and walkable(rows, n):
                dist[n] = dist[c] + 1
                queue.append(n)
    return dist


def reachable(level):
    """(casilla, rumbo de llegada) de todos los estados alcanzables desde la
    salida sin pasar por la meta."""
    board = Board(level["layout"], level["buttons"])
    start = (board.start, level["heading"], None, 0, 0, board.initial_hits, 0, board.initial_wear)
    seen = {start}
    queue = deque([(start, True)])
    pairs = set()
    while queue:
        state, first = queue.popleft()
        pairs.add((state[0], state[1]))
        if state[0] == board.goal:
            continue
        options = (0,) if first or state[0] in board.teleport_at else (0, -1, 1)
        for turn in options:
            nxt = step(board, state, turn)
            if nxt is None or nxt in seen:
                continue
            seen.add(nxt)
            queue.append((nxt, False))
            if len(seen) > STATE_CAP:
                print(f"  aviso: se ha llegado al tope de {STATE_CAP} estados", flush=True)
                return pairs
    return pairs


def enemy_cells(level):
    """(casillas de rutas de patrulla, casillas de puntos de origen)."""
    rows = level["layout"]
    routes, origins = set(), set()
    for z, row in enumerate(rows):
        for x, c in enumerate(row):
            if c in ENEMY_CHARS:
                origins.add((x, z))
            if c in PATROL_CHARS and c in level["patrols"]:
                routes |= set(route_cells((x, z), level["patrols"][c]))
    return routes, origins


def with_walls(rows, cells):
    out = [list(r) for r in rows]
    for x, z in cells:
        out[z][x] = "#"
    return ["".join(r) for r in out]


def place_shop(level, pairs, from_start, routes, origins):
    rows = level["layout"]
    best = None
    for (front, heading) in pairs:
        wall = add(front, heading)
        if at(rows, front) != "." or at(rows, wall) != "#" or front == level["collectible"]:
            continue
        guard = distances(rows, [front], SHOP_GUARD_STEPS)
        if any(c in routes or c in origins or at(rows, c) in TELEPORT_CHARS for c in guard):
            continue
        if any(at(rows, c) in "AB" for c in guard):
            continue
        steps = from_start.get(front, 9999)
        score = (exits(rows, front) != 1, steps < SHOP_MIN_STEPS, steps, wall, front)
        if best is None or score < best[0]:
            best = (score, wall, front, set(guard))
    if best is None:
        raise SystemExit(f"«{level['name']}»: no hay sitio para la tienda")
    return best[1], best[2], best[3]


def place_checkpoints(level, path_cells, routes, origins, blocked):
    rows = level["layout"]
    walk = sum(walkable(rows, (x, z)) for z, row in enumerate(rows) for x in range(len(row)))
    count = min(CHECKPOINT_MAX, walk // CHECKPOINT_EVERY)
    if count == 0:
        return []
    near_origin = distances(rows, list(origins), KEEP_AWAY) if origins else {}
    board = Board(rows)
    ends = distances(rows, [board.start, board.goal], KEEP_AWAY + 1)

    def ok(c):
        if at(rows, c) != "." or c in routes or c in near_origin or c in ends or c in blocked:
            return False
        if c == level["collectible"]:
            return False
        return not any(at(rows, add(c, d)) in TELEPORT_CHARS + BRIDGE_CHAR + SPIKE_CHAR for d in DIRS)

    chosen = []
    window = len(path_cells) // (2 * (count + 1))
    for k in range(1, count + 1):
        target = len(path_cells) * k // (count + 1)
        best = None
        for i in range(max(0, target - window), min(len(path_cells), target + window + 1)):
            c = path_cells[i]
            if not ok(c) or c in chosen:
                continue
            score = (exits(rows, c) < 3, abs(i - target))
            if best is None or score < best[0]:
                best = (score, c)
        if best:
            chosen.append(best[1])
    return chosen


def chest_count(rows):
    walk = sum(walkable(rows, (x, z)) for z, row in enumerate(rows) for x in range(len(row)))
    if walk < CHEST_MIN_CELLS:
        return 0
    return min(CHEST_MAX, 1 + walk // CHEST_EVERY)


def place_chests(level, pairs, path_cells, routes, origins, blocked, turns, star_base):
    rows = level["layout"]
    count = chest_count(rows)
    if count == 0:
        return []
    reach = {c for c, _ in pairs}
    # Casillas a las que el cubo llega de frente (para abrir con el dash).
    facing = {add(c, h) for c, h in pairs}
    board = Board(rows)
    near = distances(rows, [board.start, board.goal] + list(origins), KEEP_AWAY)
    on_path = set(path_cells)
    candidates = []
    for z, row in enumerate(rows):
        for x, ch in enumerate(row):
            c = (x, z)
            if ch != "." or c not in reach or c not in facing or c in on_path or c in routes \
                    or c in near or c in blocked or c == level["collectible"]:
                continue
            if any(at(rows, add(c, d)) in TELEPORT_CHARS for d in DIRS):
                continue
            e = exits(rows, c)
            if e == 1:
                candidates.append((0, c))
            elif e >= 3:
                candidates.append((1, c))
    if not candidates:
        return []
    from_start = distances(rows, [board.start])
    chosen = []
    pool = sorted(candidates)
    while len(chosen) < count and pool:
        # El más alejado de la salida y de los cofres ya puestos (los fondos de
        # saco primero).
        best = None
        for kind, c in pool:
            spread = min([abs(c[0] - o[0]) + abs(c[1] - o[1]) for o in chosen] + [from_start.get(c, 0)])
            score = (kind, -min(spread, 40), c)
            if best is None or score < best[0]:
                best = (score, c)
        c = best[1]
        pool = [p for p in pool if p[1] != c]
        trial = with_walls(rows, chosen + [c])
        result = solve(trial, level["heading"], buttons=level["buttons"])
        if result is None or result[0] != turns:
            continue
        if level["collectible"] is not None:
            result = solve(trial, level["heading"], buttons=level["buttons"], collectible=level["collectible"])
            if result is None or result[0] != star_base:
                continue
        chosen.append(c)
    return chosen


def place(index, level):
    rows = level["layout"]
    base = solve(rows, level["heading"], buttons=level["buttons"])
    if base is None:
        raise SystemExit(f"«{level['name']}» no tiene solución")
    turns, _, path = base
    star_base = None
    if level["collectible"] is not None:
        star_base = solve(rows, level["heading"], buttons=level["buttons"],
                          collectible=level["collectible"])[0]
    board = Board(rows)
    path_cells = [c for c, _ in path] + [board.goal]
    pairs = reachable(level)
    routes, origins = enemy_cells(level)
    from_start = distances(rows, [board.start])
    out = {}
    blocked = set()
    if (index + 1) % SHOP_EVERY == 0:
        wall, front, guard = place_shop(level, pairs, from_start, routes, origins)
        out["shop"] = (wall, front)
        blocked |= guard
    checkpoints = place_checkpoints(level, path_cells, routes, origins, blocked)
    out["checkpoints"] = checkpoints
    for c in checkpoints:
        blocked |= set(distances(rows, [c], 1))
    out["chests"] = place_chests(level, pairs, path_cells, routes, origins, blocked, turns, star_base)
    return out


def vec(cell):
    return f"Vector2i({cell[0]}, {cell[1]})"


def write(placements):
    source = LEVELS_GD.read_text(encoding="utf-8")
    source = re.sub(r'^\t\t"(shop|shop_front|chests|checkpoints)": .*\n', "", source, flags=re.M)
    pattern = re.compile(r'(\t\t"star_turns": \d+,\n)')
    parts = pattern.split(source)
    out, index = [], 0
    for part in parts:
        out.append(part)
        if pattern.fullmatch(part):
            extra = placements.get(index, {})
            if "shop" in extra:
                wall, front = extra["shop"]
                out.append(f'\t\t"shop": {vec(wall)},\n\t\t"shop_front": {vec(front)},\n')
            if extra.get("chests"):
                out.append(f'\t\t"chests": [{", ".join(vec(c) for c in extra["chests"])}],\n')
            if extra.get("checkpoints"):
                out.append(f'\t\t"checkpoints": [{", ".join(vec(c) for c in extra["checkpoints"])}],\n')
            index += 1
    LEVELS_GD.write_text("".join(out), encoding="utf-8")


def main():
    levels = read_levels()
    first, last = 1, len(levels)
    if len(sys.argv) == 3:
        first, last = int(sys.argv[1]), int(sys.argv[2])
    placements = {}
    for i, level in enumerate(levels):
        if first <= i + 1 <= last:
            extra = place(i, level)
            placements[i] = extra
            shop = f"  tienda {extra['shop'][0]}" if "shop" in extra else ""
            print(f"{i + 1:3} {level['name']:<24} cofres {len(extra['chests'])}  "
                  f"inicios {len(extra['checkpoints'])}{shop}", flush=True)
        else:
            placements[i] = existing(level)
    write(placements)


def existing(level):
    """Valores ya escritos (para no perderlos al recalcular solo unos niveles)."""
    out = {"chests": level.get("chests", []), "checkpoints": level.get("checkpoints", [])}
    if level.get("shop"):
        out["shop"] = level["shop"]
    return out


if __name__ == "__main__":
    main()
