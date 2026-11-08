class_name Level
extends Node3D
## Tablero del laberinto construido a partir de un mapa de texto.
##
## Leyenda del mapa:
##   '#' pared   '.' casilla libre   'A' inicio   'B' meta
##   Llaves (minúscula) y su puerta (mayúscula), del mismo color:
##   y/Y amarillo   o/O naranja   r/R rojo   u/U azul   g/G verde
##   Power ups: ver PowerUpCatalog (s = velocidad).
##   Muros destructibles: '1'..'5' = golpes que aguanta (5 pocas grietas,
##   1 muchas grietas). Ver BreakableWall.
##   Barrotes: c d e f h = grupo de barrotes; en minúscula empiezan abiertos y
##   en mayúscula cerrados. Ver Bars.
##   Botones: p q t v w = muro con un botón en la cara que da a su única
##   casilla libre. `button_links` indica qué grupos de barrotes cambia cada
##   botón ({"p": "cd"}). Ver WallButton.
##   Enemigos (sobre una casilla libre): x perseguidor (ver Chaser),
##   z obstáculo (ver Blocker), i j k m n patrulleros (ver Patroller); la ruta
##   de cada patrullero se indica en `patrol_routes` ({"i": "R3 D2 L3 U2"}).
##   Vacío: '~' = ni suelo ni pared. Si el cubo entra en el vacío, se cae y
##   explota (ver RollingCube). Fuera del mapa también es vacío. En los
##   niveles con vacío, bajo cada casilla con suelo o pared se dibuja un
##   bloque de roca para que el tablero parezca flotar.
##   Puente colgante: '=' = casilla de puente sobre el vacío. Las casillas '='
##   seguidas forman un puente recto, con vacío a ambos lados y suelo en los
##   dos extremos. Cada casilla aguanta HangingBridge.MAX_STABILITY salidas
##   del cubo; cuando una llega a 0 el puente entero cae y sus casillas pasan
##   a ser vacío (ver HangingBridge).
## Materiales (ver BlockCatalog): el campo "theme" del nivel elige el bloque
## del suelo ("floor"), de los muros ("wall") y, opcionalmente, de la roca de
## debajo ("foundation"; si no se da, la que va bajo el suelo). Lo que falte
## sale de DEFAULT_THEME. "theme_regions" cambia los bloques en zonas del mapa
## (para transiciones): lista de { "rect": Rect2i(x, z, ancho, alto), y las
## mismas claves que "theme" }; si se solapan, gana la última.
## Las filas crecen hacia +Z (hacia abajo en pantalla) y las columnas hacia +X.
##
## Aparición (start_reveal): al empezar o reiniciar el nivel, el tablero se
## dibuja casilla a casilla en diagonal, de arriba a la izquierda a abajo a
## la derecha, en REVEAL_TIME segundos: cada
## casilla (suelo, pared, roca y lo que haya encima) aparece en su sitio y
## con su tamaño, pasando de transparente a opaca. Mientras tanto los enemigos están
## quietos (ver set_enemies_frozen). Al acabar emite reveal_finished.

signal reveal_finished

const CELL_SIZE := 1.0
const WALL_HEIGHT := 0.5
const FLOOR_THICKNESS := 0.1
const KEY_CHARS := "yorug"
const BREAKABLE_CHARS := "12345"
const BAR_CHARS := "cdefh"
const BUTTON_CHARS := "pqtvw"
const CHASER_CHAR := "x"
const BLOCKER_CHAR := "z"
const PATROL_CHARS := "ijkmn"
const VOID_CHAR := "~"
const BRIDGE_CHAR := "="
## Profundidad del bloque de roca bajo las casillas en los niveles con vacío.
const FOUNDATION_DEPTH := 0.9
## Distancia (en casillas) entre el centro del cubo y el de un enemigo letal a
## partir de la cual el cubo muere.
const ENEMY_HIT_DISTANCE := 0.72
## Bloques por defecto de los niveles sin "theme" (ver BlockCatalog).
const DEFAULT_THEME := {"floor": "grass", "wall": "stone_bricks"}
## Tono de las baldosas oscuras del ajedrezado del suelo y de la roca de
## debajo que no da al vacío (la del borde se deja con su color).
const FLOOR_DARK_TINT := Color(0.88, 0.88, 0.88)
const FOUNDATION_INNER_TINT := Color(0.78, 0.78, 0.78)
const ITEM_COLORS := {
	"y": Color(0.98, 0.80, 0.12),
	"o": Color(1.00, 0.50, 0.08),
	"r": Color(0.88, 0.16, 0.16),
	"u": Color(0.18, 0.42, 0.95),
	"g": Color(0.18, 0.70, 0.28),
}
## La puerta es un bloque estrecho que cierra el pasillo de muro a muro.
const DOOR_THICKNESS := 0.24
const DOOR_HEIGHT := 0.8
## Duración de la animación de la puerta hundiéndose al abrirse.
const DOOR_SINK_TIME := 0.6
## Al abrir una puerta, lo que tarda la llave en volar hasta ella
## encogiéndose (la puerta se hunde cuando llega).
const KEY_TO_DOOR_TIME := 0.4
## Altura y velocidad de giro (rad/s) de las llaves que están en el mapa.
const KEY_FLOAT_HEIGHT := 0.5
const KEY_SCALE := 1.6
const KEY_SPIN_SPEED := 1.2
const POWER_UP_FLOAT_HEIGHT := 0.5
## Casillas de recorrido (contando la de delante del botón) en las que el cubo
## se considera cerca de un botón. Ver button_near().
const BUTTON_APPROACH_CELLS := 4
const NO_CELL := Vector2i(-9999, -9999)
## Aparición del tablero: duración total y lo que tarda cada casilla en
## pasar de transparente a opaca.
const REVEAL_TIME := 1.3
const REVEAL_FADE_TIME := 0.45

