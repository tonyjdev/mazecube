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
- Muros destructibles ('1'..'5' = golpes que aguantan): obstáculos como una
  pared (rebote y giros descartados). Cada choque de frente les quita un
  golpe y el cubo rebota; el choque que los rompe también rebota, pero desde
  entonces la casilla es libre.
- Botones y barrotes: los barrotes (c, d, e, f, h; minúscula = empiezan
  abiertos, mayúscula = empiezan cerrados) cierran un pasillo como una
  puerta. Los botones (p, q, t, v, w) son paredes con un botón en la cara que
  da a su única casilla libre. Al chocar de frente con un botón el cubo
  rebota y cambian de estado todos los barrotes de los grupos asociados
  (campo "buttons" del nivel: {"p": "cd"}). Barrotes cerrados = pared.
- Power ups (s = velocidad): no cambian qué decisiones hay que tomar, solo
  el ritmo del cubo, así que para el resolvedor son casillas libres.
- Enemigos (x perseguidor, z obstáculo, i j k m n patrulleros con su ruta en
  el campo "patrols" del nivel: {"i": "R3 D2 L3 U2"}): se mueven en tiempo
  real, así que el resolvedor no los simula: las casillas de perseguidores y
  patrulleros cuentan como libres y la del obstáculo como un muro (es un
  bloqueo que hay que rodear o encerrar). Los giros calculados son una
  aproximación sin enemigos en movimiento; "validate"
  comprueba que las rutas de los patrulleros pasan solo por casillas libres,
  no tocan la salida ni la meta y tienen al menos tres salidas, una de ellas
  lateral (desde una casilla intermedia de la ruta), para que el cubo
  siempre pueda esquivarlos y ningún pasillo quede intransitable.
- Vacío ('~', y también fuera del mapa): ni suelo ni pared. No es un
  obstáculo: el cubo no rebota y los giros hacia el vacío se aplican. Si el
  cubo entra en el vacío se cae y vuelve a la salida; el resolvedor descarta
  esos movimientos (nunca usa la caída como atajo).
- Puentes colgantes ('='): casillas libres sobre el vacío, en fila recta,
  con vacío a ambos lados y suelo en los dos extremos. Cada casilla aguanta
  BRIDGE_STABILITY salidas del cubo (cuenta cada vez que el cubo la deja,
  también al rebotar sobre el puente); cuando una llega a 0 cae el puente
  entero y todas sus casillas pasan a ser vacío. Si el cubo sigue encima, cae
  con él (el resolvedor descarta ese movimiento).
- Teletransporte ('6' '7' '8' '9'): parejas de casillas con el mismo número.
  Al entrar en una, el cubo aparece en la otra con el mismo rumbo. Durante
  el teletransporte no se puede girar, así que en la casilla de destino solo
  se puede seguir recto (como en la salida). Salir de ella no teletransporta.
  Los enemigos no las pisan. "validate" comprueba que cada número tiene dos
  casillas, que cada una tiene al lado un muro o el borde del suelo y que,
  entre por donde entre, el cubo no queda encajonado en la otra (sin poder
  seguir ni rebotar).
- Pinchos ('^'): salen del suelo de vez en cuando (en tiempo real), así que
  el resolvedor no los simula y cuentan como casillas libres. "validate"
  comprueba que las rutas de los patrulleros no pasan por ellos (los
  enemigos no los pisan).
- Cañones láser ('L'): son muros con un cañón que dispara láseres en tiempo
  real, así que el resolvedor no los simula y cuentan como muros. "validate"
  comprueba que cada cañón tiene exactamente una casilla libre al lado (hacia
  donde dispara).
- Cañones de bombas ('M'): son muros con un cañón encima que lanza bombas en
  tiempo real, así que el resolvedor no los simula y cuentan como muros.
  "validate" comprueba que cada cañón tiene alguna casilla libre a su
  alcance (10 casillas hacia delante y 5 a cada lado, o lo que diga el campo
  "mortars" del nivel).
