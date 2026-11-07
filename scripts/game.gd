extends Node3D
## Pantalla de juego: entrada, cámara, pausa y fin de nivel.
##
## El nivel que se juega lo indica GameState.current_level (se elige en el
## selector de niveles del menú).
##
## Sonidos (ver Sfx): vuelcos, rebotes, giros descartados, llaves, puertas,
## muros, botones y barrotes, power ups, media vuelta, muerte, meta y botones
## de la interfaz.
##
## Vibración (si está activada en Opciones): al destruir un muro, al pulsar
## un botón, al morir el cubo y, muy suave, al descartarse un giro. La flecha sobre el cubo se puede ocultar
## en Opciones.
##
## Interfaz: número de nivel arriba a la izquierda, botón de pausa arriba a la
## derecha e indicaciones de giro abajo. La pausa muestra un menú (Continuar,
## Reiniciar, Salir al selector de niveles); al llegar a la meta se marca el
## nivel como completado y se muestra otro (Siguiente nivel, Repetir, Niveles).
##
## Controles:
##   Media vuelta: pulsar izquierda y derecha a la vez (con el otro lado aún
##   pulsado, o con menos de SIMULTANEOUS_WINDOW segundos de diferencia). La
##   primera pulsación ya ha pedido un giro, pero la media vuelta lo sustituye.
##   Al darla, la cámara tiembla y el móvil vibra.
##   Teclado: ←/A gira a la izquierda, →/D a la derecha, R reinicia,
##            Esc pausa o reanuda; al completar un nivel, Intro/N pasa al siguiente.
##   Táctil:  tocar la mitad izquierda o derecha de la pantalla gira hacia ese
##            lado (con dos dedos, uno en cada mitad, media vuelta). El botón Atrás de Android pausa o reanuda.
##   En PC, el clic del ratón se trata como un toque (emulate_touch_from_mouse).
##   Solo en builds de depuración: Re Pág / Av Pág cambian de nivel.
##
## Cámara: vista cenital inclinada en perspectiva. Si el tablero no cabe
## entero, sigue al cubo; ver FollowCamera. Cada nivel puede fijar su
## distancia de cámara con "camera_distance" (limitada al máximo).
##
## La raíz de la escena se procesa siempre (para poder reanudar con el
## teclado), pero el tablero, el cubo y la cámara se detienen en la pausa.

const HINT_IDLE_ALPHA := 0.45
## Pausa entre llegar a la meta y mostrar el menú de nivel completado.
const COMPLETE_MENU_DELAY := 0.5
## Diferencia máxima entre pulsar izquierda y derecha para que cuente como a
## la vez (media vuelta).
const SIMULTANEOUS_WINDOW := 0.15

var current_level := 0
var _hint_tweens := {}
## Por lado (TURN_LEFT / TURN_RIGHT): momento de la última pulsación
## (Time.get_ticks_msec) y si sigue pulsado (teclas o dedos).
var _side_pressed_at := {RollingCube.TURN_LEFT: -100000, RollingCube.TURN_RIGHT: -100000}
var _keys_held := {RollingCube.TURN_LEFT: false, RollingCube.TURN_RIGHT: false}
## Dedo (índice del toque) -> lado de la pantalla en que se apoyó.
var _touches := {}