@export var layout: PackedStringArray = PackedStringArray([
	"#######",
	"#A....#",
	"#.###.#",
	"#...#.#",
	"###.#.#",
	"#...#.#",
	"#.#####",
	"#....B#",
	"#######",
])
## Rumbo inicial del cubo en coordenadas de casilla (x, z). (0, 1) = abajo.
@export var start_heading := Vector2i(0, 1)
## Grupos de barrotes que cambia cada botón: {"p": "cd"} (campo "buttons" del
## nivel). Pulsar un botón abre los barrotes cerrados de esos grupos y cierra
## los abiertos.
@export var button_links := {}
## Ruta de cada patrullero (campo "patrols" del nivel): {"i": "R3 D2 L3 U2"}.
## Ver Patroller.set_route.
@export var patrol_routes := {}
## Bloques del nivel (campo "theme") y por zonas ("theme_regions"). Ver la
## leyenda del principio.
@export var block_theme := {}
@export var block_regions: Array = []
## Cubo del jugador: los enemigos lo buscan y lo matan.
var cube: RollingCube:
	set(value):
		cube = value
		for enemy in _enemies:
			enemy.cube = value

var start_cell := Vector2i.ZERO
var goal_cell := Vector2i.ZERO
var _walkable := {}
## Casillas de vacío ('~').
var _void := {}
## casilla -> { "color": String, "node": Node3D }
var _keys := {}
var _doors := {}
## casilla -> { "power_up": PowerUp, "node": Node3D }
var _power_ups := {}
## casilla -> BreakableWall (solo los que siguen en pie)
var _breakables := {}
## casilla -> { "group": String, "node": Bars }
var _bars := {}
## casilla -> { "symbol": String, "node": WallButton, "front": Vector2i,
##             "near": { casilla: casillas de recorrido hasta el botón } }
var _buttons := {}
var _enemies: Array[Enemy] = []
## casilla -> HangingBridge (solo los que siguen en pie)
var _bridges := {}
## Aparición en curso: tiempo transcurrido, retraso de cada casilla,
## MultiMesh ({ "multimesh", "materials", "cells" }; la opacidad de cada
## casilla va en el color de su instancia) y nodos sueltos ({ "delay",
## "materials": [...] }, ver _fade_materials).
var _revealing := false
var _reveal_time := 0.0
var _reveal_delays := {}
var _reveal_multimeshes: Array[Dictionary] = []
var _reveal_nodes: Array[Dictionary] = []


func _ready() -> void:
	build()


## Prepara el tablero de un nivel de Levels.LIST (se construye con build()).
func configure(data: Dictionary) -> void:
	layout = PackedStringArray(data["layout"])
	start_heading = data["start_heading"]
	button_links = data.get("buttons", {})
	patrol_routes = data.get("patrols", {})
	block_theme = data.get("theme", {})
	block_regions = data.get("theme_regions", [])


func build() -> void:
	for child in get_children():
		child.queue_free()
	_revealing = false
	_reveal_multimeshes.clear()
	_reveal_nodes.clear()
	_walkable.clear()
	_void.clear()
	_keys.clear()
	_doors.clear()
	_power_ups.clear()
	_breakables.clear()
	_bars.clear()
	_buttons.clear()
	_enemies.clear()
	_bridges.clear()
	var enemy_cells := {}
	var bridge_cells := {}

	var start_mat := _make_material(Color(0.35, 0.60, 0.95))
	var goal_mat := _make_material(Color(0.30, 0.80, 0.45))
	# Muros y baldosas normales se dibujan con MultiMesh (una llamada de dibujo
	# por tipo de bloque): los mapas grandes tienen miles de casillas.
	var wall_cells: Array[Vector2i] = []
	## "bloque" -> casillas; las del suelo, "bloque|0" y "bloque|1" (ajedrezado).
	var wall_groups := {}
	var floor_groups := {}

	for z in layout.size():
		var row: String = layout[z]
		for x in row.length():
			var cell := Vector2i(x, z)
			var symbol := row[x]
			if symbol == VOID_CHAR:
				_void[cell] = true
				continue
			if symbol == "#" or BUTTON_CHARS.contains(symbol):
				wall_cells.append(cell)
				_group(wall_groups, _block_at(cell, "wall"), cell)
				if symbol != "#":
					_add_button(cell, symbol)
				continue
			_walkable[cell] = true
			if symbol == BRIDGE_CHAR:
				bridge_cells[cell] = true
				continue
			var tile := Vector3(CELL_SIZE * 0.96, FLOOR_THICKNESS, CELL_SIZE * 0.96)
			if symbol == "A":
				start_cell = cell
				_add_box(cell, tile, -FLOOR_THICKNESS * 0.5, start_mat)
			elif symbol == "B":
				goal_cell = cell
				_add_box(cell, tile, -FLOOR_THICKNESS * 0.5, goal_mat)
			else:
				_group(floor_groups, "%s|%d" % [_block_at(cell, "floor"), (x + z) % 2], cell)
			if KEY_CHARS.contains(symbol):
				_add_key(cell, symbol)
			elif KEY_CHARS.to_upper().contains(symbol):
				_add_door(cell, symbol.to_lower())
			elif PowerUpCatalog.has_symbol(symbol):
				_add_power_up(cell, symbol)
			elif BREAKABLE_CHARS.contains(symbol):
				_add_breakable(cell, int(symbol))
			elif BAR_CHARS.contains(symbol.to_lower()):
				_add_bars(cell, symbol)
			elif symbol == CHASER_CHAR or symbol == BLOCKER_CHAR or PATROL_CHARS.contains(symbol):
				enemy_cells[cell] = symbol
	for id: String in wall_groups:
		_add_multimesh(wall_groups[id], id, Vector3(CELL_SIZE, WALL_HEIGHT, CELL_SIZE),
			WALL_HEIGHT * 0.5, Color.WHITE)
	var tile_size := Vector3(CELL_SIZE * 0.96, FLOOR_THICKNESS, CELL_SIZE * 0.96)
	for key: String in floor_groups:
		var parts := key.split("|")
		_add_multimesh(floor_groups[key], parts[0], tile_size, -FLOOR_THICKNESS * 0.5,
			FLOOR_DARK_TINT if parts[1] == "1" else Color.WHITE)
	if not _void.is_empty():
		_add_foundations(wall_cells)
	_add_bridges(bridge_cells)
	for cell: Vector2i in enemy_cells:
		_add_enemy(cell, enemy_cells[cell])
	for button in _buttons.values():
		button["near"] = _cells_within(button["front"], BUTTON_APPROACH_CELLS)


func _process(delta: float) -> void:
	if _revealing:
		_update_reveal(delta)
	_check_enemy_hits()
	for item in _keys.values():
		item["node"].rotate_y(KEY_SPIN_SPEED * delta)
	for item in _power_ups.values():
		var power_up: PowerUp = item["power_up"]
		item["node"].rotate(power_up.pickup_spin_axis, power_up.pickup_spin_speed * delta)


## Casilla por la que puede pasar el cubo: como is_terrain_walkable() y,
## además, sin un obstáculo (enemigo sólido) en ella.
func is_walkable(cell: Vector2i) -> bool:
	return is_terrain_walkable(cell) and not solid_enemy_at(cell)


## Casilla libre, sin puerta ni barrotes cerrados y sin muro destructible en
## pie (sin tener en cuenta a los enemigos).
func is_terrain_walkable(cell: Vector2i) -> bool:
	return _walkable.has(cell) and not _doors.has(cell) and not _breakables.has(cell) \
		and not bars_closed(cell)


## Casilla de vacío ('~' o fuera del mapa): el cubo que entra en ella se cae.
func is_void(cell: Vector2i) -> bool:
	if _void.has(cell):
		return true
	return cell.y < 0 or cell.y >= layout.size() or cell.x < 0 or cell.x >= layout[cell.y].length()


## Casilla de un puente colgante que sigue en pie.
func is_bridge(cell: Vector2i) -> bool:
	return _bridges.has(cell)


## Estabilidad que le queda a una casilla de puente (0..MAX_STABILITY), o -1
## si no es un puente en pie.
func bridge_stability(cell: Vector2i) -> int:
	return _bridges[cell].stability(cell) if _bridges.has(cell) else -1