- Al llegar a la meta B termina el nivel.
- Cubito dorado (campo "collectible", lo colocan place_collectibles.py): con
  solve(..., collectible=casilla) solo vale llegar a la meta tras pasar por
  él. "validate" comprueba que se puede coger y que "star_turns" (los giros de
  la estrella) es el mínimo cogiéndolo más un 30 % (al menos 3).

La dificultad de un nivel es el mínimo de giros necesarios (búsqueda 0-1 BFS),
y como desempate el número de pasos del recorrido óptimo.

Uso (desde la raíz del repositorio):
  python3 tools/level_solver.py validate
      Resuelve todos los niveles de scripts/levels.gd y comprueba que el campo
      "turns" coincide con el mínimo real de giros.

  python3 tools/level_solver.py solve 0,1 "#####" "#A..#" "###B#" "#####" [--buttons p=cd,q=e]
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
BREAKABLE_CHARS = "12345"
BAR_CHARS = "cdefh"
BUTTON_CHARS = "pqtvw"
CHASER_CHAR = "x"
BLOCKER_CHAR = "z"
PATROL_CHARS = "ijkmn"
VOID_CHAR = "~"
BRIDGE_CHAR = "="
TELEPORT_CHARS = "6789"
SPIKE_CHAR = "^"
LASER_CHAR = "L"
MORTAR_CHAR = "M"
# Alcance por defecto de los cañones de bombas: hacia delante y a cada lado.
MORTAR_RANGE = (10, 5)
# Salidas del cubo que aguanta cada casilla de puente colgante.
BRIDGE_STABILITY = 4
ENEMY_CHARS = CHASER_CHAR + BLOCKER_CHAR + PATROL_CHARS
ROUTE_DIRS = {"R": (1, 0), "L": (-1, 0), "U": (0, -1), "D": (0, 1)}
# Salidas mínimas de la ruta de un patrullero (ver patrol_exits).
PATROL_MIN_EXITS = 3
LEVEL_CHARS = ("#.AB" + KEY_CHARS + DOOR_CHARS + POWERUP_CHARS + BREAKABLE_CHARS
               + BAR_CHARS + BAR_CHARS.upper() + BUTTON_CHARS + ENEMY_CHARS + VOID_CHAR + BRIDGE_CHAR
               + TELEPORT_CHARS + SPIKE_CHAR + LASER_CHAR + MORTAR_CHAR)


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
            if c not in "#" + VOID_CHAR + BUTTON_CHARS + BLOCKER_CHAR + LASER_CHAR + MORTAR_CHAR:
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

    def __init__(self, layout, buttons=None):
        self.free, self.start, self.goal = parse(layout)
        self.rows = layout
        buttons = buttons or {}
        groups = sorted({c.lower() for row in layout for c in row if c.lower() in BAR_CHARS})
        group_bit = {g: i for i, g in enumerate(groups)}
        # casilla -> (bit del grupo, empieza cerrado)
        self.bar_at = {(x, z): (group_bit[c.lower()], c.isupper())
                       for z, row in enumerate(layout) for x, c in enumerate(row)
                       if c.lower() in BAR_CHARS}
        # casilla del botón -> máscara de grupos de barrotes que conmuta
        self.button_at = {}
        for z, row in enumerate(layout):
            for x, c in enumerate(row):
                if c in BUTTON_CHARS:
                    mask = 0
                    for g in buttons.get(c, ""):
                        if g in group_bit:
                            mask |= 1 << group_bit[g]
                    self.button_at[(x, z)] = mask
        keys, doors = parse_items(layout)
        self.key_at = {cell: (i, color) for i, (cell, color) in enumerate(keys)}
        self.door_at = {cell: (i, color) for i, (cell, color) in enumerate(doors)}
        breakables = [((x, z), int(c)) for z, row in enumerate(layout)
                      for x, c in enumerate(row) if c in BREAKABLE_CHARS]
        self.breakable_at = {cell: i for i, (cell, _) in enumerate(breakables)}
        self.initial_hits = tuple(hits for _, hits in breakables)
        self.unbreakable = False
        self.no_buttons = False
        # Puentes colgantes: casilla -> índice de casilla de puente, y para
        # cada índice los índices de todo su puente.
        self.bridges = find_bridges(layout)
        self.bridge_at = {}
        self.bridge_group = []
        for bridge in self.bridges:
            first = len(self.bridge_at)
            group = tuple(range(first, first + len(bridge)))
            for cell in bridge:
                self.bridge_at[cell] = len(self.bridge_at)
                self.bridge_group.append(group)
        self.initial_wear = (BRIDGE_STABILITY,) * len(self.bridge_at)
        # Teletransporte: casilla -> casilla pareja.
        self.teleport_at = find_teleports(layout)

    def is_void(self, cell):
        """Casilla de vacío ('~' o fuera del mapa)."""
        x, z = cell
        return z < 0 or z >= len(self.rows) or x < 0 or x >= len(self.rows[z]) \
            or self.rows[z][x] == VOID_CHAR

    def fallen(self, cell, wear):
        """Casilla de un puente colgante que ya se ha caído (ahora es vacío)."""
        b = self.bridge_at.get(cell)
        return b is not None and wear[b] == 0

    def passable(self, cell, opened, hits, flipped=0):
        """Casilla libre, sin puerta ni barrotes cerrados y sin muro en pie."""
        if cell not in self.free:
            return False
        bar = self.bar_at.get(cell)
        if bar is not None and bar[1] != bool(flipped >> bar[0] & 1):
            return False
        wall = self.breakable_at.get(cell)
        if wall is not None and hits[wall] > 0:
            return False
        door = self.door_at.get(cell)
        return door is None or bool(opened >> door[0] & 1)


