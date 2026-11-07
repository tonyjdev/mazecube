#!/usr/bin/env python3
"""Resolvedor, validador y generador de niveles de Maze Cube.

Simula las reglas de scripts/rolling_cube.gd:
- El cubo avanza solo; en cada casilla (antes de cada vuelco) el jugador puede
  pedir: nada, girar a la izquierda o girar a la derecha (relativo al rumbo).
- El giro solo se aplica si la casilla en esa dirección está libre; si no, se
  descarta y el cubo sigue recto.
- Si la casilla de delante está bloqueada, el rumbo se invierte (rebote).
  Si tras invertir sigue bloqueada, el cubo se queda en su casilla.
- En la casilla de salida no se puede girar (no hay tiempo de reacción).
- Llaves y puertas (minúscula = llave, mayúscula = su puerta, del mismo color):
  y/Y amarillo, o/O naranja, r/R rojo, u/U azul, g/G verde.
  * Al llegar a la casilla de una llave el cubo la coge, salvo que ya lleve
    una (solo puede llevar una; si ya lleva otra, la llave se queda en el mapa).
  * Una puerta cerrada se comporta como una pared: el cubo rebota y los giros
    hacia ella se descartan, aunque lleve su llave.
  * Si el cubo choca de frente con una puerta llevando su llave, la puerta y
    la llave desaparecen y el cubo rebota igualmente.
- Power ups (s = velocidad): no cambian qué decisiones hay que tomar, solo
  el ritmo del cubo, así que para el resolvedor son casillas libres.
- Al llegar a la meta B termina el nivel.

La dificultad de un nivel es el mínimo de giros necesarios (búsqueda 0-1 BFS),
y como desempate el número de pasos del recorrido óptimo.

Uso (desde la raíz del repositorio):
  python3 tools/level_solver.py validate
      Resuelve todos los niveles de scripts/levels.gd y comprueba que el campo
      "turns" coincide con el mínimo real de giros.

  python3 tools/level_solver.py solve 0,1 "#####" "#A..#" "###B#" "#####"
      Resuelve un nivel. El primer argumento es el rumbo inicial x,z
      (1,0 derecha; -1,0 izquierda; 0,1 abajo; 0,-1 arriba) y el resto las filas.

  python3 tools/level_solver.py generate 9 11 6 [--braid 0.08] [--rooms 0] [--seeds 400]
      Busca un laberinto de 9x11 (dimensiones impares) que exija exactamente
      6 giros e imprime el mejor candidato listo para copiar en levels.gd.
      --braid abre bucles (fracción de paredes interiores eliminadas) y
      --rooms añade salas abiertas de 3x3.
"""
import argparse
import random
import re
import sys
from collections import deque
from pathlib import Path

LEVELS_GD = Path(__file__).resolve().parent.parent / "scripts" / "levels.gd"

# Direcciones en casillas (x, z). En pantalla "arriba" es -z.
DIRS = [(0, -1), (1, 0), (0, 1), (-1, 0)]
KEY_CHARS = "yorug"
DOOR_CHARS = KEY_CHARS.upper()
POWERUP_CHARS = "s"
LEVEL_CHARS = "#.AB" + KEY_CHARS + DOOR_CHARS + POWERUP_CHARS


def turn_left(h):
    return (h[1], -h[0])


def turn_right(h):
    return (-h[1], h[0])


def parse(layout):
    """Devuelve (casillas_libres, inicio, meta) de un mapa de texto.

    Las casillas con llave o puerta cuentan como libres; para el detalle de
    llaves y puertas se usa parse_items().
    """
    free, start, goal = set(), None, None
    for z, row in enumerate(layout):
        for x, c in enumerate(row):
            if c != "#":
                free.add((x, z))
            if c == "A":
                start = (x, z)
            elif c == "B":
                goal = (x, z)
    return free, start, goal


def parse_items(layout):
    """Devuelve (llaves, puertas): listas de (casilla, color) en orden de lectura."""
    keys, doors = [], []
    for z, row in enumerate(layout):
        for x, c in enumerate(row):
            if c in KEY_CHARS:
                keys.append(((x, z), c))
            elif c in DOOR_CHARS:
                doors.append(((x, z), c.lower()))
    return keys, doors


class Board:
    """Mapa preparado para simular: casillas libres, llaves y puertas."""

    def __init__(self, layout):
        self.free, self.start, self.goal = parse(layout)
        keys, doors = parse_items(layout)
        self.key_at = {cell: (i, color) for i, (cell, color) in enumerate(keys)}
        self.door_at = {cell: (i, color) for i, (cell, color) in enumerate(doors)}

    def passable(self, cell, opened):
        """Casilla libre y sin puerta cerrada."""
        if cell not in self.free:
            return False
        door = self.door_at.get(cell)
        return door is None or bool(opened >> door[0] & 1)


def step(board, state, turn):
    """Aplica una decisión (0, -1 izquierda, 1 derecha) y avanza una casilla.

    state = (casilla, rumbo, llave_llevada o None, puertas_abiertas, llaves_cogidas)
    (los dos últimos son máscaras de bits).
    """
    cell, heading, held, opened, taken = state
    if turn:
        candidate = turn_left(heading) if turn < 0 else turn_right(heading)
        if board.passable((cell[0] + candidate[0], cell[1] + candidate[1]), opened):
            heading = candidate
    nxt = (cell[0] + heading[0], cell[1] + heading[1])
    if not board.passable(nxt, opened):
        door = board.door_at.get(nxt)
        if door is not None and held == door[1]:
            opened |= 1 << door[0]
            held = None
        heading = (-heading[0], -heading[1])
        nxt = (cell[0] + heading[0], cell[1] + heading[1])
        if not board.passable(nxt, opened):
            return cell, heading, held, opened, taken
    key = board.key_at.get(nxt)
    if key is not None and held is None and not taken >> key[0] & 1:
        held = key[1]
        taken |= 1 << key[0]
    return nxt, heading, held, opened, taken


def solve(layout, start_heading, doors_as_walls=False):
    """Devuelve (giros_minimos, pasos, decisiones) o None si no tiene solución.

    decisiones es una lista de (casilla, giro) del recorrido óptimo.
    Con doors_as_walls=True las puertas no se pueden abrir (sirve para
    comprobar que una puerta es imprescindible).
    """
    board = Board(layout)
    if board.start is None or board.goal is None:
        raise ValueError("El nivel necesita una casilla A y una casilla B")
    if doors_as_walls:
        board.key_at = {}
    start = (board.start, start_heading, None, 0, 0)
    best = {start: (0, 0)}
    prev = {}
    queue = deque([(0, 0, start)])
    while queue:
        turns, steps, state = queue.popleft()
        if best.get(state) != (turns, steps):
            continue
        if state[0] == board.goal:
            path, key = [], state
            while key in prev:
                key, turn = prev[key]
                path.append((key[0], turn))
            return turns, steps, path[::-1]
        options = (0,) if steps == 0 else (0, -1, 1)
        for turn in options:
            nstate = step(board, state, turn)
            cost = (turns + (1 if turn else 0), steps + 1)
            if nstate not in best or cost < best[nstate]:
                best[nstate] = cost
                prev[nstate] = (state, turn)
                if turn:
                    queue.append((cost[0], cost[1], nstate))
                else:
                    queue.appendleft((cost[0], cost[1], nstate))
    return None


def generate(width, height, seed, braid=0.0, rooms=0):
    """Laberinto perfecto (DFS) con bucles opcionales y salas abiertas."""
    rng = random.Random(seed)
    grid = [["#"] * width for _ in range(height)]
    cells = {(x, z) for z in range(1, height - 1, 2) for x in range(1, width - 1, 2)}
    first = rng.choice(sorted(cells))
    stack, seen = [first], {first}
    grid[first[1]][first[0]] = "."
    while stack:
        x, z = stack[-1]
        options = [(dx, dz) for dx, dz in DIRS
                   if (x + 2 * dx, z + 2 * dz) in cells and (x + 2 * dx, z + 2 * dz) not in seen]
        if not options:
            stack.pop()
            continue
        dx, dz = rng.choice(options)
        grid[z + dz][x + dx] = "."
        grid[z + 2 * dz][x + 2 * dx] = "."
        seen.add((x + 2 * dx, z + 2 * dz))
        stack.append((x + 2 * dx, z + 2 * dz))
    walls = [(x, z) for z in range(1, height - 1) for x in range(1, width - 1)
             if grid[z][x] == "#" and (x % 2) != (z % 2)]
    rng.shuffle(walls)
    for x, z in walls[: int(len(walls) * braid)]:
        grid[z][x] = "."
    for _ in range(rooms):
        rx = rng.randrange(1, width - 4)
        rz = rng.randrange(1, height - 4)
        for z in range(rz, rz + 3):
            for x in range(rx, rx + 3):
                grid[z][x] = "."
    return ["".join(row) for row in grid]


