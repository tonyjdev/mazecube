class_name LevelMap
extends Control
## Selector de niveles: la imagen del mapa (ui/level_select/map.png) a toda
## la pantalla (ocupa todo el ancho y se desplaza en vertical), y encima el
## estado de cada nivel.
##
## La imagen trae dibujados el camino, los círculos grises de los niveles,
## la casilla de inicio y los carteles de las zonas. Dónde está cada cosa lo
## dice ui/level_select/map.json, que genera tools/find_level_circles.py a
## partir de la imagen: los círculos en el orden del camino (el primero es
## el nivel 1), su tamaño y su zona, los huecos de los carteles y el de
## «INICIO» bajo la casilla de salida.
##
## Encima de la imagen se dibuja:
## - En cada círculo, el número del nivel. Si el nivel está completado se
##   tapa el gris con circle_done.png (verde) y si es el activo (el
##   siguiente por jugar) con circle_active.png (dorado, latiendo). En los
##   bloqueados, y en los círculos de niveles que aún no existen, el número
##   se ve atenuado sobre el gris de la imagen.
## - Bajo cada nivel completado, sus tres estrellas (las de su mejor partida:
##   llenas las conseguidas y huecas las que no; ver StarIcon.draw_star).
## - El nombre de cada zona en su cartel y «INICIO» bajo la salida.
##
## Se arrastra con el dedo (o el ratón) para desplazarse, con inercia, y la
## rueda del ratón también desplaza. Tocar un círculo desbloqueado juega ese
## nivel (un toque es una pulsación que no se ha movido más de TAP_SLOP
## píxeles). Con el teclado, arriba/abajo cambian el nivel elegido e Intro
## lo juega.
##
## Solo se usan los eventos de ratón: en el móvil los toques llegan también
## como clic (emulate_mouse_from_touch) y en el PC el ratón se emula como toque.

signal level_chosen(index: int)
## Se ha tocado el rótulo «INICIO» bajo la casilla de salida.
signal start_tapped

const MAP_TEXTURE := preload("res://ui/level_select/map.png")
const DONE_TEXTURE := preload("res://ui/level_select/circle_done.png")
const ACTIVE_TEXTURE := preload("res://ui/level_select/circle_active.png")
const LAYOUT_PATH := "res://ui/level_select/map.json"
## Medidas de circle_*.png (ver tools/make_circle_sprites.py): ancho de la
## cara coloreada y altura de su centro dentro de la imagen.
const SPRITE_INNER_W := 168.0
const SPRITE_FACE_Y := 96.0

## Claves de traducción del nombre de cada zona, de abajo arriba.
const ZONE_KEYS: Array[String] = ["ZONE_1", "ZONE_2", "ZONE_3", "ZONE_4", "ZONE_5"]
const ROMAN: Array[String] = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

const TAP_SLOP := 14.0
## Margen extra (fracción del tamaño del círculo) para acertar al tocar.
const TAP_MARGIN := 0.35
## Frenado de la inercia (fracción de velocidad que se pierde por segundo).
const FRICTION := 4.0
const WHEEL_STEP := 90.0
## Latido del círculo activo: amplitud y velocidad.
const PULSE_AMOUNT := 0.06
const PULSE_SPEED := 4.0
## Tamaño del número respecto a la altura del círculo.
const NUMBER_SCALE := 0.78

