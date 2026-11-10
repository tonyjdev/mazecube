#!/usr/bin/env python3
"""Genera el tema de la interfaz (ui/theme.tres) y sus SVG.

Estilo «bloques»: los botones y paneles son bloques de vóxel vistos de frente,
con un brillo en el canto de arriba y un canto inferior más oscuro (el grosor
del bloque) que se hunde al pulsar. Los acentos son los colores de las caras
del cubo del juego (amarillo, azul y rojo) sobre el marrón del menú y del
icono. Tipografía: Russo One (ui/fonts, licencia OFL).

El canto inferior es la sombra del StyleBoxFlat desplazada hacia abajo y sin
difuminar; al pulsar, la cara baja (expand_margin) y el canto se estrecha, así
que el bloque ocupa siempre lo mismo.

Uso (desde la raíz del repositorio): python3 tools/make_ui_theme.py
"""

# Colores de las caras del cubo (los mismos que el icono, ver make_icon.py).
TOP, LEFT, RIGHT, OUTLINE = "#fad94d", "#4db3f2", "#e64d4d", "#2a211a"
ICON = "#fbe2a6"

# Grosor del canto inferior del bloque y cuánto se hunde al pulsar (px).
DEPTH = 7
PRESS = 5
RADIUS = 7


def rgba(hex_color: str, alpha: float = 1.0) -> str:
    h = hex_color.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return f"Color({r:.3g}, {g:.3g}, {b:.3g}, {alpha:.3g})"


# --- SVG --------------------------------------------------------------------

def cube(cx, cy, s, top=TOP, left=LEFT, right=RIGHT, stroke=OUTLINE, sw=0.0):
    """Cubo isométrico de «radio» s centrado en (cx, cy)."""
    k = 0.866 * s
    pts = lambda p: " ".join(f"{x:.2f},{y:.2f}" for x, y in p)
    t = [(cx, cy - s), (cx + k, cy - s / 2), (cx, cy), (cx - k, cy - s / 2)]
    l = [(cx - k, cy - s / 2), (cx, cy), (cx, cy + s), (cx - k, cy + s / 2)]
    r = [(cx + k, cy - s / 2), (cx, cy), (cx, cy + s), (cx + k, cy + s / 2)]
    st = f' stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round"' if sw else ""
    return (f'<polygon points="{pts(t)}" fill="{top}"{st}/>'
            f'<polygon points="{pts(l)}" fill="{left}"{st}/>'
            f'<polygon points="{pts(r)}" fill="{right}"{st}/>')


def write_svg(name, w, h, body):
    with open(f"ui/{name}", "w") as f:
        f.write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
                f'viewBox="0 0 {w} {h}">{body}</svg>\n')


def make_svgs():
    # Tirador de los deslizadores: un cubito.
    write_svg("slider_grabber.svg", 44, 44, cube(22, 22, 19, sw=2.5))

    # Interruptores: carril de bloque con un cubito que pasa de un lado a otro.
    def switch(on):
        track, edge = ("#4db3f2", "#2a7fb8") if on else ("#1c1611", "#120e0b")
        knob = (cube(78, 28, 22, sw=3) if on
                else cube(26, 28, 22, "#9a8b78", "#6e604f", "#5a4e40", OUTLINE, 3))
        return (f'<rect x="4" y="18" width="100" height="24" rx="6" fill="{edge}"/>'
                f'<rect x="4" y="14" width="100" height="24" rx="6" fill="{track}"/>' + knob)
    write_svg("switch_on.svg", 108, 56, switch(True))
    write_svg("switch_off.svg", 108, 56, switch(False))
    # Flecha del desplegable.
    write_svg("dropdown_arrow.svg", 28, 28,
              f'<path d="M6 10 L14 19 L22 10" fill="none" stroke="{ICON}" stroke-width="4" '
              'stroke-linecap="round" stroke-linejoin="round"/>')

    # Iconos del HUD de las estrellas: corazón (sin morir) y cubito dorado.
    write_svg("hud_heart.svg", 40, 40,
              f'<path d="M20 35 C8 26 3 19 3 12.5 C3 7 7.5 3.5 12 3.5 C15.5 3.5 18.5 5.5 20 8.5 '
              f'C21.5 5.5 24.5 3.5 28 3.5 C32.5 3.5 37 7 37 12.5 C37 19 32 26 20 35 Z" '
              f'fill="{RIGHT}" stroke="{OUTLINE}" stroke-width="3" stroke-linejoin="round"/>'
              '<ellipse cx="12.5" cy="11" rx="4" ry="3" fill="#ffffff" fill-opacity="0.45"/>')
    write_svg("hud_gold_cube.svg", 40, 40, cube(20, 20, 17, "#ffe27a", "#f0b429", "#c98a12", OUTLINE, 3))

    # Redes sociales de los créditos (glifos de Instagram y X, del color de
    # los iconos).
    write_svg("social_instagram.svg", 48, 48,
              f'<rect x="5" y="5" width="38" height="38" rx="11" fill="none" stroke="{ICON}" stroke-width="4"/>'
              f'<circle cx="24" cy="24" r="8.5" fill="none" stroke="{ICON}" stroke-width="4"/>'
              f'<circle cx="35" cy="13" r="2.6" fill="{ICON}"/>')
    write_svg("social_x.svg", 48, 48,
              f'<g transform="translate(4 4) scale(1.6667)"><path fill="{ICON}" d="M18.244 2.25h3.308l-7.227 '
              '8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231z'
              'm-1.161 17.52h1.833L7.084 4.126H5.117z"/></g>')

    # Icono de pausa del juego (dos barras, como los de los botones de pausa).
    write_svg("pause_pause.svg", 48, 48,
              f'<rect x="13" y="10" width="8" height="28" rx="2" fill="{ICON}"/>'
              f'<rect x="27" y="10" width="8" height="28" rx="2" fill="{ICON}"/>')

    # Inmunidad (botón de arriba en el centro de la partida): escudo con un rayo.
    write_svg("hud_immunity.svg", 48, 48,
              f'<path d="M24 4 L41 10 V22 C41 32 34 40 24 44 C14 40 7 32 7 22 V10 Z" fill="none" '
              f'stroke="{ICON}" stroke-width="4" stroke-linejoin="round"/>'
              f'<path d="M27 11 L17 26 H24 L21 37 L31 21 H24 Z" fill="{ICON}" stroke="{ICON}" '
              f'stroke-width="1.5" stroke-linejoin="round"/>')

    # Enciclopedia: libro abierto (botón de la pausa), flechas de página y
    # cerrar.
    write_svg("enc_book.svg", 48, 48,
              f'<path d="M24 13 C19 9 11 9 5 11 V38 C11 36 19 36 24 40 C29 36 37 36 43 38 V11 '
              f'C37 9 29 9 24 13 Z M24 13 V40" fill="none" stroke="{ICON}" stroke-width="4" '
              f'stroke-linejoin="round" stroke-linecap="round"/>'
              f'<path d="M10 18 C14 17 17 17 19 18 M10 24 C14 23 17 23 19 24 M29 18 C31 17 34 17 38 18 '
              f'M29 24 C31 23 34 23 38 24" fill="none" stroke="{ICON}" stroke-width="2.5" '
              f'stroke-linecap="round" opacity="0.8"/>')
    write_svg("enc_prev.svg", 48, 48,
              f'<path d="M30 9 L15 24 L30 39" fill="none" stroke="{ICON}" stroke-width="7" '
              f'stroke-linecap="round" stroke-linejoin="round"/>')
    write_svg("enc_next.svg", 48, 48,
              f'<path d="M18 9 L33 24 L18 39" fill="none" stroke="{ICON}" stroke-width="7" '
              f'stroke-linecap="round" stroke-linejoin="round"/>')
    write_svg("enc_close.svg", 48, 48,
              f'<path d="M12 12 L36 36 M36 12 L12 36" fill="none" stroke="{ICON}" stroke-width="7" '
              f'stroke-linecap="round"/>')


# --- Tema -------------------------------------------------------------------

