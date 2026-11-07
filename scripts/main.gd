extends Node3D
## Escena principal del prototipo: entrada, cámara y estado de la partida.
##
## Controles:
##   Teclado: ←/A gira a la izquierda, →/D a la derecha, R reinicia, C cámara.
##   Táctil:  tocar la mitad izquierda o derecha de la pantalla gira hacia ese
##            lado; los botones superiores reinician y cambian la cámara.
##   En PC, el clic del ratón se trata como un toque (emulate_touch_from_mouse).

enum CameraMode { TILTED_TOP, ISOMETRIC }

const CAMERA_NAMES := {
	CameraMode.TILTED_TOP: "Cenital inclinada",
	CameraMode.ISOMETRIC: "Isométrica",
}
const HINT_IDLE_ALPHA := 0.45

@export var camera_mode := CameraMode.TILTED_TOP
## Inclinación de la vista cenital (90 = totalmente desde arriba).
@export_range(45.0, 90.0) var tilted_pitch_degrees := 65.0
## Margen alrededor del tablero al encuadrarlo (1.0 = justo al borde).
@export_range(1.0, 1.5) var camera_fit_margin := 1.08

var _hint_tweens := {}

@onready var level: Level = $Level
@onready var cube: RollingCube = $Cube
@onready var camera: Camera3D = $Camera3D
@onready var status_label: Label = $UI/Margin/VBox/Header/Status
@onready var restart_button: Button = $UI/Margin/VBox/Header/Buttons/RestartButton
@onready var camera_button: Button = $UI/Margin/VBox/Header/Buttons/CameraButton
@onready var help_label: Label = $UI/Margin/VBox/BottomBar/Help
@onready var left_hint: Label = $UI/Margin/VBox/BottomBar/LeftHint
@onready var right_hint: Label = $UI/Margin/VBox/BottomBar/RightHint


func _ready() -> void:
	cube.reached_goal.connect(_on_reached_goal)
	cube.rolled.connect(_on_rolled)
	restart_button.pressed.connect(_restart)
	camera_button.pressed.connect(_toggle_camera)
	left_hint.modulate.a = HINT_IDLE_ALPHA
	right_hint.modulate.a = HINT_IDLE_ALPHA
	if _is_touch_device():
		help_label.text = "Toca a la izquierda o a la derecha de la pantalla para girar"
	else:
		help_label.text = "←/A · →/D o clic a cada lado para girar   R reiniciar   C cámara"
	get_viewport().size_changed.connect(_apply_camera)
	_restart()
	_apply_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and not _is_over_buttons(touch.position):
			var half := get_viewport().get_visible_rect().size.x * 0.5
			_turn(RollingCube.TURN_LEFT if touch.position.x < half else RollingCube.TURN_RIGHT)
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("turn_left"):
		_turn(RollingCube.TURN_LEFT)
	elif event.is_action_pressed("turn_right"):
		_turn(RollingCube.TURN_RIGHT)
	elif event.is_action_pressed("restart"):
		_restart()
	elif event.is_action_pressed("toggle_camera"):
		_toggle_camera()


func _turn(direction: int) -> void:
	cube.request_turn(direction)
	_flash_hint(left_hint if direction == RollingCube.TURN_LEFT else right_hint)


func _restart() -> void:
	cube.reset(level)
	status_label.text = "Llega a la casilla verde"


func _toggle_camera() -> void:
	camera_mode = CameraMode.ISOMETRIC if camera_mode == CameraMode.TILTED_TOP else CameraMode.TILTED_TOP
	_apply_camera()


func _apply_camera() -> void:
	var center := level.get_center()
	var corners := _board_corners(center)
	if camera_mode == CameraMode.TILTED_TOP:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 45.0
		var pitch := deg_to_rad(tilted_pitch_degrees)
		var dir := Vector3(0, sin(pitch), cos(pitch))
		# Distancia mínima a la que cabe todo el tablero.
		_fit(_place_camera.bind(center, dir), corners, 2.0, 200.0)
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		var extent := float(maxi(level.get_grid_size().x, level.get_grid_size().y))
		camera.position = center + Vector3(1, 1, 1).normalized() * extent * 2.0
		camera.look_at(center, Vector3.UP)
		# Tamaño ortográfico mínimo con el que cabe todo el tablero.
		_fit(_set_ortho_size, corners, 1.0, 200.0)
	camera_button.text = "Cámara: %s" % CAMERA_NAMES[camera_mode]


func _place_camera(distance: float, center: Vector3, dir: Vector3) -> void:
	camera.position = center + dir * distance
	camera.look_at(center, Vector3.UP)


func _set_ortho_size(size: float) -> void:
	camera.size = size


## Esquinas del tablero (suelo y altura de las paredes), ampliadas con el margen.
func _board_corners(center: Vector3) -> Array[Vector3]:
	var grid := level.get_grid_size()
	var half := Level.CELL_SIZE * 0.5
	var lo := level.cell_to_world(Vector2i.ZERO) - Vector3(half, Level.FLOOR_THICKNESS, half)
	var hi := level.cell_to_world(grid - Vector2i.ONE) + Vector3(half, Level.WALL_HEIGHT, half)
	var corners: Array[Vector3] = []
	for x in [lo.x, hi.x]:
		for y in [lo.y, hi.y]:
			for z in [lo.z, hi.z]:
				var p := Vector3(x, y, z)
				corners.append(center + (p - center) * camera_fit_margin)
	return corners


## Búsqueda binaria del menor valor (distancia o tamaño) con el que todas las
## esquinas quedan dentro de la vista de la cámara, sea cual sea la proporción
## de la pantalla.
func _fit(apply: Callable, corners: Array[Vector3], lo: float, hi: float) -> void:
	for i in 30:
		var mid := (lo + hi) * 0.5
		apply.call(mid)
		var inside := true
		for p in corners:
			if not camera.is_position_in_frustum(p):
				inside = false
				break
		if inside:
			hi = mid
		else:
			lo = mid
	apply.call(hi)


## Los toques sobre los botones no cuentan como giro.
func _is_over_buttons(pos: Vector2) -> bool:
	return restart_button.get_global_rect().has_point(pos) \
		or camera_button.get_global_rect().has_point(pos)


func _is_touch_device() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


## Resalta brevemente la indicación del lado pulsado.
func _flash_hint(hint: Label) -> void:
	if _hint_tweens.has(hint) and _hint_tweens[hint].is_valid():
		_hint_tweens[hint].kill()
	hint.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(hint, "modulate:a", HINT_IDLE_ALPHA, 0.35)
	_hint_tweens[hint] = tween


func _on_rolled(_cell: Vector2i) -> void:
	if not cube.is_finished:
		status_label.text = "Llega a la casilla verde"


func _on_reached_goal() -> void:
	status_label.text = "¡Meta alcanzada! Reinicia para volver a jugar"