const TEXT_COLOR := Color(1.0, 0.98, 0.92)
const DONE_OUTLINE := Color(0.08, 0.30, 0.08)
const ACTIVE_OUTLINE := Color(0.45, 0.25, 0.02)
const LOCKED_TEXT := Color(0.95, 0.95, 0.97, 0.55)
const LOCKED_OUTLINE := Color(0.18, 0.18, 0.2, 0.45)
const LABEL_OUTLINE := Color(0.06, 0.05, 0.1, 0.85)
const SELECTED_RING := Color(1, 1, 1, 0.95)
## Estrellas bajo el círculo: radio y separación (fracción del ancho del
## círculo) y cuánto bajan las de los lados (en arco).
const STAR_RADIUS := 0.2
const STAR_SPACING := 0.42
const STAR_ARC := 0.08

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
## Mientras el jugador no mueva el mapa, se vuelve a centrar en el nivel
## activo cada vez que cambia de tamaño (al abrir la pantalla en el móvil el
## tamaño definitivo puede llegar unos fotogramas después).
var _follow_selected := false
## Datos de map.json.
var _image_size := Vector2.ONE
var _circles: Array[Dictionary] = []
var _zones: Array[Rect2] = []
var _start_label := Rect2()
## Capas del dibujo (ver _create_layers).
var _content: Node2D
var _active_node: Node2D
var _ring_node: Node2D
var _badge_nodes: Array[Node2D] = []
var _star_nodes: Array[Node2D] = []
## Nivel activo y tamaño de letra de los carteles (calculados en _rebuild).
var _active := 0
var _zone_font_size := 0


func _ready() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_on_resized)
	focus_entered.connect(_update_ring)
	focus_exited.connect(_update_ring)
	_load_layout()
	_create_layers()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_rebuild()


## Rehace el mapa (progreso o idioma cambiados) y centra el nivel activo.
func refresh() -> void:
	_selected = _next_level()
	_velocity = 0.0
	# Se centra en el siguiente fotograma, cuando el mapa ya tiene su tamaño.
	_center_pending = true
	_follow_selected = true
	_rebuild()


func _on_resized() -> void:
	if _follow_selected and size.y > 0.0:
		_center_on(_selected)
	_clamp_scroll()
	_rebuild()


func _load_layout() -> void:
	var data: Variant = null
	var resource := load(LAYOUT_PATH)
	if resource is JSON:
		data = (resource as JSON).data
	else:
		var file := FileAccess.open(LAYOUT_PATH, FileAccess.READ)
		if file:
			data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		push_error("No se puede leer %s" % LAYOUT_PATH)
		return
	_image_size = Vector2(data["size"][0], data["size"][1])
	_circles.clear()
	for c: Dictionary in data["circles"]:
		_circles.append({"pos": Vector2(c["x"], c["y"]), "size": Vector2(c["w"], c["h"]), "zone": int(c["zone"])})
	_zones.clear()
	for z: Dictionary in data["zones"]:
		_zones.append(Rect2(z["x"], z["y"], z["w"], z["h"]))
	var label: Dictionary = data["start"]["label"]
	_start_label = Rect2(label["x"], label["y"], label["w"], label["h"])
	if Levels.count() > _circles.size():
		push_warning("Hay %d niveles pero el mapa solo tiene %d círculos" % [Levels.count(), _circles.size()])


func _process(delta: float) -> void:
	_time += delta
	if _center_pending and size.y > 0.0:
		_center_pending = false
		_center_on(_selected)
	if not _pressing and absf(_velocity) > 1.0:
		_scroll += _velocity * delta
		_velocity *= maxf(0.0, 1.0 - FRICTION * delta)
		_clamp_scroll()
	if _active_node and _active_node.visible:
		_active_node.scale = Vector2.ONE * (1.0 + PULSE_AMOUNT * sin(_time * PULSE_SPEED))


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button:
		if button.pressed:
			_follow_selected = false
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
		_follow_selected = false
		_select(_selected + 1)
		accept_event()
	elif event.is_action_pressed("ui_down"):
		_follow_selected = false
		_select(_selected - 1)
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		if _selected < Levels.count() and GameState.is_unlocked(_selected):
			level_chosen.emit(_selected)
		accept_event()


# --- Dibujo -------------------------------------------------------------------
#
# Para que el desplazamiento sea fluido no se redibuja nada al mover el mapa:
# todo cuelga de _content, que se dibuja una sola vez (en _rebuild) en
# coordenadas de la imagen ya escalada, y al desplazarse solo cambia su
# posición. Cada círculo es su propio CanvasItem (insignia y estrellas), así
# que el motor descarta los que quedan fuera de la pantalla. El círculo activo
# late cambiando la escala de su nodo, sin redibujarlo.

func _create_layers() -> void:
	_content = Node2D.new()
	_content.name = "Content"
	add_child(_content)
	_content.draw.connect(_draw_content)
	var badges := Node2D.new()
	badges.name = "Badges"
	_content.add_child(badges)
	_active_node = Node2D.new()
	_active_node.name = "Active"
	_content.add_child(_active_node)
	_active_node.draw.connect(_draw_active)
	var stars := Node2D.new()
	stars.name = "Stars"
	_content.add_child(stars)
	_ring_node = Node2D.new()
	_ring_node.name = "Ring"
	_content.add_child(_ring_node)
	_ring_node.draw.connect(_draw_ring)
	for i in _circles.size():
		var badge := Node2D.new()
		badges.add_child(badge)
		badge.draw.connect(_draw_badge.bind(badge, i))
		_badge_nodes.append(badge)
		var star := Node2D.new()
		stars.add_child(star)
		star.draw.connect(_draw_stars.bind(star, i))
		_star_nodes.append(star)


## Vuelve a dibujar todo el mapa (tamaño, progreso o idioma cambiados).
func _rebuild() -> void:
	if _content == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var scale := _scale()
	var font := get_theme_default_font()
	# Todos los carteles con el mismo tamaño de letra: el que cabe en todos.
	_zone_font_size = 0
	for i in _zones.size():
		var fit := _fit_font_size(_zone_text_area(_scaled_rect(_zones[i])), _zone_words(i), font)
		_zone_font_size = fit if _zone_font_size == 0 else mini(_zone_font_size, fit)
	_active = _next_level()
	for i in _circles.size():
		var center: Vector2 = _circles[i]["pos"] * scale
		_badge_nodes[i].position = center
		_badge_nodes[i].queue_redraw()
		_star_nodes[i].position = center
		_star_nodes[i].visible = i < Levels.count() and GameState.is_completed(i)
		_star_nodes[i].queue_redraw()
	_active_node.visible = _has_active()
	if _active < _circles.size():
		_active_node.position = _circles[_active]["pos"] * scale
	_active_node.queue_redraw()
	_update_ring()
	_content.queue_redraw()
	_update_content_position()


func _has_active() -> bool:
	return _active < Levels.count() and _active < _circles.size() and GameState.is_unlocked(_active)


func _update_content_position() -> void:
	if _content:
		var origin := _image_origin()
		if _content.position != origin:
			_content.position = origin


func _update_ring() -> void:
	if _ring_node == null:
		return
	_ring_node.visible = has_focus() and _selected < _circles.size()
	if _ring_node.visible:
		_ring_node.position = _circles[_selected]["pos"] * _scale()
		_ring_node.queue_redraw()


## La imagen y los rótulos de las zonas y de «INICIO».
func _draw_content() -> void:
	var scale := _scale()
	_content.draw_texture_rect(MAP_TEXTURE, Rect2(Vector2.ZERO, _image_size * scale), false)
	var font := get_theme_default_font()
	for i in _zones.size():
		_draw_fitted_text(_content, _zone_text_area(_scaled_rect(_zones[i])), _zone_words(i), font,
			TEXT_COLOR, HORIZONTAL_ALIGNMENT_LEFT, _zone_font_size)
	_draw_fitted_text(_content, _scaled_rect(_start_label), [tr("MAP_START")], font, TEXT_COLOR)


## Círculo `i` (completado, bloqueado o que aún no existe); el activo lo
## dibuja _active_node.
func _draw_badge(canvas: Node2D, i: int) -> void:
	if i == _active and _has_active():
		return
	var completed := i < Levels.count() and GameState.is_completed(i)
	if completed:
		_draw_circle_face(canvas, i, DONE_TEXTURE, DONE_OUTLINE, TEXT_COLOR)
	else:
		_draw_circle_face(canvas, i, null, LOCKED_OUTLINE, LOCKED_TEXT)


func _draw_active() -> void:
	if _has_active():
		_draw_circle_face(_active_node, _active, ACTIVE_TEXTURE, ACTIVE_OUTLINE, TEXT_COLOR)


## Dibuja el círculo `i` centrado en el origen de `canvas`: el sprite
## coloreado (si hay) y el número.
func _draw_circle_face(canvas: CanvasItem, i: int, texture: Texture2D, outline: Color,
		text_color: Color) -> void:
	var circle_size: Vector2 = _circles[i]["size"] * _scale()
	if texture:
		var k := circle_size.x / SPRITE_INNER_W
		var tex_size := Vector2(texture.get_width(), texture.get_height()) * k
		var top_left := -Vector2(tex_size.x * 0.5, SPRITE_FACE_Y * k)
		canvas.draw_texture_rect(texture, Rect2(top_left, tex_size), false)
	var font := get_theme_default_font()
	var number := str(i + 1)
	var font_size := maxi(8, int(circle_size.y * NUMBER_SCALE))
	var text_size := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := Vector2(-text_size.x * 0.5,
		font.get_ascent(font_size) * 0.5 - font.get_descent(font_size) * 0.3)
	canvas.draw_string_outline(font, baseline, number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		maxi(2, font_size / 6), outline)
	canvas.draw_string(font, baseline, number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)


## Las tres estrellas de la mejor partida, en arco bajo el círculo.
func _draw_stars(canvas: Node2D, i: int) -> void:
	if i >= Levels.count() or not GameState.is_completed(i):
		return
	var circle_size: Vector2 = _circles[i]["size"] * _scale()
	var stars := GameState.best_stars(i)
	var radius := circle_size.x * STAR_RADIUS
	var spacing := circle_size.x * STAR_SPACING
	var base := Vector2(0, circle_size.y * 0.5 + radius * 0.9)
	for k in 3:
		var offset := k - 1
		var pos := base + Vector2(offset * spacing, absf(offset) * circle_size.x * STAR_ARC)
		StarIcon.draw_star(canvas, pos, radius, stars.size() == 3 and stars[k])


func _draw_ring() -> void:
	if _selected >= _circles.size():
		return
	var radii: Vector2 = _circles[_selected]["size"] * _scale() * 0.5 + Vector2(10, 8)
	var points := PackedVector2Array()
	for s in 41:
		var a := TAU * s / 40.0
		points.append(Vector2(cos(a) * radii.x, sin(a) * radii.y))
	_ring_node.draw_polyline(points, SELECTED_RING, 3.0, true)


## Texto del cartel de la zona `i`: el número romano seguido del nombre
## («II. LAS TIERRAS SALVAJES»), palabra a palabra.
func _zone_words(i: int) -> Array[String]:
	var words: Array[String] = [ROMAN[mini(i, ROMAN.size() - 1)] + "."]
	if i < ZONE_KEYS.size():
		words.append_array(tr(ZONE_KEYS[i]).split(" ", false))
	return words


## Hueco para el texto dentro del cartel (acaba en punta por la derecha: el
## texto se queda algo antes).
func _zone_text_area(rect: Rect2) -> Rect2:
	return Rect2(rect.position + Vector2(rect.size.x * 0.05, rect.size.y * 0.1),
		Vector2(rect.size.x * 0.85, rect.size.y * 0.8))


## Tamaño de letra más grande con el que `words`, repartidas en líneas,
## caben en `rect`.
func _fit_font_size(rect: Rect2, words: Array[String], font: Font) -> int:
	var font_size := maxi(int(rect.size.y), 8)
	while font_size > 8:
		var lines := _wrap(words, font, font_size, rect.size.x)
		var widest := 0.0
		for line in lines:
			widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		if lines.size() * font.get_height(font_size) <= rect.size.y and widest <= rect.size.x:
			break
		font_size -= 1
	return font_size