def find_candidates(width, height, target, braid, rooms, seeds):
    """Laberintos con A en la fila superior y B abajo que exigen `target` giros.

    Ordena por número de cruces en el recorrido óptimo (más decisiones = más
    interesante) y, a igualdad, por recorrido más corto.
    """
    found = []
    for seed in range(seeds):
        base = generate(width, height, seed, braid, rooms)
        free, _, _ = parse(base)
        top = sorted(c for c in free if c[1] == 1)
        if not top:
            continue
        a = top[seed % len(top)]
        heading = next((h for h in DIRS if (a[0] + h[0], a[1] + h[1]) in free), None)
        if heading is None:
            continue
        for b in (c for c in free if c[1] >= height - 4):
            rows = [list(r) for r in base]
            rows[a[1]][a[0]] = "A"
            rows[b[1]][b[0]] = "B"
            layout = ["".join(r) for r in rows]
            result = solve(layout, heading)
            if result and result[0] == target:
                junctions = sum(
                    1 for c, _ in result[2]
                    if sum((c[0] + dx, c[1] + dz) in free for dx, dz in DIRS) >= 3)
                found.append((junctions, -result[1], seed, layout, heading, result[1]))
    found.sort(reverse=True)
    return found


def read_levels(path=LEVELS_GD):
    """Lee los niveles de scripts/levels.gd."""
    source = path.read_text(encoding="utf-8")
    pattern = re.compile(
        r'"name":\s*"([^"]+)",\s*"turns":\s*(\d+),\s*'
        r'"start_heading":\s*Vector2i\((-?\d+),\s*(-?\d+)\),\s*"layout":\s*\[(.*?)\]',
        re.S)
    levels = []
    for name, turns, hx, hz, body in pattern.findall(source):
        rows = re.findall(r'"([' + re.escape(LEVEL_CHARS) + r']+)"', body)
        levels.append({"name": name, "turns": int(turns),
                       "heading": (int(hx), int(hz)), "layout": rows})
    return levels


def cmd_validate(_args):
    levels = read_levels()
    if not levels:
        print(f"No se encontraron niveles en {LEVELS_GD}")
        return 1
    ok = True
    for i, lvl in enumerate(levels, 1):
        rows = lvl["layout"]
        problems = []
        if len({len(r) for r in rows}) != 1:
            problems.append("filas de distinta longitud")
        result = None if problems else solve(rows, lvl["heading"])
        if not problems and result is None:
            problems.append("sin solución")
        elif result and result[0] != lvl["turns"]:
            problems.append(f"declara {lvl['turns']} giros pero el mínimo es {result[0]}")
        ok &= not problems
        size = f"{len(rows[0])}x{len(rows)}"
        detail = f"giros={result[0]:>2} pasos={result[1]:>3}" if result else ""
        status = "OK" if not problems else "ERROR: " + "; ".join(problems)
        print(f"{i:2} {lvl['name']:<20} {size:>6} {detail}  {status}")
    print("Todos los niveles son correctos." if ok else "Hay niveles con errores.")
    return 0 if ok else 1


def cmd_solve(args):
    hx, hz = (int(v) for v in args.heading.split(","))
    result = solve(args.rows, (hx, hz))
    if result is None:
        print("Sin solución")
        return 1
    turns, steps, path = result
    print(f"Giros mínimos: {turns}   Pasos: {steps}")
    for cell, turn in path:
        if turn:
            print(f"  en la casilla {cell}: {'izquierda' if turn < 0 else 'derecha'}")
    return 0


def cmd_generate(args):
    if args.width % 2 == 0 or args.height % 2 == 0:
        print("El ancho y el alto deben ser impares")
        return 1
    found = find_candidates(args.width, args.height, args.turns, args.braid, args.rooms, args.seeds)
    if not found:
        print("Sin candidatos: prueba con otro número de giros, más semillas u otro tamaño")
        return 1
    junctions, _, seed, layout, heading, steps = found[0]
    print(f"# {args.width}x{args.height}  giros={args.turns}  pasos={steps}  "
          f"cruces={junctions}  semilla={seed}")
    print(f'"start_heading": Vector2i({heading[0]}, {heading[1]}),')
    print('"layout": [')
    for row in layout:
        print(f'\t"{row}",')
    print("],")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("validate", help="comprueba los niveles de scripts/levels.gd")
    p_solve = sub.add_parser("solve", help="resuelve un nivel dado por sus filas")
    p_solve.add_argument("heading", help="rumbo inicial x,z (p. ej. 1,0)")
    p_solve.add_argument("rows", nargs="+", help="filas del mapa")
    p_gen = sub.add_parser("generate", help="busca un laberinto con un número de giros dado")
    p_gen.add_argument("width", type=int)
    p_gen.add_argument("height", type=int)
    p_gen.add_argument("turns", type=int)
    p_gen.add_argument("--braid", type=float, default=0.1)
    p_gen.add_argument("--rooms", type=int, default=0)
    p_gen.add_argument("--seeds", type=int, default=400)
    args = parser.parse_args()
    handlers = {"validate": cmd_validate, "solve": cmd_solve, "generate": cmd_generate}
    return handlers[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