## El cubo acaba de salir de `cell` (ya está en otra casilla): si era un
## puente, pierde estabilidad y, si llega a 0, el puente entero cae, con el
## cubo si sigue encima.
func cube_left_cell(cell: Vector2i) -> void:
	if not _bridges.has(cell):
		return
	var bridge: HangingBridge = _bridges[cell]
	if not bridge.wear(cell):
		Sfx.play("creak", 0.1, -4.0 * bridge.stability(cell))
		return
	var cube_cell := NO_CELL
	if cube and cube.is_alive() and (bridge.has_cell(cube.cell) or bridge.has_cell(cube.roll_target())):
		cube_cell = cube.cell if bridge.has_cell(cube.cell) else cube.roll_target()
	for c in bridge.cells:
		_bridges.erase(c)
		_walkable.erase(c)
		_void[c] = true
	bridge.collapse(cell, cube_cell)
	Sfx.play("collapse")
	if cube_cell != NO_CELL:
		cube.drop()


## Casilla con suelo (no es pared), haya lo que haya en ella.
func has_floor(cell: Vector2i) -> bool:
	return _walkable.has(cell)


## Hay un enemigo sólido (obstáculo) ocupando la casilla, sin contar `except`.
func solid_enemy_at(cell: Vector2i, except: Enemy = null) -> bool:
	for enemy in _enemies:
		if enemy.solid and enemy != except and enemy.occupies(cell):
			return true
	return false


## El cubo ha muerto: los enemigos le pierden la pista.
func notify_cube_died() -> void:
	for enemy in _enemies:
		enemy.on_cube_died()


## Si un enemigo letal toca al cubo, el cubo explota.
func _check_enemy_hits() -> void:
	if cube == null or not cube.is_vulnerable():
		return
	var anchor := to_local(cube.get_trail_anchor())
	var cube_pos := Vector2(anchor.x, anchor.z) / CELL_SIZE
	for enemy in _enemies:
		if enemy.lethal and enemy.board_position().distance_to(cube_pos) < ENEMY_HIT_DISTANCE:
			cube.die()
			return


## Hay barrotes cerrados en la casilla.
func bars_closed(cell: Vector2i) -> bool:
	return _bars.has(cell) and not _bars[cell]["node"].is_open


## Hay un muro con botón en la casilla.
func is_button(cell: Vector2i) -> bool:
	return _buttons.has(cell)


## Botón cerca de la casilla (a BUTTON_APPROACH_CELLS casillas de recorrido o
## menos de la casilla de delante del botón), o NO_CELL si no hay ninguno. Si
## hay varios, el más cercano.
func button_near(cell: Vector2i) -> Vector2i:
	var best := NO_CELL
	var best_steps := BUTTON_APPROACH_CELLS + 1
	for button_cell in _buttons:
		var near: Dictionary = _buttons[button_cell]["near"]
		if near.has(cell) and near[cell] < best_steps:
			best = button_cell
			best_steps = near[cell]
	return best


## Casilla libre de delante del botón.
func button_front(button_cell: Vector2i) -> Vector2i:
	return _buttons[button_cell]["front"] if _buttons.has(button_cell) else NO_CELL


