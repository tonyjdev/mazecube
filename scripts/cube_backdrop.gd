class_name CubeBackdrop
extends Control
## Fondo de los menús: degradado marrón, una rejilla isométrica muy tenue y
## unos pocos cubos isométricos que suben flotando despacio y se balancean.
## Son el cubo del juego (caras blancas con una franja gris en los bordes,
## como RollingCube), medio transparentes. Al salir por arriba vuelven a
## entrar por abajo.

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
## Caras (arriba, izquierda, derecha): blanco y franja gris del borde, con
## un sombreado suave por cara (como el icono, ver tools/make_icon.py).
const FACES := [Color(1.0, 1.0, 1.0), Color(0.89, 0.9, 0.92), Color(0.79, 0.8, 0.83)]
const EDGES := [Color(0.75, 0.76, 0.78), Color(0.66, 0.67, 0.71), Color(0.57, 0.58, 0.63)]
## Ancho de la franja gris (fracción del lado, RollingCube.EDGE_WIDTH).
const EDGE := 0.07

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
			"alpha": lerpf(0.18, 0.4, depth),
			"phase": rng.randf() * TAU,
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
		_draw_cube(Vector2(x, y), r, cube.alpha)


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


## Cubo isométrico. Los colores se mezclan a mano con el fondo (en vez de
## dibujar con transparencia) para que la franja gris y la cara blanca no se
## sumen donde se solapan.
func _draw_cube(center: Vector2, r: float, alpha: float) -> void:
	var k := r * 0.866
	var h := r * 0.5
	var back := TOP_COLOR.lerp(BOTTOM_COLOR, clampf(center.y / maxf(size.y, 1.0), 0.0, 1.0))
	# Cada cara: esquina de origen y los dos lados que salen de ella.
	var frames := [
		[center + Vector2(-k, -h), Vector2(k, -h), Vector2(k, h)],
		[center + Vector2(-k, -h), Vector2(k, h), Vector2(0, r)],
		[center, Vector2(k, -h), Vector2(0, r)],
	]
	for i in 3:
		var o: Vector2 = frames[i][0]
		var a: Vector2 = frames[i][1]
		var b: Vector2 = frames[i][2]
		var f := 1.0 - EDGE
		draw_colored_polygon(PackedVector2Array([o, o + a, o + a + b, o + b]), back.lerp(EDGES[i], alpha))
		draw_colored_polygon(PackedVector2Array([o + (a + b) * EDGE, o + a * f + b * EDGE,
			o + (a + b) * f, o + a * EDGE + b * f]), back.lerp(FACES[i], alpha))
