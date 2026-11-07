extends Node3D
## Escena principal del prototipo: entrada, cámara y estado de la partida.
##
## Controles:
##   Teclado: ←/A gira a la izquierda, →/D a la derecha, R reinicia.
##   Táctil:  tocar la mitad izquierda o derecha de la pantalla gira hacia ese
##            lado; el botón superior reinicia el nivel.
##   En PC, el clic del ratón se trata como un toque (emulate_touch_from_mouse).
##   Al completar un nivel: botón "Siguiente nivel" o Intro/N.
##   Solo en builds de depuración: Re Pág / Av Pág cambian de nivel.
##
## El nivel actual se guarda en user://progress.cfg para continuar al volver.
##
## Cámara: vista cenital inclinada en perspectiva (decisión definitiva).

const HINT_IDLE_ALPHA := 0.45
const PROGRESS_PATH := "user://progress.cfg"

## Inclinación de la vista cenital (90 = totalmente desde arriba).
@export_range(45.0, 90.0) var tilted_pitch_degrees := 65.0
## Margen alrededor del tablero al encuadrarlo (1.0 = justo al borde).
@export_range(1.0, 1.5) var camera_fit_margin := 1.08

var current_level := 0
var _hint_tweens := {}

@onready var level: Level = $Level
@onready var cube: RollingCube = $Cube
@onready var camera: Camera3D = $Camera3D
@onready var level_label: Label = $UI/Margin/VBox/Header/LevelLabel
@onready var status_label: Label = $UI/Margin/VBox/Header/Status
@onready var next_button: Button = $UI/Margin/VBox/Header/Buttons/NextButton
## Hueco libre entre la cabecera y la barra inferior: ahí se encuadra el tablero.
@onready var play_area: Control = $UI/Margin/VBox/Spacer
@onready var restart_button: Button = $UI/Margin/VBox/Header/Buttons/RestartButton
@onready var help_label: Label = $UI/Margin/VBox/BottomBar/Help
@onready var left_hint: Label = $UI/Margin/VBox/BottomBar/LeftHint
@onready var right_hint: Label = $UI/Margin/VBox/BottomBar/RightHint


func _ready() -> void:
	cube.reached_goal.connect(_on_reached_goal)
	cube.key_picked.connect(_on_key_picked)
	cube.door_opened.connect(_on_door_opened)
	cube.power_up_picked.connect(_on_power_up_picked)
	cube.power_up_ended.connect(_on_power_up_ended)
	restart_button.pressed.connect(_restart)
	next_button.pressed.connect(_next_level)
	left_hint.modulate.a = HINT_IDLE_ALPHA
	right_hint.modulate.a = HINT_IDLE_ALPHA
	if _is_touch_device():
		help_label.text = "Toca a la izquierda o a la derecha de la pantalla para girar"
	else:
		help_label.text = "←/A · →/D o clic a cada lado para girar   R reiniciar"
	# El hueco libre cambia al rotar o redimensionar la pantalla.
	play_area.resized.connect(_apply_camera)
	_load_level(_load_progress())


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
	elif event.is_action_pressed("next_level") and cube.is_finished:
		_next_level()
	elif OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_PAGEDOWN:
			_load_level(current_level + 1)
		elif event.keycode == KEY_PAGEUP:
			_load_level(current_level - 1)


func _turn(direction: int) -> void:
	cube.request_turn(direction)
	_flash_hint(left_hint if direction == RollingCube.TURN_LEFT else right_hint)


func _restart() -> void:
	# Reconstruir el tablero devuelve a su sitio las llaves y puertas.
	level.build()
	cube.reset(level)
	next_button.visible = false
	status_label.text = "Llega a la casilla verde"


func _load_level(index: int) -> void:
	current_level = clampi(index, 0, Levels.count() - 1)
	var data := Levels.get_level(current_level)
	level.layout = PackedStringArray(data["layout"])
	level.start_heading = data["start_heading"]
	level_label.text = "Nivel %d de %d · %s" % [current_level + 1, Levels.count(), data["name"]]
	_save_progress()
	_restart()
	_apply_camera()


## Tras el último nivel se vuelve al primero.
func _next_level() -> void:
	_load_level((current_level + 1) % Levels.count())


func _load_progress() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(PROGRESS_PATH) != OK:
		return 0
	return int(cfg.get_value("progress", "current_level", 0))


func _save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "current_level", current_level)
	cfg.save(PROGRESS_PATH)


func _apply_camera() -> void:
	var center := level.get_center()
	var corners := _board_corners(center)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 45.0
	var pitch := deg_to_rad(tilted_pitch_degrees)
	var dir := Vector3(0, sin(pitch), cos(pitch))
	# Distancia mínima a la que cabe todo el tablero.
	_fit(_place_camera.bind(center, dir), corners, 2.0, 200.0)


func _place_camera(distance: float, center: Vector3, dir: Vector3) -> void:
	camera.position = center + dir * distance
	camera.look_at(center, Vector3.UP)


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


## Búsqueda binaria de la menor distancia con la que todas las
## esquinas quedan dentro del hueco libre de la interfaz, sea cual sea la
## proporción de la pantalla.
func _fit(apply: Callable, corners: Array[Vector3], lo: float, hi: float) -> void:
	var area := play_area.get_global_rect()
	if area.size.x < 1.0 or area.size.y < 1.0:
		area = get_viewport().get_visible_rect()
	for i in 30:
		var mid := (lo + hi) * 0.5
		apply.call(mid)
		var inside := true
		for p in corners:
			if camera.is_position_behind(p) or not area.has_point(camera.unproject_position(p)):
				inside = false
				break
		if inside:
			hi = mid
		else:
			lo = mid
	apply.call(hi)


## Los toques sobre los botones no cuentan como giro.
func _is_over_buttons(pos: Vector2) -> bool:
	for button: Button in [restart_button, next_button]:
		if button.visible and button.get_global_rect().has_point(pos):
			return true
	return false


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


func _on_key_picked(color: String) -> void:
	status_label.text = "Llevas la llave %s" % Level.COLOR_NAMES[color]


func _on_door_opened(color: String) -> void:
	status_label.text = "Puerta %s abierta" % Level.COLOR_NAMES[color]


func _on_power_up_picked(power_up: PowerUp, stacks: int) -> void:
	status_label.text = power_up.describe(stacks)


func _on_power_up_ended(power_up: PowerUp) -> void:
	if not cube.is_finished:
		status_label.text = "%s perdida" % power_up.display_name


func _on_reached_goal() -> void:
	if current_level == Levels.count() - 1:
		status_label.text = "¡Has completado todos los niveles!"
		next_button.text = "Volver al nivel 1"
	else:
		status_label.text = "¡Nivel completado!"
		next_button.text = "Siguiente nivel →"
	next_button.visible = true