## Casillas de todos los barrotes que cambia el botón.
func button_bars(button_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not _buttons.has(button_cell):
		return cells
	var groups: String = button_links.get(_buttons[button_cell]["symbol"], "")
	for bar_cell in _bars:
		if groups.contains(_bars[bar_cell]["group"]):
			cells.append(bar_cell)
	return cells


## Pulsa el botón de la casilla: todos los barrotes de sus grupos cambian de
## estado al instante (los abiertos se cierran y los cerrados se abren).
func press_button(cell: Vector2i) -> void:
	if not _buttons.has(cell):
		return
	_buttons[cell]["node"].press()
	var groups: String = button_links.get(_buttons[cell]["symbol"], "")
	for item in _bars.values():
		if groups.contains(item["group"]):
			var bars: Bars = item["node"]
			bars.set_open(not bars.is_open)


## Golpes que le quedan al muro destructible de la casilla (0 si no hay).
func breakable_hits(cell: Vector2i) -> int:
	return _breakables[cell].hits if _breakables.has(cell) else 0


## Golpea de frente el muro destructible de la casilla en la dirección
## `heading`. Devuelve los golpes que le quedan; con 0 el muro se rompe y la
## casilla pasa a ser libre al instante, aunque los pedazos sigan cayendo.
func hit_breakable(cell: Vector2i, heading: Vector2i) -> int:
	if not _breakables.has(cell):
		return 0
	var left: int = _breakables[cell].hit(Vector3(heading.x, 0, heading.y))
	if left == 0:
		_breakables.erase(cell)
	return left


## Color de la puerta cerrada de la casilla, o "" si no hay.
func door_color(cell: Vector2i) -> String:
	return _doors[cell]["color"] if _doors.has(cell) else ""


## Color de la llave que hay en la casilla, o "" si no hay.
func key_color(cell: Vector2i) -> String:
	return _keys[cell]["color"] if _keys.has(cell) else ""


## Quita la llave del mapa y devuelve su color.
## Posición y giro (globales) de la llave de esa casilla en el mapa.
func key_transform(cell: Vector2i) -> Transform3D:
	return _keys[cell]["node"].global_transform if _keys.has(cell) else Transform3D()


func take_key(cell: Vector2i) -> String:
	var color := key_color(cell)
	if color != "":
		_keys[cell]["node"].queue_free()
		_keys.erase(cell)
	return color


## Power up que hay en la casilla, o null si no hay.
func power_up_at(cell: Vector2i) -> PowerUp:
	return _power_ups[cell]["power_up"] if _power_ups.has(cell) else null


## Quita el power up del mapa y lo devuelve (null si no había).
func take_power_up(cell: Vector2i) -> PowerUp:
	var power_up := power_up_at(cell)
	if power_up:
		_power_ups[cell]["node"].queue_free()
		_power_ups.erase(cell)
	return power_up


## Abre la puerta: la casilla pasa a ser libre al instante y la puerta se
## hunde en el suelo hasta desaparecer.
## Abre la puerta (deja de ser obstáculo al momento). Si se pasa la llave
## (`key`, el nodo que lleva el cubo), primero vuela desde donde está hasta
## la puerta encogiéndose hasta desaparecer, y entonces la puerta se hunde.
func open_door(cell: Vector2i, key: Node3D = null) -> void:
	if not _doors.has(cell):
		return
	var door: Node3D = _doors[cell]["node"]
	_doors.erase(cell)
	var tween := door.create_tween()
	if key:
		# La llave pasa a ser del tablero: si se reinicia el nivel, se va con él.
		var from := key.global_transform
		key.reparent(self)
		key.top_level = false
		key.global_transform = from
		var fly := key.create_tween().set_parallel()
		fly.tween_property(key, "position", door.position, KEY_TO_DOOR_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		fly.tween_property(key, "scale", Vector3.ONE * 0.01, KEY_TO_DOOR_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fly.tween_property(key, "rotation:y", key.rotation.y + TAU, KEY_TO_DOOR_TIME)
		fly.chain().tween_callback(key.queue_free)
		tween.tween_interval(KEY_TO_DOOR_TIME)
	tween.tween_property(door, "position:y", door.position.y - DOOR_HEIGHT - FLOOR_THICKNESS,
			DOOR_SINK_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(door.queue_free)


func cell_to_world(cell: Vector2i) -> Vector3:
	return global_transform * Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)


func get_center() -> Vector3:
	var size := get_grid_size()
	return global_transform * Vector3((size.x - 1) * CELL_SIZE * 0.5, 0.0, (size.y - 1) * CELL_SIZE * 0.5)


func get_grid_size() -> Vector2i:
	var width := 0
	for row in layout:
		width = maxi(width, row.length())
	return Vector2i(width, layout.size())


# --- Aparición del tablero -----------------------------------------------------

## Oculta el tablero y lo hace aparecer casilla a casilla en diagonal, desde
## arriba a la izquierda (ver REVEAL_TIME).
## Los enemigos se quedan quietos hasta set_enemies_frozen(false).
func start_reveal() -> void:
	_reveal_time = 0.0
	_reveal_delays.clear()
	var max_delay := REVEAL_TIME - REVEAL_FADE_TIME
	var grid := get_grid_size()
	# Cada diagonal (x + z constante) empieza algo después de la anterior.
	var diagonals := maxf(1.0, grid.x + grid.y - 2)
	for z in layout.size():
		for x in layout[z].length():
			_reveal_delays[Vector2i(x, z)] = (x + z) / diagonals * max_delay
	# Los materiales del fundido escriben profundidad: si no, el suelo y las
	# paredes (un solo objeto transparente cada uno) taparían lo que tienen
	# encima según el orden en que se dibujen.
	for entry in _reveal_multimeshes:
		for mat: BaseMaterial3D in entry["materials"]:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	_reveal_nodes.clear()
	for child in get_children():
		var node := child as Node3D
		if node == null or node is MultiMeshInstance3D or node.is_queued_for_deletion():
			continue
		var cell := Vector2i(roundi(node.position.x / CELL_SIZE), roundi(node.position.z / CELL_SIZE))
		_reveal_nodes.append({"delay": _reveal_delays.get(cell, 0.0),
			"materials": _fade_materials(node)})
	set_enemies_frozen(true)
	_revealing = true
	# Todo empieza transparente.
	_apply_reveal()


func is_revealing() -> bool:
	return _revealing


## Detiene o reanuda a los enemigos (durante la aparición del nivel).
func set_enemies_frozen(frozen: bool) -> void:
	for enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.process_mode = Node.PROCESS_MODE_DISABLED if frozen else Node.PROCESS_MODE_INHERIT


func _update_reveal(delta: float) -> void:
	_reveal_time += delta
	_apply_reveal()
	if _reveal_time >= REVEAL_TIME:
		_finish_reveal()
		reveal_finished.emit()


## Deja todo opaco, con los materiales del juego normales.
func _finish_reveal() -> void:
	_revealing = false
	for entry in _reveal_multimeshes:
		var multimesh: MultiMesh = entry["multimesh"]
		for i in multimesh.instance_count:
			multimesh.set_instance_color(i, Color.WHITE)
		for mat: BaseMaterial3D in entry["materials"]:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	for entry in _reveal_nodes:
		for item: Dictionary in entry["materials"]:
			var mesh_instance: MeshInstance3D = item["node"]
			if not is_instance_valid(mesh_instance):
				continue
			if item["surface"] < 0:
				mesh_instance.material_override = item["original"]
			else:
				mesh_instance.set_surface_override_material(item["surface"], item["original"])
	_reveal_nodes.clear()


## Opacidad de cada casilla según su progreso: de transparente a opaca.
func _apply_reveal() -> void:
	for entry in _reveal_multimeshes:
		var multimesh: MultiMesh = entry["multimesh"]
		var cells: Array = entry["cells"]
		for i in cells.size():
			var k := _reveal_progress(_reveal_delays.get(cells[i], 0.0))
			if k >= 0.0:
				multimesh.set_instance_color(i, Color(1, 1, 1, k))
	for entry in _reveal_nodes:
		var k := _reveal_progress(entry["delay"])
		if k < 0.0:
			continue
		for item: Dictionary in entry["materials"]:
			var mat: BaseMaterial3D = item["material"]
			mat.albedo_color.a = item["alpha"] * k


## Pone a las mallas de `node` (y sus descendientes) copias transparentes
## de sus materiales para el fundido. Devuelve lo necesario para animarlas
## y restaurarlas: { "node", "surface" (-1 = material_override), "original",
## "material", "alpha" }.
func _fade_materials(node: Node3D) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var found: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		found.append(node)
	for mesh_instance: MeshInstance3D in found:
		if mesh_instance.material_override:
			var fade := _fade_copy(mesh_instance.material_override)
			if fade:
				items.append({"node": mesh_instance, "surface": -1,
					"original": mesh_instance.material_override, "material": fade,
					"alpha": fade.albedo_color.a})
				mesh_instance.material_override = fade
			continue
		if mesh_instance.mesh == null:
			continue
		for i in mesh_instance.mesh.get_surface_count():
			var fade := _fade_copy(mesh_instance.get_active_material(i))
			if fade == null:
				continue
			items.append({"node": mesh_instance, "surface": i,
				"original": mesh_instance.get_surface_override_material(i), "material": fade,
				"alpha": fade.albedo_color.a})
			mesh_instance.set_surface_override_material(i, fade)
	return items


static func _fade_copy(material: Material) -> BaseMaterial3D:
	var base := material as BaseMaterial3D
	if base == null:
		return null
	var fade := base.duplicate() as BaseMaterial3D
	if fade.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
		fade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fade.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	return fade


## Opacidad (0-1, suavizada) de una casilla con ese retraso; -1 si ya ha
## terminado y no hay que tocarla (para no repintar miles de casillas en
## cada fotograma).
func _reveal_progress(delay: float) -> float:
	if _reveal_time - delay > REVEAL_FADE_TIME + 0.1:
		return -1.0
	return smoothstep(0.0, 1.0, (_reveal_time - delay) / REVEAL_FADE_TIME)


## Un mismo bloque del catálogo (BlockCatalog) repetido en varias casillas,
## en un solo MultiMesh. La cara de arriba de cada casilla va girada al azar
## (siempre igual en la misma casilla) para que no se note la repetición.
func _add_multimesh(cells: Array, block: String, size: Vector3, y: float, tint: Color) -> void:
	if cells.is_empty():
		return
	var mesh := BlockCatalog.make_mesh(block, size, tint)
	var materials: Array[BaseMaterial3D] = []
	for i in mesh.get_surface_count():
		materials.append(mesh.surface_get_material(i))
	var spin := BlockCatalog.spin(block)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	# El color de cada instancia (blanco) lleva su opacidad en la aparición.
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = cells.size()
	for i in cells.size():
		var cell: Vector2i = cells[i]
		var turns := 0
		if spin > 1:
			turns = (_cell_hash(cell) % spin) * (4 / spin)
		multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, turns * PI * 0.5),
			Vector3(cell.x * CELL_SIZE, y, cell.y * CELL_SIZE)))
		multimesh.set_instance_color(i, Color.WHITE)
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	add_child(instance)
	_reveal_multimeshes.append({"multimesh": multimesh, "materials": materials, "cells": cells.duplicate()})


static func _cell_hash(cell: Vector2i) -> int:
	return absi((cell.x * 73856093) ^ (cell.y * 19349663)) >> 3


static func _group(groups: Dictionary, key: String, cell: Vector2i) -> void:
	if not groups.has(key):
		groups[key] = []
	groups[key].append(cell)


## Bloque del catálogo de una casilla para `part` ("floor", "wall" o
## "foundation"): el de la última zona de block_regions que la contiene, si
## no el del nivel y si no el de DEFAULT_THEME. La roca, si no se indica, es
## la que va bajo el bloque del suelo.
func _block_at(cell: Vector2i, part: String) -> String:
	var found := ""
	for i in range(block_regions.size() - 1, -1, -1):
		var region: Dictionary = block_regions[i]
		if region.has(part) and (region["rect"] as Rect2i).has_point(cell):
			found = region[part]
			break
	if found == "":
		found = block_theme.get(part, "")
	if found == "":
		if part == "foundation":
			return BlockCatalog.under(_block_at(cell, "floor"))
		found = DEFAULT_THEME[part]
	if not BlockCatalog.has(found):
		push_error("Bloque desconocido '%s' en el tema del nivel" % found)
		return DEFAULT_THEME.get(part, "stone")
	return found


## Bloques de roca bajo el suelo y las paredes (niveles con vacío): el
## tablero parece una isla flotando sobre el abismo. Las casillas que dan al
## vacío llevan un bloque algo más claro para que se vea el borde.
func _add_foundations(wall_cells: Array[Vector2i]) -> void:
	## "bloque" -> casillas, por separado las que dan al vacío.
	var inner := {}
	var edge := {}
	var cells: Array[Vector2i] = []
	cells.append_array(wall_cells)
	cells.append_array(_walkable.keys())
	for cell in cells:
		if bridge_cell(cell):
			continue
		var at_edge := false
		for dir: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			if is_void(cell + dir):
				at_edge = true
				break
		_group(edge if at_edge else inner, _block_at(cell, "foundation"), cell)
	var size := Vector3(CELL_SIZE, FOUNDATION_DEPTH, CELL_SIZE)
	var y := -FLOOR_THICKNESS - FOUNDATION_DEPTH * 0.5
	for id: String in inner:
		_add_multimesh(inner[id], id, size, y, FOUNDATION_INNER_TINT)
	for id: String in edge:
		_add_multimesh(edge[id], id, size, y, Color.WHITE)


