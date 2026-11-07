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
## Cámara: vista cenital inclinada en perspectiva (decisión definitiva). Si el
## tablero no cabe entero, sigue al cubo; ver FollowCamera. Cada nivel puede
## fijar su distancia de cámara con "camera_distance" (limitada al máximo).

const HINT_IDLE_ALPHA := 0.45
const PROGRESS_PATH := "user://progress.cfg"

var current_level := 0
var _hint_tweens := {}

@onready var level: Level = $Level
@onready var cube: RollingCube = $Cube
@onready var camera: FollowCamera = $Camera3D
@onready var level_label: Label = %LevelLabel
@onready var status_label: Label = %Status
@onready var next_button: Button = %NextButton
## Hueco libre entre las columnas laterales: ahí se encuadra el tablero.
@onready var play_area: Control = %Spacer
@onready var restart_button: Button = %RestartButton
@onready var help_label: Label = %Help
@onready var left_hint: Label = %LeftHint
@onready var right_hint: Label = %RightHint


func _ready() -> void:
	cube.reached_goal.connect(_on_reached_goal)
	cube.key_picked.connect(_on_key_picked)
	cube.door_opened.connect(_on_door_opened)
	cube.breakable_hit.connect(_on_breakable_hit)
	cube.power_up_picked.connect(_on_power_up_picked)
	cube.power_up_ended.connect(_on_power_up_ended)
	restart_button.pressed.connect(_restart)
	next_button.pressed.connect(_next_level)
	left_hint.modulate.a = HINT_IDLE_ALPHA
	right_hint.modulate.a = HINT_IDLE_ALPHA
	if _is_touch_device():
		help_label.text = "Toca a la izquierda o a la derecha de la pantalla para girar"
	else:
		help_label.text = "←/A · →/D o clic a cada lado para girar\nR reiniciar"
	# El hueco libre cambia al rotar o redimensionar la pantalla.
	camera.setup(level, cube, play_area)
	play_area.resized.connect(_on_play_area_resized)
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
	camera.snap()
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
	camera.frame_level(data.get("camera_distance", 0.0))


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


func _on_play_area_resized() -> void:
	camera.refresh_layout()
	camera.snap()


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


## El estado del muro solo se muestra con sus grietas; aquí se avisa al romperlo.
func _on_breakable_hit(_cell: Vector2i, hits_left: int) -> void:
	if hits_left == 0:
		status_label.text = "¡Muro destruido!"


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