class Theme:
    def __init__(self):
        self.subs = []
        self.props = []

    def style(self, sid, kind="StyleBoxFlat", **p):
        lines = [f'[sub_resource type="{kind}" id="{sid}"]']
        lines += [f"{k} = {v}" for k, v in p.items()]
        self.subs.append("\n".join(lines))
        return f'SubResource("{sid}")'

    def block(self, sid, face, top, side, pressed=False, margins=(28, 14), alpha=1.0, radius=RADIUS,
              depth=DEPTH):
        """Bloque: cara, brillo arriba (borde superior) y canto inferior (sombra)."""
        mx, my = margins
        p = dict(
            content_margin_left=f"{mx}.0", content_margin_right=f"{mx}.0",
            content_margin_top=f"{my + (PRESS if pressed else 0)}.0",
            content_margin_bottom=f"{my - (PRESS if pressed else 0)}.0",
            bg_color=rgba(face, alpha),
            border_width_top=2 if pressed else 3,
            border_color=rgba(top, alpha),
            border_blend="false",
        )
        for c in ("top_left", "top_right", "bottom_right", "bottom_left"):
            p[f"corner_radius_{c}"] = radius
        p["corner_detail"] = 6
        if pressed:
            p["expand_margin_bottom"] = f"{PRESS}.0"
            p["expand_margin_top"] = f"-{PRESS}.0"
        p.update(shadow_color=rgba(side, alpha), shadow_size=1,
                 shadow_offset=f"Vector2(0, {depth - PRESS if pressed else depth})")
        return self.style(sid, **p)

    def set(self, key, value):
        self.props.append(f"{key} = {value}")

    def button_type(self, name, styles, font, font_pressed, disabled_font, size=30):
        for state, sub in styles.items():
            self.set(f"{name}/styles/{state}", sub)
        self.set(f"{name}/colors/font_color", font)
        self.set(f"{name}/colors/font_hover_color", font)
        self.set(f"{name}/colors/font_focus_color", font)
        self.set(f"{name}/colors/font_pressed_color", font_pressed)
        self.set(f"{name}/colors/font_hover_pressed_color", font_pressed)
        self.set(f"{name}/colors/font_disabled_color", disabled_font)
        self.set(f"{name}/font_sizes/font_size", size)

    def write(self, path, ext):
        head = f'[gd_resource type="Theme" load_steps={len(self.subs) + len(ext) + 1} format=3]\n'
        exts = "\n".join(f'[ext_resource type="{t}" path="{p}" id="{i}"]' for i, (t, p) in ext.items())
        with open(path, "w") as f:
            f.write(head + "\n" + exts + "\n\n" + "\n\n".join(self.subs)
                    + "\n\n[resource]\n" + "\n".join(self.props) + "\n")


