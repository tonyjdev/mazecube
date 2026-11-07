class_name Level
extends Node3D
## Tablero del laberinto construido a partir de un mapa de texto.
##
## Leyenda del mapa:
##   '#' pared   '.' casilla libre   'A' inicio   'B' meta
## Las filas crecen hacia +Z (hacia abajo en pantalla) y las columnas hacia +X.

const CELL_SIZE := 1.0
const WALL_HEIGHT := 0.5
const FLOOR_THICKNESS := 0.1

@export var layout: PackedStringArray = PackedStringArray([
	"#########",
	"#A..#...#",
	"#.#.#.#.#",
	"#.#...#.#",
	"#.#####.#",
	"#.....#B#",
	"#########",
])
## Rumbo inicial del cubo en coordenadas de casilla (x, z). (1, 0) = derecha.
@export var start_heading := Vector2i(1, 0)

var start_cell := Vector2i.ZERO
var goal_cell := Vector2i.ZERO
var _walkable := {}


func _ready() -> void:
	build()


func build() -> void:
	for child in get_children():
		child.queue_free()
	_walkable.clear()

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


func is_walkable(cell: Vector2i) -> bool:
	return _walkable.has(cell)


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


func _add_box(cell: Vector2i, size: Vector3, y: float, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = Vector3(cell.x * CELL_SIZE, y, cell.y * CELL_SIZE)
	add_child(instance)


func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat
