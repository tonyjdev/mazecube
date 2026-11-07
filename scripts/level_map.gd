class_name LevelMap
extends Control
## Mapa de niveles con desplazamiento vertical: un camino de baldosas que
## serpentea de abajo (nivel 1) hacia arriba, con una parada por nivel.
##
## Cada parada es una baldosa redondeada con el número del nivel y su nombre
## debajo: verde si está completado, dorada (latiendo) si es el siguiente por
## jugar y gris con candado si está bloqueado. Un cubito de colores flota
## sobre el nivel siguiente por jugar. A los lados del camino hay bloques de
## muro decorativos, como en los laberintos.
##
## Se arrastra con el dedo (o el ratón) para desplazarse, con inercia, y la
## rueda del ratón también desplaza. Tocar una parada desbloqueada la juega
## (un toque es una pulsación que no se ha movido más de TAP_SLOP píxeles).
## Con el teclado, arriba/abajo cambian el nivel elegido e Intro lo juega.
##
## Solo se usan los eventos de ratón: en el móvil los toques llegan también
## como clic (emulate_mouse_from_touch) y en el PC el ratón se emula como toque.

signal level_chosen(index: int)

const SPACING := 150.0
## Hueco bajo la primera parada y sobre la última (incluye el nombre y el
## cubito que flota encima).
const BOTTOM_MARGIN := 110.0
const TOP_MARGIN := 120.0
const NODE_RADIUS := 44.0
## Lado de cada bloque de los muros decorativos.
const BLOCK := 30.0
## Amplitud de la curva del camino (fracción del ancho, con un máximo).
const WAVE_FRACTION := 0.24
const WAVE_MAX := 300.0
const WAVE_STEP := 1.1
const PATH_WIDTH := 34.0
const TAP_SLOP := 14.0
## Frenado de la inercia (fracción de velocidad que se pierde por segundo).
const FRICTION := 4.0
const WHEEL_STEP := 90.0

const PATH_COLOR := Color(0.86, 0.84, 0.80)
const PATH_EDGE := Color(0.55, 0.50, 0.44)
const PATH_DONE := Color(0.62, 0.86, 0.55)
const WALL_COLOR := Color(0.32, 0.36, 0.45)
const WALL_TOP := Color(0.42, 0.47, 0.58)
const DONE_COLOR := Color(0.30, 0.72, 0.40)
const NEXT_COLOR := Color(0.98, 0.78, 0.30)
const LOCKED_COLOR := Color(0.45, 0.43, 0.40)
const SELECTED_RING := Color(1, 1, 1, 0.9)
const TEXT_COLOR := Color(0.98, 0.95, 0.88)
const SHADOW := Color(0, 0, 0, 0.3)

var _scroll := 0.0
var _velocity := 0.0
var _pressing := false
var _dragged := false
var _press_pos := Vector2.ZERO
var _last_y := 0.0
var _last_time := 0.0
var _selected := 0
var _time := 0.0
var _center_pending := false
## Muros decorativos: (posición en niveles, lado, separación del camino,
## forma). Cada uno es una pieza de 2 o 3 bloques en línea o en L.
var _decor: Array[Vector4] = []


func _ready() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_clamp_scroll)
	_build_decor()


## Rehace el mapa (progreso o idioma cambiados) y centra el nivel siguiente
## por jugar.
func refresh() -> void:
	_selected = _next_level()
	_velocity = 0.0
	# Se centra en el siguiente fotograma, cuando el mapa ya tiene su tamaño.
	_center_pending = true
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _center_pending and size.y > 0.0:
		_center_pending = false
		_center_on(_selected)
	if not _pressing and absf(_velocity) > 1.0:
		_scroll += _velocity * delta
		_velocity *= maxf(0.0, 1.0 - FRICTION * delta)
		_clamp_scroll()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_scroll_by(WHEEL_STEP)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_scroll_by(-WHEEL_STEP)
		elif button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_pressing = true
				_dragged = false
				_press_pos = button.position
				_last_y = button.position.y
				_last_time = _now()
				_velocity = 0.0
			elif _pressing:
				_pressing = false
				if not _dragged:
					_tap(button.position)
		accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion and _pressing:
		if not _dragged and motion.position.distance_to(_press_pos) > TAP_SLOP:
			_dragged = true
		if _dragged:
			var dy := motion.position.y - _last_y
			var now := _now()
			var dt := maxf(now - _last_time, 0.001)
			_scroll += dy
			_clamp_scroll()
			_velocity = lerpf(_velocity, dy / dt, 0.5)
			_last_y = motion.position.y
			_last_time = now
		accept_event()
		return
	if event.is_action_pressed("ui_up"):
		_select(_selected + 1)
		accept_event()
	elif event.is_action_pressed("ui_down"):
		_select(_selected - 1)
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		if GameState.is_unlocked(_selected):
			level_chosen.emit(_selected)
		accept_event()


func _draw() -> void:
	var count := Levels.count()
	var first := maxi(0, int(floor((_scroll - BOTTOM_MARGIN - size.y) / SPACING)) - 1)
	var last := mini(count - 1, int(ceil((_scroll + size.y) / SPACING)) + 1)
	_draw_decor()
	# Camino: tramos entre paradas consecutivas, en verde los ya recorridos.
	for i in range(maxi(first - 1, 0), mini(last + 1, count - 1)):
		var a := _node_pos(i)
		var b := _node_pos(i + 1)
		var done := GameState.is_completed(i)
		_draw_segment(a, b, PATH_DONE if done else PATH_COLOR)
	var font := get_theme_default_font()
	for i in range(first, last + 1):
		_draw_stop(i, font)
	_draw_player_marker()


func _draw_segment(a: Vector2, b: Vector2, color: Color) -> void:
	# Curva suave entre las dos paradas (puntos de control en vertical).
	var points := PackedVector2Array()
	var c1 := a + Vector2(0, -SPACING * 0.5)
	var c2 := b + Vector2(0, SPACING * 0.5)
	for s in 17:
		var t := s / 16.0
		var u := 1.0 - t
		points.append(a * u * u * u + c1 * 3 * u * u * t + c2 * 3 * u * t * t + b * t * t * t)
	draw_polyline(points, PATH_EDGE, PATH_WIDTH + 8.0, true)
	draw_polyline(points, color, PATH_WIDTH, true)
	# Juntas de las baldosas.
	for s in range(2, 16, 3):
		var p := points[s]
		var dir := (points[s + 1] - points[s - 1]).normalized()
		var side := Vector2(-dir.y, dir.x) * PATH_WIDTH * 0.5
		draw_line(p - side, p + side, PATH_EDGE.lerp(color, 0.4), 2.0, true)


func _draw_stop(i: int, font: Font) -> void:
	var pos := _node_pos(i)
	var unlocked := GameState.is_unlocked(i)
	var completed := GameState.is_completed(i)
	var is_next := unlocked and not completed
	var color := DONE_COLOR if completed else (NEXT_COLOR if is_next else LOCKED_COLOR)
	var radius := NODE_RADIUS
	if is_next:
		radius *= 1.0 + 0.06 * sin(_time * 4.0)
	var rect := Rect2(pos - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	_draw_rounded(rect.grow(4).grow_individual(0, -2, 0, 6), SHADOW, radius * 0.4)
	_draw_rounded(rect.grow(4), color.darkened(0.35), radius * 0.4)
	_draw_rounded(rect, color, radius * 0.35)
	_draw_rounded(Rect2(rect.position + Vector2(6, 6), Vector2(rect.size.x - 12, rect.size.y * 0.45)),
		color.lightened(0.18), radius * 0.3)
	if i == _selected and has_focus():
		draw_arc(pos, radius + 12.0, 0, TAU, 48, SELECTED_RING, 4.0, true)
	if unlocked:
		var number := str(i + 1)
		var number_size := 40
		var text_size := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size)
		var baseline := pos + Vector2(-text_size.x * 0.5,
			font.get_ascent(number_size) * 0.5 - font.get_descent(number_size) * 0.3)
		draw_string_outline(font, baseline, number, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size, 8,
			color.darkened(0.55))
		draw_string(font, baseline, number, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size, TEXT_COLOR)
	else:
		_draw_padlock(pos)
	var name_text: String = tr(Levels.get_level(i)["name"]) if unlocked else tr("LEVEL_LOCKED")
	var name_size := 22
	var name_w := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
	var name_pos := pos + Vector2(-name_w * 0.5, NODE_RADIUS + 30)
	draw_string_outline(font, name_pos, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, 6,
		Color(0.12, 0.10, 0.08))
	draw_string(font, name_pos, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size,
		TEXT_COLOR if unlocked else TEXT_COLOR.darkened(0.35))


func _draw_padlock(pos: Vector2) -> void:
	var body := Rect2(pos + Vector2(-17, -4), Vector2(34, 26))
	draw_arc(pos + Vector2(0, -6), 11.0, PI, TAU, 16, Color(0.25, 0.24, 0.23), 6.0, true)
	_draw_rounded(body, Color(0.25, 0.24, 0.23), 5.0)
	draw_circle(pos + Vector2(0, 8), 4.0, LOCKED_COLOR)


## Cubito con tres caras visibles flotando sobre el nivel siguiente por jugar.
func _draw_player_marker() -> void:
	var index := _next_level()
	var pos := _node_pos(index) + Vector2(0, -NODE_RADIUS - 46 + sin(_time * 3.0) * 6.0)
	var s := 22.0
	var top := PackedVector2Array([pos + Vector2(0, -s), pos + Vector2(s, -s * 0.5),
		pos + Vector2(0, 0), pos + Vector2(-s, -s * 0.5)])
	var left := PackedVector2Array([pos + Vector2(-s, -s * 0.5), pos, pos + Vector2(0, s),
		pos + Vector2(-s, s * 0.5)])
	var right := PackedVector2Array([pos, pos + Vector2(s, -s * 0.5), pos + Vector2(s, s * 0.5),
		pos + Vector2(0, s)])
	var faces := RollingCube.FACE_COLORS
	draw_colored_polygon(top, faces[2])
	draw_colored_polygon(left, faces[1])
	draw_colored_polygon(right, faces[0])
	for poly in [top, left, right]:
		var closed := PackedVector2Array(poly)
		closed.append(poly[0])
		draw_polyline(closed, Color(0.15, 0.12, 0.10, 0.8), 2.0, true)


## Bloques de muro a los lados del camino, colocados siempre igual.
func _build_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7071
	_decor.clear()
	for i in range(-2, Levels.count() + 3):
		for side: float in [-1.0, 1.0]:
			_decor.append(Vector4(i + rng.randf_range(-0.3, 0.3), side,
				rng.randf_range(0.35, 0.9), rng.randi_range(0, 3)))


func _draw_decor() -> void:
	var amplitude := _amplitude()
	# Formas: desplazamientos (en bloques) de cada bloque de la pieza.
	var shapes := [
		[Vector2(0, 0), Vector2(1, 0), Vector2(2, 0)],
		[Vector2(0, 0), Vector2(0, 1), Vector2(0, 2)],
		[Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)],
		[Vector2(0, 0), Vector2(1, 0)],
	]
	for d in _decor:
		var center := _node_pos_f(d.x)
		var x := size.x * 0.5 + d.y * (amplitude + NODE_RADIUS + 40.0 + d.z * size.x * 0.12)
		var origin := Vector2(x, center.y)
		if origin.y < -120 or origin.y > size.y + 120:
			continue
		for offset: Vector2 in shapes[int(d.w)]:
			var pos := origin + Vector2(offset.x * d.y, offset.y) * BLOCK
			var block := Rect2(pos - Vector2.ONE * BLOCK * 0.5, Vector2.ONE * BLOCK)
			draw_rect(Rect2(block.position + Vector2(0, BLOCK * 0.3), block.size), WALL_COLOR.darkened(0.35))
			draw_rect(block, WALL_TOP)
			draw_rect(block, WALL_COLOR, false, 2.0)


func _draw_rounded(rect: Rect2, color: Color, radius: float) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius))
	box.anti_aliasing = true
	draw_style_box(box, rect)


func _tap(at: Vector2) -> void:
	for i in Levels.count():
		if at.distance_to(_node_pos(i)) <= NODE_RADIUS + 10.0:
			_selected = i
			if GameState.is_unlocked(i):
				level_chosen.emit(i)
			return


func _select(index: int) -> void:
	_selected = clampi(index, 0, Levels.count() - 1)
	_center_on(_selected, false)


## Nivel siguiente por jugar: el primero desbloqueado sin completar (o el
## último si están todos completados).
func _next_level() -> int:
	for i in Levels.count():
		if GameState.is_unlocked(i) and not GameState.is_completed(i):
			return i
	return Levels.count() - 1


## Posición en pantalla de la parada del nivel `i`.
func _node_pos(i: int) -> Vector2:
	return _node_pos_f(float(i))


func _node_pos_f(i: float) -> Vector2:
	var y := size.y - BOTTOM_MARGIN - i * SPACING + _scroll
	var x := size.x * 0.5 + sin(i * WAVE_STEP) * _amplitude()
	return Vector2(x, y)


func _amplitude() -> float:
	return minf(size.x * WAVE_FRACTION, WAVE_MAX)


func _max_scroll() -> float:
	var content := BOTTOM_MARGIN + (Levels.count() - 1) * SPACING + TOP_MARGIN
	return maxf(0.0, content - size.y)


func _center_on(i: int, instant := true) -> void:
	var target := clampf(i * SPACING + BOTTOM_MARGIN - size.y * 0.5, 0.0, _max_scroll())
	if instant:
		_scroll = target
	else:
		# Se desliza hasta él (con la inercia del arrastre).
		_velocity = (target - _scroll) * FRICTION
	_clamp_scroll()


func _scroll_by(amount: float) -> void:
	_velocity = 0.0
	_scroll += amount
	_clamp_scroll()


func _clamp_scroll() -> void:
	var clamped := clampf(_scroll, 0.0, _max_scroll())
	if clamped != _scroll:
		_velocity = 0.0
	_scroll = clamped


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
