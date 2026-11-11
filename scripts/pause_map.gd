class_name PauseMap
extends Control
## Mapa 2D del nivel en la pausa, al estilo de los metroidvania: sobre un
## fondo negro medio transparente (detrás se ve la partida congelada, ver
## Game) se dibujan los límites del tablero, las casillas de inicio (la
## activada resaltada), lo que se puede coger, los cofres sin abrir y los
## obstáculos fijos, tal como están ahora y solo en la zona ya explorada
## (ver Level.map_snapshot y Level.mark_seen_around). Nunca los enemigos ni
## lo que se mueve. El borde de lo explorado (lo que solo se ha visto de
## lejos) se difumina, ver Level.seen_alpha. El cubo se marca con un anillo
## que late. El encuadre y el arrastre se limitan a la zona explorada.
##
## El mapa se dibuja una sola vez al abrir la pausa (open): desplazarlo y
## acercarlo solo cambia la posición y la escala del nodo que lo dibuja.
## Todo se dibuja en unidades de casilla (1 = una casilla) y ese nodo se
## escala a `_zoom` píxeles por casilla.
##
## Controles: arrastrar un dedo (o el ratón) desplaza el mapa; pellizcar con
## dos dedos, la rueda del ratón o los botones + y − lo acercan o alejan; el
## botón de la diana lo centra en el cubo y el de la lista muestra u oculta
## la leyenda (solo con lo que hay ahora en el nivel; se recuerda abierta o
## cerrada entre pausas).

const BACKDROP_COLOR := Color(0.0, 0.0, 0.0, 0.72)
const FLOOR_COLOR := Color(0.27, 0.29, 0.34)
const WALL_COLOR := Color(0.85, 0.81, 0.72)
const OUTLINE_COLOR := Color(0.08, 0.07, 0.06)
const BREAKABLE_COLOR := Color(0.66, 0.5, 0.36)
const BRIDGE_COLOR := Color(0.64, 0.46, 0.28)
const SPIKE_COLOR := Color(0.95, 0.35, 0.3)
const LASER_COLOR := Color(1.0, 0.22, 0.18)
const MORTAR_COLOR := Color(1.0, 0.58, 0.16)
const GOLD_COLOR := Color(1.0, 0.8, 0.2)
const POWER_UP_COLOR := Color(0.4, 0.9, 1.0)
const CUBE_COLOR := Color(1.0, 1.0, 1.0)
## Color de cada grupo de barrotes; los botones llevan el del grupo que
## cambian (el primero, si cambian varios).
const BAR_COLORS := {
	"c": Color(0.95, 0.85, 0.3),
	"d": Color(0.45, 0.85, 1.0),
	"e": Color(0.95, 0.5, 0.85),
	"f": Color(0.6, 0.95, 0.45),
	"h": Color(1.0, 0.6, 0.35),
}
## Elementos que van sobre una casilla de muro (en la leyenda, su fondo).
const WALL_KINDS := ["wall", "button", "laser", "mortar", "breakable"]

## Píxeles por casilla: al abrir (como mínimo; si el mapa cabe entero con
## más, se abre entero) y como máximo al acercar. Al alejar se puede llegar
## hasta ver el mapa entero.
const OPEN_CELL_PX := 20.0
const MAX_CELL_PX := 64.0
const ZOOM_STEP := 1.5
const WHEEL_STEP := 1.15
const ZOOM_TIME := 0.2
const CENTER_TIME := 0.35
## Hueco libre para el mapa (px desde cada borde): a la izquierda están los
## botones de la pausa, a la derecha los del mapa y abajo la indicación.
const AREA_LEFT := 160.0
const AREA_RIGHT := 150.0
const AREA_TOP := 24.0
const AREA_BOTTOM := 84.0
## Lo que se puede arrastrar el mapa más allá del hueco libre (px).
const PAN_SLACK := 48.0
const BUTTON_SIZE := 88.0
const LEGEND_SWATCH := 34.0

