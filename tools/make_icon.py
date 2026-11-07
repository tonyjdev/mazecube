"""Genera el icono de Maze Cube: icon.svg y los PNG del lanzador de Android."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

# Uso (desde la raíz del repositorio): python3 tools/make_icon.py
root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent
BG = "#3c3228"
BG_DARK = "#2e261e"
WALL = "#525c73"
WALL_TOP = "#6b7894"
TOP, LEFT, RIGHT = "#fad94d", "#4db3f2", "#e64d4d"
OUTLINE = "#2a211a"

# Muros del laberinto de fondo (en un lienzo de 512): rectángulos x, y, w, h.
WALLS = [(40, 40, 170, 34), (40, 40, 34, 160), (300, 40, 172, 34), (438, 40, 34, 200),
         (40, 300, 34, 172), (40, 438, 180, 34), (300, 438, 172, 34), (438, 330, 34, 142)]


def cube(cx, cy, s):
    """Vértices de un cubo isométrico de lado s centrado en (cx, cy)."""
    h = s * 0.5
    top = [(cx, cy - s), (cx + s * 0.866, cy - h), (cx, cy), (cx - s * 0.866, cy - h)]
    left = [(cx - s * 0.866, cy - h), (cx, cy), (cx, cy + s), (cx - s * 0.866, cy + h)]
    right = [(cx, cy), (cx + s * 0.866, cy - h), (cx + s * 0.866, cy + h), (cx, cy + s)]
    return top, left, right


def draw(size, background=True, foreground=True, scale_cube=1.0, mono=False, rounded=True):
    k = 4  # supermuestreo
    img = Image.new("RGBA", (size * k, size * k), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    f = size * k / 512.0
    if background:
        if rounded:
            d.rounded_rectangle([0, 0, size * k - 1, size * k - 1], radius=int(96 * f), fill=BG)
        else:
            d.rectangle([0, 0, size * k, size * k], fill=BG)
        for x, y, w, hh in WALLS:
            d.rectangle([x * f, (y + 10) * f, (x + w) * f, (y + hh + 10) * f], fill=BG_DARK)
            d.rectangle([x * f, y * f, (x + w) * f, (y + hh) * f], fill=WALL_TOP)
    if foreground:
        s = 150 * scale_cube
        cy = 256 + s * 0.12
        faces = cube(256, cy, s)
        colors = ["white"] * 3 if mono else [TOP, LEFT, RIGHT]
        for poly, color in zip(faces, colors):
            pts = [(x * f, y * f) for x, y in poly]
            d.polygon(pts, fill=color)
        if not mono:
            for poly in faces:
                pts = [(x * f, y * f) for x, y in poly]
                d.line(pts + [pts[0]], fill=OUTLINE, width=int(12 * f * scale_cube), joint="curve")
            # Flecha blanca sobre la cara de arriba (como la del juego).
            ax, ay = 256, cy - s * 0.5
            arrow = [(ax + 40 * scale_cube, ay - 23 * scale_cube), (ax - 2 * scale_cube, ay - 30 * scale_cube),
                     (ax + 14 * scale_cube, ay + 2 * scale_cube)]
            d.polygon([(x * f, y * f) for x, y in arrow], fill="white")
    return img.resize((size, size), Image.LANCZOS)


icons = root / "icons"
icons.mkdir(exist_ok=True)
draw(192).save(icons / "launcher_192.png")
draw(512).save(icons / "launcher_512.png")
# Icono adaptativo: el primer plano debe caber en el círculo central (66%).
draw(432, background=False, scale_cube=0.78).save(icons / "adaptive_foreground_432.png")
draw(432, foreground=False, rounded=False).save(icons / "adaptive_background_432.png")
draw(432, background=False, scale_cube=0.78, mono=True).save(icons / "adaptive_monochrome_432.png")

# SVG del proyecto (misma figura, en vectorial).
top, left, right = cube(256, 256 + 18, 150)
def pts(poly):
    return " ".join(f"{x:.1f},{y:.1f}" for x, y in poly)
walls = "".join(
    f'<rect x="{x}" y="{y + 10}" width="{w}" height="{h}" fill="{BG_DARK}"/>'
    f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{WALL_TOP}"/>' for x, y, w, h in WALLS)
ax, ay = 256, 256 + 18 - 75
arrow = [(ax + 40, ay - 23), (ax - 2, ay - 30), (ax + 14, ay + 2)]
svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">'
       f'<rect width="512" height="512" rx="96" fill="{BG}"/>{walls}'
       f'<g stroke="{OUTLINE}" stroke-width="12" stroke-linejoin="round">'
       f'<polygon points="{pts(top)}" fill="{TOP}"/><polygon points="{pts(left)}" fill="{LEFT}"/>'
       f'<polygon points="{pts(right)}" fill="{RIGHT}"/></g>'
       f'<polygon points="{pts(arrow)}" fill="#fff"/></svg>\n')
(root / "icon.svg").write_text(svg)
print("ok")
