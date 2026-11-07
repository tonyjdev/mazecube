extends Node3D
## Escena principal del prototipo: entrada, cámara y estado de la partida.

enum CameraMode { TILTED_TOP, ISOMETRIC }

const CAMERA_NAMES := {
	CameraMode.TILTED_TOP: "Cenital inclinada",
	CameraMode.ISOMETRIC: "Isométrica",
}

@export var camera_mode := CameraMode.TILTED_TOP
## Inclinación de la vista cenital (90 = totalmente desde arriba).
@export_range(45.0, 90.0) var tilted_pitch_degrees := 65.0

@onready var level: Level = $Level
@onready var cube: RollingCube = $Cube
@onready var camera: Camera3D = $Camera3D
@onready var status_label: Label = $UI/Margin/VBox/Status
@onready var help_label: Label = $UI/Margin/VBox/Help


func _ready() -> void:
	cube.reached_goal.connect(_on_reached_goal)
	cube.rolled.connect(_on_rolled)
	_restart()
	_apply_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("turn_left"):
		cube.request_turn(RollingCube.TURN_LEFT)
	elif event.is_action_pressed("turn_right"):
		cube.request_turn(RollingCube.TURN_RIGHT)
	elif event.is_action_pressed("restart"):
		_restart()
	elif event.is_action_pressed("toggle_camera"):
		camera_mode = CameraMode.ISOMETRIC if camera_mode == CameraMode.TILTED_TOP else CameraMode.TILTED_TOP
		_apply_camera()


func _restart() -> void:
	cube.reset(level)
	status_label.text = "Llega a la casilla verde"


func _apply_camera() -> void:
	var center := level.get_center()
	var grid := level.get_grid_size()
	var extent := float(maxi(grid.x, grid.y)) * Level.CELL_SIZE
	if camera_mode == CameraMode.TILTED_TOP:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 45.0
		var pitch := deg_to_rad(tilted_pitch_degrees)
		camera.position = center + Vector3(0, sin(pitch), cos(pitch)) * extent * 1.25
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = extent * 0.85
		camera.position = center + Vector3(1, 1, 1).normalized() * extent * 2.0
	camera.look_at(center, Vector3.UP)
	help_label.text = "←/A izquierda   →/D derecha   R reiniciar   C cámara (%s)" % CAMERA_NAMES[camera_mode]


func _on_rolled(_cell: Vector2i) -> void:
	if not cube.is_finished:
		status_label.text = "Llega a la casilla verde"


func _on_reached_goal() -> void:
	status_label.text = "¡Meta alcanzada! Pulsa R para reiniciar"