@onready var level: Level = $Level
@onready var cube: RollingCube = $Cube
@onready var camera: FollowCamera = $Camera3D
@onready var level_label: Label = %LevelLabel
@onready var pause_button: Button = %PauseButton
## Hueco libre entre la barra superior y la inferior: ahí se encuadra el tablero.
@onready var play_area: Control = %PlayArea
@onready var left_hint: Label = %LeftHint
@onready var right_hint: Label = %RightHint
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var complete_menu: CanvasLayer = $CompleteMenu
@onready var complete_title: Label = %CompleteTitle
@onready var next_button: Button = %NextButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for node: Node in [level, cube, camera, $UI]:
		node.process_mode = Node.PROCESS_MODE_PAUSABLE

	cube.reached_goal.connect(_on_reached_goal)
	level.cube = cube
	cube.died.connect(func(_cell: Vector2i) -> void:
		Sfx.play("explode")
		level.notify_cube_died()
		camera.shake()
		GameState.vibrate(GameState.VIBRATION_DEATH))
	cube.fell.connect(func(_cell: Vector2i) -> void:
		Sfx.play("fall")
		level.notify_cube_died()
		GameState.vibrate(GameState.VIBRATION_TURN_REJECTED))
	cube.show_arrow = GameState.show_arrow
	cube.turn_rejected.connect(func(_dir: Vector2i) -> void:
		Sfx.play("reject")
		GameState.vibrate(GameState.VIBRATION_TURN_REJECTED))
	cube.breakable_hit.connect(func(_cell: Vector2i, hits_left: int) -> void:
		Sfx.play("crack" if hits_left > 0 else "break", 0.08)
		if hits_left == 0:
			GameState.vibrate(GameState.VIBRATION_WALL_BROKEN))
	cube.reversed.connect(func(_cell: Vector2i) -> void:
		Sfx.play("reverse")
		camera.shake()
		GameState.vibrate(GameState.VIBRATION_REVERSE))
	cube.button_pressed.connect(func(_cell: Vector2i) -> void:
		Sfx.play("button")
		Sfx.play("bars", 0.05)
		camera.notify_button_pressed()
		GameState.vibrate(GameState.VIBRATION_BUTTON))
	cube.rolled.connect(func(_cell: Vector2i) -> void: Sfx.play("roll", 0.12))
	cube.bounced.connect(func(_cell: Vector2i) -> void: Sfx.play("bounce", 0.1))
	cube.key_picked.connect(func(_color: String) -> void: Sfx.play("key"))
	cube.door_opened.connect(func(_color: String) -> void: Sfx.play("door"))
	cube.power_up_picked.connect(func(_power_up: PowerUp, _stacks: int) -> void:
		Sfx.play("powerup"))
	for button in find_children("*", "BaseButton", true, false):
		(button as BaseButton).pressed.connect(func() -> void: Sfx.play("click"))
	pause_button.pressed.connect(_set_paused.bind(true))
	%ContinueButton.pressed.connect(_set_paused.bind(false))
	%RestartButton.pressed.connect(func() -> void:
		_set_paused(false)
		_restart())
	%QuitButton.pressed.connect(GameState.go_to_menu.bind("levels"))
	next_button.pressed.connect(_next_level)
	%RetryButton.pressed.connect(_restart)
	%LevelsButton.pressed.connect(GameState.go_to_menu.bind("levels"))

	left_hint.modulate.a = HINT_IDLE_ALPHA
	right_hint.modulate.a = HINT_IDLE_ALPHA
	# El hueco libre cambia al rotar o redimensionar la pantalla.
	camera.setup(level, cube, play_area)
	play_area.resized.connect(_on_play_area_resized)
	_load_level(GameState.current_level)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_update_level_label()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and not GameState.is_loading:
		_toggle_pause()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("mobile") \
			and is_node_ready() and not cube.is_finished and not GameState.is_loading:
		# En el móvil, al salir de la aplicación (llamada, cambiar de app...) se pausa.
		_set_paused(true)


func _unhandled_input(event: InputEvent) -> void:
	# Mientras se ve la pantalla de carga, el juego no atiende a la entrada.
	if GameState.is_loading:
		return
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if get_tree().paused:
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			_touches.erase(touch.index)
		elif not _is_over_buttons(touch.position):
			var half := get_viewport().get_visible_rect().size.x * 0.5
			var side := RollingCube.TURN_LEFT if touch.position.x < half else RollingCube.TURN_RIGHT
			_touches[touch.index] = side
			_press_side(side)
			get_viewport().set_input_as_handled()
		return

	if event.is_action_released("turn_left"):
		_keys_held[RollingCube.TURN_LEFT] = false
	elif event.is_action_released("turn_right"):
		_keys_held[RollingCube.TURN_RIGHT] = false
	elif event.is_action_pressed("turn_left"):
		_keys_held[RollingCube.TURN_LEFT] = true
		_press_side(RollingCube.TURN_LEFT)
	elif event.is_action_pressed("turn_right"):
		_keys_held[RollingCube.TURN_RIGHT] = true
		_press_side(RollingCube.TURN_RIGHT)
	elif event.is_action_pressed("restart"):
		_restart()
	elif event.is_action_pressed("next_level") and complete_menu.visible:
		_next_level()
	elif OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_PAGEDOWN:
			_load_level(current_level + 1)
		elif event.keycode == KEY_PAGEUP:
			_load_level(current_level - 1)


