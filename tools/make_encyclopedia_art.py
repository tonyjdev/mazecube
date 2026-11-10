#!/usr/bin/env python3
"""Genera los dibujos de la enciclopedia (ui/encyclopedia/<id>.png).

Cada elemento del juego (enemigos, habilidades, objetos y obstáculos) se
dibuja como si fuera con tiza sobre una pizarra: trazos que tiemblan un poco,
no cierran del todo y dejan ver el grano de la pizarra, sombreados a rayas y
algún manchurrón de tiza. No son los modelos 3D: son bocetos aproximados con
flechas y marcas que explican cómo funciona cada cosa (sin textos, para que
valgan en cualquier idioma).

Para añadir un dibujo nuevo: escribir una función draw_<id>(b) y añadirla a
DRAWINGS; el id es el mismo que el de su página en EncyclopediaData. Es
determinista (cada dibujo tiene su semilla).

Uso (desde la raíz del repositorio):
    uv run --with numpy --with pillow tools/make_encyclopedia_art.py [id ...]
"""
import math
import random
import sys
import zlib
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT_DIR = Path("ui/encyclopedia")
# Tamaño final y supermuestreo (se dibuja a S× y se reduce).
W, H = 720, 600
S = 2

BOARD = np.array([34, 47, 41], np.float32)
CHALK = {
    "white": (238, 238, 228), "grey": (165, 168, 160), "yellow": (247, 222, 112),
    "orange": (246, 168, 92), "red": (242, 112, 102), "blue": (124, 184, 242),
    "purple": (192, 152, 242), "teal": (112, 214, 194), "green": (152, 222, 122),
    "pink": (242, 142, 212), "cyan": (120, 220, 245), "brown": (200, 160, 112),
}

# Letras de trazo (caja 0..1, y hacia abajo): solo las que usan los dibujos.
GLYPHS = {
    "!": [[(0.5, 0.0), (0.5, 0.62)], [(0.5, 0.9), (0.5, 0.95)]],
    "?": [[(0.15, 0.25), (0.3, 0.05), (0.7, 0.05), (0.85, 0.25), (0.5, 0.5), (0.5, 0.65)],
          [(0.5, 0.9), (0.5, 0.95)]],
    "x": [[(0.15, 0.35), (0.75, 0.95)], [(0.75, 0.35), (0.15, 0.95)]],
    "+": [[(0.5, 0.3), (0.5, 0.95)], [(0.15, 0.62), (0.85, 0.62)]],
    "1": [[(0.25, 0.2), (0.55, 0.0), (0.55, 1.0)]],
    "2": [[(0.12, 0.25), (0.3, 0.04), (0.7, 0.04), (0.86, 0.25), (0.8, 0.45), (0.12, 1.0), (0.9, 1.0)]],
    "4": [[(0.65, 1.0), (0.65, 0.0), (0.1, 0.7), (0.9, 0.7)]],
    "5": [[(0.85, 0.02), (0.2, 0.02), (0.15, 0.45), (0.6, 0.4), (0.85, 0.6), (0.8, 0.88),
           (0.5, 1.0), (0.15, 0.9)]],
}


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


