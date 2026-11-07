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


def turn_left(h):
    return (h[1], -h[0])


def turn_right(h):
    return (-h[1], h[0])


def parse(layout):
    """Devuelve (casillas_libres, inicio, meta) de un mapa de texto."""
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


def step(free, cell, heading, turn):
    """Aplica una decisión (0, -1 izquierda, 1 derecha) y avanza una casilla."""
    if turn:
        candidate = turn_left(heading) if turn < 0 else turn_right(heading)
        if (cell[0] + candidate[0], cell[1] + candidate[1]) in free:
            heading = candidate
    nxt = (cell[0] + heading[0], cell[1] + heading[1])
    if nxt not in free:
        heading = (-heading[0], -heading[1])
        nxt = (cell[0] + heading[0], cell[1] + heading[1])
        if nxt not in free:
            return cell, heading
    return nxt, heading


def solve(layout, start_heading):
    """Devuelve (giros_minimos, pasos, decisiones) o None si no tiene solución.

    decisiones es una lista de (casilla, giro) del recorrido óptimo.
    """
    free, start, goal = parse(layout)
    if start is None or goal is None:
        raise ValueError("El nivel necesita una casilla A y una casilla B")
    best = {(start, start_heading): (0, 0)}
    prev = {}
    queue = deque([(0, 0, start, start_heading)])
    while queue:
        turns, steps, cell, heading = queue.popleft()
        if best.get((cell, heading)) != (turns, steps):
            continue
        if cell == goal:
            path, key = [], (cell, heading)
            while key in prev:
                key, turn, at = prev[key]
                path.append((at, turn))
            return turns, steps, path[::-1]
        options = (0,) if steps == 0 else (0, -1, 1)
        for turn in options:
            ncell, nheading = step(free, cell, heading, turn)
            cost = (turns + (1 if turn else 0), steps + 1)
            key = (ncell, nheading)
            if key not in best or cost < best[key]:
                best[key] = cost
                prev[key] = ((cell, heading), turn, cell)
                if turn:
                    queue.append((cost[0], cost[1], ncell, nheading))
                else:
                    queue.appendleft((cost[0], cost[1], ncell, nheading))
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
        rows = re.findall(r'"([#.AB]+)"', body)
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