## Pulsación de un lado: giro hacia ese lado o, si el otro lado sigue pulsado
## o se acaba de pulsar, media vuelta.
func _press_side(side: int) -> void:
	var other := -side
	var now := Time.get_ticks_msec()
	var simultaneous: bool = _is_side_held(other) \
		or now - int(_side_pressed_at[other]) <= int(SIMULTANEOUS_WINDOW * 1000.0)
	_side_pressed_at[side] = now
	if simultaneous:
		# Evita que una tercera pulsación cuente otra vez con la misma.
		_side_pressed_at[other] = -100000
		cube.request_reverse()
		_flash_hint(left_hint)
		_flash_hint(right_hint)
	else:
		cube.request_turn(side)
		_flash_hint(left_hint if side == RollingCube.TURN_LEFT else right_hint)


func _clear_held_sides() -> void:
	_touches.clear()
	for side in _keys_held:
		_keys_held[side] = false
		_side_pressed_at[side] = -100000


func _is_side_held(side: int) -> bool:
	return _keys_held[side] or _touches.values().has(side)


func _toggle_pause() -> void:
	if complete_menu.visible:
		return
	_set_paused(not get_tree().paused)


func _set_paused(paused: bool) -> void:
	if complete_menu.visible and paused:
		return
	get_tree().paused = paused
	pause_menu.visible = paused
	# En la pausa no llegan las sueltas de teclas y dedos.
	_clear_held_sides()
	if paused:
		_focus_first(pause_menu)


func _restart() -> void:
	# Reconstruir el tablero devuelve a su sitio llaves, puertas y muros.
	level.build()
	cube.reset(level)
	camera.snap()
	_clear_held_sides()
	complete_menu.visible = false
	pause_button.visible = true


func _load_level(index: int) -> void:
	current_level = clampi(index, 0, Levels.count() - 1)
	GameState.current_level = current_level
	var data := Levels.get_level(current_level)
	level.configure(data)
	_update_level_label()
	_restart()
	camera.frame_level(data.get("camera_distance", 0.0))


func _update_level_label() -> void:
	level_label.text = tr("HUD_LEVEL") % (current_level + 1)


func _next_level() -> void:
	if current_level >= Levels.count() - 1:
		GameState.go_to_menu("levels")
	else:
		GameState.play_level(current_level + 1)


func _on_reached_goal() -> void:
	Sfx.play("goal")
	GameState.mark_completed(current_level)
	pause_button.visible = false
	var last := current_level >= Levels.count() - 1
	complete_title.text = "COMPLETE_ALL" if last else "COMPLETE_TITLE"
	next_button.visible = not last
	await get_tree().create_timer(COMPLETE_MENU_DELAY).timeout
	if cube.is_finished:
		complete_menu.visible = true
		_focus_first(complete_menu)


func _on_play_area_resized() -> void:
	camera.refresh_layout()
	camera.snap()


## Los toques sobre los botones no cuentan como giro.
func _is_over_buttons(pos: Vector2) -> bool:
	return pause_button.visible and pause_button.get_global_rect().has_point(pos)


## Da el foco al primer botón visible para poder usar el teclado (no en el
## móvil, donde solo se vería el recuadro de foco).
func _focus_first(root: Node) -> void:
	if OS.has_feature("mobile"):
		return
	for node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button.is_visible_in_tree():
			button.grab_focus.call_deferred()
			return


## Resalta brevemente la indicación del lado pulsado.
func _flash_hint(hint: Label) -> void:
	if _hint_tweens.has(hint) and _hint_tweens[hint].is_valid():
		_hint_tweens[hint].kill()
	hint.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(hint, "modulate:a", HINT_IDLE_ALPHA, 0.35)
	_hint_tweens[hint] = tween
