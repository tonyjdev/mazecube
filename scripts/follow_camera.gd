class_name FollowCamera
extends Camera3D
## Cámara cenital inclinada que encuadra el tablero o sigue al cubo.
##
## La cámara mira a un punto del suelo (el foco) desde una distancia dada, con
## una inclinación fija. La distancia tiene un máximo (MAX_DISTANCE), que es a
## la que se veía entero un tablero de 7×9 casillas; cada nivel puede pedir una
## distancia menor (para acercarla) y en el futuro se podrá cambiar durante la
## partida con set_distance(), siempre con una transición suave.
##
## - Si el tablero entero cabe en el hueco libre de la interfaz, la cámara se
##   acerca hasta encuadrarlo justo y se queda quieta en su centro.
## - Si no cabe, sigue al cubo. En cada eje, el foco va hacia el cubo pero sin
##   enseñar más allá del borde del tablero; en el eje en que el tablero sí
##   cabe, se queda centrada.
## - Cuando el cubo va más rápido (power up de velocidad o cualquier otra
##   causa), la cámara se aleja un poco para que se vea más mapa, y vuelve a
##   su distancia al recuperar la velocidad normal. Este alejamiento se suma a
##   la distancia del nivel y puede superar MAX_DISTANCE; si el tablero entero
##   ya cabe en pantalla, no se aleja.
## - Botones: cuando el cubo se acerca a un botón (ver Level.button_near) y
##   alguno de sus barrotes queda fuera de pantalla, la cámara se aleja y se
##   centra para que se vean a la vez el cubo, el botón y todos sus barrotes.
##   Al alejarse el cubo del botón, vuelve a su comportamiento normal, aunque
##   tras pulsarlo espera un momento (ATTENTION_HOLD) para que se vea cómo
##   cambian los barrotes. Si al llegar ya se ven todos, no cambia nada.
## - Tanto el foco como la distancia se mueven con un amortiguamiento crítico:
##   arrancan y frenan con suavidad, van con un pequeño retraso respecto al
##   cubo y nunca se pasan del objetivo (no rebotan cuando el cubo rebota).

## Distancia máxima de la cámara al foco: la del antiguo nivel 4 (7×9 casillas)
## encuadrado entero en la pantalla apaisada de referencia (1280×720).
const MAX_DISTANCE := 13.5
const MIN_DISTANCE := 3.0
## Alejamiento por velocidad: fracción de distancia que se añade por cada
## unidad de velocidad extra (con ×2 de velocidad, la cámara se aleja un 30%).
const SPEED_ZOOM_PER_EXTRA_SPEED := 0.3
## Cuánto se puede ver más allá del borde exterior del tablero al seguir al cubo.
const EDGE_MARGIN := 0.4
## Segundos que la cámara sigue enseñando los barrotes tras pulsar un botón,
## aunque el cubo ya se haya alejado.
const ATTENTION_HOLD := 0.8

## Inclinación de la vista cenital (90 = totalmente desde arriba).
@export_range(45.0, 90.0) var pitch_degrees := 65.0
## Margen alrededor del tablero al encuadrarlo entero (1.0 = justo al borde).
@export_range(1.0, 1.5) var fit_margin := 1.08
## Tiempo aproximado que tarda el foco en alcanzar al cubo (retraso del seguimiento).
@export var follow_smooth_time := 0.45
## Tiempo aproximado de una transición de distancia (acercar o alejar).
@export var zoom_smooth_time := 0.7

var level: Level
var target: Node3D
## Hueco libre de la interfaz en el que se encuadra el tablero.
var play_area: Control

## Distancia pedida (antes de limitarla a lo necesario para ver el tablero entero).
var _requested_distance := MAX_DISTANCE
## Distancia a la que el tablero entero cabe en el hueco libre.
var _fit_distance := MAX_DISTANCE
var _distance := MAX_DISTANCE
var _distance_vel := 0.0
var _focus := Vector3.ZERO
var _focus_vel := Vector3.ZERO
## Botón cercano al cubo (Level.NO_CELL si no hay) y si la cámara se ha
## alejado para enseñar sus barrotes.
var _attention_button := Level.NO_CELL
var _attention_active := false
## Encuadre del botón ya calculado: [distancia, foco], válido mientras el
## cubo siga en la casilla _attention_frame_cell.
var _attention_frame: Array = []
var _attention_frame_cell := Level.NO_CELL
## Hasta cuándo (Time.get_ticks_msec) se mantiene el encuadre tras pulsar.
var _attention_hold_until := 0


func _ready() -> void:
	projection = PROJECTION_PERSPECTIVE
	fov = 45.0


func setup(target_level: Level, followed: Node3D, area: Control) -> void:
	level = target_level
	target = followed
	play_area = area


## Prepara la cámara para el nivel cargado: distancia del nivel (0 = la
## máxima) y encuadre inmediato, sin transición.
func frame_level(requested_distance := 0.0) -> void:
	_requested_distance = requested_distance if requested_distance > 0.0 else MAX_DISTANCE
	refresh_layout()
	snap()


## Cambia la distancia de la cámara (limitada a MAX_DISTANCE). Con
## instant = false la transición es suave.
func set_distance(distance: float, instant := false) -> void:
	_requested_distance = distance
	if instant:
		_distance = _target_distance()
		_distance_vel = 0.0


func get_distance() -> float:
	return _distance


## Recalcula el encuadre cuando cambia el hueco libre (girar o redimensionar).
func refresh_layout() -> void:
	if level == null:
		return
	_fit_distance = _compute_fit_distance()
	_attention_frame_cell = Level.NO_CELL


## Coloca la cámara directamente en su posición final, sin transición.
func snap() -> void:
	_attention_button = Level.NO_CELL
	_attention_active = false
	_attention_frame_cell = Level.NO_CELL
	_attention_hold_until = 0
	_distance = _target_distance()
	_distance_vel = 0.0
	_place(_distance, Vector3.ZERO)
	_focus = _desired_focus()
	_focus_vel = Vector3.ZERO
	_place(_distance, _focus)


func _process(delta: float) -> void:
	if level == null:
		return
	_update_attention()
	var goal_distance := _target_distance()
	var goal_focus := Vector3.ZERO
	if _attention_active:
		var frame := _get_attention_frame()
		goal_distance = frame[0]
		goal_focus = frame[1]
	var d := _smooth_damp(Vector3(_distance, 0, 0), Vector3(goal_distance, 0, 0),
			Vector3(_distance_vel, 0, 0), zoom_smooth_time, delta)
	_distance = d[0].x
	_distance_vel = d[1].x
	if not _attention_active:
		goal_focus = _desired_focus()
	var f := _smooth_damp(_focus, goal_focus, _focus_vel, follow_smooth_time, delta)
	_focus = f[0]
	_focus_vel = f[1]
	_place(_distance, _focus)


## Distancia a la que debe ir la cámara: la del nivel (limitada al máximo y a
## lo necesario para ver el tablero entero), más el alejamiento por velocidad.
func _target_distance() -> float:
	var base := clampf(minf(_requested_distance, _fit_distance), MIN_DISTANCE, MAX_DISTANCE)
	var zoomed := base * (1.0 + SPEED_ZOOM_PER_EXTRA_SPEED * maxf(_target_speed() - 1.0, 0.0))
	return maxf(base, minf(zoomed, _fit_distance))


## Velocidad del objeto seguido respecto a la normal (1.0 si no la indica).
func _target_speed() -> float:
	if target and target.has_method("speed_multiplier"):
		return target.speed_multiplier()
	return 1.0


func _view_dir() -> Vector3:
	var pitch := deg_to_rad(pitch_degrees)
	return Vector3(0, sin(pitch), cos(pitch))


func _place(distance: float, focus: Vector3) -> void:
	position = focus + _view_dir() * distance
	look_at(focus, Vector3.UP)


## Punto al que debe mirar la cámara con la distancia actual: el centro del
## tablero en los ejes en que cabe entero, y el cubo (sin pasarse del borde)
## en los que no.
func _desired_focus() -> Vector3:
	var anchor: Vector3 = target.get_trail_anchor() if target.has_method("get_trail_anchor") else target.global_position
	return _clamped_focus(anchor, _distance)


