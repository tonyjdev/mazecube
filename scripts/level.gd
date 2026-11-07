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
## Las filas crecen hacia +Z (hacia abajo en pantalla) y las columnas hacia +X.

const CELL_SIZE := 1.0
const WALL_HEIGHT := 0.5
const FLOOR_THICKNESS := 0.1
const KEY_CHARS := "yorug"
const BREAKABLE_CHARS := "12345"
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
## La puerta tiene dos hojas que, al abrirse, se deslizan hacia los lados
## (hacia dentro de los muros) y después se recogen hasta desaparecer.
const DOOR_LEAF_GAP := 0.02
const DOOR_SLIDE_TIME := 0.45
const DOOR_FOLD_TIME := 0.2
## Altura y velocidad de giro (rad/s) de las llaves que están en el mapa.
const KEY_FLOAT_HEIGHT := 0.5
const KEY_SCALE := 1.6
const KEY_SPIN_SPEED := 1.2
const POWER_UP_FLOAT_HEIGHT := 0.5

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

var start_cell := Vector2i.ZERO
var goal_cell := Vector2i.ZERO
var _walkable := {}
## casilla -> { "color": String, "node": Node3D }
var _keys := {}
var _doors := {}
## casilla -> { "power_up": PowerUp, "node": Node3D }
var _power_ups := {}
## casilla -> BreakableWall (solo los que siguen en pie)
var _breakables := {}


func _ready() -> void:
	build()


## Sustituye el tablero por el de un nivel de Levels.LIST.
func load_level(data: Dictionary) -> void:
	layout = PackedStringArray(data["layout"])
	start_heading = data["start_heading"]
	build()


func build() -> void:
	for child in get_children():
		child.queue_free()
	_walkable.clear()
	_keys.clear()
	_doors.clear()
	_power_ups.clear()
	_breakables.clear()

	var floor_a := _make_material(Color(0.86, 0.84, 0.80))
	var floor_b := _make_material(Color(0.78, 0.76, 0.72))
	var wall_mat := _make_material(Color(0.32, 0.36, 0.45))
	var start_mat := _make_material(Color(0.35, 0.60, 0.95))
	var goal_mat := _make_material(Color(0.30, 0.80, 0.45))

	for z in layout.size():
		var row: String = layout[z]
		for x in row.length():
			var cell := Vector2i(x, z)
			var symbol := row[x]
			if symbol == "#":
				_add_box(cell, Vector3(CELL_SIZE, WALL_HEIGHT, CELL_SIZE), WALL_HEIGHT * 0.5, wall_mat)
				continue
			_walkable[cell] = true
			var mat := floor_a if (x + z) % 2 == 0 else floor_b
			if symbol == "A":
				start_cell = cell
				mat = start_mat
			elif symbol == "B":
				goal_cell = cell
				mat = goal_mat
			var tile := Vector3(CELL_SIZE * 0.96, FLOOR_THICKNESS, CELL_SIZE * 0.96)
			_add_box(cell, tile, -FLOOR_THICKNESS * 0.5, mat)
			if KEY_CHARS.contains(symbol):
				_add_key(cell, symbol)
			elif KEY_CHARS.to_upper().contains(symbol):
				_add_door(cell, symbol.to_lower())
			elif PowerUpCatalog.has_symbol(symbol):
				_add_power_up(cell, symbol)
			elif BREAKABLE_CHARS.contains(symbol):
				_add_breakable(cell, int(symbol))


func _process(delta: float) -> void:
	for item in _keys.values():
		item["node"].rotate_y(KEY_SPIN_SPEED * delta)
	for item in _power_ups.values():
		var power_up: PowerUp = item["power_up"]
		item["node"].rotate(power_up.pickup_spin_axis, power_up.pickup_spin_speed * delta)


## Casilla por la que se puede pasar: libre, sin puerta cerrada y sin muro
## destructible en pie.
func is_walkable(cell: Vector2i) -> bool:
	return _walkable.has(cell) and not _doors.has(cell) and not _breakables.has(cell)


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


## Abre la puerta: la casilla pasa a ser libre al instante y las dos hojas
## se deslizan hacia los lados, dentro de los muros, y luego se recogen
## hacia el suelo hasta desaparecer.
func open_door(cell: Vector2i) -> void:
	if not _doors.has(cell):
		return
	var door: Node3D = _doors[cell]["node"]
	_doors.erase(cell)
	var tween := door.create_tween().set_parallel()
	for leaf: Node3D in door.get_children():
		var outward := leaf.position.normalized()
		var slide := leaf.position + outward * (CELL_SIZE * 0.5)
		tween.tween_property(leaf, "position", slide, DOOR_SLIDE_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(leaf, "scale:y", 0.01, DOOR_FOLD_TIME) \
			.set_delay(DOOR_SLIDE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(door.queue_free)


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


func _add_breakable(cell: Vector2i, hits: int) -> void:
	var wall := BreakableWall.new(hits)
	wall.position = Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)
	add_child(wall)
	_breakables[cell] = wall


## La puerta se orienta según los muros que la rodean: si los muros están a
## izquierda y derecha, el pasillo va de arriba abajo y la puerta lo cruza en X.
## Está formada por dos hojas, una a cada lado del centro del pasillo; cada
## hoja tiene su origen a ras de suelo para poder recogerla hacia abajo.
func _add_door(cell: Vector2i, color: String) -> void:
	var across_x := _is_wall(cell + Vector2i.LEFT) and _is_wall(cell + Vector2i.RIGHT)
	var axis := Vector3.RIGHT if across_x else Vector3.BACK
	var leaf_width := (CELL_SIZE * 0.98 - DOOR_LEAF_GAP) * 0.5
	var size := Vector3(leaf_width, DOOR_HEIGHT, DOOR_THICKNESS) if across_x \
		else Vector3(DOOR_THICKNESS, DOOR_HEIGHT, leaf_width)
	var mat := _make_material(ITEM_COLORS[color])
	mat.roughness = 0.5
	var door := Node3D.new()
	door.position = Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)
	add_child(door)
	for side in [-1.0, 1.0]:
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh.material = mat
		var leaf_mesh := MeshInstance3D.new()
		leaf_mesh.mesh = mesh
		leaf_mesh.position = Vector3(0, DOOR_HEIGHT * 0.5, 0)
		var leaf := Node3D.new()
		leaf.position = axis * side * (leaf_width + DOOR_LEAF_GAP) * 0.5
		leaf.add_child(leaf_mesh)
		door.add_child(leaf)
	_doors[cell] = {"color": color, "node": door}


func _is_wall(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= layout.size() or cell.x < 0 or cell.x >= layout[cell.y].length():
		return true
	var symbol := layout[cell.y][cell.x]
	return symbol == "#" or BREAKABLE_CHARS.contains(symbol)


func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat
