#!/usr/bin/env python3
"""Detecta los elementos de la imagen del selector de niveles.

Lee la imagen del mapa (ui/level_select/map.png) y guarda en
ui/level_select/map.json lo que LevelMap necesita para colocar sus capas
encima:
- "circles": los círculos de nivel en el orden del camino, empezando por el
  más cercano a la casilla de inicio. Cada uno con su centro (x, y), su
  ancho y alto (w, h) en píxeles de la imagen y la zona a la que pertenece.
- "zones": los carteles de zona de la izquierda (rectángulo del hueco para
  el texto), de abajo arriba.
- "start": la casilla de inicio (el cubo azul) y el hueco de debajo para el
  texto «INICIO».

Cómo detecta cada cosa:
- Círculos: manchas grises (poco saturadas, ni muy claras ni muy oscuras)
  con forma de elipse y del tamaño de un círculo.
- Orden: recorre el camino de color crema desde cada círculo (búsqueda en
  anchura por los píxeles del camino) para saber qué círculos están unidos
  por el camino. Donde el camino se corta (pasa por detrás de algo), une los
  tramos de forma que la suma de los saltos sea la menor posible. Empieza
  por el extremo más bajo.
- Carteles: filas con un tramo horizontal ancho de un color saturado y
  uniforme cerca del borde izquierdo.
- Zona de cada círculo: la del cartel más bajo que queda por encima del
  círculo (con un margen ZONE_MARGIN), contando de abajo arriba.
- Inicio: los píxeles azules del cubo brillante cerca del primer círculo.

Si se cambia la imagen, basta con volver a ejecutarlo (y comprobar la
imagen de control que genera con --check).

Uso (desde la raíz del repositorio):
  python3 tools/find_level_circles.py [--check salida.png]
"""
import argparse
import json
import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
IMAGE = ROOT / "ui" / "level_select" / "map.png"
OUTPUT = ROOT / "ui" / "level_select" / "map.json"

# Tamaño aceptado de un círculo (píxeles de la imagen) y cuánto de su caja
# debe estar relleno.
CIRCLE_W = (22, 70)
CIRCLE_H = (12, 45)
CIRCLE_FILL = 0.45
# Grosor del borde claro y la sombra de cada círculo, que no son camino.
RIM = 7
# Un cartel empieza a contar ZONE_MARGIN píxeles por encima de su borde
# superior (los círculos de su zona quedan algo por debajo de él).
ZONE_MARGIN = 30
# Ancho mínimo del tramo uniforme de un cartel y columna en la que se mide
# (fracciones del ancho de la imagen).
BANNER_MIN_WIDTH = 0.14
BANNER_PROBE_X = 0.21
# El hueco del texto «INICIO» queda bajo el cubo, en la cara del pedestal:
# desplazamiento de su centro desde el centro del borde inferior del cubo y
# su tamaño, en fracciones del ancho del cubo.
START_LABEL_OFFSET = (0.2, 0.97)
START_LABEL_SIZE = (2.2, 0.7)
# Distancia máxima (píxeles) entre el primer círculo y el cubo de inicio.
START_SEARCH = 140
# Separación máxima (píxeles) entre las caras del cubo.
START_GAP = 12


def is_grey(c):
    return max(c) - min(c) < 20 and 105 < max(c) < 215


def is_path(c):
    r, g, b = c
    return r > 230 and g > 205 and b > 170 and r - b < 90


def is_start_cube(c):
    r, g, b = c
    return b > 240 and 120 < g < 185 and r < 60


def components(width, height, mask):
    """Manchas conexas (4 vecinos) de una máscara: lista de listas de índices."""
    seen = bytearray(width * height)
    found = []
    for start in range(width * height):
        if not mask[start] or seen[start]:
            continue
        seen[start] = 1
        queue, pixels = deque([start]), []
        while queue:
            i = queue.popleft()
            pixels.append(i)
            x = i % width
            for j in (i - 1 if x > 0 else -1, i + 1 if x < width - 1 else -1, i - width, i + width):
                if 0 <= j < width * height and mask[j] and not seen[j]:
                    seen[j] = 1
                    queue.append(j)
        found.append(pixels)
    return found


