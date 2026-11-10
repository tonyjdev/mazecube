#!/usr/bin/env python3
"""Coloca el coleccionable (cubito dorado) de cada nivel y calcula los giros
de la estrella de giros. Escribe en scripts/levels.gd, en cada nivel:

    "collectible": Vector2i(x, z),   # casilla del cubito dorado
    "star_turns": N,                 # giros máximos para la estrella de giros

Dónde se pone el cubito:
- En una casilla de suelo normal ('.') fuera del recorrido óptimo del nivel,
  y nunca en la ruta de un patrullero ni junto a la salida o la meta.
- Mejor en un fondo de saco (una sola casilla libre al lado) y algo apartado
  del recorrido, para que haya que desviarse a por él.
- Ir a por él debe costar unos pocos giros más que el mínimo del nivel
  (EXTRA_RATIO del mínimo, entre EXTRA_MIN y EXTRA_MAX): de los candidatos se
  elige el que más se acerca a ese coste.
- Si no hay ninguna casilla fuera del recorrido (niveles diminutos), se pone
  en el propio recorrido.

star_turns = mínimo de giros recogiendo el cubito + un margen del 25 % (al
menos 2), así que las tres estrellas siempre se pueden conseguir.

Es determinista. Ejecutarlo de nuevo tras cambiar o regenerar los niveles
(sustituye los valores anteriores) y después "level_solver.py validate".

Uso (desde la raíz del repositorio): python3 tools/place_collectibles.py [primer_nivel último_nivel]
"""
import math
import re
import sys
from collections import deque

from level_solver import (DIRS, LEVELS_GD, PATROL_CHARS, Board, read_levels, route_cells, solve)

EXTRA_RATIO = 0.12
EXTRA_MIN = 1
EXTRA_MAX = 6
# Candidatos que se prueban con el resolvedor (los mejores según la forma del mapa).
MAX_CANDIDATES = 8
STAR_MARGIN = 0.25
STAR_MARGIN_MIN = 2


def star_turns(min_turns):
    return min_turns + max(STAR_MARGIN_MIN, math.ceil(min_turns * STAR_MARGIN))


def walkable(rows, cell):
    x, z = cell
    if z < 0 or z >= len(rows) or x < 0 or x >= len(rows[z]):
        return False
    return rows[z][x] not in "#~MLpqtvwz"


def route_of(path, goal):
    return {cell for cell, _ in path} | {goal}


def distances(rows, sources):
    """Casillas a recorrer desde el conjunto `sources` (BFS por suelo)."""
    dist = {c: 0 for c in sources}
    queue = deque(sources)
    while queue:
        c = queue.popleft()
        for dx, dz in DIRS:
            n = (c[0] + dx, c[1] + dz)
            if n not in dist and walkable(rows, n):
                dist[n] = dist[c] + 1
                queue.append(n)
    return dist


def candidates(level, route):
    rows = level["layout"]
    board = Board(rows, level["buttons"])
    banned = set(route)
    for z, row in enumerate(rows):
        for x, c in enumerate(row):
            if c in PATROL_CHARS and c in level["patrols"]:
                banned |= set(route_cells((x, z), level["patrols"][c]))
    near_ends = {(board.start[0] + dx, board.start[1] + dz) for dx, dz in DIRS} | \
                {(board.goal[0] + dx, board.goal[1] + dz) for dx, dz in DIRS}
    dist = distances(rows, route)
    found = []
    for z, row in enumerate(rows):
        for x, c in enumerate(row):
            cell = (x, z)
            if c != "." or cell in banned or cell in near_ends or cell not in dist:
                continue
            exits = sum(walkable(rows, (x + dx, z + dz)) for dx, dz in DIRS)
            dead_end = exits == 1
            # Fondos de saco primero; después, los más apartados (sin pasarse).
            found.append((not dead_end, -min(dist[cell], 12), dist[cell], cell))
    found.sort()
    return [cell for *_, cell in found]


def place(level):
    rows, heading, buttons = level["layout"], level["heading"], level["buttons"]
    base = solve(rows, heading, buttons=buttons)
    if base is None:
        raise SystemExit(f"«{level['name']}» no tiene solución")
    min_turns, _, path = base
    target = max(EXTRA_MIN, min(EXTRA_MAX, round(min_turns * EXTRA_RATIO)))
    best = None
    for cell in candidates(level, route_of(path, Board(rows).goal))[:MAX_CANDIDATES]:
        result = solve(rows, heading, buttons=buttons, collectible=cell)
        if result is None:
            continue
        extra = result[0] - min_turns
        if extra < 1:
            continue
        score = abs(extra - target)
        if best is None or score < best[0]:
            best = (score, cell, result[0])
        if score == 0:
            break
    if best is None:
        # Sin casillas apartadas: en el recorrido, lejos de la salida.
        cells = [c for c, _ in path if rows[c[1]][c[0]] == "."]
        cell = cells[len(cells) * 2 // 3] if cells else path[-1][0]
        best = (0, cell, solve(rows, heading, buttons=buttons, collectible=cell)[0])
    _, cell, with_turns = best
    return cell, min_turns, with_turns


def write(placements):
    source = LEVELS_GD.read_text(encoding="utf-8")
    source = re.sub(r'^\t\t"(collectible|star_turns)": .*\n', "", source, flags=re.M)
    # Tras el "layout" de cada nivel (en orden), sus dos campos.
    pattern = re.compile(r'(\t\t"layout": \[\n(?:\t\t\t.*\n)*?\t\t\],\n)')
    parts = pattern.split(source)
    out, index = [], 0
    for part in parts:
        out.append(part)
        if pattern.fullmatch(part):
            if index in placements:
                (x, z), stars = placements[index]
                out.append(f'\t\t"collectible": Vector2i({x}, {z}),\n\t\t"star_turns": {stars},\n')
            index += 1
    LEVELS_GD.write_text("".join(out), encoding="utf-8")


def main():
    levels = read_levels()
    first, last = 1, len(levels)
    if len(sys.argv) == 3:
        first, last = int(sys.argv[1]), int(sys.argv[2])
    placements = {}
    previous = read_existing()
    for i in range(len(levels)):
        if first <= i + 1 <= last:
            cell, min_turns, with_turns = place(levels[i])
            placements[i] = (cell, star_turns(with_turns))
            print(f"{i + 1:3} {levels[i]['name']:<24} mínimo {min_turns:3}  con cubito {with_turns:3} "
                  f"(+{with_turns - min_turns})  estrella <= {star_turns(with_turns):3}  en {cell}",
                  flush=True)
        elif i in previous:
            placements[i] = previous[i]
    write(placements)


def read_existing():
    """Valores ya escritos (para no perderlos al recalcular solo unos niveles)."""
    found = {}
    for i, level in enumerate(read_levels()):
        if level.get("collectible") is not None:
            found[i] = (level["collectible"], level["star_turns"])
    return found


if __name__ == "__main__":
    main()