def step(board, state, turn):
    """Aplica una decisión (0, -1 izquierda, 1 derecha) y avanza una casilla.

    state = (casilla, rumbo, llave_llevada o None, puertas_abiertas, llaves_cogidas,
             golpes_restantes, barrotes_conmutados, desgaste_de_puentes)
    (puertas_abiertas, llaves_cogidas y barrotes_conmutados son máscaras de
    bits; golpes_restantes es una tupla con los golpes que le quedan a cada
    muro destructible; desgaste_de_puentes, las salidas que le quedan a cada
    casilla de puente colgante). Devuelve None si el cubo cae al vacío.
    """
    cell, heading, held, opened, taken, hits, flipped, wear = state

    def void(c):
        return board.is_void(c) or board.fallen(c, wear)

    if turn:
        candidate = turn_left(heading) if turn < 0 else turn_right(heading)
        side = (cell[0] + candidate[0], cell[1] + candidate[1])
        if board.passable(side, opened, hits, flipped) or void(side):
            heading = candidate
    nxt = (cell[0] + heading[0], cell[1] + heading[1])
    if void(nxt):
        return None
    if not board.passable(nxt, opened, hits, flipped):
        door = board.door_at.get(nxt)
        wall = board.breakable_at.get(nxt)
        button = board.button_at.get(nxt)
        if door is not None and held == door[1]:
            opened |= 1 << door[0]
            held = None
        elif wall is not None and hits[wall] > 0 and not board.unbreakable:
            hits = hits[:wall] + (hits[wall] - 1,) + hits[wall + 1:]
        elif button is not None and not board.no_buttons:
            flipped ^= button
        heading = (-heading[0], -heading[1])
        nxt = (cell[0] + heading[0], cell[1] + heading[1])
        if void(nxt):
            return None
        if not board.passable(nxt, opened, hits, flipped):
            return cell, heading, held, opened, taken, hits, flipped, wear
    # Sale de una casilla de puente: pierde una salida y, si llega a 0, cae el
    # puente entero (y el cubo con él si la siguiente casilla es del puente).
    b = board.bridge_at.get(cell)
    if b is not None:
        wear = wear[:b] + (wear[b] - 1,) + wear[b + 1:]
        if wear[b] == 0:
            group = board.bridge_group[b]
            wear = tuple(0 if i in group else w for i, w in enumerate(wear))
            if board.bridge_at.get(nxt) in group:
                return None
    nxt = board.teleport_at.get(nxt, nxt)
    key = board.key_at.get(nxt)
    if key is not None and held is None and not taken >> key[0] & 1:
        held = key[1]
        taken |= 1 << key[0]
    return nxt, heading, held, opened, taken, hits, flipped, wear


def solve(layout, start_heading, doors_as_walls=False, breakables_as_walls=False,
          buttons=None, no_buttons=False, collectible=None):
    """Devuelve (giros_minimos, pasos, decisiones) o None si no tiene solución.

    Con collectible=(x, z) solo vale llegar a la meta habiendo pasado antes
    por esa casilla (el coleccionable del nivel, ver place_collectibles.py).

    decisiones es una lista de (casilla, giro) del recorrido óptimo.
    Con doors_as_walls=True las puertas no se pueden abrir (sirve para
    comprobar que una puerta es imprescindible) y con breakables_as_walls=True
    los muros destructibles no se pueden romper. buttons es el campo "buttons"
    del nivel y con no_buttons=True los botones no hacen nada.
    """
    board = Board(layout, buttons)
    board.no_buttons = no_buttons
    if board.start is None or board.goal is None:
        raise ValueError("El nivel necesita una casilla A y una casilla B")
    if doors_as_walls:
        board.key_at = {}
    if breakables_as_walls:
        board.unbreakable = True
    # El último elemento del estado indica si ya se ha cogido el coleccionable.
    start = (board.start, start_heading, None, 0, 0, board.initial_hits, 0, board.initial_wear,
             collectible is None)
    best = {start: (0, 0)}
    prev = {}
    queue = deque([(0, 0, start)])
    while queue:
        turns, steps, state = queue.popleft()
        if best.get(state) != (turns, steps):
            continue
        if state[0] == board.goal:
            if not state[-1]:
                continue  # el nivel termina al llegar a la meta: sin coleccionable no vale
            path, key = [], state
            while key in prev:
                key, turn = prev[key]
                path.append((key[0], turn))
            return turns, steps, path[::-1]
        # En la salida y al llegar por un teletransporte no se puede girar.
        options = (0,) if steps == 0 or state[0] in board.teleport_at else (0, -1, 1)
        for turn in options:
            nstate = step(board, state[:-1], turn)
            if nstate is None:
                continue
            nstate = nstate + (state[-1] or nstate[0] == collectible,)
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
        r'"start_heading":\s*Vector2i\((-?\d+),\s*(-?\d+)\),\s*"layout":\s*\[(.*?)\],'
        r'(.*?)\n\t\}',
        re.S)
    levels = []
    for name, turns, hx, hz, body, extra in pattern.findall(source):
        rows = re.findall(r'"([' + re.escape(LEVEL_CHARS) + r']+)"', body)
        buttons = {}
        block = re.search(r'"buttons":\s*\{(.*?)\}', extra, re.S)
        if block:
            buttons = dict(re.findall(r'"(\w)":\s*"(\w*)"', block.group(1)))
        patrols = {}
        block = re.search(r'"patrols":\s*\{(.*?)\}', extra, re.S)
        if block:
            patrols = dict(re.findall(r'"(\w)":\s*"([^"]*)"', block.group(1)))
        # "mortars": {Vector2i(x, z): {"facing": Vector2i(a, b), "range": Vector2i(f, s)}}
        mortars = {}
        block = re.search(r'"mortars":\s*\{((?:[^{}]|\{[^{}]*\})*)\}', extra, re.S)
        if block:
            for mx, mz, body_m in re.findall(r'Vector2i\((\d+),\s*(\d+)\):\s*\{([^}]*)\}', block.group(1)):
                settings = {}
                for key, a, b in re.findall(r'"(facing|range)":\s*Vector2i\((-?\d+),\s*(-?\d+)\)', body_m):
                    settings[key] = (int(a), int(b))
                mortars[(int(mx), int(mz))] = settings
        # Coleccionable y giros de la estrella (ver place_collectibles.py).
        collectible = None
        found = re.search(r'"collectible":\s*Vector2i\((\d+),\s*(\d+)\)', extra)
        if found:
            collectible = (int(found.group(1)), int(found.group(2)))
        found = re.search(r'"star_turns":\s*(\d+)', extra)
        star = int(found.group(1)) if found else None
        levels.append({"name": name, "turns": int(turns),
                       "heading": (int(hx), int(hz)), "layout": rows, "buttons": buttons,
                       "patrols": patrols, "mortars": mortars, "collectible": collectible,
                       "star_turns": star})
    declared = len(re.findall(r'^\t\t"name":', source, re.M))
    if declared != len(levels):
        raise SystemExit(f"Solo se han podido leer {len(levels)} de los {declared} niveles de "
                         f"{path.name}: \"name\", \"turns\", \"start_heading\" y \"layout\" "
                         f"deben ir en ese orden y al principio de cada nivel.")
    return levels


def check_buttons(rows, buttons):
    """Problemas de colocación de botones y barrotes (lista de textos)."""
    problems = []
    free, _, _ = parse(rows)
    used = {c for row in rows for c in row}
    groups = {c.lower() for c in used if c.lower() in BAR_CHARS}

    def wall(x, z):
        if z < 0 or z >= len(rows) or x < 0 or x >= len(rows[z]):
            return True
        return rows[z][x] in "#" + LASER_CHAR + MORTAR_CHAR or rows[z][x] in BUTTON_CHARS or rows[z][x] in BREAKABLE_CHARS

    fronts = set()
    for z, row in enumerate(rows):
        for x, c in enumerate(row):
            if c in BUTTON_CHARS:
                sides = [(x + dx, z + dz) for dx, dz in DIRS if (x + dx, z + dz) in free]
                if len(sides) != 1:
                    problems.append(f"el botón {c} en {(x, z)} debe tener exactamente una casilla libre al lado")
                fronts.update(sides)
                if not buttons.get(c):
                    problems.append(f"el botón {c} no tiene barrotes asignados")
            elif c.lower() in BAR_CHARS:
                across_x = wall(x - 1, z) and wall(x + 1, z)
                across_z = wall(x, z - 1) and wall(x, z + 1)
                if across_x == across_z:
                    problems.append(f"los barrotes {c} en {(x, z)} deben tener pared justo a ambos lados del pasillo")
    for cell in fronts:
        if cell in {(x, z) for z, row in enumerate(rows) for x, c in enumerate(row) if c.lower() in BAR_CHARS}:
            problems.append(f"hay barrotes delante de un botón en {cell}")
    for b, linked in buttons.items():
        if b not in used:
            problems.append(f"el botón {b} de \"buttons\" no está en el mapa")
        for g in linked:
            if g not in groups:
                problems.append(f"el botón {b} acciona los barrotes {g}, que no están en el mapa")
    return problems


def route_cells(origin, route):
    """Casillas de una ruta de patrulla desde su casilla de partida (incluida)."""
    cells, cell = [origin], origin
    for part in route.split():
        d = ROUTE_DIRS[part[0].upper()]
        for _ in range(int(part[1:])):
            cell = (cell[0] + d[0], cell[1] + d[1])
            cells.append(cell)
    return cells