var _data := {}
## Tablero entero y zona explorada (lo que se encuadra), en casillas.
var _grid := Vector2.ONE
var _bounds := Rect2(0, 0, 1, 1)
var _cube_cell := Vector2i.ZERO
var _zoom := OPEN_CELL_PX
var _min_zoom := OPEN_CELL_PX
var _offset := Vector2.ZERO
var _canvas: MapCanvas
var _marker: CubeMarker
var _controls: VBoxContainer
var _legend: PanelContainer
var _legend_grid: GridContainer
var _legend_open := false
var _tween: Tween
## Dedos apoyados: índice -> posición.
var _touches := {}


func _ready() -> void:
	# Ya está en el árbol: set_anchors_preset() conservaría el tamaño actual (0).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_canvas = MapCanvas.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_marker = CubeMarker.new()
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_marker)

	_controls = VBoxContainer.new()
	_controls.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_controls.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_controls.grow_vertical = Control.GROW_DIRECTION_BOTH
	_controls.offset_right = -28.0
	_controls.add_theme_constant_override("separation", 18)
	add_child(_controls)
	_add_button("res://ui/map_zoom_in.svg", "MAP_ZOOM_IN",
		func() -> void: _zoom_smoothly(ZOOM_STEP))
	_add_button("res://ui/map_zoom_out.svg", "MAP_ZOOM_OUT",
		func() -> void: _zoom_smoothly(1.0 / ZOOM_STEP))
	_add_button("res://ui/map_center.svg", "MAP_CENTER", center_on_cube)
	_add_button("res://ui/map_legend.svg", "MAP_LEGEND", func() -> void:
		_legend_open = not _legend_open
		_legend.visible = _legend_open)

	_legend = PanelContainer.new()
	_legend.mouse_filter = Control.MOUSE_FILTER_STOP
	_legend.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_legend.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_legend.offset_right = -(28.0 + BUTTON_SIZE + 20.0)
	_legend.offset_top = AREA_TOP
	_legend.visible = false
	add_child(_legend)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_legend.add_child(box)
	var title := Label.new()
	title.text = "MAP_LEGEND_TITLE"
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	_legend_grid = GridContainer.new()
	_legend_grid.add_theme_constant_override("h_separation", 28)
	_legend_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(_legend_grid)

	resized.connect(_relayout)
	set_process(false)


func _add_button(icon: String, tooltip: String, action: Callable) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	button.theme_type_variation = &"IconButton"
	button.icon = load(icon)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.tooltip_text = tooltip
	button.pressed.connect(action)
	_controls.add_child(button)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP_COLOR)


## Dibuja el mapa con el estado actual del nivel y lo encuadra: entero si
## cabe con OPEN_CELL_PX o más por casilla; si no, a ese tamaño y centrado en
## el cubo.
func open(level: Level, cube_cell: Vector2i) -> void:
	_stop_tween()
	_touches.clear()
	_data = level.map_snapshot()
	_grid = Vector2(_data["size"]).max(Vector2.ONE)
	_cube_cell = cube_cell
	var seen: Rect2i = _data["bounds"]
	seen = Rect2i(cube_cell, Vector2i.ONE) if seen.size == Vector2i.ZERO \
		else seen.merge(Rect2i(cube_cell, Vector2i.ONE))
	_bounds = Rect2(seen)
	_canvas.data = _data
	_canvas.set_alpha_map(_data["alpha"])
	# Con su tamaño real: Godot no dibuja un Control cuyo rectángulo queda
	# fuera de la pantalla (con tamaño 0, al acercar se dejaba de ver).
	_canvas.size = _grid
	_canvas.queue_redraw()
	_marker.size = Vector2.ONE * CubeMarker.EXTENT * 2.0
	_marker.position = Vector2(cube_cell) + Vector2(0.5, 0.5) - Vector2.ONE * CubeMarker.EXTENT
	_marker.set_process(true)
	_build_legend()
	_legend.visible = _legend_open
	var fit := _fit_zoom()
	_min_zoom = minf(fit, OPEN_CELL_PX)
	_zoom = clampf(fit, OPEN_CELL_PX, MAX_CELL_PX)
	_offset = _offset_for_cell(cube_cell)
	_apply()


func close() -> void:
	_stop_tween()
	_touches.clear()
	_marker.set_process(false)