## La casilla es '=' en el mapa (aunque el puente ya se haya caído).
func bridge_cell(cell: Vector2i) -> bool:
	return cell.y >= 0 and cell.y < layout.size() and cell.x >= 0 and cell.x < layout[cell.y].length() \
		and layout[cell.y][cell.x] == BRIDGE_CHAR


## Agrupa las casillas '=' en puentes rectos (horizontales o verticales).
func _add_bridges(bridge_cells: Dictionary) -> void:
	var pending := bridge_cells.duplicate()
	for z in layout.size():
		for x in layout[z].length():
			var first := Vector2i(x, z)
			if not pending.has(first):
				continue
			var along := Vector2i.RIGHT
			if not bridge_cells.has(first + Vector2i.RIGHT) and bridge_cells.has(first + Vector2i.DOWN):
				along = Vector2i.DOWN
			elif not bridge_cells.has(first + Vector2i.RIGHT):
				# Puente de una casilla: va de un suelo al otro.
				if has_floor(first + Vector2i.UP) and has_floor(first + Vector2i.DOWN):
					along = Vector2i.DOWN
			var run: Array[Vector2i] = []
			var c := first
			while pending.has(c):
				run.append(c)
				pending.erase(c)
				c += along
			var bridge := HangingBridge.new()
			bridge.name = "Bridge%d" % get_child_count()
			bridge.setup(run, along, CELL_SIZE)
			add_child(bridge)
			for cell in run:
				_bridges[cell] = bridge