def patrol_exits(free, cells):
    """Salidas de una ruta de patrulla: (total, laterales).

    Una salida es una casilla libre junto a la ruta que no forma parte de
    ella. Las laterales salen de una casilla intermedia (no de un extremo de
    una ruta de ida y vuelta): son las únicas que sirven para esquivar al
    patrullero, porque los extremos los ocupa él mismo al dar la vuelta. En
    una ruta circular todas las casillas son intermedias.
    """
    loop = len(cells) > 2 and cells[-1] == cells[0]
    on_route = set(cells)
    exits, lateral = set(), set()
    for k, (x, z) in enumerate(cells):
        inner = loop or 0 < k < len(cells) - 1
        for dx, dz in DIRS:
            n = (x + dx, z + dz)
            if n in free and n not in on_route:
                exits.add(n)
                if inner:
                    lateral.add(n)
    return len(exits), len(lateral)


def find_teleports(rows):
    """Casilla de teletransporte -> casilla pareja (solo parejas completas)."""
    cells = {}
    for z, row in enumerate(rows):
        for x, c in enumerate(row):
            if c in TELEPORT_CHARS:
                cells.setdefault(c, []).append((x, z))
    pairs = {}
    for group in cells.values():
        if len(group) == 2:
            pairs[group[0]] = group[1]
            pairs[group[1]] = group[0]
    return pairs


def check_teleports(rows):
    """Problemas de las casillas de teletransporte (lista de textos)."""
    problems = []
    cells = {}
    for z, row in enumerate(rows):
        for x, c in enumerate(row):
            if c in TELEPORT_CHARS:
                cells.setdefault(c, []).append((x, z))

    def edge(x, z):
        if z < 0 or z >= len(rows) or x < 0 or x >= len(rows[z]):
            return True
        return rows[z][x] in "#" + VOID_CHAR + BUTTON_CHARS + BREAKABLE_CHARS + LASER_CHAR + MORTAR_CHAR

    free, _, _ = parse(rows)
    for c, group in sorted(cells.items()):
        if len(group) != 2:
            problems.append(f"el teletransporte {c} tiene {len(group)} casillas (deben ser 2)")
            continue
        for i, (x, z) in enumerate(group):
            if not any(edge(x + dx, z + dz) for dx, dz in DIRS):
                problems.append(f"la casilla de teletransporte {c} en {(x, z)} no tiene muro ni borde al lado")
            # Por cada lado por el que se puede entrar, el cubo sale de la
            # otra casilla con ese rumbo: no puede quedar encajonado (sin
            # poder seguir ni rebotar), porque allí no se puede girar.
            px, pz = group[1 - i]
            for dx, dz in DIRS:
                if (x - dx, z - dz) in free and (px + dx, pz + dz) not in free \
                        and (px - dx, pz - dz) not in free:
                    problems.append(f"entrando en el teletransporte {c} de {(x, z)} con rumbo {(dx, dz)}, "
                                    f"el cubo queda encajonado en {(px, pz)}")
    return problems


def check_lasers(rows):
    """Problemas de colocación de los cañones láser (lista de textos)."""
    problems = []
    free, _, _ = parse(rows)
    for z, row in enumerate(rows):
        for x, c in enumerate(row):
            if c == LASER_CHAR:
                sides = [(x + dx, z + dz) for dx, dz in DIRS if (x + dx, z + dz) in free]
                if len(sides) != 1:
                    problems.append(f"el cañón láser en {(x, z)} debe tener exactamente una casilla libre al lado")
    return problems


def check_mortars(rows, mortars):
    """Problemas de los cañones de bombas (lista de textos): cada uno debe
    tener alguna casilla libre a su alcance mirando hacia donde mira (la de
    "mortars" o, si no se indica, la que tiene más casillas libres)."""
    problems = []
    free, _, _ = parse(rows)

    def in_reach(cell, facing, reach, target):
        ox, oz = target[0] - cell[0], target[1] - cell[1]
        forward = ox * facing[0] + oz * facing[1]
        side = ox * facing[1] - oz * facing[0]
        return 1 <= forward <= reach[0] and abs(side) <= reach[1]

    for z, row in enumerate(rows):
        for x, c in enumerate(row):
            if c != MORTAR_CHAR:
                continue
            settings = mortars.get((x, z), {})
            reach = settings.get("range", MORTAR_RANGE)
            facings = [settings["facing"]] if "facing" in settings else DIRS
            best = max(sum(1 for t in free if in_reach((x, z), f, reach, t)) for f in facings)
            if best == 0:
                problems.append(f"el cañón de bombas en {(x, z)} no tiene ninguna casilla libre a su alcance")
    for cell in mortars:
        x, z = cell
        if z >= len(rows) or x >= len(rows[z]) or rows[z][x] != MORTAR_CHAR:
            problems.append(f'"mortars" habla de {cell}, que no es un cañón de bombas')
    return problems


def find_bridges(rows):
    """Puentes colgantes: listas de casillas '=' seguidas en fila recta, en
    orden de lectura. Una casilla suelta cuenta como un puente de una casilla."""
    cells = {(x, z) for z, row in enumerate(rows) for x, c in enumerate(row) if c == BRIDGE_CHAR}
    bridges, seen = [], set()
    for z, row in enumerate(rows):
        for x, c in enumerate(row):
            if c != BRIDGE_CHAR or (x, z) in seen:
                continue
            step_dir = (1, 0) if (x + 1, z) in cells else (0, 1)
            run, cell = [], (x, z)
            while cell in cells and cell not in seen:
                run.append(cell)
                seen.add(cell)
                cell = (cell[0] + step_dir[0], cell[1] + step_dir[1])
            bridges.append(run)
    return bridges


def check_bridges(rows):
    """Problemas de forma de los puentes colgantes (lista de textos)."""
    problems = []

    def at(x, z):
        if z < 0 or z >= len(rows) or x < 0 or x >= len(rows[z]):
            return VOID_CHAR
        return rows[z][x]

    for bridge in find_bridges(rows):
        first, last = bridge[0], bridge[-1]
        if len(bridge) > 1:
            along = (bridge[1][0] - first[0], bridge[1][1] - first[1])
        else:
            x, z = first
            along = (0, 1) if at(x, z - 1) not in "#" + VOID_CHAR + LASER_CHAR + MORTAR_CHAR \
                and at(x, z + 1) not in "#" + VOID_CHAR + LASER_CHAR + MORTAR_CHAR \
                else (1, 0)
        side = (along[1], along[0])
        for x, z in bridge:
            for sx, sz in (side, (-side[0], -side[1])):
                if at(x + sx, z + sz) != VOID_CHAR:
                    problems.append(f"el puente de {first} tiene en {(x + sx, z + sz)} algo que no es vacío "
                                    f"a un lado (debe tener vacío a ambos lados)")
        for end in ((first[0] - along[0], first[1] - along[1]), (last[0] + along[0], last[1] + along[1])):
            c = at(*end)
            if c in "#" + VOID_CHAR + BRIDGE_CHAR + LASER_CHAR + MORTAR_CHAR or c in BUTTON_CHARS \
                    or c in BREAKABLE_CHARS:
                problems.append(f"el puente de {first} no acaba en suelo en {end}")
    return problems