## Foco que mira a `anchor` desde `distance` sin enseñar más allá del borde
## del tablero; en los ejes en que el tablero cabe entero, su centro.
func _clamped_focus(anchor: Vector3, distance: float) -> Vector3:
	var center := level.get_center()
	var bounds := _board_bounds()
	var view := _visible_extents(distance)
	var focus := Vector3(center.x, 0, center.z)
	# view = (izquierda, derecha, lejos, cerca): distancias del foco al borde visible.
	if bounds.size.x + EDGE_MARGIN * 2.0 > view.x + view.y:
		focus.x = clampf(anchor.x, bounds.position.x - EDGE_MARGIN + view.x,
				bounds.end.x + EDGE_MARGIN - view.y)
	if bounds.size.y + EDGE_MARGIN * 2.0 > view.z + view.w:
		focus.z = clampf(anchor.z, bounds.position.y - EDGE_MARGIN + view.z,
				bounds.end.y + EDGE_MARGIN - view.w)
	return focus


## Avisa de que el cubo ha pulsado un botón: si la cámara está enseñando sus
## barrotes, los sigue enseñando un momento aunque el cubo se aleje.
func notify_button_pressed() -> void:
	_attention_hold_until = Time.get_ticks_msec() + int(ATTENTION_HOLD * 1000.0)


## Comprueba si el cubo está cerca de un botón. Al llegar cerca de uno, la
## cámara solo se aleja si con el encuadre normal no se ven todos sus
## barrotes; se queda así hasta que el cubo se aleja del botón.
func _update_attention() -> void:
	var cube_cell = target.get("cell")
	var button := level.button_near(cube_cell) if cube_cell is Vector2i else Level.NO_CELL
	if button == _attention_button:
		return
	if _attention_active and Time.get_ticks_msec() < _attention_hold_until:
		return
	_attention_button = button
	_attention_frame_cell = Level.NO_CELL
	_attention_active = false
	if button == Level.NO_CELL or level.button_bars(button).is_empty():
		return
	var points := _cells_points(level.button_bars(button))
	_attention_active = not _points_fit(points, _target_distance(), _desired_focus())


## Encuadre [distancia, foco] en el que se ven el cubo, el botón cercano y
## todos sus barrotes: la menor distancia (nunca más cerca que la normal) con
## la que caben en el hueco libre. Si hace falta alejarse tanto que se ve el
## tablero entero, se encuadra el tablero. Se recalcula al cambiar de casilla.
func _get_attention_frame() -> Array:
	var cube_cell: Vector2i = target.get("cell")
	if cube_cell == _attention_frame_cell and not _attention_frame.is_empty():
		return _attention_frame
	_attention_frame_cell = cube_cell
	var cells: Array[Vector2i] = level.button_bars(_attention_button)
	cells.append_array([_attention_button, level.button_front(_attention_button), cube_cell])
	var points := _cells_points(cells)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in points:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	var anchor := Vector3((lo.x + hi.x) * 0.5, 0.0, (lo.y + hi.y) * 0.5)
	var low := _target_distance()
	var high := maxf(_fit_distance, low)
	if _points_fit(points, low, _clamped_focus(anchor, low)):
		high = low
	else:
		for i in 20:
			var mid := (low + high) * 0.5
			if _points_fit(points, mid, _clamped_focus(anchor, mid)):
				high = mid
			else:
				low = mid
	_attention_frame = [high, _clamped_focus(anchor, high)]
	return _attention_frame


## Esquinas de las casillas, a ras de suelo y a la altura de los muros.
func _cells_points(cells: Array[Vector2i]) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var half := Level.CELL_SIZE * 0.5
	for cell in cells:
		var c := level.cell_to_world(cell)
		for dx in [-half, half]:
			for dz in [-half, half]:
				for y in [0.0, Level.WALL_HEIGHT]:
					points.append(c + Vector3(dx, y, dz))
	return points


## Si todos los puntos se ven en el hueco libre con la cámara a `distance`
## mirando a `focus`.
func _points_fit(points: Array[Vector3], distance: float, focus: Vector3) -> bool:
	var area := _area_rect()
	var saved := transform
	_place(distance, focus)
	var inside := true
	for p in points:
		if is_position_behind(p) or not area.has_point(unproject_position(p)):
			inside = false
			break
	transform = saved
	return inside


