extends Node3D
## Escaparate de BlockCatalog (scenes/block_catalog_preview.tscn): cada
## bloque como una pequeña parcela de suelo con un muro encima y la roca
## debajo, con su nombre. Sirve para revisar los materiales; se abre en el
## editor y se ejecuta con F6. Arrastrar con el ratón gira la vista y la
## rueda acerca o aleja.

const COLUMNS := 6
const SPACING := 4.0

var _yaw := -0.6
var _pitch := -0.75
var _distance := 22.0
var _center := Vector3.ZERO
@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	var ids := BlockCatalog.ids()
	for i in ids.size():
		var id: String = ids[i]
		var origin := Vector3((i % COLUMNS) * SPACING, 0, floori(i / float(COLUMNS)) * SPACING)
		_add_plot(id, origin)
	var rows := ceili(ids.size() / float(COLUMNS))
	_center = Vector3((COLUMNS - 1) * SPACING * 0.5, 0, (rows - 1) * SPACING * 0.5)
	_update_camera()


## Parcela de 3x3 casillas: suelo con ajedrezado, un muro en forma de L y la
## roca de debajo.
func _add_plot(id: String, origin: Vector3) -> void:
	var tile := BlockCatalog.make_mesh(id, Vector3(0.96, Level.FLOOR_THICKNESS, 0.96))
	var tile_dark := BlockCatalog.make_mesh(id, Vector3(0.96, Level.FLOOR_THICKNESS, 0.96), Level.FLOOR_DARK_TINT)
	var wall := BlockCatalog.make_mesh(id, Vector3(1, Level.WALL_HEIGHT, 1))
	var rock := BlockCatalog.make_mesh(BlockCatalog.under(id), Vector3(1, Level.FOUNDATION_DEPTH, 1))
	for x in 3:
		for z in 3:
			var p := origin + Vector3(x - 1, 0, z - 1)
			var is_wall := x == 0 or z == 0
			if is_wall:
				_add_mesh(wall, p + Vector3.UP * Level.WALL_HEIGHT * 0.5)
			else:
				_add_mesh(tile if (x + z) % 2 == 0 else tile_dark, p + Vector3.DOWN * Level.FLOOR_THICKNESS * 0.5)
			_add_mesh(rock, p + Vector3.DOWN * (Level.FLOOR_THICKNESS + Level.FOUNDATION_DEPTH * 0.5))
	var label := Label3D.new()
	label.text = "%s\n(%s)" % [BlockCatalog.display_name(id), id]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.outline_size = 12
	label.pixel_size = 0.006
	label.position = origin + Vector3(0, 1.3, 0)
	add_child(label)


func _add_mesh(mesh: Mesh, pos: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	add_child(instance)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_yaw -= event.relative.x * 0.008
		_pitch = clampf(_pitch - event.relative.y * 0.008, -1.5, -0.15)
		_update_camera()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(4.0, _distance * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(60.0, _distance * 1.1)
		_update_camera()


func _update_camera() -> void:
	var orbit := Basis.from_euler(Vector3(_pitch, _yaw, 0))
	_camera.position = _center + orbit * Vector3(0, 0, _distance)
	_camera.look_at(_center)