def find_circles(img):
    width, height = img.size
    px = img.load()
    mask = bytearray(1 if is_grey(px[i % width, i // width]) else 0 for i in range(width * height))
    circles = []
    for pixels in components(width, height, mask):
        xs = [i % width for i in pixels]
        ys = [i // width for i in pixels]
        w = max(xs) - min(xs) + 1
        h = max(ys) - min(ys) + 1
        if CIRCLE_W[0] <= w <= CIRCLE_W[1] and CIRCLE_H[0] <= h <= CIRCLE_H[1] \
                and len(pixels) > CIRCLE_FILL * w * h:
            circles.append({"x": sum(xs) / len(xs), "y": sum(ys) / len(ys), "w": w, "h": h,
                            "pixels": set(pixels)})
    return circles


def path_neighbours(img, circles):
    """Para cada círculo, los círculos a los que se llega por el camino sin
    pasar por otro círculo."""
    width, height = img.size
    px = img.load()
    owner = {}
    for k, c in enumerate(circles):
        # El borde claro del círculo también cuenta como suyo.
        grown = set(c["pixels"])
        for i in c["pixels"]:
            for d in range(-RIM, RIM + 1):
                for e in range(-RIM, RIM + 1):
                    grown.add(i + d + e * width)
        for i in grown:
            owner[i] = k
    walkable = bytearray(width * height)
    for i in range(width * height):
        if i in owner or is_path(px[i % width, i // width]):
            walkable[i] = 1
    links = [set() for _ in circles]
    for k, c in enumerate(circles):
        start = [i for i in owner if owner[i] == k]
        seen = set(start)
        queue = deque(start)
        while queue:
            i = queue.popleft()
            x = i % width
            for j in (i - 1 if x > 0 else -1, i + 1 if x < width - 1 else -1, i - width, i + width):
                if j < 0 or j >= width * height or j in seen or not walkable[j]:
                    continue
                seen.add(j)
                other = owner.get(j)
                if other is not None and other != k:
                    links[k].add(other)
                    continue
                queue.append(j)
    return links


def order_circles(circles, links):
    """Encadena los círculos siguiendo el camino. Donde el camino se ve
    entero, `links` une cada círculo con sus vecinos; donde se corta (pasa
    por detrás de algo o cambia de color), quedan tramos sueltos que se unen
    por sus extremos más cercanos. Empieza por el extremo más bajo de la
    imagen (el camino sale de la casilla de inicio, abajo)."""
    def dist(a, b):
        return ((circles[a]["x"] - circles[b]["x"]) ** 2 + (circles[a]["y"] - circles[b]["y"]) ** 2) ** 0.5

    # Tramos: componentes conexas del grafo de enlaces, como listas en orden.
    seen, segments = set(), []
    for k in range(len(circles)):
        if k in seen:
            continue
        group, stack = set(), [k]
        while stack:
            c = stack.pop()
            if c in group:
                continue
            group.add(c)
            stack.extend(links[c] - group)
        seen |= group
        ends = [c for c in group if len(links[c] & group) <= 1] or [k]
        chain, prev, cur = [ends[0]], None, ends[0]
        while True:
            nxt = [c for c in links[cur] & group if c != prev and c not in chain]
            if not nxt:
                break
            prev, cur = cur, min(nxt, key=lambda c: dist(cur, c))
            chain.append(cur)
        if len(chain) != len(group):
            print(f"Aviso: el camino se bifurca cerca del círculo en "
                  f"({circles[k]['x']:.0f}, {circles[k]['y']:.0f})", file=sys.stderr)
            chain += sorted(group - set(chain), key=lambda c: dist(chain[-1], c))
        segments.append(chain)
    first = max((seg for seg in segments), key=lambda seg: max(circles[seg[0]]["y"], circles[seg[-1]]["y"]))
    if circles[first[-1]]["y"] > circles[first[0]]["y"]:
        first.reverse()
    order = list(first) + _join_segments(first, [seg for seg in segments if seg is not first], dist)
    if len(segments) > 1:
        print(f"El camino se ve cortado en {len(segments) - 1} sitios; los tramos se han unido "
              f"con los saltos más cortos (revisa la imagen de --check)", file=sys.stderr)
    return [circles[k] for k in order]


def _join_segments(first, rest, dist):
    """Orden y sentido de los tramos sueltos que siguen a `first` con la
    menor suma de saltos entre el final de un tramo y el principio del
    siguiente (programación dinámica sobre los subconjuntos de tramos)."""
    if not rest:
        return []
    n = len(rest)
    ends = [(seg[0], seg[-1]) for seg in rest]
    # best[(máscara, último, sentido)] = (coste, anterior)
    best = {}
    for k in range(n):
        for o in (0, 1):
            head = ends[k][o]
            best[(1 << k, k, o)] = (dist(first[-1], head), None)
    for mask in range(1, 1 << n):
        for k in range(n):
            for o in (0, 1):
                state = best.get((mask, k, o))
                if state is None:
                    continue
                tail = ends[k][1 - o]
                for m in range(n):
                    if mask >> m & 1:
                        continue
                    for p in (0, 1):
                        key = (mask | 1 << m, m, p)
                        cost = state[0] + dist(tail, ends[m][p])
                        if key not in best or cost < best[key][0]:
                            best[key] = (cost, (mask, k, o))
    full = (1 << n) - 1
    key = min(((full, k, o) for k in range(n) for o in (0, 1)), key=lambda kk: best[kk][0])
    chain = []
    while key is not None:
        _, k, o = key
        chain.append(rest[k] if o == 0 else rest[k][::-1])
        key = best[key][1]
    result = []
    for seg in reversed(chain):
        result += seg
    return result


def find_banners(img):
    width, height = img.size
    px = img.load()
    probe = int(width * BANNER_PROBE_X)
    rows = []
    for y in range(height):
        c = px[probe, y]
        if max(c) - min(c) < 60:
            continue

        def same(x):
            return sum(abs(a - b) for a, b in zip(px[x, y], c)) < 66

        left = probe
        while left > 0 and same(left - 1):
            left -= 1
        right = probe
        while right < width - 1 and same(right + 1):
            right += 1
        if right - left > BANNER_MIN_WIDTH * width:
            rows.append((y, left, right))
    groups = []
    for row in rows:
        if groups and row[0] - groups[-1][-1][0] <= 12:
            groups[-1].append(row)
        else:
            groups.append([row])
    banners = []
    for g in groups:
        if len(g) < 20:
            continue
        lefts = sorted(r[1] for r in g)
        rights = sorted(r[2] for r in g)
        banners.append({"x": lefts[len(lefts) // 2], "y": g[0][0],
                        "w": rights[len(rights) // 2] - lefts[len(lefts) // 2], "h": g[-1][0] - g[0][0]})
    # De abajo arriba, como las zonas.
    banners.sort(key=lambda b: -b["y"])
    return banners


def find_start(img, first_circle):
    """El cubo azul brillante de la casilla de inicio: las manchas de su
    azul que quedan a menos de START_SEARCH píxeles del primer círculo (las
    cascadas tienen un azul parecido, pero están más lejos)."""
    width, height = img.size
    px = img.load()
    fx, fy = first_circle["x"], first_circle["y"]
    x0, x1 = max(0, int(fx - START_SEARCH)), min(width, int(fx + START_SEARCH))
    y0, y1 = max(0, int(fy - START_SEARCH)), min(height, int(fy + START_SEARCH))
    sub_w, sub_h = x1 - x0, y1 - y0
    mask = bytearray(sub_w * sub_h)
    for i in range(sub_w * sub_h):
        x, y = x0 + i % sub_w, y0 + i // sub_w
        if is_start_cube(px[x, y]) and (x - fx) ** 2 + (y - fy) ** 2 < START_SEARCH ** 2:
            mask[i] = 1
    # Las caras del cubo salen como manchas separadas por sus aristas
    # blancas: se juntan las manchas casi pegadas y se elige el grupo más
    # cercano al primer círculo (el agua también puede tener ese azul).
    clusters = []
    for pixels in components(sub_w, sub_h, mask):
        if len(pixels) < 40:
            continue
        xs = [x0 + i % sub_w for i in pixels]
        ys = [y0 + i // sub_w for i in pixels]
        box = [len(pixels), min(xs), max(xs), min(ys), max(ys)]
        for c in clusters:
            if box[1] <= c[2] + START_GAP and box[2] >= c[1] - START_GAP \
                    and box[3] <= c[4] + START_GAP and box[4] >= c[3] - START_GAP:
                c[0] += box[0]
                c[1], c[2] = min(c[1], box[1]), max(c[2], box[2])
                c[3], c[4] = min(c[3], box[3]), max(c[4], box[4])
                break
        else:
            clusters.append(box)
    clusters = [c for c in clusters if c[0] >= 100]
    if not clusters:
        return None
    _, left, right, top, bottom = min(
        clusters, key=lambda c: ((c[1] + c[2]) / 2 - fx) ** 2 + ((c[3] + c[4]) / 2 - fy) ** 2)
    cx = (left + right) / 2
    cube_w = right - left + 1
    label_w, label_h = START_LABEL_SIZE[0] * cube_w, START_LABEL_SIZE[1] * cube_w
    label_center = (cx + START_LABEL_OFFSET[0] * cube_w, bottom + START_LABEL_OFFSET[1] * cube_w)
    return {"x": cx, "y": (top + bottom) / 2,
            "label": {"x": round(label_center[0] - label_w / 2, 1), "y": round(label_center[1] - label_h / 2, 1),
                      "w": round(label_w, 1), "h": round(label_h, 1)}}


def zone_of(circle, banners):
    """Índice (de abajo arriba) de la zona del círculo. Cada cartel está en
    lo alto de su zona: el círculo es de la zona del cartel más alto que
    sigue por encima de él (contando el margen ZONE_MARGIN)."""
    below = sum(1 for b in banners if b["y"] - ZONE_MARGIN > circle["y"])
    return min(below, len(banners) - 1)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", help="guarda una copia de la imagen con lo detectado marcado")
    args = parser.parse_args()
    img = Image.open(IMAGE).convert("RGB")
    circles = find_circles(img)
    links = path_neighbours(img, circles)
    ordered = order_circles(circles, links)
    start = find_start(img, ordered[0])
    if start is None:
        print("No se encuentra la casilla de inicio (cubo azul) cerca del primer círculo")
        return 1
    banners = find_banners(img)
    data = {
        "image": IMAGE.name,
        "size": list(img.size),
        "circles": [{"x": round(c["x"], 1), "y": round(c["y"], 1), "w": c["w"], "h": c["h"],
                     "zone": zone_of(c, banners)} for c in ordered],
        "zones": [{"x": b["x"], "y": b["y"], "w": b["w"], "h": b["h"]} for b in banners],
        "start": start,
    }
    OUTPUT.write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    per_zone = [sum(1 for c in data["circles"] if c["zone"] == z) for z in range(len(banners))]
    print(f"{len(ordered)} círculos, {len(banners)} zonas (círculos por zona: {per_zone}) -> {OUTPUT}")
    if args.check:
        check = img.copy()
        draw = ImageDraw.Draw(check)
        for k, c in enumerate(data["circles"]):
            draw.text((c["x"] - 6, c["y"] - 7), str(k + 1), fill=(255, 0, 0))
            if k:
                p = data["circles"][k - 1]
                draw.line((p["x"], p["y"], c["x"], c["y"]), fill=(255, 0, 0), width=1)
        for b in data["zones"]:
            draw.rectangle((b["x"], b["y"], b["x"] + b["w"], b["y"] + b["h"]), outline=(255, 255, 0))
        lab = start["label"]
        draw.rectangle((lab["x"], lab["y"], lab["x"] + lab["w"], lab["y"] + lab["h"]), outline=(255, 255, 0))
        check.save(args.check)
    return 0


if __name__ == "__main__":
    sys.exit(main())
