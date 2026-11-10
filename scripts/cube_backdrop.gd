class_name CubeBackdrop
extends Control
## Fondo de los menús: degradado marrón, una rejilla isométrica muy tenue y
## unos pocos cubos isométricos que suben flotando despacio y se balancean.
## Casi todos son del color de los muros; alguno tiene los colores del cubo
## del juego. Al salir por arriba vuelven a entrar por abajo.

const TOP_COLOR := Color(0.27, 0.225, 0.18)
const BOTTOM_COLOR := Color(0.17, 0.14, 0.11)
const GRID_COLOR := Color(1.0, 0.93, 0.8, 0.035)
## Lado de las celdas de la rejilla (px).
const GRID_SIZE := 64.0
const CUBE_COUNT := 14
## Tamaño de los cubos («radio», px) y velocidad de subida (px/s).
const SIZE_MIN := 14.0
const SIZE_MAX := 46.0
const SPEED_MIN := 8.0
const SPEED_MAX := 22.0
## Balanceo horizontal: amplitud (px) y frecuencia (rad/s).
const SWAY := 18.0
const SWAY_SPEED := 0.5
## Caras (arriba, izquierda, derecha): muro y cubo del juego.
const WALL_FACES := [Color(0.42, 0.47, 0.58), Color(0.32, 0.36, 0.45), Color(0.25, 0.28, 0.36)]
const GAME_FACES := [Color(0.98, 0.85, 0.3), Color(0.3, 0.7, 0.95), Color(0.9, 0.3, 0.3)]
## Uno de cada GAME_EVERY cubos tiene los colores del cubo del juego.
const GAME_EVERY := 5

var _cubes: Array[Dictionary] = []
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Cada cubo en su franja vertical y a una altura distinta para que no se
	# amontonen.
	var columns := range(CUBE_COUNT)
	var rows := range(CUBE_COUNT)
	columns.shuffle()
	rows.shuffle()
	for i in CUBE_COUNT:
		# Los pequeños van más despacio y más transparentes (más lejos).
		var depth := rng.randf()
		_cubes.append({
			"x": (columns[i] + rng.randf_range(0.2, 0.8)) / CUBE_COUNT,
			"y": (rows[i] + rng.randf()) / CUBE_COUNT,
			"size": lerpf(SIZE_MIN, SIZE_MAX, depth),
			"speed": lerpf(SPEED_MIN, SPEED_MAX, depth),
			"alpha": lerpf(0.10, 0.28, depth),
			"phase": rng.randf() * TAU,
			"game": i % GAME_EVERY == 2,
		})
	_cubes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.size < b.size)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_polygon(
		PackedVector2Array([rect.position, Vector2(rect.end.x, 0), rect.end, Vector2(0, rect.end.y)]),
		PackedColorArray([TOP_COLOR, TOP_COLOR, BOTTOM_COLOR, BOTTOM_COLOR]))
	_draw_grid()
	for cube in _cubes:
		var r: float = cube.size
		var span := size.y + r * 4.0
		var y := fposmod(cube.y * span - _time * cube.speed, span) - r * 2.0
		var x: float = cube.x * size.x + sin(_time * SWAY_SPEED + cube.phase) * SWAY
		_draw_cube(Vector2(x, y), r, GAME_FACES if cube.game else WALL_FACES, cube.alpha)


## Rejilla isométrica: dos familias de líneas a ±30°.
func _draw_grid() -> void:
	var slope := tan(deg_to_rad(30.0))
	var step := GRID_SIZE / cos(deg_to_rad(30.0))
	var rise := size.x * slope
	var c := -rise
	while c < size.y + rise:
		draw_line(Vector2(0, c), Vector2(size.x, c + rise), GRID_COLOR, 1.0)
		draw_line(Vector2(0, c + rise), Vector2(size.x, c), GRID_COLOR, 1.0)
		c += step


func _draw_cube(center: Vector2, r: float, faces: Array, alpha: float) -> void:
	var k := r * 0.866
	var top := center + Vector2(0, -r)
	var left := center + Vector2(-k, -r * 0.5)
	var right := center + Vector2(k, -r * 0.5)
	var bottom := center + Vector2(0, r)
	var left_low := center + Vector2(-k, r * 0.5)
	var right_low := center + Vector2(k, r * 0.5)
	draw_colored_polygon(PackedVector2Array([top, right, center, left]), _with_alpha(faces[0], alpha))
	draw_colored_polygon(PackedVector2Array([left, center, bottom, left_low]), _with_alpha(faces[1], alpha))
	draw_colored_polygon(PackedVector2Array([right, center, bottom, right_low]), _with_alpha(faces[2], alpha))


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color, alpha)
