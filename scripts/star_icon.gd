class_name StarIcon
extends Control
## Estrella de la pantalla de nivel completado, con el estilo «bloques» de la
## interfaz: cara amarilla con un canto más oscuro debajo (conseguida) o
## hueca y oscura (no conseguida).
##
## reveal(filled) la hace aparecer de golpe (crece con un pequeño rebote y
## gira un poco); si está conseguida, suelta además un destello en anillo.
## draw_star() dibuja una estrella en cualquier CanvasItem (también la usa el
## mapa de niveles, más pequeña).

const FACE := Color(0.98, 0.85, 0.3)
const FACE_LIGHT := Color(1.0, 0.95, 0.65)
const SIDE := Color(0.62, 0.47, 0.1)
const EMPTY_FACE := Color(0.2, 0.16, 0.12, 0.92)
const EMPTY_SIDE := Color(0.1, 0.08, 0.06, 0.92)
const OUTLINE := Color(0.13, 0.1, 0.07)
const EMPTY_OUTLINE := Color(0.45, 0.37, 0.28)
## Radio interior respecto al exterior (lo puntiaguda que es).
const INNER_RATIO := 0.48
const REVEAL_TIME := 0.45

## Conseguida o no (cómo se dibuja).
var filled := false
var _pop := 0.0
var _burst := 0.0
var _shown := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size * 0.5
	resized.connect(func() -> void: pivot_offset = size * 0.5)


## La deja oculta, lista para reveal().
func reset() -> void:
	_shown = false
	_pop = 0.0
	_burst = 0.0
	queue_redraw()


func reveal(is_filled: bool) -> void:
	filled = is_filled
	_shown = true
	var tween := create_tween().set_parallel()
	tween.tween_method(_set_pop, 0.0, 1.0, REVEAL_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if filled:
		tween.tween_method(_set_burst, 0.0, 1.0, REVEAL_TIME * 1.6).set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_OUT)


func _set_pop(value: float) -> void:
	_pop = value
	queue_redraw()


func _set_burst(value: float) -> void:
	_burst = value
	queue_redraw()


func _draw() -> void:
	if not _shown:
		return
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.42
	if filled and _burst > 0.0 and _burst < 1.0:
		# Anillo de luz que se abre y se apaga.
		draw_arc(center, radius * (0.8 + _burst * 0.7), 0.0, TAU, 48,
			Color(FACE_LIGHT, (1.0 - _burst) * 0.8), radius * 0.12 * (1.0 - _burst) + 1.0, true)
	draw_set_transform(center, (1.0 - _pop) * -0.6, Vector2.ONE * _pop)
	draw_star(self, Vector2.ZERO, radius, filled)
	draw_set_transform_matrix(Transform2D.IDENTITY)


static func star_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10:
		var angle := -PI * 0.5 + i * PI / 5.0
		var r := radius if i % 2 == 0 else radius * INNER_RATIO
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	return points


## Estrella con canto inferior (grosor ≈ 12 % del radio) y contorno.
static func draw_star(canvas: CanvasItem, center: Vector2, radius: float, is_filled: bool,
		alpha := 1.0) -> void:
	var depth := Vector2(0, maxf(2.0, radius * 0.13))
	var outline_width := maxf(1.5, radius * 0.09)
	var face := FACE if is_filled else EMPTY_FACE
	var side := SIDE if is_filled else EMPTY_SIDE
	var line := OUTLINE if is_filled else EMPTY_OUTLINE
	var body := star_points(center, radius)
	var below := star_points(center + depth, radius)
	var outline := below.duplicate()
	outline.append(below[0])
	canvas.draw_polyline(outline, Color(OUTLINE, alpha), outline_width * 2.0, true)
	canvas.draw_colored_polygon(below, Color(side, alpha))
	canvas.draw_colored_polygon(body, Color(face, alpha))
	if is_filled:
		# Brillo en la mitad de arriba.
		canvas.draw_colored_polygon(star_points(center + Vector2(0, -radius * 0.08), radius * 0.45),
			Color(FACE_LIGHT, alpha * 0.55))
	var ring := body.duplicate()
	ring.append(body[0])
	canvas.draw_polyline(ring, Color(line, alpha), outline_width, true)