## Rectángulo del tablero en el suelo (x, z), hasta el borde exterior de los muros.
func _board_bounds() -> Rect2:
	var grid := level.get_grid_size()
	var half := Level.CELL_SIZE * 0.5
	var lo := level.cell_to_world(Vector2i.ZERO) - Vector3(half, 0, half)
	var hi := level.cell_to_world(grid - Vector2i.ONE) + Vector3(half, 0, half)
	return Rect2(lo.x, lo.z, hi.x - lo.x, hi.z - lo.z)


## Distancias en el suelo desde el foco hasta los bordes del hueco libre:
## (izquierda, derecha, lejos, cerca). Para los lados se usa el borde cercano
## de la pantalla, que es el más estrecho por la perspectiva. Para el borde
## lejano se mide a la altura de los muros, que por la perspectiva se ven más
## arriba que su base: así el muro exterior no queda cortado.
func _visible_extents(distance: float) -> Vector4:
	var area := _area_rect()
	var saved := transform
	_place(distance, Vector3.ZERO)
	var left := _ground_hit(Vector2(area.position.x, area.end.y))
	var right := _ground_hit(Vector2(area.end.x, area.end.y))
	var far := _ground_hit(Vector2(area.get_center().x, area.position.y), Level.WALL_HEIGHT)
	var near := _ground_hit(Vector2(area.get_center().x, area.end.y))
	transform = saved
	return Vector4(-left.x, right.x, -far.z, near.z)


## Punto en que el rayo de la cámara por ese punto de pantalla corta el plano
## horizontal de altura `height`.
func _ground_hit(screen_point: Vector2, height := 0.0) -> Vector3:
	var origin := project_ray_origin(screen_point)
	var normal := project_ray_normal(screen_point)
	if absf(normal.y) < 0.0001:
		return origin
	return origin + normal * ((height - origin.y) / normal.y)


func _area_rect() -> Rect2:
	var area := play_area.get_global_rect() if play_area else Rect2()
	if area.size.x < 1.0 or area.size.y < 1.0:
		area = get_viewport().get_visible_rect()
	return area


## Menor distancia con la que todas las esquinas del tablero (suelo y altura de
## los muros, ampliadas con el margen) quedan dentro del hueco libre, mirando
## a su centro. Búsqueda binaria.
func _compute_fit_distance() -> float:
	var center := level.get_center()
	var corners := _board_corners(center)
	var area := _area_rect()
	var saved := transform
	var lo := 1.0
	var hi := 200.0
	for i in 30:
		var mid := (lo + hi) * 0.5
		_place(mid, center)
		var inside := true
		for p in corners:
			if is_position_behind(p) or not area.has_point(unproject_position(p)):
				inside = false
				break
		if inside:
			hi = mid
		else:
			lo = mid
	transform = saved
	return hi


func _board_corners(center: Vector3) -> Array[Vector3]:
	var grid := level.get_grid_size()
	var half := Level.CELL_SIZE * 0.5
	var lo := level.cell_to_world(Vector2i.ZERO) - Vector3(half, Level.FLOOR_THICKNESS, half)
	var hi := level.cell_to_world(grid - Vector2i.ONE) + Vector3(half, Level.WALL_HEIGHT, half)
	var corners: Array[Vector3] = []
	for x in [lo.x, hi.x]:
		for y in [lo.y, hi.y]:
			for z in [lo.z, hi.z]:
				corners.append(center + (Vector3(x, y, z) - center) * fit_margin)
	return corners


## Amortiguamiento crítico (como SmoothDamp): devuelve [valor, velocidad].
## Acelera y frena con suavidad y nunca se pasa del objetivo.
static func _smooth_damp(current: Vector3, goal: Vector3, velocity: Vector3,
		smooth_time: float, delta: float) -> Array:
	var omega := 2.0 / maxf(smooth_time, 0.0001)
	var x := omega * delta
	var decay := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := current - goal
	var temp := (velocity + omega * change) * delta
	var new_velocity := (velocity - omega * temp) * decay
	var value := goal + (change + temp) * decay
	# Evita pasarse del objetivo por errores numéricos.
	if (goal - current).dot(value - goal) > 0.0:
		value = goal
		new_velocity = Vector3.ZERO
	return [value, new_velocity]