## Escribe `words` en `rect` (en `canvas`), repartidas en líneas y centradas en vertical.
## `align` es la alineación horizontal de cada línea (izquierda o centro) y
## `font_size` el tamaño de letra (0 = el más grande que quepa).
func _draw_fitted_text(canvas: CanvasItem, rect: Rect2, words: Array[String], font: Font, color: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER, font_size := 0) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	if font_size <= 0:
		font_size = _fit_font_size(rect, words, font)
	var lines := _wrap(words, font, font_size, rect.size.x)
	var line_h := font.get_height(font_size)
	var y := rect.position.y + (rect.size.y - lines.size() * line_h) * 0.5 + font.get_ascent(font_size)
	var outline_size := maxi(3, font_size / 5)
	for line in lines:
		var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var x := rect.position.x
		if align == HORIZONTAL_ALIGNMENT_CENTER:
			x += (rect.size.x - w) * 0.5
		var pos := Vector2(x, y)
		canvas.draw_string_outline(font, pos, line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_size, LABEL_OUTLINE)
		canvas.draw_string(font, pos, line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		y += line_h


func _wrap(words: Array[String], font: Font, font_size: int, max_width: float) -> Array[String]:
	var lines: Array[String] = []
	var current := ""
	for word in words:
		var candidate := word if current == "" else current + " " + word
		if current != "" and font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width:
			lines.append(current)
			current = word
		else:
			current = candidate
	if current != "":
		lines.append(current)
	return lines


# --- Posiciones -----------------------------------------------------------------

## Escala de la imagen: ocupa todo el ancho del mapa y, como mínimo, todo
## el alto (si sobra anchura se recorta por los lados, centrada).
func _scale() -> float:
	if _image_size.x <= 0.0 or _image_size.y <= 0.0:
		return 1.0
	return maxf(size.x / _image_size.x, size.y / _image_size.y)


func _content_height() -> float:
	return _image_size.y * _scale()


## Esquina superior izquierda de la imagen en pantalla. Con _scroll = 0 se ve
## la parte de abajo (la salida); al subir, _scroll crece.
func _image_origin() -> Vector2:
	var x := (size.x - _image_size.x * _scale()) * 0.5
	return Vector2(x, size.y - _content_height() + _scroll)


func _to_screen(point: Vector2) -> Vector2:
	return _image_origin() + point * _scale()


func _to_screen_rect(rect: Rect2) -> Rect2:
	return Rect2(_to_screen(rect.position), rect.size * _scale())


## `rect` de la imagen, escalado (en coordenadas de _content).
func _scaled_rect(rect: Rect2) -> Rect2:
	return Rect2(rect.position * _scale(), rect.size * _scale())


func _circle_center(i: int) -> Vector2:
	return _to_screen(_circles[i]["pos"])


# --- Selección y desplazamiento ---------------------------------------------

func _tap(at: Vector2) -> void:
	if _to_screen_rect(_start_label).grow(12.0).has_point(at):
		start_tapped.emit()
		return
	for i in _circles.size():
		var half: Vector2 = _circles[i]["size"] * _scale() * (0.5 + TAP_MARGIN)
		var d := (at - _circle_center(i)) / half
		if d.length_squared() <= 1.0:
			_selected = i
			if i < Levels.count() and GameState.is_unlocked(i):
				level_chosen.emit(i)
			return


func _select(index: int) -> void:
	_selected = clampi(index, 0, _selectable_count() - 1)
	_center_on(_selected, false)
	_update_ring()


func _selectable_count() -> int:
	return maxi(1, mini(Levels.count(), _circles.size()))


## Nivel activo: el primero desbloqueado sin completar (o el último si están
## todos completados).
func _next_level() -> int:
	for i in _selectable_count():
		if GameState.is_unlocked(i) and not GameState.is_completed(i):
			return i
	return _selectable_count() - 1


func _max_scroll() -> float:
	return maxf(0.0, _content_height() - size.y)


func _center_on(i: int, instant := true) -> void:
	if i >= _circles.size():
		return
	var y: float = _circles[i]["pos"].y * _scale()
	var target := clampf(size.y * 0.5 - y - size.y + _content_height(), 0.0, _max_scroll())
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
	_update_content_position()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