## Desplaza el mapa (con una transición) hasta dejar el cubo en el centro.
func center_on_cube() -> void:
	_stop_tween()
	var target := _clamped(_offset_for_cell(_cube_cell), _zoom)
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(value: Vector2) -> void:
		_offset = value
		_apply(), _offset, target, CENTER_TIME)


# --- Encuadre -----------------------------------------------------------------

func _area() -> Rect2:
	var area := Rect2(AREA_LEFT, AREA_TOP, size.x - AREA_LEFT - AREA_RIGHT,
		size.y - AREA_TOP - AREA_BOTTOM)
	area.size = area.size.max(Vector2(100.0, 100.0))
	return area


## Píxeles por casilla con los que la zona explorada cabe entera en el hueco libre.
func _fit_zoom() -> float:
	var area := _area()
	return minf(area.size.x / _bounds.size.x, area.size.y / _bounds.size.y)


func _offset_for_cell(cell: Vector2i) -> Vector2:
	return _area().get_center() - (Vector2(cell) + Vector2(0.5, 0.5)) * _zoom


## Posición del mapa sin que la zona explorada se salga del hueco libre: si en un
## eje cabe entera, centrada; si no, sin dejar más de PAN_SLACK de hueco por
## ningún lado.
func _clamped(offset: Vector2, zoom: float) -> Vector2:
	var area := _area()
	var map_size := _bounds.size * zoom
	# Esquina de la zona explorada en la pantalla.
	var corner := offset + _bounds.position * zoom
	for axis in 2:
		if map_size[axis] <= area.size[axis]:
			corner[axis] = area.position[axis] + (area.size[axis] - map_size[axis]) * 0.5
		else:
			corner[axis] = clampf(corner[axis], area.end[axis] - map_size[axis] - PAN_SLACK,
				area.position[axis] + PAN_SLACK)
	return corner - _bounds.position * zoom


func _apply() -> void:
	_offset = _clamped(_offset, _zoom)
	_canvas.position = _offset
	_canvas.scale = Vector2(_zoom, _zoom)


## Cambia el zoom dejando quieto el punto del mapa que está bajo `pivot`.
func _set_zoom(zoom: float, pivot: Vector2) -> void:
	zoom = clampf(zoom, _min_zoom, MAX_CELL_PX)
	_offset = pivot - (pivot - _offset) * (zoom / _zoom)
	_zoom = zoom
	_apply()


func _zoom_smoothly(factor: float) -> void:
	_stop_tween()
	var pivot := _area().get_center()
	var target := clampf(_zoom * factor, _min_zoom, MAX_CELL_PX)
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_zoom.bind(pivot), _zoom, target, ZOOM_TIME)


func _stop_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


## Al girar o redimensionar la pantalla.
func _relayout() -> void:
	if _data.is_empty():
		return
	_min_zoom = minf(_fit_zoom(), OPEN_CELL_PX)
	_zoom = clampf(_zoom, _min_zoom, MAX_CELL_PX)
	_apply()


# --- Entrada ------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch:
		if touch.pressed:
			_stop_tween()
			_touches[touch.index] = touch.position
		else:
			_touches.erase(touch.index)
		accept_event()
		return
	var drag := event as InputEventScreenDrag
	if drag:
		var before := _touches.duplicate()
		_touches[drag.index] = drag.position
		if _touches.size() == 1:
			_offset += drag.relative
			_apply()
		elif _touches.size() >= 2 and before.size() >= 2:
			# Pellizco: el mapa sigue al punto medio de los dos dedos y se
			# escala con la distancia entre ellos.
			var ids: Array = _touches.keys().slice(0, 2)
			var a0: Vector2 = before[ids[0]]
			var b0: Vector2 = before[ids[1]]
			var a1: Vector2 = _touches[ids[0]]
			var b1: Vector2 = _touches[ids[1]]
			var mid := (a1 + b1) * 0.5
			_offset += mid - (a0 + b0) * 0.5
			if a0.distance_to(b0) > 1.0:
				_set_zoom(_zoom * a1.distance_to(b1) / a0.distance_to(b0), mid)
			else:
				_apply()
		accept_event()
		return
	var button := event as InputEventMouseButton
	if button and button.pressed:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_stop_tween()
			_set_zoom(_zoom * WHEEL_STEP, button.position)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_stop_tween()
			_set_zoom(_zoom / WHEEL_STEP, button.position)
			accept_event()
		return
	var magnify := event as InputEventMagnifyGesture
	if magnify:
		_stop_tween()
		_set_zoom(_zoom * magnify.factor, magnify.position)
		accept_event()


# --- Leyenda ------------------------------------------------------------------

func _build_legend() -> void:
	for child in _legend_grid.get_children():
		_legend_grid.remove_child(child)
		child.queue_free()
	var entries := _legend_entries()
	_legend_grid.columns = 2 if entries.size() > 7 else 1
	for entry: Array in entries:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var swatch := Swatch.new()
		swatch.kind = entry[0]
		swatch.info = entry[2]
		swatch.custom_minimum_size = Vector2(LEGEND_SWATCH, LEGEND_SWATCH)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		var label := Label.new()
		label.text = entry[1]
		label.add_theme_font_size_override("font_size", 22)
		row.add_child(label)
		_legend_grid.add_child(row)


## [tipo, texto, datos] de lo que hay ahora en el nivel.
func _legend_entries() -> Array:
	var entries := [["cube", "MAP_LEGEND_CUBE", {}]]
	var checkpoints: Dictionary = _data["checkpoints"]
	if checkpoints.size() > 1 or (checkpoints.size() == 1 and checkpoints.keys()[0] != _data["start"]):
		if checkpoints.values().has(true):
			entries.append(["start", "MAP_LEGEND_CHECKPOINT", {"active": true}])
		if checkpoints.values().has(false):
			entries.append(["start", "MAP_LEGEND_CHECKPOINT_OFF", {"active": false}])
	elif _data["start"] != Level.NO_CELL:
		entries.append(["start", "MAP_LEGEND_START", {}])
	if _data["goal"] != Level.NO_CELL:
		entries.append(["goal", "MAP_LEGEND_GOAL", {}])
	if not _data["walls"].is_empty():
		entries.append(["wall", "MAP_LEGEND_WALL", {}])
	var keys: Dictionary = _data["keys"]
	if not keys.is_empty():
		entries.append(["key", "ENC_KEY_NAME", {"color": keys.values()[0]}])
	var doors: Dictionary = _data["doors"]
	if not doors.is_empty():
		entries.append(["door", "ENC_DOOR_NAME", {"color": doors.values()[0]["color"], "horizontal": true}])
	if _data["collectible"] != Level.NO_CELL:
		entries.append(["gold", "ENC_GOLDEN_CUBE_NAME", {}])
	var power_ups: Dictionary = _data["power_ups"]
	var seen := {}
	for id: String in power_ups.values():
		if not seen.has(id):
			seen[id] = true
			entries.append(["power_up", "ENC_%s_NAME" % id.to_upper(), {}])
	if not _data["breakables"].is_empty():
		entries.append(["breakable", "ENC_BREAKABLE_NAME", {}])
	var bars: Dictionary = _data["bars"]
	if not bars.is_empty():
		var group: String = bars.values()[0]["group"]
		entries.append(["bars", "MAP_LEGEND_BARS", {"group": group, "closed": true}])
	var buttons: Dictionary = _data["buttons"]
	if not buttons.is_empty():
		entries.append(["button", "MAP_LEGEND_BUTTON",
			{"groups": buttons.values()[0]["groups"], "dir": Vector2i.DOWN}])
	if not _data["bridges"].is_empty():
		entries.append(["bridge", "ENC_BRIDGE_NAME", {"horizontal": true}])
	var teleports: Dictionary = _data["teleports"]
	if not teleports.is_empty():
		entries.append(["teleport", "ENC_TELEPORT_NAME", {"symbol": teleports.values()[0]}])
	if not _data["spikes"].is_empty():
		entries.append(["spikes", "ENC_SPIKES_NAME", {}])
	if not _data["lasers"].is_empty():
		entries.append(["laser", "ENC_LASER_NAME", {"dir": Vector2i.DOWN}])
	if not _data["mortars"].is_empty():
		entries.append(["mortar", "ENC_MORTAR_NAME", {}])
	if not _data["chests"].is_empty():
		entries.append(["chest", "MAP_LEGEND_CHEST", {}])
	if _data["shop"] != Level.NO_CELL:
		entries.append(["shop", "MAP_LEGEND_SHOP", {"dir": Vector2i.DOWN}])
	return entries


# --- Dibujo -------------------------------------------------------------------

## Dibuja un elemento en la casilla cuya esquina superior izquierda es `o`
## (en unidades de casilla). El suelo o el muro de debajo ya está dibujado,
## salvo en el muro destructible, que pone el suyo.
static func draw_item(ci: CanvasItem, kind: String, o: Vector2, info: Dictionary) -> void:
	var c := o + Vector2(0.5, 0.5)
	match kind:
		"floor":
			ci.draw_rect(Rect2(o, Vector2.ONE), FLOOR_COLOR)
		"wall":
			ci.draw_rect(Rect2(o, Vector2.ONE), WALL_COLOR)
		"cube":
			ci.draw_rect(Rect2(c - Vector2(0.34, 0.34), Vector2(0.68, 0.68)), OUTLINE_COLOR)
			ci.draw_rect(Rect2(c - Vector2(0.27, 0.27), Vector2(0.54, 0.54)), CUBE_COLOR)
		"start":
			# Casilla de inicio: la activada, del color de la salida; las demás, apagadas.
			var active: bool = info.get("active", true)
			ci.draw_rect(Rect2(o + Vector2(0.12, 0.12), Vector2(0.76, 0.76)),
				Level.START_COLOR if active else CheckpointTile.OFF_COLOR)
			if active:
				ci.draw_rect(Rect2(o + Vector2(0.34, 0.34), Vector2(0.32, 0.32)), Level.START_COLOR.lightened(0.5))
		"chest":
			ci.draw_rect(Rect2(o + Vector2(0.12, 0.22), Vector2(0.76, 0.6)), OUTLINE_COLOR)
			ci.draw_rect(Rect2(o + Vector2(0.17, 0.27), Vector2(0.66, 0.5)), TreasureChest.WOOD)
			ci.draw_rect(Rect2(o + Vector2(0.17, 0.27), Vector2(0.66, 0.16)), TreasureChest.WOOD.lightened(0.15))
			ci.draw_rect(Rect2(o + Vector2(0.17, 0.42), Vector2(0.66, 0.04)), OUTLINE_COLOR)
			ci.draw_rect(Rect2(o + Vector2(0.44, 0.38), Vector2(0.12, 0.16)), TreasureChest.METAL)
		"goal":
			ci.draw_rect(Rect2(o + Vector2(0.12, 0.12), Vector2(0.76, 0.76)), Level.GOAL_COLOR)
			# Bandera de meta: ajedrezado blanco en el centro.
			for i in 3:
				for j in 3:
					if (i + j) % 2 == 0:
						ci.draw_rect(Rect2(o + Vector2(0.23 + i * 0.18, 0.23 + j * 0.18),
							Vector2(0.18, 0.18)), Color.WHITE)
		"key":
			var key_color: Color = Level.ITEM_COLORS.get(info.get("color", "y"), Color.WHITE)
			ci.draw_circle(o + Vector2(0.32, 0.5), 0.2, OUTLINE_COLOR)
			ci.draw_circle(o + Vector2(0.32, 0.5), 0.15, key_color)
			ci.draw_circle(o + Vector2(0.32, 0.5), 0.06, OUTLINE_COLOR)
			ci.draw_rect(Rect2(o + Vector2(0.44, 0.44), Vector2(0.44, 0.12)), key_color)
			ci.draw_rect(Rect2(o + Vector2(0.66, 0.56), Vector2(0.08, 0.12)), key_color)
			ci.draw_rect(Rect2(o + Vector2(0.8, 0.56), Vector2(0.08, 0.16)), key_color)
		"door":
			var door_color: Color = Level.ITEM_COLORS.get(info.get("color", "y"), Color.WHITE)
			var bar := Rect2(o + Vector2(0.0, 0.32), Vector2(1.0, 0.36)) if info.get("horizontal", true) \
				else Rect2(o + Vector2(0.32, 0.0), Vector2(0.36, 1.0))
			ci.draw_rect(bar, OUTLINE_COLOR)
			ci.draw_rect(bar.grow(-0.05), door_color)
			ci.draw_circle(c, 0.07, OUTLINE_COLOR)
		"gold":
			var r := 0.32
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r - 0.06), c + Vector2(r + 0.06, 0),
				c + Vector2(0, r + 0.06), c + Vector2(-r - 0.06, 0)]), OUTLINE_COLOR)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0),
				c + Vector2(0, r), c + Vector2(-r, 0)]), GOLD_COLOR)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.5, -r * 0.5),
				c, c + Vector2(-r * 0.5, -r * 0.5)]), GOLD_COLOR.lightened(0.5))
		"power_up":
			ci.draw_circle(c, 0.34, OUTLINE_COLOR)
			ci.draw_circle(c, 0.28, POWER_UP_COLOR)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.04, -0.22), c + Vector2(-0.12, 0.03),
				c + Vector2(0.0, 0.03), c + Vector2(-0.04, 0.22), c + Vector2(0.12, -0.03),
				c + Vector2(0.0, -0.03)]), OUTLINE_COLOR)
		"breakable":
			ci.draw_rect(Rect2(o, Vector2.ONE), BREAKABLE_COLOR)
			ci.draw_polyline(PackedVector2Array([o + Vector2(0.2, 0.1), o + Vector2(0.42, 0.42),
				o + Vector2(0.35, 0.62), o + Vector2(0.6, 0.9)]), OUTLINE_COLOR, 0.07)
			ci.draw_polyline(PackedVector2Array([o + Vector2(0.42, 0.42), o + Vector2(0.78, 0.32)]),
				OUTLINE_COLOR, 0.07)
		"bars":
			var bar_color: Color = BAR_COLORS.get(info.get("group", "c"), Color.WHITE)
			if not info.get("closed", true):
				bar_color.a = 0.3
			for i in 3:
				ci.draw_rect(Rect2(o + Vector2(0.2 + i * 0.25, 0.06), Vector2(0.1, 0.88)), bar_color)
			ci.draw_rect(Rect2(o + Vector2(0.1, 0.06), Vector2(0.8, 0.1)), bar_color)
			ci.draw_rect(Rect2(o + Vector2(0.1, 0.84), Vector2(0.8, 0.1)), bar_color)
		"button":
			var groups: String = info.get("groups", "")
			var button_color: Color = BAR_COLORS.get(groups.left(1), Color(0.9, 0.9, 0.9))
			var dir: Vector2i = info.get("dir", Vector2i.DOWN)
			var face := Vector2(dir)
			var across := Vector2(absf(face.y), absf(face.x))
			var center := c + face * 0.36
			var half := across * 0.26 + Vector2(absf(face.x), absf(face.y)) * 0.12
			ci.draw_rect(Rect2(center - half - Vector2(0.04, 0.04), half * 2.0 + Vector2(0.08, 0.08)),
				OUTLINE_COLOR)
			ci.draw_rect(Rect2(center - half, half * 2.0), button_color)
		"bridge":
			var planks := Rect2(o + Vector2(0.0, 0.2), Vector2(1.0, 0.6)) if info.get("horizontal", true) \
				else Rect2(o + Vector2(0.2, 0.0), Vector2(0.6, 1.0))
			ci.draw_rect(planks, BRIDGE_COLOR)
			for i in 3:
				var t := 0.2 + i * 0.3
				if info.get("horizontal", true):
					ci.draw_rect(Rect2(o + Vector2(t, 0.2), Vector2(0.05, 0.6)), OUTLINE_COLOR)
				else:
					ci.draw_rect(Rect2(o + Vector2(0.2, t), Vector2(0.6, 0.05)), OUTLINE_COLOR)
		"teleport":
			var pad_color: Color = Level.TELEPORT_COLORS.get(info.get("symbol", "6"), Color.WHITE)
			ci.draw_circle(c, 0.38, pad_color)
			ci.draw_circle(c, 0.26, FLOOR_COLOR)
			ci.draw_circle(c, 0.12, pad_color)
		"spikes":
			for i in 2:
				for j in 2:
					var base := o + Vector2(0.12 + i * 0.4, 0.14 + j * 0.4)
					ci.draw_colored_polygon(PackedVector2Array([base + Vector2(0.18, 0.0),
						base + Vector2(0.36, 0.32), base + Vector2(0.0, 0.32)]), SPIKE_COLOR)
		"laser":
			# Boca del cañón hacia la casilla libre a la que dispara.
			var aim := Vector2(info.get("dir", Vector2i.DOWN))
			ci.draw_line(c, c + aim * 0.5, LASER_COLOR, 0.16)
			ci.draw_circle(c, 0.24, OUTLINE_COLOR)
			ci.draw_circle(c, 0.17, LASER_COLOR)
		"mortar":
			ci.draw_circle(c, 0.38, OUTLINE_COLOR)
			ci.draw_circle(c, 0.3, MORTAR_COLOR)
			ci.draw_circle(c, 0.16, OUTLINE_COLOR)
		"shop":
			# Casita blanca con el toldo rojo del lado de la entrada (`dir`).
			var dir: Vector2i = info.get("dir", Vector2i.DOWN)
			var xform := Transform2D(Vector2(dir).angle() - PI * 0.5, c)
			_draw_turned_rect(ci, xform, Rect2(-0.42, -0.42, 0.84, 0.84), OUTLINE_COLOR)
			_draw_turned_rect(ci, xform, Rect2(-0.35, -0.35, 0.7, 0.7), ShopBuilding.WHITE)
			for i in 4:
				_draw_turned_rect(ci, xform, Rect2(-0.35 + i * 0.175, 0.12, 0.175, 0.26),
					ShopBuilding.RED if i % 2 == 0 else ShopBuilding.WHITE)
			_draw_turned_rect(ci, xform, Rect2(-0.08, -0.22, 0.16, 0.3), ShopBuilding.GLASS)


