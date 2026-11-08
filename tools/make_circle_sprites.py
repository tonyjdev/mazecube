#!/usr/bin/env python3
"""Dibuja las capas que se superponen a los círculos del selector de niveles.

Los círculos de la imagen del mapa (ui/level_select/map.png) son discos
grises con un borde claro y algo de grosor. Para marcar el estado de un
nivel se dibuja encima uno igual de otro color:
- circle_done.png: nivel completado (verde).
- circle_active.png: nivel activo, el siguiente por jugar (dorado, con un
  halo alrededor).

La cara superior coloreada (sin el borde) ocupa INNER_W píxeles de ancho en
la imagen: LevelMap la escala para que coincida con el ancho del gris de
cada círculo (campo "w" de map.json).

Uso (desde la raíz del repositorio): python3 tools/make_circle_sprites.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "ui" / "level_select"
# Tamaño final de cada imagen y ancho de la cara coloreada dentro de ella.
SIZE = (256, 208)
INNER_W = 168
# Se dibuja al doble y se reduce para suavizar los bordes.
SS = 2
RATIO = 0.66
RIM = 12
THICKNESS = 16
OUTLINE = 4

STYLES = {
    "done": {"top": (104, 206, 84), "light": (168, 236, 132), "side": (46, 120, 44),
             "rim": (240, 250, 232), "glow": None},
    "active": {"top": (250, 196, 54), "light": (255, 236, 140), "side": (176, 112, 18),
               "rim": (255, 252, 236), "glow": (255, 214, 80)},
}


def ellipse(draw, cx, cy, rx, ry, fill):
    draw.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=fill)


def make(style):
    w, h = SIZE[0] * SS, SIZE[1] * SS
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cx = w / 2
    rx = INNER_W * SS / 2
    ry = rx * RATIO
    cy = h / 2 - THICKNESS * SS / 2
    outer_rx = rx + RIM * SS
    outer_ry = ry + RIM * SS
    if style["glow"]:
        glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        ellipse(gd, cx, cy + THICKNESS * SS / 2, outer_rx + 10 * SS, outer_ry + 10 * SS, style["glow"] + (200,))
        glow = glow.filter(ImageFilter.GaussianBlur(9 * SS))
        img = Image.alpha_composite(img, glow)
    d = ImageDraw.Draw(img)
    t = THICKNESS * SS
    o = OUTLINE * SS
    dark = tuple(int(c * 0.45) for c in style["side"]) + (255,)
    # Contorno oscuro y grosor del disco (de abajo arriba).
    ellipse(d, cx, cy + t, outer_rx + o, outer_ry + o, dark)
    d.rectangle((cx - outer_rx - o, cy, cx + outer_rx + o, cy + t), fill=dark)
    ellipse(d, cx, cy, outer_rx + o, outer_ry + o, dark)
    ellipse(d, cx, cy + t, outer_rx, outer_ry, style["side"] + (255,))
    d.rectangle((cx - outer_rx, cy, cx + outer_rx, cy + t), fill=style["side"] + (255,))
    # Borde claro y cara superior con un brillo arriba.
    ellipse(d, cx, cy, outer_rx, outer_ry, style["rim"] + (255,))
    ellipse(d, cx, cy, rx + o * 0.5, ry + o * 0.5, dark)
    ellipse(d, cx, cy, rx, ry, style["top"] + (255,))
    shine = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shine)
    ellipse(sd, cx, cy - ry * 0.32, rx * 0.78, ry * 0.5, style["light"] + (190,))
    shine = shine.filter(ImageFilter.GaussianBlur(5 * SS))
    # El brillo solo dentro de la cara superior.
    mask = Image.new("L", (w, h), 0)
    ellipse(ImageDraw.Draw(mask), cx, cy, rx, ry, 255)
    shine.putalpha(Image.composite(shine.getchannel("A"), Image.new("L", (w, h), 0), mask))
    img = Image.alpha_composite(img, shine)
    return img.resize(SIZE, Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, style in STYLES.items():
        path = OUT / f"circle_{name}.png"
        make(style).save(path)
        print("Guardado", path)


if __name__ == "__main__":
    main()