def make_theme():
    t = Theme()
    ext = {
        "font": ("FontFile", "res://ui/fonts/RussoOne-Regular.ttf"),
        "sw_on": ("Texture2D", "res://ui/switch_on.svg"),
        "sw_off": ("Texture2D", "res://ui/switch_off.svg"),
        "grabber": ("Texture2D", "res://ui/slider_grabber.svg"),
        "arrow": ("Texture2D", "res://ui/dropdown_arrow.svg"),
    }
    light = rgba("#f6efe2")
    dark_text = rgba(OUTLINE)

    focus = t.style("focus", bg_color=rgba("#000000", 0), border_width_left=3, border_width_top=3,
                    border_width_right=3, border_width_bottom=3, border_color=rgba(TOP, 0.95),
                    corner_radius_top_left=RADIUS + 3, corner_radius_top_right=RADIUS + 3,
                    corner_radius_bottom_right=RADIUS + 3, corner_radius_bottom_left=RADIUS + 3,
                    expand_margin_left="5.0", expand_margin_top="5.0", expand_margin_right="5.0",
                    expand_margin_bottom=f"{DEPTH + 5}.0")

    # Botón normal: bloque marrón.
    t.button_type("Button", {
        "normal": t.block("btn_normal", "#5b4a39", "#7d6750", "#221a13"),
        "hover": t.block("btn_hover", "#6a5642", "#8f775d", "#221a13"),
        "pressed": t.block("btn_pressed", "#4f4032", "#6c5946", "#221a13", pressed=True),
        "hover_pressed": t.block("btn_hover_pressed", "#57473a", "#75614c", "#221a13", pressed=True),
        "disabled": t.block("btn_disabled", "#4a3e33", "#5a4c3f", "#221a13", alpha=0.55),
        "focus": focus,
    }, light, rgba("#ffffff"), rgba("#d8cbb8", 0.5))

    # Botón principal (Jugar, Siguiente nivel, Continuar): bloque amarillo.
    t.set("PrimaryButton/base_type", '&"Button"')
    t.button_type("PrimaryButton", {
        "normal": t.block("pri_normal", "#f6cf45", "#fff0a0", "#9c7a1a"),
        "hover": t.block("pri_hover", "#ffdb5c", "#fff5c0", "#9c7a1a"),
        "pressed": t.block("pri_pressed", "#e8bf34", "#f8e080", "#9c7a1a", pressed=True),
        "hover_pressed": t.block("pri_hover_pressed", "#efc63c", "#fbe690", "#9c7a1a", pressed=True),
    }, dark_text, dark_text, dark_text)

    # Botón cuadrado con icono (pausa, atrás): bloque más compacto.
    t.set("IconButton/base_type", '&"Button"')
    for state, args in {
        "normal": ("#5b4a39", "#7d6750", False), "hover": ("#6a5642", "#8f775d", False),
        "pressed": ("#4f4032", "#6c5946", True), "hover_pressed": ("#57473a", "#75614c", True),
    }.items():
        face, top, pressed = args
        t.set(f"IconButton/styles/{state}",
              t.block(f"icon_{state}", face, top, "#221a13", pressed=pressed, margins=(10, 10)))

    # Panel: bloque oscuro y grueso.
    t.set("PanelContainer/styles/panel",
          t.style("panel", content_margin_left="40.0", content_margin_top="32.0",
                  content_margin_right="40.0", content_margin_bottom="32.0",
                  bg_color=rgba("#2e261e", 0.96), border_width_top=3, border_color=rgba("#4d3f31"),
                  border_blend="false", corner_radius_top_left=12, corner_radius_top_right=12,
                  corner_radius_bottom_right=12, corner_radius_bottom_left=12, corner_detail=6,
                  shadow_color=rgba("#1a1410"), shadow_size=1, shadow_offset="Vector2(0, 9)"))

    # Placa del HUD (número de nivel): bloque translúcido.
    t.set("HudBadge/base_type", '&"PanelContainer"')
    t.set("HudBadge/styles/panel",
          t.style("hud_badge", content_margin_left="18.0", content_margin_top="6.0",
                  content_margin_right="18.0", content_margin_bottom="8.0",
                  bg_color=rgba("#2e261e", 0.72), border_width_top=2, border_color=rgba("#5b4a39", 0.8),
                  border_blend="false", corner_radius_top_left=RADIUS, corner_radius_top_right=RADIUS,
                  corner_radius_bottom_right=RADIUS, corner_radius_bottom_left=RADIUS,
                  shadow_color=rgba("#1a1410", 0.6), shadow_size=1, shadow_offset="Vector2(0, 5)"))

    # Textos.
    t.set("default_font", 'ExtResource("font")')
    t.set("default_font_size", 28)
    t.set("Label/colors/font_color", light)
    t.set("Label/colors/font_outline_color", rgba("#1f1812", 0.85))
    t.set("Label/constants/outline_size", 6)
    # Títulos: texto con un canto oscuro debajo, como un bloque.
    t.set("TitleLabel/base_type", '&"Label"')
    t.set("TitleLabel/colors/font_color", rgba(TOP))
    t.set("TitleLabel/colors/font_shadow_color", rgba("#1f1812"))
    t.set("TitleLabel/colors/font_outline_color", rgba("#1f1812"))
    t.set("TitleLabel/constants/outline_size", 10)
    t.set("TitleLabel/constants/shadow_offset_x", 0)
    t.set("TitleLabel/constants/shadow_offset_y", 6)
    t.set("TitleLabel/constants/shadow_outline_size", 10)
    t.set("TitleLabel/font_sizes/font_size", 52)

    # Deslizadores: carril hundido, relleno azul y un cubito como tirador.
    t.set("HSlider/styles/slider",
          t.style("slider", content_margin_top="6.0", content_margin_bottom="6.0",
                  bg_color=rgba("#1c1611"), border_width_top=2, border_color=rgba("#120e0b"),
                  border_blend="false", corner_radius_top_left=4, corner_radius_top_right=4,
                  corner_radius_bottom_right=4, corner_radius_bottom_left=4))
    fill = t.style("slider_fill", content_margin_top="6.0", content_margin_bottom="6.0",
                   bg_color=rgba(LEFT), border_width_top=2, border_color=rgba("#8fd3ff"),
                   border_blend="false", corner_radius_top_left=4, corner_radius_top_right=4,
                   corner_radius_bottom_right=4, corner_radius_bottom_left=4)
    t.set("HSlider/styles/grabber_area", fill)
    t.set("HSlider/styles/grabber_area_highlight", fill)
    t.set("HSlider/icons/grabber", 'ExtResource("grabber")')
    t.set("HSlider/icons/grabber_highlight", 'ExtResource("grabber")')

    # Interruptores.
    empty = t.style("empty", kind="StyleBoxEmpty")
    for state in ("normal", "hover", "pressed", "hover_pressed", "disabled"):
        t.set(f"CheckButton/styles/{state}", empty)
    t.set("CheckButton/styles/focus", focus)
    for icon in ("checked", "checked_disabled", "checked_mirrored"):
        t.set(f"CheckButton/icons/{icon}", 'ExtResource("sw_on")')
    for icon in ("unchecked", "unchecked_disabled", "unchecked_mirrored"):
        t.set(f"CheckButton/icons/{icon}", 'ExtResource("sw_off")')

    t.set("OptionButton/icons/arrow", 'ExtResource("arrow")')
    t.set("OptionButton/constants/arrow_margin", 18)

    # Desplegable (idioma): lista con el mismo panel y la opción en amarillo.
    t.set("PopupMenu/styles/panel",
          t.style("popup", content_margin_left="8.0", content_margin_top="8.0",
                  content_margin_right="8.0", content_margin_bottom="8.0",
                  bg_color=rgba("#2e261e"), border_width_left=2, border_width_top=2,
                  border_width_right=2, border_width_bottom=2, border_color=rgba("#5b4a39"),
                  corner_radius_top_left=RADIUS, corner_radius_top_right=RADIUS,
                  corner_radius_bottom_right=RADIUS, corner_radius_bottom_left=RADIUS))
    t.set("PopupMenu/styles/hover",
          t.style("popup_hover", bg_color=rgba(TOP), corner_radius_top_left=5, corner_radius_top_right=5,
                  corner_radius_bottom_right=5, corner_radius_bottom_left=5))
    t.set("PopupMenu/colors/font_color", light)
    t.set("PopupMenu/colors/font_hover_color", dark_text)
    t.set("PopupMenu/font_sizes/font_size", 28)
    t.set("PopupMenu/constants/v_separation", 14)

    # Barra de desplazamiento (créditos): fina, con el tirador de bloque.
    t.set("VScrollBar/styles/scroll",
          t.style("scroll", content_margin_left="5.0", content_margin_right="5.0",
                  bg_color=rgba("#1c1611"), corner_radius_top_left=4, corner_radius_top_right=4,
                  corner_radius_bottom_right=4, corner_radius_bottom_left=4))
    grab = t.style("scroll_grab", bg_color=rgba("#7d6750"), corner_radius_top_left=4,
                   corner_radius_top_right=4, corner_radius_bottom_right=4, corner_radius_bottom_left=4)
    for state in ("grabber", "grabber_highlight", "grabber_pressed"):
        t.set(f"VScrollBar/styles/{state}", grab)

    t.write("ui/theme.tres", ext)


if __name__ == "__main__":
    make_svgs()
    make_theme()