## Rectángulo girado y desplazado con `xform` (sin tocar la transformación
## de dibujo, que la muestra de la leyenda usa para escalar).
static func _draw_turned_rect(ci: CanvasItem, xform: Transform2D, rect: Rect2, color: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([xform * rect.position,
		xform * Vector2(rect.end.x, rect.position.y), xform * rect.end,
		xform * Vector2(rect.position.x, rect.end.y)]), color)


## Nodo que dibuja el mapa entero (en unidades de casilla).
class MapCanvas:
	extends Control

	## Opacidad por casilla (ver Level.seen_alpha): una imagen de una casilla
	## por píxel con filtro lineal, así el borde de lo explorado se difumina
	## suave en vez de a escalones.
	const FADE_SHADER := """
shader_type canvas_item;
uniform sampler2D alpha_map : filter_linear, repeat_disable;
uniform vec2 grid = vec2(1.0);
varying vec2 cell_pos;
void vertex() {
	cell_pos = VERTEX;
}
void fragment() {
	COLOR.a *= texture(alpha_map, cell_pos / grid).r;
}
"""
	static var _shader: Shader

	var data := {}

	func set_alpha_map(image: Image) -> void:
		if _shader == null:
			_shader = Shader.new()
			_shader.code = FADE_SHADER
		var mat := material as ShaderMaterial
		if mat == null:
			mat = ShaderMaterial.new()
			mat.shader = _shader
			material = mat
		mat.set_shader_parameter("alpha_map", ImageTexture.create_from_image(image))
		mat.set_shader_parameter("grid", Vector2(image.get_size()))

	func _draw() -> void:
		if data.is_empty():
			return
		var walls := {}
		for cell: Vector2i in data["walls"]:
			walls[cell] = true
		var floor_cells := {}
		for cell: Vector2i in data["floor"]:
			floor_cells[cell] = true
		var grid: Vector2i = data["size"]
		# Suelo y muros por tramos de cada fila (menos órdenes de dibujo).
		for z in grid.y:
			_draw_runs(z, grid.x, floor_cells, PauseMap.FLOOR_COLOR)
			_draw_runs(z, grid.x, walls, PauseMap.WALL_COLOR)
		for cell: Vector2i in data["breakables"]:
			PauseMap.draw_item(self, "breakable", Vector2(cell), {})
		var bridges: Dictionary = data["bridges"]
		for cell: Vector2i in bridges:
			PauseMap.draw_item(self, "bridge", Vector2(cell), {"horizontal": bridges[cell]})
		var checkpoints: Dictionary = data["checkpoints"]
		for cell: Vector2i in checkpoints:
			PauseMap.draw_item(self, "start", Vector2(cell), {"active": checkpoints[cell]})
		if data["goal"] != Level.NO_CELL:
			PauseMap.draw_item(self, "goal", Vector2(data["goal"]), {})
		for cell: Vector2i in data["spikes"]:
			PauseMap.draw_item(self, "spikes", Vector2(cell), {})
		var teleports: Dictionary = data["teleports"]
		for cell: Vector2i in teleports:
			PauseMap.draw_item(self, "teleport", Vector2(cell), {"symbol": teleports[cell]})
		var bars: Dictionary = data["bars"]
		for cell: Vector2i in bars:
			PauseMap.draw_item(self, "bars", Vector2(cell), bars[cell])
		var buttons: Dictionary = data["buttons"]
		for cell: Vector2i in buttons:
			var front: Vector2i = buttons[cell]["front"]
			PauseMap.draw_item(self, "button", Vector2(cell),
				{"groups": buttons[cell]["groups"], "dir": front - cell})
		var lasers: Dictionary = data["lasers"]
		for cell: Vector2i in lasers:
			PauseMap.draw_item(self, "laser", Vector2(cell), {"dir": lasers[cell]})
		for cell: Vector2i in data["mortars"]:
			PauseMap.draw_item(self, "mortar", Vector2(cell), {})
		var doors: Dictionary = data["doors"]
		for cell: Vector2i in doors:
			PauseMap.draw_item(self, "door", Vector2(cell), doors[cell])
		var keys: Dictionary = data["keys"]
		for cell: Vector2i in keys:
			PauseMap.draw_item(self, "key", Vector2(cell), {"color": keys[cell]})
		var power_ups: Dictionary = data["power_ups"]
		for cell: Vector2i in power_ups:
			PauseMap.draw_item(self, "power_up", Vector2(cell), {})
		for cell: Vector2i in data["chests"]:
			PauseMap.draw_item(self, "chest", Vector2(cell), {})
		if data["collectible"] != Level.NO_CELL:
			PauseMap.draw_item(self, "gold", Vector2(data["collectible"]), {})
		if data["shop"] != Level.NO_CELL:
			PauseMap.draw_item(self, "shop", Vector2(data["shop"]), {"dir": data["shop_facing"]})

	func _draw_runs(z: int, width: int, cells: Dictionary, color: Color) -> void:
		var x := 0
		while x < width:
			if not cells.has(Vector2i(x, z)):
				x += 1
				continue
			var start := x
			while x < width and cells.has(Vector2i(x, z)):
				x += 1
			draw_rect(Rect2(start, z, x - start, 1), color)


## Marca del cubo: el cubo y un anillo que se agranda y se desvanece en bucle.
class CubeMarker:
	extends Control

	const PULSE_TIME := 1.2
	## Medio lado del nodo (en casillas), centrado en el cubo: cabe el anillo.
	const EXTENT := 1.5
	var _time := 0.0

	func _process(delta: float) -> void:
		_time = fmod(_time + delta, PULSE_TIME)
		queue_redraw()

	func _draw() -> void:
		var k := _time / PULSE_TIME
		var ring := Color(PauseMap.CUBE_COLOR, 1.0 - k)
		var center := Vector2.ONE * EXTENT
		draw_arc(center, 0.45 + k * 0.9, 0.0, TAU, 32, ring, 0.1)
		PauseMap.draw_item(self, "cube", center - Vector2(0.5, 0.5), {})


## Muestra de un elemento en la leyenda, sobre su suelo o su muro.
class Swatch:
	extends Control

	var kind := ""
	var info := {}

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, size)
		var base := "wall" if PauseMap.WALL_KINDS.has(kind) else "floor"
		PauseMap.draw_item(self, base, Vector2.ZERO, {})
		PauseMap.draw_item(self, kind, Vector2.ZERO, info)