def check_enemies(rows, patrols):
    """Problemas de colocación de enemigos y rutas de patrulla (lista de textos)."""
    problems = []
    free, start, goal = parse(rows)
    found = set()
    for z, row in enumerate(rows):
        for x, c in enumerate(row):
            if c not in PATROL_CHARS:
                continue
            if c in found:
                problems.append(f"el patrullero {c} aparece más de una vez")
            found.add(c)
            route = patrols.get(c, "")
            if not route:
                problems.append(f"el patrullero {c} no tiene ruta")
                continue
            cell = (x, z)
            for part in route.split():
                d = ROUTE_DIRS.get(part[:1].upper())
                if d is None or not part[1:].isdigit() or int(part[1:]) <= 0:
                    problems.append(f"tramo '{part}' no válido en la ruta de {c}")
                    break
                for _ in range(int(part[1:])):
                    cell = (cell[0] + d[0], cell[1] + d[1])
                    if cell not in free or cell in (start, goal) \
                            or rows[cell[1]][cell[0]] in BRIDGE_CHAR + TELEPORT_CHARS + SPIKE_CHAR:
                        problems.append(f"la ruta de {c} pasa por {cell}, que no es libre o es la salida, "
                                        f"la meta, un puente colgante, un teletransporte o pinchos")
                        break
                else:
                    continue
                break
            else:
                total, lateral = patrol_exits(free, route_cells((x, z), route))
                if total < PATROL_MIN_EXITS or lateral < 1:
                    problems.append(
                        f"la ruta de {c} tiene {total} salidas ({lateral} laterales): necesita "
                        f"{PATROL_MIN_EXITS} o más y al menos una lateral para poder esquivarlo")
    for c in patrols:
        if c not in found:
            problems.append(f"el patrullero {c} de \"patrols\" no está en el mapa")
    return problems


def check_collectible(lvl):
    """El cubito dorado está en suelo y se puede coger, y "star_turns" es el
    mínimo de giros cogiéndolo más el margen (ver place_collectibles.py)."""
    cell, star = lvl["collectible"], lvl["star_turns"]
    if cell is None or star is None:
        return ['falta "collectible" o "star_turns" (ejecutar place_collectibles.py)']
    rows = lvl["layout"]
    x, z = cell
    if not (0 <= z < len(rows) and 0 <= x < len(rows[z])) or rows[z][x] != ".":
        return [f"el coleccionable {cell} no está en una casilla de suelo"]
    result = solve(rows, lvl["heading"], buttons=lvl["buttons"], collectible=cell)
    if result is None:
        return [f"el coleccionable {cell} no se puede coger"]
    turns = result[0]
    expected = turns + max(3, -(-turns * 3 // 10))
    if star != expected:
        return [f"star_turns es {star} pero debería ser {expected} ({turns} giros con el coleccionable)"]
    return []


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
        problems += check_buttons(rows, lvl["buttons"])
        problems += check_enemies(rows, lvl["patrols"])
        problems += check_bridges(rows)
        problems += check_teleports(rows)
        problems += check_lasers(rows)
        problems += check_mortars(rows, lvl["mortars"])
        result = None if problems else solve(rows, lvl["heading"], buttons=lvl["buttons"])
        if not problems and result is None:
            problems.append("sin solución")
        elif result and result[0] != lvl["turns"]:
            problems.append(f"declara {lvl['turns']} giros pero el mínimo es {result[0]}")
        if result and not problems:
            problems += check_collectible(lvl)
        ok &= not problems
        size = f"{len(rows[0])}x{len(rows)}"
        detail = f"giros={result[0]:>2} pasos={result[1]:>3}" if result else ""
        status = "OK" if not problems else "ERROR: " + "; ".join(problems)
        print(f"{i:2} {lvl['name']:<20} {size:>6} {detail}  {status}")
    print("Todos los niveles son correctos." if ok else "Hay niveles con errores.")
    return 0 if ok else 1


def cmd_solve(args):
    hx, hz = (int(v) for v in args.heading.split(","))
    buttons = dict(pair.split("=") for pair in args.buttons.split(",")) if args.buttons else {}
    for problem in check_buttons(args.rows, buttons):
        print("Aviso:", problem)
    result = solve(args.rows, (hx, hz), buttons=buttons)
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
    p_solve.add_argument("--buttons", default="", help='botones y sus barrotes, p. ej. "p=cd,q=e"')
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