class Board:
    def __init__(self, seed):
        self.rng = np.random.default_rng(seed)
        self.w, self.h = W * S, H * S
        self.img = self._background()
        self.grain = self._noise(0.8)

    # --- Pizarra -----------------------------------------------------------

    def _noise(self, blur):
        n = Image.fromarray((self.rng.random((self.h, self.w)) * 255).astype(np.uint8))
        n = n.filter(ImageFilter.GaussianBlur(blur * S))
        a = np.asarray(n, np.float32) / 255.0
        return (a - a.min()) / max(1e-6, a.max() - a.min())

    def _background(self):
        img = np.empty((self.h, self.w, 3), np.float32)
        img[:] = BOARD
        low = self._noise(60) - 0.5
        img += low[..., None] * 14.0
        fine = self.rng.random((self.h, self.w)).astype(np.float32) - 0.5
        img += fine[..., None] * 5.0
        # Restos de tiza borrada: arcos anchos muy difuminados.
        smudge = Image.new("L", (self.w, self.h))
        d = ImageDraw.Draw(smudge)
        for _ in range(7):
            cx, cy = self.rng.uniform(0, self.w), self.rng.uniform(0, self.h)
            r = self.rng.uniform(150, 420) * S
            a0 = self.rng.uniform(0, 360)
            d.arc((cx - r, cy - r * 0.6, cx + r, cy + r * 0.6), a0, a0 + self.rng.uniform(60, 160),
                  fill=255, width=int(self.rng.uniform(40, 90) * S))
        smudge = np.asarray(smudge.filter(ImageFilter.GaussianBlur(28 * S)), np.float32) / 255.0
        img += smudge[..., None] * 16.0
        # Bordes algo más oscuros.
        yy, xx = np.mgrid[0:self.h, 0:self.w].astype(np.float32)
        v = ((xx / self.w - 0.5) ** 2 + (yy / self.h - 0.5) ** 2)
        img *= (1.0 - v * 0.5)[..., None]
        return img

    # --- Composición -------------------------------------------------------

    def _mask(self, fn):
        m = Image.new("L", (self.w, self.h))
        fn(ImageDraw.Draw(m))
        return np.asarray(m, np.float32) / 255.0

    def _grain(self):
        dx, dy = self.rng.integers(0, 400, 2)
        return np.roll(self.grain, (int(dy), int(dx)), (0, 1))

    def _chalk(self, mask, color, alpha=0.92, rough=0.55, clip=None):
        if clip is not None:
            mask = mask * clip
        g = self._grain()
        a = np.clip((mask - (1.0 - g) * rough) * 2.4, 0.0, 1.0) * alpha
        c = np.array(CHALK.get(color, color) if isinstance(color, str) else color, np.float32)
        self.img = self.img * (1.0 - a[..., None]) + c * a[..., None]

    # --- Trazos ------------------------------------------------------------

    def _wobble(self, pts, amount, closed=False):
        pts = [np.array(p, np.float32) * S for p in pts]
        if closed:
            pts = pts + [pts[0]]
        out = []
        for a, b in zip(pts[:-1], pts[1:]):
            n = max(2, int(np.linalg.norm(b - a) / (5 * S)))
            for t in np.linspace(0, 1, n, endpoint=False):
                out.append(a + (b - a) * t)
        out.append(pts[-1])
        out = np.array(out)
        if len(out) < 3 or amount <= 0:
            return out
        # Desplazamiento perpendicular con ruido suave.
        seg = np.diff(out, axis=0)
        seg = np.vstack([seg, seg[-1:]])
        normal = np.stack([-seg[:, 1], seg[:, 0]], 1)
        normal /= np.maximum(np.linalg.norm(normal, axis=1, keepdims=True), 1e-6)
        dist = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(out, axis=0), axis=1))])
        knots = np.arange(0, dist[-1] + 60 * S, 45 * S)
        vals = self.rng.normal(0, amount * S, len(knots))
        off = np.interp(dist, knots, vals)
        return out + normal * off[:, None]

    def line(self, pts, color="white", width=4.0, alpha=0.92, wobble=1.2, passes=2,
             closed=False, overshoot=True, clip=None, rough=0.55):
        if len(pts) < 2:
            return
        pts = list(pts)
        if overshoot and not closed:
            p0, p1 = np.array(pts[0], float), np.array(pts[1], float)
            q0, q1 = np.array(pts[-1], float), np.array(pts[-2], float)
            e = self.rng.uniform(0.0, width * 1.2)
            d0 = (p0 - p1) / max(np.linalg.norm(p0 - p1), 1e-6)
            d1 = (q0 - q1) / max(np.linalg.norm(q0 - q1), 1e-6)
            pts[0] = tuple(p0 + d0 * e)
            pts[-1] = tuple(q0 + d1 * self.rng.uniform(0.0, width * 1.2))
        for i in range(passes):
            path = self._wobble(pts, wobble * (1.0 if i == 0 else 0.7), closed)
            if i > 0:
                path = path + self.rng.normal(0, 0.6 * S, 2)
            flat = [tuple(p) for p in path]
            w = width * S * (1.0 if i == 0 else 0.7)

            def draw(d, flat=flat, w=w):
                d.line(flat, fill=255, width=max(1, int(round(w))), joint="curve")
                r = w / 2
                for p in (flat[0], flat[-1]):
                    d.ellipse((p[0] - r, p[1] - r, p[0] + r, p[1] + r), fill=255)
            self._chalk(self._mask(draw), color, alpha * (1.0 if i == 0 else 0.6), rough, clip)

    def poly(self, pts, color="white", width=4.0, **kw):
        self.line(pts, color, width, closed=True, overshoot=False, **kw)

    def ellipse_pts(self, c, rx, ry, a0=0.0, a1=360.0, n=None, tilt=0.0):
        n = n or max(12, int((rx + ry) * abs(a1 - a0) / 360.0 * 0.6))
        pts = []
        ct, st = math.cos(math.radians(tilt)), math.sin(math.radians(tilt))
        for t in np.linspace(math.radians(a0), math.radians(a1), n):
            x, y = math.cos(t) * rx, math.sin(t) * ry
            pts.append((c[0] + x * ct - y * st, c[1] + x * st + y * ct))
        return pts

    def circle(self, c, rx, ry=None, color="white", width=4.0, a0=None, tilt=0.0, **kw):
        """Círculo a mano: empieza en un punto al azar y se pasa un poco."""
        ry = rx if ry is None else ry
        a0 = self.rng.uniform(0, 360) if a0 is None else a0
        self.line(self.ellipse_pts(c, rx, ry, a0, a0 + 370, tilt=tilt), color, width,
                  overshoot=False, **kw)

    def arrow(self, pts, color="white", width=4.0, head=16.0, both=False, **kw):
        self.line(pts, color, width, **kw)
        ends = [(pts[-1], pts[-2])] + ([(pts[0], pts[1])] if both else [])
        for tip, prev in ends:
            d = np.array(tip, float) - np.array(prev, float)
            d /= max(np.linalg.norm(d), 1e-6)
            n = np.array([-d[1], d[0]])
            for side in (1, -1):
                base = np.array(tip) - d * head + n * head * 0.6 * side
                self.line([tuple(base), tip], color, width, overshoot=False, wobble=0.5)

    def dashed(self, pts, color="white", width=3.5, dash=16.0, gap=12.0, arrow=False, **kw):
        path = self._wobble(pts, 0.0) / S
        dist = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(path, axis=0), axis=1))])
        t = 0.0
        while t < dist[-1]:
            a, b = t, min(t + dash, dist[-1])
            seg = [(float(np.interp(s, dist, path[:, 0])), float(np.interp(s, dist, path[:, 1])))
                   for s in np.linspace(a, b, 4)]
            self.line(seg, color, width, passes=1, wobble=0.3, overshoot=False, **kw)
            t += dash + gap
        if arrow:
            self.arrow([path[-6].tolist(), path[-1].tolist()], color, width, passes=1)

    def curve(self, p0, p1, p2, n=24):
        """Curva de Bézier cuadrática (puntos)."""
        out = []
        for t in np.linspace(0, 1, n):
            out.append(((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
                        (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]))
        return out

    # --- Rellenos ----------------------------------------------------------

    def poly_mask(self, pts, grow=0):
        flat = [(p[0] * S, p[1] * S) for p in pts]
        m = self._mask(lambda d: d.polygon(flat, fill=255))
        if grow:
            img = Image.fromarray((m * 255).astype(np.uint8))
            img = img.filter(ImageFilter.MaxFilter(2 * grow * S + 1) if grow > 0
                             else ImageFilter.MinFilter(-2 * grow * S + 1))
            m = np.asarray(img, np.float32) / 255.0
        return m

    def circle_mask(self, c, rx, ry=None):
        ry = rx if ry is None else ry
        return self._mask(lambda d: d.ellipse(((c[0] - rx) * S, (c[1] - ry) * S,
                                               (c[0] + rx) * S, (c[1] + ry) * S), fill=255))

    def hatch(self, clip, color="white", spacing=11.0, angle=-35.0, width=2.6, alpha=0.75):
        """Rayado paralelo dentro de la máscara `clip`."""
        ys, xs = np.nonzero(clip > 0.5)
        if len(xs) == 0:
            return
        x0, x1, y0, y1 = xs.min() / S, xs.max() / S, ys.min() / S, ys.max() / S
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        r = math.hypot(x1 - x0, y1 - y0) / 2 + 10
        d = np.array([math.cos(math.radians(angle)), math.sin(math.radians(angle))])
        n = np.array([-d[1], d[0]])
        lines = []
        for k in np.arange(-r, r, spacing):
            o = np.array([cx, cy]) + n * (k + self.rng.uniform(-1.5, 1.5))
            lines.append([tuple(o - d * r), tuple(o + d * r)])

        def draw(dr):
            for a, b in lines:
                dr.line([(a[0] * S, a[1] * S), (b[0] * S, b[1] * S)], fill=255, width=int(width * S))
        self._chalk(self._mask(draw), color, alpha, 0.6, clip)

    def smear(self, clip, color="white", alpha=0.22, blur=5.0):
        """Mancha de tiza frotada con el dedo."""
        img = Image.fromarray((clip * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur * S))
        m = np.asarray(img, np.float32) / 255.0
        g = self._noise(3.0)
        a = m * (0.45 + 0.55 * g) * alpha
        c = np.array(CHALK.get(color, color), np.float32)
        self.img = self.img * (1.0 - a[..., None]) + c * a[..., None]

    def outline_mask(self, mask, width=4.0, color="white", alpha=0.92):
        """Contorno de una máscara (para nubes y formas compuestas)."""
        img = Image.fromarray((mask * 255).astype(np.uint8))
        inner = img.filter(ImageFilter.MinFilter(int(width * S) | 1))
        edge = np.clip(np.asarray(img, np.float32) - np.asarray(inner, np.float32), 0, 255) / 255.0
        self._chalk(edge, color, alpha)

    # --- Figuras -----------------------------------------------------------

    def text(self, s, x, y, size, color="white", width=4.5, spacing=0.75):
        for ch in s:
            for stroke in GLYPHS.get(ch, []):
                pts = [(x + px * size * 0.6, y + py * size) for px, py in stroke]
                if len(pts) == 2 and np.allclose(pts[0], pts[1], atol=size * 0.06):
                    self.line(pts, color, width * 1.4, wobble=0.2, overshoot=False)
                else:
                    self.line(pts, color, width, wobble=0.6)
            x += size * spacing

    def sparkle(self, c, r, color="yellow", width=3.5):
        self.line([(c[0], c[1] - r), (c[0], c[1] + r)], color, width, wobble=0.3)
        self.line([(c[0] - r, c[1]), (c[0] + r, c[1])], color, width, wobble=0.3)
        k = r * 0.45
        self.line([(c[0] - k, c[1] - k), (c[0] + k, c[1] + k)], color, width * 0.7, wobble=0.2)
        self.line([(c[0] + k, c[1] - k), (c[0] - k, c[1] + k)], color, width * 0.7, wobble=0.2)

    def burst(self, c, r0, r1, n=10, color="yellow", width=3.5, a0=0.0, a1=360.0):
        for t in np.linspace(math.radians(a0), math.radians(a1), n, endpoint=(a1 - a0) < 360):
            t += self.rng.uniform(-0.1, 0.1)
            k = self.rng.uniform(0.8, 1.15)
            self.line([(c[0] + math.cos(t) * r0, c[1] + math.sin(t) * r0),
                       (c[0] + math.cos(t) * r1 * k, c[1] + math.sin(t) * r1 * k)], color, width, wobble=0.3)

    def cloud(self, c, r, color="grey", width=3.5, blobs=5):
        m = np.zeros((self.h, self.w), np.float32)
        for i in range(blobs):
            t = i / blobs * math.tau + self.rng.uniform(-0.3, 0.3)
            rr = r * self.rng.uniform(0.45, 0.65)
            p = (c[0] + math.cos(t) * r * 0.5, c[1] + math.sin(t) * r * 0.35)
            m = np.maximum(m, self.circle_mask(p, rr))
        self.smear(m, color, 0.18, 3)
        self.outline_mask(m, width, color, 0.85)

    def save(self, path):
        img = Image.fromarray(np.clip(self.img, 0, 255).astype(np.uint8))
        img = img.resize((W, H), Image.LANCZOS)
        img.save(path, optimize=True)


# --- Perspectiva isométrica --------------------------------------------------

class Iso:
    """Proyección isométrica: x hacia abajo a la derecha, y hacia abajo a la
    izquierda, z hacia arriba; `u` = píxeles por casilla."""

    def __init__(self, b, ox, oy, u):
        self.b, self.ox, self.oy, self.u = b, ox, oy, u

    def p(self, x, y, z=0.0):
        return (self.ox + (x - y) * self.u * 0.866, self.oy + (x + y) * self.u * 0.5 - z * self.u)

    def tiles(self, cells, color="grey", width=2.4, inset=0.06, alpha=0.6):
        for x, y in cells:
            i = inset
            self.b.poly([self.p(x + i, y + i), self.p(x + 1 - i, y + i), self.p(x + 1 - i, y + 1 - i),
                         self.p(x + i, y + 1 - i)], color, width, alpha=alpha, passes=1, wobble=0.6)

    def faces(self, x, y, z, dx, dy, dz):
        top = [self.p(x, y, z + dz), self.p(x + dx, y, z + dz), self.p(x + dx, y + dy, z + dz),
               self.p(x, y + dy, z + dz)]
        right = [self.p(x + dx, y, z), self.p(x + dx, y + dy, z), self.p(x + dx, y + dy, z + dz),
                 self.p(x + dx, y, z + dz)]
        left = [self.p(x, y + dy, z), self.p(x + dx, y + dy, z), self.p(x + dx, y + dy, z + dz),
                self.p(x, y + dy, z + dz)]
        return top, left, right

    def mask(self, x, y, z, dx, dy, dz):
        """Máscara de lo que ocupa una caja en pantalla (sus tres caras)."""
        return np.maximum.reduce([self.b.poly_mask(f) for f in self.faces(x, y, z, dx, dy, dz)])

    def box(self, x, y, z, dx, dy, dz, color="white", width=4.0, shade=True, hatch_color=None,
            fill=None):
        b = self.b
        top, left, right = self.faces(x, y, z, dx, dy, dz)
        hc = hatch_color or color
        if fill:
            b.smear(self.mask(x, y, z, dx, dy, dz), fill, 0.25, 2)
        if shade:
            b.hatch(b.poly_mask(left, -2), hc, spacing=14, angle=60, width=2.2, alpha=0.5)
            b.hatch(b.poly_mask(right, -2), hc, spacing=8, angle=-60, width=2.4, alpha=0.65)
        sil = [self.p(x, y, z + dz), self.p(x + dx, y, z + dz), self.p(x + dx, y, z),
               self.p(x + dx, y + dy, z), self.p(x, y + dy, z), self.p(x, y + dy, z + dz)]
        b.poly(sil, color, width)
        near = self.p(x + dx, y + dy, z + dz)
        b.line([self.p(x + dx, y, z + dz), near, self.p(x, y + dy, z + dz)], color, width * 0.9)
        b.line([near, self.p(x + dx, y + dy, z)], color, width * 0.9)
        return top, left, right

    def cube(self, x, y, z=0.0, s=1.0, color="white", width=4.0):
        """Cubo del jugador (blanco, con las caras laterales sombreadas)."""
        m = (1 - s) / 2
        return self.box(x + m, y + m, z, s, s, s, color, width, hatch_color="grey")


# --- Dibujos -----------------------------------------------------------------

def cube_front(b, c, s, color="white", width=4.5, hatch="grey"):
    """Cubo del jugador en isométrico, centrado en c (en píxeles)."""
    iso = Iso(b, c[0], c[1] - s * 0.5, s)
    return iso.box(-0.5, -0.5, -0.5, 1, 1, 1, color, width, hatch_color=hatch)


def eyes(b, c, sep, r, look=(0.0, 0.0), angry=False, color="white"):
    for side in (-1, 1):
        e = (c[0] + side * sep, c[1])
        b.circle(e, r, r * 1.15, color, 3.5)
        p = (e[0] + look[0] * r * 0.45, e[1] + look[1] * r * 0.45)
        b.smear(b.circle_mask(p, r * 0.45), color, 0.9, 0.6)
        if angry:
            b.line([(e[0] + side * r * 1.1, e[1] - r * 1.9), (e[0] - side * r * 0.9, e[1] - r * 1.25)],
                   color, 4.5)


def draw_chaser(b):
    c, r = (300, 300), 140
    b.circle((c[0] + 10, 488), 130, 26, "grey", 3, alpha=0.5)
    b.hatch(b.circle_mask((c[0] + 10, 488), 124, 22), "grey", 9, 20, 2, 0.35)
    body = b.circle_mask(c, r)
    shade = body * (1 - b.circle_mask((c[0] - 38, c[1] - 40), r * 0.98))
    b.smear(body, "red", 0.16, 4)
    b.hatch(shade, "red", 9, -40, 2.6, 0.7)
    b.circle(c, r, color="red", width=5.5)
    b.line(b.ellipse_pts((c[0] - 55, c[1] - 62), 38, 22, 200, 290), "white", 3.5, alpha=0.6)
    eyes(b, (c[0] + 20, c[1] - 10), 42, 24, (1, 0.2), angry=True)
    b.line(b.curve((c[0] - 10, c[1] + 70), (c[0] + 30, c[1] + 50), (c[0] + 75, c[1] + 70)), "white", 4)
    # Botes.
    for k in (0, 1):
        y = 470 + k * 16
        b.line([(c[0] - 175 + k * 18, y), (c[0] - 125 + k * 18, y)], "red", 3, alpha=0.7)
    b.text("!", 480, 80, 90, "yellow", 6)
    b.text("!", 530, 95, 70, "yellow", 5)
    # El cubo, huyendo.
    cube_front(b, (590, 340), 74)
    for k, y in enumerate((300, 335, 370)):
        b.line([(500 - k * 10, y), (535, y)], "white", 3, alpha=0.7)


def octahedron(b, c, h, w, color, width=5.0):
    top, bot = (c[0], c[1] - h), (c[0], c[1] + h)
    l, r = (c[0] - w, c[1]), (c[0] + w, c[1])
    f, k = (c[0] - w * 0.25, c[1] + w * 0.32), (c[0] + w * 0.25, c[1] - w * 0.32)
    b.smear(b.poly_mask([top, r, bot, l]), color, 0.2, 3)
    b.hatch(b.poly_mask([top, f, r]), color, 10, -35, 2.4, 0.65)
    b.hatch(b.poly_mask([bot, f, r]), color, 7, 35, 2.4, 0.75)
    b.hatch(b.poly_mask([bot, l, f]), color, 13, -60, 2.0, 0.45)
    b.poly([top, r, bot, l], color, width)
    b.line([top, f, bot], color, width * 0.9)
    b.line([l, f, r], color, width * 0.9)
    b.line([top, k, bot], color, width * 0.5, alpha=0.45, passes=1)
    b.line([l, k, r], color, width * 0.5, alpha=0.45, passes=1)


def draw_patroller(b):
    iso = Iso(b, 320, 330, 58)
    cells = [(x, y) for x in range(-2, 3) for y in range(-2, 3) if abs(x) == 2 or abs(y) == 2]
    iso.tiles(cells, "grey", 2.2, alpha=0.5)
    route = [iso.p(-1.5, -1.5), iso.p(2.5, -1.5), iso.p(2.5, 2.5), iso.p(-1.5, 2.5)]
    route = [(p[0], p[1]) for p in route]
    for a, z in zip(route, route[1:] + route[:1]):
        mid = ((a[0] * 0.35 + z[0] * 0.65), (a[1] * 0.35 + z[1] * 0.65))
        b.dashed([a, mid], "purple", 3.5, 14, 10)
        b.arrow([(a[0] * 0.5 + z[0] * 0.5, a[1] * 0.5 + z[1] * 0.5), mid], "purple", 3.5, 14, passes=1)
        b.dashed([mid, z], "purple", 3.5, 14, 10)
    # El patrullero flotando sobre la esquina de la ruta, con su sombra.
    sp = iso.p(2.5, -1.5)
    b.circle((sp[0], sp[1]), 44, 18, "grey", 3, alpha=0.5)
    b.hatch(b.circle_mask(sp, 40, 15), "grey", 7, 20, 2, 0.4)
    octahedron(b, (sp[0], sp[1] - 120), 78, 56, "purple")
    b.line(b.ellipse_pts((sp[0], sp[1] - 120), 84, 20, 20, 160), "purple", 3, alpha=0.6)
    # El cubo esperando su momento en el centro.
    p = iso.p(0.5, 0.5)
    cube_front(b, (p[0], p[1] + 10), 70)
    b.text("?", p[0] + 45, p[1] - 100, 50, "yellow", 4.5)


def dodecahedron(b, c, R, color, width=5.0):
    outer = [(c[0] + math.cos(math.radians(-90 + i * 36)) * R,
              c[1] + math.sin(math.radians(-90 + i * 36)) * R) for i in range(10)]
    inner = [(c[0] + math.cos(math.radians(90 + i * 72)) * R * 0.5,
              c[1] + math.sin(math.radians(90 + i * 72)) * R * 0.5) for i in range(5)]
    mid = [(c[0] + math.cos(math.radians(90 + i * 72)) * R * 0.78,
            c[1] + math.sin(math.radians(90 + i * 72)) * R * 0.78) for i in range(5)]
    b.smear(b.poly_mask(outer), color, 0.18, 3)
    # Caras de la derecha y de abajo, sombreadas.
    for i in range(5):
        j = (i + 1) % 5
        face = [inner[i], mid[i], outer[(5 + 2 * i) % 10], mid[j], inner[j]]
        ang = math.degrees(math.atan2(inner[i][1] + inner[j][1] - 2 * c[1], inner[i][0] + inner[j][0] - 2 * c[0]))
        if -30 < ang < 150:
            b.hatch(b.poly_mask(face, -2), color, 8 if ang < 60 else 11, ang + 60, 2.4, 0.65)
    b.poly(outer, color, width)
    b.poly(inner, color, width * 0.9)
    for i in range(5):
        b.line([inner[i], mid[i], outer[(5 + 2 * i) % 10]], color, width * 0.85)
        b.line([mid[i], outer[(4 + 2 * i) % 10]], color, width * 0.85)
        b.line([mid[i], outer[(6 + 2 * i) % 10]], color, width * 0.85)


def draw_blocker(b):
    iso = Iso(b, 360, 290, 66)
    cells = [(x, 0) for x in range(-3, 4)]
    iso.tiles(cells, "grey", 2.2, alpha=0.5)
    for x in range(-3, 4):
        iso.box(x, -1, 0, 1, 1, 0.5, "grey", 2.6, shade=False)
    sp = iso.p(1.5, 0.5)
    b.circle((sp[0], sp[1] + 6), 58, 20, "grey", 3, alpha=0.5)
    dodecahedron(b, (sp[0], sp[1] - 66), 78, "teal")
    # El cubo choca y rebota.
    cp = iso.p(-1.5, 0.5)
    cube_front(b, (cp[0], cp[1] + 10), 76)
    b.burst((sp[0] - 95, sp[1] - 40), 10, 34, 7, "yellow", 3.5, 130, 250)
    b.arrow(b.curve((cp[0] + 30, cp[1] - 90), (cp[0] - 20, cp[1] - 170), (cp[0] - 110, cp[1] - 90)),
            "white", 4)
    # No hace daño: corazón entero.
    hc = (560, 470)
    heart = b.curve((hc[0], hc[1] + 34), (hc[0] - 70, hc[1] - 10), (hc[0] - 22, hc[1] - 30)) + \
        b.curve((hc[0] - 22, hc[1] - 30), (hc[0], hc[1] - 34), (hc[0], hc[1] - 12)) + \
        b.curve((hc[0], hc[1] - 12), (hc[0], hc[1] - 34), (hc[0] + 22, hc[1] - 30)) + \
        b.curve((hc[0] + 22, hc[1] - 30), (hc[0] + 70, hc[1] - 10), (hc[0], hc[1] + 34))
    b.smear(b.poly_mask(heart), "pink", 0.35, 2)
    b.line(heart, "pink", 4.5, overshoot=False)
    # Barrotes que lo encierran (a la derecha).
    bx = iso.p(3, 0)
    for k in range(4):
        y = bx[1] - 20 - k * 16
        b.line([(bx[0] - 52, y + 30), (bx[0] + 6, y - 4)], "grey", 3.5)


def draw_turn(b):
    iso = Iso(b, 360, 150, 70)
    cells = [(0, y) for y in range(-1, 3)] + [(x, 2) for x in range(1, 4)] + [(-1, 2), (-2, 2)]
    iso.tiles(cells, "grey", 2.2, alpha=0.5)
    p = iso.p(0.5, 2.5)
    cube_front(b, (p[0], p[1] + 8), 74)
    # De dónde viene y hacia dónde puede girar.
    b.dashed([iso.p(0.5, -0.5), iso.p(0.5, 1.4)], "white", 3.5, 14, 10, arrow=True)
    b.arrow(b.curve(iso.p(0.7, 1.7, 1.4), iso.p(1.0, 2.6, 1.6), iso.p(2.3, 2.5, 1.2)), "red", 5, 18)
    b.arrow(b.curve(iso.p(0.3, 1.7, 1.4), iso.p(0.2, 2.6, 1.6), iso.p(0.3, 3.9, 1.2)), "blue", 5, 18)
    # El móvil: tocar la mitad izquierda o la derecha.
    x0, y0, w, h = 210, 470, 300, 110
    b.poly([(x0, y0), (x0 + w, y0), (x0 + w, y0 + h), (x0, y0 + h)], "white", 3.5)
    b.dashed([(x0 + w / 2, y0 + 8), (x0 + w / 2, y0 + h - 8)], "grey", 2.5, 8, 7)
    for cx, col in ((x0 + w * 0.25, "blue"), (x0 + w * 0.75, "red")):
        b.circle((cx, y0 + h / 2), 22, color=col, width=4)
        b.circle((cx, y0 + h / 2), 36, color=col, width=2.5, alpha=0.5)


def draw_reverse(b):
    iso = Iso(b, 360, 255, 72)
    cells = [(x, 0) for x in range(-3, 4)]
    iso.tiles(cells, "grey", 2.2, alpha=0.5)
    p = iso.p(0.5, 0.5)
    for dx, dy in ((-115, -10), (115, 10), (-40, 60), (50, -70)):
        b.cloud((p[0] + dx, p[1] + dy), 48, "grey", 3)
    cube_front(b, (p[0], p[1] + 8), 80)
    # Media vuelta: flecha en U sobre el cubo.
    a = iso.p(-0.6, 0.5, 2.0)
    z = iso.p(1.6, 0.5, 2.0)
    u = b.curve(a, (p[0] + 10, p[1] - 290), z)
    b.arrow(u[::-1], "yellow", 5.5, 20)
    b.dashed([iso.p(-2.6, 0.5), iso.p(-1.0, 0.5)], "white", 3.5, 14, 10, arrow=True)
    # Cuenta como dos giros.
    b.text("x2", 470, 430, 90, "yellow", 6)
    # Las dos mitades a la vez.
    x0, y0, w, h = 120, 450, 250, 100
    b.poly([(x0, y0), (x0 + w, y0), (x0 + w, y0 + h), (x0, y0 + h)], "white", 3.5)
    b.dashed([(x0 + w / 2, y0 + 8), (x0 + w / 2, y0 + h - 8)], "grey", 2.5, 8, 7)
    for cx in (x0 + w * 0.25, x0 + w * 0.75):
        b.circle((cx, y0 + h / 2), 20, color="yellow", width=4)
        b.circle((cx, y0 + h / 2), 32, color="yellow", width=2.5, alpha=0.5)
    b.text("+", x0 + w / 2 - 18, y0 + h / 2 - 34, 46, "white", 4)


def swipe(b, x, y, up=True, color="yellow"):
    """Móvil con un dedo deslizando hacia arriba o hacia abajo."""
    b.poly([(x - 48, y - 80), (x + 48, y - 80), (x + 48, y + 80), (x - 48, y + 80)], "white", 3.5)
    b.line([(x - 12, y - 68), (x + 12, y - 68)], "grey", 3)
    a, z = ((x, y + 45), (x, y - 50)) if up else ((x, y - 45), (x, y + 50))
    b.circle(a, 15, color=color, width=3.5)
    b.arrow([a, z], color, 4.5, 16)


def draw_dash(b):
    iso = Iso(b, 300, 250, 72)
    cells = [(x, 0) for x in range(-3, 4)]
    iso.tiles(cells, "grey", 2.2, alpha=0.5)
    p = iso.p(-0.2, 0.5)
    # Líneas de velocidad detrás del cubo.
    for k, dy in enumerate((-45, -10, 25, 60)):
        a = (p[0] - 220 + k * 15, p[1] - 60 + dy - 40 + k * 6)
        z = (p[0] - 70, p[1] - 60 + dy + 15)
        b.line([a, z], "white", 3.5, alpha=0.75)
    cube_front(b, (p[0] + 10, p[1] + 10), 82)
    # El muro destructible saltando en pedazos.
    w0 = iso.p(1.8, 0.5)
    b.burst((w0[0] - 30, w0[1] - 60), 30, 80, 9, "yellow", 4, -80, 80)
    for dx, dy, s, rot in ((40, -150, 26, 20), (95, -95, 22, -15), (70, -10, 30, 40),
                           (130, -170, 18, 10), (150, -40, 20, -30)):
        cx, cy = w0[0] + dx, w0[1] + dy
        pts = [(cx + math.cos(math.radians(rot + a)) * s, cy + math.sin(math.radians(rot + a)) * s * 0.8)
               for a in (0, 80, 170, 250)]
        b.hatch(b.poly_mask(pts), "brown", 7, rot, 2, 0.6)
        b.poly(pts, "brown", 3.5)
    # Un enemigo aplastado.
    e = (w0[0] + 40, w0[1] + 70)
    b.circle(e, 30, 16, "red", 3.5)
    b.text("x", e[0] - 22, e[1] - 22, 24, "red", 3)
    b.text("x", e[0] + 2, e[1] - 22, 24, "red", 3)
    swipe(b, 610, 470, True)


def draw_stomp(b):
    iso = Iso(b, 360, 290, 50)
    cells = [(x, y) for x in range(-2, 3) for y in range(-2, 3)]
    zone = b.poly_mask([iso.p(-2, -2), iso.p(3, -2), iso.p(3, 3), iso.p(-2, 3)])
    b.smear(zone, "yellow", 0.13, 6)
    iso.tiles(cells, "grey", 2.0, alpha=0.5)
    b.poly([iso.p(-2, -2), iso.p(3, -2), iso.p(3, 3), iso.p(-2, 3)], "yellow", 3.5, alpha=0.8)
    c = iso.p(0.5, 0.5)
    for k, r in enumerate((60, 110, 160)):
        b.line(b.ellipse_pts(c, r, r * 0.5, 0, 360), "white", 3.5 - k * 0.6, alpha=0.8 - k * 0.2,
               overshoot=False)
    # Grietas desde el centro.
    for a in (20, 150, 260, 320):
        pts = [c]
        for k in range(1, 4):
            t = math.radians(a + b.rng.uniform(-14, 14))
            pts.append((c[0] + math.cos(t) * 26 * k, c[1] + math.sin(t) * 13 * k))
        b.line(pts, "white", 2.6, alpha=0.7)
    # Enemigos saltando por los aires.
    for e, col in ((iso.p(-1.3, 1.6, 1.6), "red"), (iso.p(2.4, -0.6, 1.8), "purple")):
        b.circle(e, 20, color=col, width=3.5)
        b.text("x", e[0] - 15, e[1] - 14, 16, col, 2.6)
        b.text("x", e[0] + 1, e[1] - 14, 16, col, 2.6)
        b.burst(e, 26, 40, 6, col, 2.5)
    # El cubo cayendo con fuerza.
    top = (c[0], c[1] - 160)
    for dx in (-40, 0, 40):
        b.line([(top[0] + dx, top[1] - 120), (top[0] + dx, top[1] - 70)], "white", 3, alpha=0.7)
    cube_front(b, top, 80)
    b.arrow([(top[0] + 95, top[1] - 30), (top[0] + 95, top[1] + 120)], "yellow", 5, 18)
    swipe(b, 625, 470, False)


def zigzag(b, a, z, rnd, color="cyan", width=3.5, steps=5, amp=14.0):
    """Rayo quebrado de a hasta z."""
    dx, dy = z[0] - a[0], z[1] - a[1]
    n = math.hypot(dx, dy) or 1.0
    px, py = -dy / n, dx / n
    pts = [a]
    for i in range(1, steps):
        t = i / steps
        k = amp * (1 if i % 2 else -1) * rnd.uniform(0.6, 1.2)
        pts.append((a[0] + dx * t + px * k, a[1] + dy * t + py * k))
    pts.append(z)
    b.line(pts, color, width)


def draw_immunity(b):
    rnd = random.Random(31)
    c = (330, 320)
    # Centro del aura (el cubo se dibuja algo por encima de c).
    ac = (330, 290)
    iso = Iso(b, 330, 300, 80)
    iso.tiles([(x, y) for x in range(-2, 2) for y in range(-1, 2)], "grey", 2.2, alpha=0.4)
    # El cubo, «disuelto»: trazos de tiza más finos y borrosos con motas.
    b.smear(b.circle_mask(ac, 150, 130), "cyan", 0.12, 8)
    cube_front(b, c, 110, "cyan", 3.5, hatch="cyan")
    for k in range(26):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(40, 120)
        q = (ac[0] + math.cos(a) * r, ac[1] + math.sin(a) * r * 0.85)
        b.smear(b.circle_mask(q, rnd.uniform(2, 5)), "white", 0.8, 0.6)
    # Aura eléctrica alrededor, con chispas.
    ring = [(ac[0] + math.cos(math.radians(a)) * (150 + rnd.uniform(-10, 10)),
             ac[1] + math.sin(math.radians(a)) * (128 + rnd.uniform(-10, 10))) for a in range(0, 360, 15)]
    b.poly(ring, "cyan", 3.5)
    for a in (20, 95, 160, 250, 320):
        t = math.radians(a)
        p0 = (ac[0] + math.cos(t) * 150, ac[1] + math.sin(t) * 128)
        p1 = (ac[0] + math.cos(t) * 200, ac[1] + math.sin(t) * 172)
        zigzag(b, p0, p1, rnd, "cyan", 3, 3, 9)
    # Un perseguidor rebota contra el aura.
    e = (95, 210)
    b.circle(e, 42, color="red", width=4.5)
    b.hatch(b.circle_mask(e, 40), "red", 9, -40, 2.4, 0.55)
    b.text("x", e[0] - 30, e[1] - 22, 26, "red", 3)
    b.text("x", e[0] + 4, e[1] - 22, 26, "red", 3)
    b.burst((185, 215), 10, 38, 9, "yellow", 3.5)
    b.arrow([(150, 175), (85, 120)], "white", 4)
    # Y un láser se deshace al chocar con ella.
    s, z = (690, 370), (482, 345)
    b.line([s, z], "red", 6)
    b.line([s, z], "white", 2, alpha=0.8, passes=1)
    b.burst(z, 10, 34, 9, "red", 3)
    # Arriba, el gesto: el dedo desliza hacia un lado (da igual cuál).
    x, y = 590, 110
    b.poly([(x - 48, y - 80), (x + 48, y - 80), (x + 48, y + 80), (x - 48, y + 80)], "white", 3.5)
    b.line([(x - 12, y - 68), (x + 12, y - 68)], "grey", 3)
    b.circle((x, y + 5), 15, color="cyan", width=3.5)
    b.arrow([(x - 34, y + 5), (x - 100, y + 5)], "cyan", 4.5, 16)
    b.arrow([(x + 34, y + 5), (x + 100, y + 5)], "cyan", 4.5, 16)


def draw_speed(b):
    c = (330, 240)
    # Cubito translúcido: apenas el contorno y un poco de color.
    iso = Iso(b, c[0], c[1] - 60, 120)
    b.smear(iso.mask(-0.5, -0.5, -0.5, 1, 1, 1), "cyan", 0.22, 4)
    iso.box(-0.5, -0.5, -0.5, 1, 1, 1, "cyan", 4.5, shade=False)
    b.line([iso.p(-0.5, -0.5, -0.5), iso.p(0.5, -0.5, -0.5)], "cyan", 2.5, alpha=0.35, passes=1)
    b.line([iso.p(-0.5, -0.5, -0.5), iso.p(-0.5, 0.5, -0.5)], "cyan", 2.5, alpha=0.35, passes=1)
    b.line([iso.p(-0.5, -0.5, -0.5), iso.p(-0.5, -0.5, 0.5)], "cyan", 2.5, alpha=0.35, passes=1)
    for s in ((c[0] - 120, c[1] - 120, 18), (c[0] + 125, c[1] - 90, 14), (c[0] + 100, c[1] + 95, 12)):
        b.sparkle(s[:2], s[2], "cyan", 3)
    # Rayo.
    bolt = [(500, 110), (455, 210), (500, 205), (455, 310)]
    b.smear(b.poly_mask([(500, 110), (450, 214), (494, 210), (455, 310), (515, 196), (472, 200)]),
            "yellow", 0.4, 2)
    b.line(bolt, "yellow", 5)
    # Abajo: el cubo rodando deprisa con su estela de polvo.
    gp = (520, 470)
    for k, (dx, r) in enumerate(((-330, 20), (-270, 26), (-200, 32), (-125, 36))):
        b.cloud((gp[0] + dx, gp[1] + 30 - k * 3), r, "brown", 3)
    cube_front(b, gp, 72)
    for y in (430, 460, 490):
        b.line([(gp[0] - 110, y), (gp[0] - 60, y)], "white", 3, alpha=0.6)
    b.text("x2", 590, 400, 60, "yellow", 5)


def key_shape(b, c, s, color, width=5.0, angle=-30.0):
    ca, sa = math.cos(math.radians(angle)), math.sin(math.radians(angle))

    def t(x, y):
        return (c[0] + (x * ca - y * sa) * s, c[1] + (x * sa + y * ca) * s)
    ring = [t(math.cos(a) * 0.55 - 1.2, math.sin(a) * 0.55) for a in np.linspace(0, math.tau, 40)]
    b.smear(b.poly_mask(ring), color, 0.25, 2)
    b.line(ring, color, width, overshoot=False)
    hole = [t(math.cos(a) * 0.22 - 1.2, math.sin(a) * 0.22) for a in np.linspace(0, math.tau, 24)]
    b.line(hole, color, width * 0.8, overshoot=False)
    shaft = [t(-0.65, -0.12), t(1.4, -0.12), t(1.4, 0.12), t(-0.65, 0.12)]
    b.hatch(b.poly_mask(shaft), color, 6, angle + 70, 2, 0.6)
    b.line([t(-0.65, -0.12), t(1.4, -0.12)], color, width)
    b.line([t(-0.65, 0.12), t(0.6, 0.12), t(0.6, 0.5), t(0.85, 0.5), t(0.85, 0.12), t(1.0, 0.12),
            t(1.0, 0.38), t(1.25, 0.38), t(1.25, 0.12), t(1.4, 0.12), t(1.4, -0.12)], color, width)


def draw_key(b):
    key_shape(b, (300, 230), 120, "yellow", 6)
    b.sparkle((470, 120), 22, "yellow")
    b.sparkle((160, 330), 14, "yellow")
    # Las cinco llaves de colores, pequeñas.
    for i, col in enumerate(("yellow", "orange", "red", "blue", "green")):
        key_shape(b, (90 + i * 92, 450), 26, col, 3.5, -10)
    # Llave sobre el cubo: solo se puede llevar una.
    cube_front(b, (585, 360), 70)
    key_shape(b, (585, 250), 30, "yellow", 3.5, 0)
    b.arrow([(585, 290), (585, 300)], "yellow", 3, 10, passes=1)


def draw_golden(b):
    c, r = (360, 270), 115
    # Rayos de luz alrededor.
    for i in range(14):
        t = math.radians(i * 360 / 14 + 8)
        long = i % 2 == 0
        r0, r1 = r * 1.15, r * (2.0 if long else 1.6)
        w = 0.07 if long else 0.05
        ray = [(c[0] + math.cos(t - w) * r0, c[1] + math.sin(t - w) * r0),
               (c[0] + math.cos(t) * r1, c[1] + math.sin(t) * r1),
               (c[0] + math.cos(t + w) * r0, c[1] + math.sin(t + w) * r0)]
        b.smear(b.poly_mask(ray), "yellow", 0.3 if long else 0.2, 3)
        b.line(ray, "yellow", 3.2, alpha=0.75 if long else 0.5)
    b.smear(b.circle_mask(c, r * 1.1), "yellow", 0.18, 18)
    # Cubo apoyado en un vértice: un hexágono con una Y dentro.
    hexa = [(c[0] + math.cos(math.radians(-90 + i * 60)) * r, c[1] + math.sin(math.radians(-90 + i * 60)) * r)
            for i in range(6)]
    b.smear(b.poly_mask(hexa), "yellow", 0.3, 2)
    left = [c, hexa[3], hexa[4], hexa[5]]
    right = [c, hexa[1], hexa[2], hexa[3]]
    b.hatch(b.poly_mask(left, -2), "orange", 12, 30, 2.4, 0.6)
    b.hatch(b.poly_mask(right, -2), "orange", 7, -30, 2.6, 0.75)
    b.poly(hexa, "yellow", 6)
    for k in (1, 3, 5):
        b.line([c, hexa[k]], "yellow", 5)
    # Flota.
    b.arrow([(c[0] - 175, c[1] + 40), (c[0] - 175, c[1] - 40)], "white", 3.5, 14, both=True)
    b.circle((c[0], 520), 70, 14, "grey", 3, alpha=0.5)
    for s in ((150, 110, 20), (575, 150, 16), (560, 420, 22), (170, 440, 13)):
        b.sparkle(s[:2], s[2])


def draw_breakable(b):
    iso = Iso(b, 300, 270, 170)
    b.smear(iso.mask(0, 0, 0, 1, 1, 1), "brown", 0.18, 3)
    iso.box(0, 0, 0, 1, 1, 1, "white", 5, shade=False)
    # Ladrillos en las caras laterales.
    for axis in ("y", "x"):
        for k in (1, 2, 3):
            z = k / 4
            if axis == "y":
                a, z2 = iso.p(0, 1, z), iso.p(1, 1, z)
            else:
                a, z2 = iso.p(1, 0, z), iso.p(1, 1, z)
            b.line([a, z2], "grey", 2.6, alpha=0.7)
        for k in range(4):
            off = 0.25 if k % 2 else 0.5
            for t in (off, off + 0.5) if off < 0.5 else (off,):
                if t >= 1:
                    continue
                zz = (k / 4, (k + 1) / 4)
                if axis == "y":
                    b.line([iso.p(t, 1, zz[0]), iso.p(t, 1, zz[1])], "grey", 2.4, alpha=0.7)
                else:
                    b.line([iso.p(1, t, zz[0]), iso.p(1, t, zz[1])], "grey", 2.4, alpha=0.7)
    # Grietas.
    for start, ang in ((iso.p(1, 0.35, 1), 100), (iso.p(1, 1, 0.55), 160), (iso.p(0.5, 1, 1), 70),
                       (iso.p(1, 0.8, 0.25), 20)):
        pts = [start]
        for _ in range(5):
            t = math.radians(ang + b.rng.uniform(-35, 35))
            l = b.rng.uniform(16, 28)
            pts.append((pts[-1][0] + math.cos(t) * l, pts[-1][1] + math.sin(t) * l))
        b.line(pts, "white", 3.2)
        b.line([pts[2], (pts[2][0] + 18, pts[2][1] + 10)], "white", 2.2, alpha=0.8)
    # El cubo golpeando.
    b.burst((560, 330), 18, 50, 9, "yellow", 4, 120, 250)
    cube_front(b, (620, 380), 70)
    # Golpes que aguanta: 5 a 1.
    for i in range(5):
        x = 120 + i * 30
        b.line([(x, 520), (x + 6, 470)], "yellow", 4)
    b.line([(105, 510), (275, 478)], "yellow", 4)


def draw_door(b):
    iso = Iso(b, 290, 280, 170)
    b.smear(iso.mask(0, 0, 0, 1, 1, 1), "orange", 0.3, 3)
    iso.box(0, 0, 0, 1, 1, 1, "orange", 5, hatch_color="orange")
    # Cerradura en la cara de delante.
    k = iso.p(0.5, 1, 0.55)
    b.circle(k, 18, 22, "white", 4)
    b.line([(k[0], k[1] + 18), (k[0] - 8, k[1] + 55), (k[0] + 8, k[1] + 55), (k[0], k[1] + 18)],
           "white", 4)
    # La llave volando hacia la puerta.
    key_shape(b, (560, 150), 42, "orange", 4.5, 20)
    b.dashed(b.curve((520, 205), (470, 300), (k[0] + 30, k[1] + 20)), "white", 3.5, 14, 10, arrow=True)
    # Choque de frente.
    cube_front(b, (580, 420), 74)
    b.arrow([(520, 440), (430, 470)], "white", 4)
    b.burst((395, 470), 14, 40, 7, "yellow", 3.5, 100, 260)


def draw_bars(b):
    iso = Iso(b, 250, 200, 100)
    iso.tiles([(0, y) for y in range(-1, 3)], "grey", 2.2, alpha=0.5)
    iso.box(-1, 0, 0, 1, 1, 0.9, "grey", 3.5, shade=True)
    # Cinco lanzas de muro a muro, con la punta alterna.
    for k in range(5):
        z = 0.12 + k * 0.17
        a, z2 = iso.p(0.0, 0.5, z), iso.p(1.0, 0.5, z)
        b.line([a, z2], "white", 4)
        tip, prev = (z2, a) if k % 2 == 0 else (a, z2)
        d = np.array(tip) - np.array(prev)
        d /= np.linalg.norm(d)
        n = np.array([-d[1], d[0]])
        b.line([tuple(np.array(tip) - d * 14 + n * 7), tip, tuple(np.array(tip) - d * 14 - n * 7)],
               "white", 3)
    iso.box(1, 0, 0, 1, 1, 0.9, "grey", 3.5, shade=True)
    # El botón en otro muro.
    bi = Iso(b, 560, 300, 92)
    bi.box(0, 0, 0, 1, 1, 1.0, "grey", 3.5)
    p = bi.p(0.5, 1, 0.5)
    b.poly([(p[0] - 30, p[1] - 18), (p[0] + 30, p[1] - 2), (p[0] + 30, p[1] + 40), (p[0] - 30, p[1] + 24)],
           "white", 3.5)
    b.smear(b.circle_mask((p[0], p[1] + 11), 15), "red", 0.8, 1)
    b.circle((p[0], p[1] + 11), 16, color="red", width=4)
    # El botón cambia los barrotes.
    b.dashed(b.curve((p[0] - 50, p[1] - 20), (420, 240), iso.p(1.0, 0.5, 1.0)), "yellow", 3.5, 14, 10,
             arrow=True)
    cube_front(b, (420, 520), 64)
    b.arrow([(470, 500), (515, 470)], "white", 4)


def draw_void(b):
    iso = Iso(b, 270, 185, 64)
    cells = [(x, y) for x in range(-1, 2) for y in range(-1, 3)]
    for x, y in cells:
        b.poly([iso.p(x, y), iso.p(x + 1, y), iso.p(x + 1, y + 1), iso.p(x, y + 1)], "grey", 2.2,
               alpha=0.5, passes=1)
    # Grosor de la isla y roca de debajo.
    b.line([iso.p(2, -1), iso.p(2, -1, -0.8), iso.p(2, 3, -0.8), iso.p(-1, 3, -0.8), iso.p(-1, 3)],
           "brown", 3.5)
    b.line([iso.p(2, 3), iso.p(2, 3, -0.8)], "brown", 3.5)
    b.hatch(b.poly_mask([iso.p(2, -1), iso.p(2, 3), iso.p(2, 3, -0.8), iso.p(2, -1, -0.8)]), "brown", 9,
            -60, 2, 0.45)
    b.line([iso.p(2, -1), iso.p(2, 3), iso.p(-1, 3)], "white", 4)
    # El cubo cayendo dando vueltas.
    cube_front(b, iso.p(2.6, 0.4, 0.4), 62)
    b.arrow(b.curve(iso.p(1.2, 0.5, 1.4), iso.p(2.3, 0.5, 2.2), iso.p(2.9, 0.4, 1.2)), "white", 4)
    q = iso.p(3.6, 0.6, -2.7)
    b.dashed(b.curve(iso.p(2.9, 0.4, -0.4), iso.p(3.4, 0.5, -1.0), q), "white", 3.5, 12, 9, arrow=True)
    b.burst((q[0] + 20, q[1] + 40), 14, 46, 11, "orange", 4)
    b.burst((q[0] + 20, q[1] + 40), 8, 26, 7, "yellow", 3)
    # Ondas de vacío.
    for k in range(3):
        y = 520 + k * 22
        pts = [(80 + i * 12, y + math.sin(i * 0.9 + k) * 6) for i in range(14)]
        b.line(pts, "grey", 2.5, alpha=0.4, passes=1)


def draw_bridge(b):
    iso = Iso(b, 120, 200, 74)
    for x in (0, 1):
        iso.box(x, 0, -0.5, 1, 1, 0.5, "grey", 3, shade=False)
    for x in (6, 7):
        iso.box(x, 0, -0.5, 1, 1, 0.5, "grey", 3, shade=False)
    # Tablas del puente.
    for i in range(12):
        x = 2 + i / 3
        sag = -0.25 * math.sin(math.pi * (x - 2) / 4)
        crack = i == 7
        pts = [iso.p(x + 0.04, 0.05, sag), iso.p(x + 0.29, 0.05, sag), iso.p(x + 0.29, 0.95, sag),
               iso.p(x + 0.04, 0.95, sag)]
        col = "brown"
        if crack:
            b.line([pts[0], iso.p(x + 0.2, 0.5, sag), pts[2]], "white", 2.6)
        b.hatch(b.poly_mask(pts), col, 9, 30, 2, 0.5)
        b.poly(pts, col, 3)
        if crack:
            for k in range(4):
                d = iso.p(x + 0.17 + b.rng.uniform(-0.1, 0.1), 0.6, sag - 0.4 - k * 0.35)
                b.line([d, (d[0] + 1, d[1] + 4)], "brown", 3.5, overshoot=False)
    for y in (0, 1):
        rope = [iso.p(2 + t * 4, y, 0.55 - 0.45 * math.sin(math.pi * t)) for t in np.linspace(0, 1, 20)]
        b.line(rope, "white", 3.2)
        for t in np.linspace(0.08, 0.92, 7):
            x = 2 + t * 4
            b.line([iso.p(x, y, 0.55 - 0.45 * math.sin(math.pi * t)),
                    iso.p(x, y, -0.25 * math.sin(math.pi * t))], "grey", 2, alpha=0.7, passes=1)
    for x in (2, 6):
        for y in (0, 1):
            b.line([iso.p(x, y, 0), iso.p(x, y, 0.7)], "brown", 5)
    cube_front(b, iso.p(3.2, 0.5, 0.0), 58)
    b.arrow([iso.p(3.9, 0.5, 0.9), iso.p(5, 0.5, 0.9)], "white", 4)
    # Estabilidad: 4 salidas, la última rompe.
    for i in range(4):
        x0 = 150 + i * 60
        pts = [(x0, 500), (x0 + 44, 500), (x0 + 44, 530), (x0, 530)]
        if i < 3:
            b.hatch(b.poly_mask(pts), "brown", 7, 30, 2, 0.6)
        b.poly(pts, "brown", 3)
    b.text("!", 400, 470, 60, "yellow", 5)


def teleport_pad(b, c, color):
    b.smear(b.circle_mask(c, 70, 34), color, 0.25, 6)
    b.circle(c, 70, 34, color, 4.5)
    pts = []
    for t in np.linspace(0, 3.2 * math.pi, 60):
        r = 6 + t * 5.6
        pts.append((c[0] + math.cos(t) * r, c[1] + math.sin(t) * r * 0.48))
    b.line(pts, color, 3.5, alpha=0.85)
    for dx in (-48, -16, 16, 48):
        h = 70 + abs(dx) * -0.5 + b.rng.uniform(-10, 10)
        b.line([(c[0] + dx, c[1] - 6), (c[0] + dx * 0.9, c[1] - h)], color, 2.5, alpha=0.5, passes=1)


def draw_teleport(b):
    a, z = (190, 400), (540, 230)
    teleport_pad(b, a, "cyan")
    teleport_pad(b, z, "cyan")
    b.dashed(b.curve((a[0] + 30, a[1] - 90), (330, 40), (z[0] - 20, z[1] - 90)), "white", 3.5, 14, 10,
             arrow=True)
    cube_front(b, (a[0] - 10, a[1] - 40), 66)
    b.line([(a[0] - 60, a[1] - 80), (a[0] - 52, a[1] - 72)], "cyan", 2.5)
    # Sale con el mismo rumbo.
    b.arrow([(z[0] + 60, z[1] + 30), (z[0] + 150, z[1] + 75)], "white", 4)
    b.arrow([(a[0] - 150, a[1] - 60), (a[0] - 75, a[1] - 22)], "white", 4)
    # Los enemigos no pueden seguirte.
    e = (460, 470)
    b.circle(e, 30, color="red", width=4)
    eyes(b, (e[0] + 4, e[1] - 4), 10, 6, (0, 0))
    b.circle((e[0] + 80, e[1]), 32, color="white", width=3.5, alpha=0.8)
    b.line([(e[0] + 58, e[1] - 22), (e[0] + 102, e[1] + 22)], "white", 3.5)


def draw_spikes(b):
    iso = Iso(b, 330, 150, 210)
    plate = [iso.p(0.08, 0.08, 0.05), iso.p(0.92, 0.08, 0.05), iso.p(0.92, 0.92, 0.05), iso.p(0.08, 0.92, 0.05)]
    b.smear(b.poly_mask(plate), "grey", 0.25, 3)
    b.poly(plate, "white", 4.5)
    b.line([iso.p(0.92, 0.08, 0.05), iso.p(0.92, 0.08, 0), iso.p(0.92, 0.92, 0), iso.p(0.08, 0.92, 0),
            iso.p(0.08, 0.92, 0.05)], "white", 3)
    for hx, hy in ((0.3, 0.3), (0.7, 0.3), (0.3, 0.7), (0.7, 0.7)):
        h = iso.p(hx, hy, 0.05)
        b.circle(h, 20, 10, "white", 3)
        if (hx, hy) != (0.3, 0.3):
            tip = iso.p(hx, hy, 0.95)
            spear = [(h[0] - 12, h[1]), tip, (h[0] + 12, h[1])]
            b.hatch(b.poly_mask(spear), "grey", 6, 80, 2, 0.6)
            b.line(spear, "white", 4)
        else:
            # Asomando.
            tip = iso.p(hx, hy, 0.35)
            b.line([(h[0] - 10, h[1]), tip, (h[0] + 10, h[1])], "white", 3.5)
    # La placa tiembla antes de salir.
    for side in (-1, 1):
        for k in (0, 1):
            x = 330 + side * (205 + k * 22)
            b.line(b.curve((x, 330), (x + side * 10, 360), (x, 390)), "yellow", 3.2, alpha=0.8)
    b.text("!", 590, 80, 80, "yellow", 6)
    # Ritmo: espera, aviso, fuera.
    y = 520
    b.line([(110, y), (330, y)], "grey", 3)
    b.line([(330, y), (370, y)], "yellow", 4)
    b.line([(370, y), (370, y - 50), (440, y - 50), (440, y), (600, y)], "red", 4)


def draw_laser(b):
    iso = Iso(b, 330, 200, 96)
    iso.box(-1, 0, 0, 1, 1, 1, "grey", 4, shade=True)
    iso.box(0, 0, 0, 1, 1, 1, "grey", 4, shade=True)
    iso.tiles([(x, 1) for x in range(-1, 4)] + [(0, 2), (0, 3)], "grey", 2.2, alpha=0.4)
    # Placa con el cañón en la cara que da al pasillo.
    m = iso.p(0.5, 1, 0.45)
    b.circle(m, 38, 30, "white", 4)
    for i in range(8):
        t = math.radians(i * 45)
        p = (m[0] + math.cos(t) * 30, m[1] + math.sin(t) * 23)
        b.smear(b.circle_mask(p, 4), "red", 0.95, 0.5)
    b.circle(m, 14, 11, "white", 4)
    b.burst(m, 46, 66, 10, "red", 2.8)
    # El láser avanza en línea recta.
    s, e = iso.p(0.5, 1.3, 0.45), iso.p(0.5, 3.4, 0.45)
    b.smear(b.poly_mask([(s[0] - 10, s[1]), (s[0] + 10, s[1]), (e[0] + 10, e[1]), (e[0] - 10, e[1])]),
            "red", 0.6, 5)
    b.line([s, e], "red", 6)
    b.line([s, e], "white", 2, alpha=0.8, passes=1)
    b.burst(e, 8, 30, 8, "red", 3)
    cube_front(b, iso.p(1.5, 3.5, 0), 66)
    b.arrow([iso.p(2.6, 3.5, 0.5), iso.p(1.9, 3.5, 0.5)], "white", 4)
    b.text("!", 600, 70, 80, "red", 6)


def draw_mortar(b):
    iso = Iso(b, 230, 190, 56)
    zone_c = (5, 2)
    cells = [(x, y) for x in range(zone_c[0] - 2, zone_c[0] + 3) for y in range(zone_c[1] - 2, zone_c[1] + 3)]
    zone = b.poly_mask([iso.p(3, 0), iso.p(8, 0), iso.p(8, 5), iso.p(3, 5)])
    b.smear(zone, "red", 0.22, 4)
    b.hatch(zone, "red", 12, 15, 2, 0.4)
    iso.tiles(cells, "grey", 2, alpha=0.4)
    b.poly([iso.p(3, 0), iso.p(8, 0), iso.p(8, 5), iso.p(3, 5)], "red", 3.5)
    iso.box(0, 1, 0, 1, 1, 0.8, "grey", 4)
    # Cañón encima del muro.
    base = iso.p(0.5, 1.5, 0.8)
    b.circle((base[0], base[1] - 4), 34, 16, "white", 4)
    mouth = (base[0] + 40, base[1] - 85)
    barrel = [(base[0] - 14, base[1] - 10), (mouth[0] - 18, mouth[1] - 6), (mouth[0] + 10, mouth[1] + 10),
              (base[0] + 22, base[1] - 4)]
    b.hatch(b.poly_mask(barrel), "grey", 7, 30, 2, 0.6)
    b.poly(barrel, "white", 4.5)
    b.cloud((mouth[0] - 6, mouth[1] - 28), 26, "grey", 3)
    # Trayectoria.
    land = iso.p(5.5, 2.5)
    b.dashed(b.curve((mouth[0] + 10, mouth[1] - 10), (320, -100), (land[0], land[1] - 40)), "white", 3.5,
             14, 10, arrow=True)
    # La bomba con la mecha encendida.
    bc = (land[0], land[1] - 20)
    dodec = [(bc[0] + math.cos(math.radians(i * 36)) * 30, bc[1] + math.sin(math.radians(i * 36)) * 28)
             for i in range(10)]
    b.hatch(b.poly_mask(dodec), "grey", 6, -30, 2, 0.6)
    b.poly(dodec, "white", 4.5)
    fuse = [(bc[0] + 8, bc[1] - 28), (bc[0] + 18, bc[1] - 44), (bc[0] + 10, bc[1] - 56)]
    b.line(fuse, "white", 3.5)
    b.burst(fuse[-1], 4, 18, 8, "yellow", 2.6)
    cube_front(b, iso.p(3.6, 4.5, 0), 56)
    b.arrow([iso.p(2.9, 4.6, 0.6), iso.p(1.6, 4.6, 0.6)], "white", 4)


DRAWINGS = {
    "chaser": draw_chaser, "patroller": draw_patroller, "blocker": draw_blocker,
    "turn": draw_turn, "reverse": draw_reverse, "dash": draw_dash, "stomp": draw_stomp,
    "immunity": draw_immunity,
    "speed": draw_speed, "key": draw_key, "golden_cube": draw_golden,
    "breakable": draw_breakable, "door": draw_door, "bars": draw_bars, "void": draw_void,
    "bridge": draw_bridge, "teleport": draw_teleport, "spikes": draw_spikes, "laser": draw_laser,
    "mortar": draw_mortar,
}


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    ids = sys.argv[1:] or list(DRAWINGS)
    for name in ids:
        b = Board(zlib.crc32(name.encode()))
        DRAWINGS[name](b)
        b.save(OUT_DIR / f"{name}.png")
        print(f"ui/encyclopedia/{name}.png")


if __name__ == "__main__":
    main()
