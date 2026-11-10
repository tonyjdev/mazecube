"""Genera el icono de Maze Cube: icon.svg y los PNG del lanzador de Android.

El cubo del juego en isométrico: caras blancas con una franja gris en cada
borde (como RollingCube: EDGE_WIDTH = 7 % del lado), con un sombreado suave
por cara, sobre el fondo marrón del menú con trozos de muro de laberinto."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

# Uso (desde la raíz del repositorio): python3 tools/make_icon.py
root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent
BG = "#3c3228"
BG_DARK = "#2e261e"
WALL = "#525c73"
WALL_TOP = "#6b7894"
OUTLINE = "#2a211a"
# Cara blanca y borde gris de cada cara visible (arriba, izquierda, derecha).
FACES = [("#ffffff", "#bfc1c8"), ("#e4e6eb", "#a9acb5"), ("#c9ccd3", "#9295a0")]
EDGE = 0.07

# Muros del laberinto de fondo (en un lienzo de 512): rectángulos x, y, w, h.
WALLS = [(40, 40, 170, 34), (40, 40, 34, 160), (300, 40, 172, 34), (438, 40, 34, 200),
         (40, 300, 34, 172), (40, 438, 180, 34), (300, 438, 172, 34), (438, 330, 34, 142)]


def cube(cx, cy, s):
    """Caras de un cubo isométrico de lado s centrado en (cx, cy): para cada
    cara (arriba, izquierda, derecha), su contorno y su parte blanca interior."""
    k, h = s * 0.866, s * 0.5
    # Cada cara: esquina de origen y los dos lados que salen de ella.
    frames = [((cx - k, cy - h), (k, -h), (k, h)),
              ((cx - k, cy - h), (k, h), (0, s)),
              ((cx, cy), (k, -h), (0, s))]
    faces = []
    for (ox, oy), (ax, ay), (bx, by) in frames:
        def at(u, v):
            return (ox + ax * u + bx * v, oy + ay * u + by * v)
        outer = [at(0, 0), at(1, 0), at(1, 1), at(0, 1)]
        e, f = EDGE, 1 - EDGE
        inner = [at(e, e), at(f, e), at(f, f), at(e, f)]
        faces.append((outer, inner))
    return faces


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
        for (outer, inner), (face, edge) in zip(faces, FACES):
            d.polygon([(x * f, y * f) for x, y in outer], fill="white" if mono else edge)
            if not mono:
                d.polygon([(x * f, y * f) for x, y in inner], fill=face)
        if not mono:
            for outer, _ in faces:
                pts = [(x * f, y * f) for x, y in outer]
                d.line(pts + [pts[0]], fill=OUTLINE, width=int(12 * f * scale_cube), joint="curve")
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
def pts(poly):
    return " ".join(f"{x:.1f},{y:.1f}" for x, y in poly)
walls = "".join(
    f'<rect x="{x}" y="{y + 10}" width="{w}" height="{h}" fill="{BG_DARK}"/>'
    f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{WALL_TOP}"/>' for x, y, w, h in WALLS)
faces_svg = "".join(f'<polygon points="{pts(outer)}" fill="{edge}"/><polygon points="{pts(inner)}" fill="{face}"/>'
                    for (outer, inner), (face, edge) in zip(cube(256, 256 + 18, 150), FACES))
outlines = "".join(f'<polygon points="{pts(outer)}"/>' for outer, _ in cube(256, 256 + 18, 150))
svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">'
       f'<rect width="512" height="512" rx="96" fill="{BG}"/>{walls}'
       f'{faces_svg}<g fill="none" stroke="{OUTLINE}" stroke-width="12" stroke-linejoin="round">'
       f'{outlines}</g></svg>\n')
(root / "icon.svg").write_text(svg)
print("ok")