func _add_box(cell: Vector2i, size: Vector3, y: float, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = Vector3(cell.x * CELL_SIZE, y, cell.y * CELL_SIZE)
	add_child(instance)
	return instance


func _add_key(cell: Vector2i, color: String) -> void:
	var key := KeyVisual.create(ITEM_COLORS[color])
	key.scale = Vector3.ONE * KEY_SCALE
	key.position = Vector3(cell.x * CELL_SIZE, KEY_FLOAT_HEIGHT, cell.y * CELL_SIZE)
	add_child(key)
	_keys[cell] = {"color": color, "node": key}


func _add_power_up(cell: Vector2i, symbol: String) -> void:
	var power_up := PowerUpCatalog.create(symbol)
	var node := power_up.create_pickup_visual()
	node.position = Vector3(cell.x * CELL_SIZE, POWER_UP_FLOAT_HEIGHT, cell.y * CELL_SIZE)
	add_child(node)
	_power_ups[cell] = {"power_up": power_up, "node": node}


## Los barrotes se orientan como las puertas: las lanzas van de muro a muro
## y, al abrirse, se esconden dentro de ellos.
func _add_bars(cell: Vector2i, symbol: String) -> void:
	var bars := Bars.new(symbol == symbol.to_lower())
	bars.position = Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)
	if not (_is_wall(cell + Vector2i.LEFT) and _is_wall(cell + Vector2i.RIGHT)):
		bars.rotation.y = PI * 0.5
	add_child(bars)
	_bars[cell] = {"group": symbol.to_lower(), "node": bars}


## El botón se pega a la cara del muro que da a la casilla libre de al lado
## (nunca a una de vacío: su cara exterior no se puede pulsar).
func _add_button(cell: Vector2i, symbol: String) -> void:
	var facing := Vector2i.ZERO
	for dir: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var n := cell + dir
		if n.y >= 0 and n.y < layout.size() and n.x >= 0 and n.x < layout[n.y].length() \
				and not "#~".contains(layout[n.y][n.x]) and not BUTTON_CHARS.contains(layout[n.y][n.x]):
			facing = dir
			break
	if facing == Vector2i.ZERO:
		push_warning("Botón '%s' en %s sin casilla libre al lado" % [symbol, cell])
		return
	var button := WallButton.new()
	button.position = Vector3((cell.x + facing.x * 0.5) * CELL_SIZE, 0.0, (cell.y + facing.y * 0.5) * CELL_SIZE)
	button.rotation.y = atan2(facing.x, facing.y)
	add_child(button)
	_buttons[cell] = {"symbol": symbol, "node": button, "front": cell + facing, "near": {}}


## Casillas libres a `max_steps` pasos o menos de `origin` (contando origin
## como 1), sin tener en cuenta puertas, barrotes ni muros destructibles.
func _cells_within(origin: Vector2i, max_steps: int) -> Dictionary:
	var steps := {origin: 1}
	var queue: Array[Vector2i] = [origin]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if steps[current] >= max_steps:
			continue
		for dir: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var n := current + dir
			if _walkable.has(n) and not steps.has(n):
				steps[n] = steps[current] + 1
				queue.append(n)
	return steps


func _add_enemy(cell: Vector2i, symbol: String) -> void:
	var enemy: Enemy
	if symbol == CHASER_CHAR:
		enemy = Chaser.new()
	elif symbol == BLOCKER_CHAR:
		enemy = Blocker.new()
	else:
		var patroller := Patroller.new()
		var problem := patroller.set_route(cell, patrol_routes.get(symbol, ""))
		for route_cell in patroller.route:
			if problem == "" and not _walkable.has(route_cell):
				problem = "pasa por la casilla %s, que no es libre" % route_cell
		if problem != "":
			push_warning("Ruta del patrullero '%s': %s" % [symbol, problem])
			patroller.route = [cell]
		enemy = patroller
	add_child(enemy)
	enemy.setup(self, cell)
	enemy.cube = cube
	_enemies.append(enemy)


func _add_breakable(cell: Vector2i, hits: int) -> void:
	var wall := BreakableWall.new(hits)
	wall.position = Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)
	add_child(wall)
	_breakables[cell] = wall


## La puerta se orienta según los muros que la rodean: si los muros están a
## izquierda y derecha, el pasillo va de arriba abajo y la puerta lo cruza en X.
func _add_door(cell: Vector2i, color: String) -> void:
	var across_x := _is_wall(cell + Vector2i.LEFT) and _is_wall(cell + Vector2i.RIGHT)
	var size := Vector3(CELL_SIZE * 0.98, DOOR_HEIGHT, DOOR_THICKNESS) if across_x \
		else Vector3(DOOR_THICKNESS, DOOR_HEIGHT, CELL_SIZE * 0.98)
	var mat := _make_material(ITEM_COLORS[color])
	mat.roughness = 0.5
	var door := _add_box(cell, size, DOOR_HEIGHT * 0.5, mat)
	_doors[cell] = {"color": color, "node": door}


func _is_wall(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= layout.size() or cell.x < 0 or cell.x >= layout[cell.y].length():
		return true
	var symbol := layout[cell.y][cell.x]
	return symbol == "#" or BREAKABLE_CHARS.contains(symbol) or BUTTON_CHARS.contains(symbol)


func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat
