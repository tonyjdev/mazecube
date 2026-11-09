extends Node3D
## Pantalla de juego: entrada, cámara, pausa y fin de nivel.
##
## El nivel que se juega lo indica GameState.current_level (se elige en el
## selector de niveles del menú).
##
## Sonidos (ver Sfx): vuelcos, rebotes, giros descartados, dash, pisotón,
## enemigos destruidos, llaves, puertas,
## muros, botones y barrotes, power ups, media vuelta, muerte, meta y botones
## de la interfaz.
##
## Vibración (si está activada en Opciones): al destruir un muro, al pulsar
## un botón, al morir el cubo y, muy suave, al descartarse un giro.
##
## Interfaz: número de nivel arriba a la izquierda, botón de pausa arriba a la
## derecha e indicaciones de giro abajo. La pausa oculta esa interfaz y
## muestra a la izquierda tres botones con iconos (Continuar, Reiniciar,
## Salir al selector de niveles); la cámara se aleja y se pone casi vertical,
## y arrastrando el dedo se recorre el mapa (ver FollowCamera.start_explore).
## Al continuar, la cámara vuelve a su sitio y después se reanuda el juego:
## la velocidad del juego (Engine.time_scale) sube de 0 a la normal en
## RESUME_RAMP_TIME segundos con una curva ease-in cúbica (empieza muy
## despacio y acelera).
##
## Inicio del nivel (al entrar o reiniciar): la pantalla funde a negro (al
## reiniciar; al entrar ya viene en negro de la pantalla de carga), aparece
## desde negro mientras el tablero aparece en diagonal (Level.start_reveal) y
## después aparece el cubo
## (RollingCube.appear); los enemigos no se mueven hasta que el cubo empieza
## a rodar.
## Al llegar a la meta se marca el nivel como completado y se muestra otro
## menú (Siguiente nivel, Repetir, Niveles).
##
## Controles:
##   Media vuelta: pulsar izquierda y derecha a la vez (con el otro lado aún
##   pulsado, o con menos de SIMULTANEOUS_WINDOW segundos de diferencia). La
##   primera pulsación ya ha pedido un giro, pero la media vuelta lo sustituye.
##   Al darla, la cámara tiembla y el móvil vibra.
##   Dash y pisotón: deslizar el dedo hacia arriba (dash) o hacia abajo
##   (pisotón), en cualquier lado de la pantalla. Para distinguir un toque de
##   un deslizamiento, el giro de un toque no se pide al apoyar el dedo sino
##   en cuanto se levanta o, si se deja apoyado sin moverlo, a los
##   TAP_COMMIT_TIME segundos. Si el dedo se mueve más de SWIPE_SLOP antes de
##   eso, se espera a ver si llega a deslizamiento (SWIPE_DISTANCE en vertical,
##   claramente más vertical que horizontal); si se levanta o pasa
##   SWIPE_MAX_TIME sin llegar, cuenta como toque. El dedo que desliza no
##   cuenta para la media vuelta.
##   Teclado: ←/A gira a la izquierda, →/D a la derecha, ↑/W dash, ↓/S pisotón, R reinicia,
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
## teclado), pero el tablero y el cubo se detienen en la pausa; la cámara
## solo se mueve en ella para explorar el mapa.

const HINT_IDLE_ALPHA := 0.45
## Pausa entre llegar a la meta y mostrar el menú de nivel completado.
const COMPLETE_MENU_DELAY := 0.5
## Diferencia máxima entre pulsar izquierda y derecha para que cuente como a
## la vez (media vuelta).
const SIMULTANEOUS_WINDOW := 0.15
## Toque frente a deslizamiento (ver Controles): distancias en fracción del
## alto de la pantalla y tiempos en segundos.
const TAP_COMMIT_TIME := 0.08
const SWIPE_SLOP := 0.02
const SWIPE_DISTANCE := 0.06
const SWIPE_MAX_TIME := 0.35
## Un deslizamiento debe ser al menos así de más vertical que horizontal.
const SWIPE_VERTICAL_RATIO := 1.5
## Tiempo que tarda el juego en recuperar su velocidad al salir de la pausa.
const RESUME_RAMP_TIME := 1.0
## Tiempo máximo que el cubo espera a la cámara para reaparecer tras morir.
const RESPAWN_CAMERA_WAIT := 3.0

var current_level := 0
var _hint_tweens := {}
## Por lado (TURN_LEFT / TURN_RIGHT): momento de la última pulsación
## (Time.get_ticks_msec) y si sigue pulsado (teclas o dedos).
var _side_pressed_at := {RollingCube.TURN_LEFT: -100000, RollingCube.TURN_RIGHT: -100000}
var _keys_held := {RollingCube.TURN_LEFT: false, RollingCube.TURN_RIGHT: false}
## Dedo (índice del toque) -> lado de la pantalla en que se apoyó (solo los
## que ya han contado como toque).
var _touches := {}
## Dedos apoyados que aún no se sabe si son un toque o un deslizamiento:
## índice -> { "side": int, "start": Vector2, "pos": Vector2, "time": int (ms) }
var _pending_touches := {}
## Arrastre del mapa en la pausa: si hay un dedo (o el ratón) pulsado y
## dónde estaba en el último movimiento.
var _dragging := false
var _drag_last := Vector2.ZERO
## Aceleración tras la pausa (anima Engine.time_scale).
var _speed_tween: Tween
## Cuenta de inicios del nivel: un reinicio cancela la secuencia anterior.
var _intro_id := 0
## Fundiendo a negro para reiniciar.
var _restarting := false

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
	# La cámara se procesa siempre (ver FollowCamera) para explorar en la pausa.
	for node: Node in [level, cube, $UI]:
		node.process_mode = Node.PROCESS_MODE_PAUSABLE

	cube.reached_goal.connect(_on_reached_goal)
	level.cube = cube
	cube.respawned.connect(_appear_after_camera)
	cube.died.connect(func(_cell: Vector2i) -> void:
		Sfx.play("explode")
		level.notify_cube_died()
		camera.shake()
		GameState.vibrate(GameState.VIBRATION_DEATH))
	cube.fell.connect(func(_cell: Vector2i) -> void:
		Sfx.play("fall")
		level.notify_cube_died()
		GameState.vibrate(GameState.VIBRATION_TURN_REJECTED))
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
	cube.dashed.connect(func(_from: Vector2i, _to: Vector2i) -> void:
		Sfx.play("dash", 0.08)
		GameState.vibrate(GameState.VIBRATION_DASH))
	cube.stomped.connect(func(_cell: Vector2i) -> void:
		Sfx.play("stomp", 0.05)
		camera.shake()
		GameState.vibrate(GameState.VIBRATION_STOMP))
	cube.bounced.connect(func(_cell: Vector2i) -> void: Sfx.play("bounce", 0.1))
	cube.landed.connect(func() -> void: Sfx.play("bounce", 0.1))
	cube.key_picked.connect(func(_color: String) -> void: Sfx.play("key"))
	cube.door_opened.connect(func(_color: String) -> void: Sfx.play("door"))
	cube.power_up_picked.connect(func(_power_up: PowerUp, _stacks: int) -> void:
		Sfx.play("powerup"))
	for button in find_children("*", "BaseButton", true, false):
		(button as BaseButton).pressed.connect(func() -> void: Sfx.play("click"))
	pause_button.pressed.connect(_set_paused.bind(true))
	%ContinueButton.pressed.connect(_set_paused.bind(false))
	%RestartButton.pressed.connect(func() -> void:
		# Sigue en pausa mientras la pantalla funde a negro.
		_close_pause_menu()
		_restart_with_fade())
	%DragArea.gui_input.connect(_on_drag_area_input)
	%QuitButton.pressed.connect(GameState.go_to_menu.bind("levels"))
	next_button.pressed.connect(_next_level)
	%RetryButton.pressed.connect(_restart_with_fade)
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
			if _pending_touches.has(touch.index):
				_pending_touches[touch.index]["pos"] = touch.position
				# Levantado sin llegar a deslizamiento: es un toque.
				if not _try_swipe(touch.index):
					var side: int = _pending_touches[touch.index]["side"]
					_pending_touches.erase(touch.index)
					_press_side(side)
		elif not _is_over_buttons(touch.position):
			var half := get_viewport().get_visible_rect().size.x * 0.5
			var side := RollingCube.TURN_LEFT if touch.position.x < half else RollingCube.TURN_RIGHT
			_pending_touches[touch.index] = {"side": side, "start": touch.position,
				"pos": touch.position, "time": Time.get_ticks_msec()}
			get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _pending_touches.has(drag.index):
			_pending_touches[drag.index]["pos"] = drag.position
			_try_swipe(drag.index)
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
	elif event.is_action_pressed("dash"):
		cube.request_dash()
	elif event.is_action_pressed("stomp"):
		cube.request_stomp()
	elif event.is_action_pressed("restart"):
		_restart_with_fade()
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


## Deslizamiento del dedo `index` (pendiente): si ya ha recorrido
## SWIPE_DISTANCE en vertical, pide el dash (arriba) o el pisotón (abajo),
## olvida el dedo y devuelve true.
func _try_swipe(index: int) -> bool:
	var info: Dictionary = _pending_touches[index]
	var moved: Vector2 = info["pos"] - info["start"]
	var height := get_viewport().get_visible_rect().size.y
	if absf(moved.y) < SWIPE_DISTANCE * height \
			or absf(moved.y) < absf(moved.x) * SWIPE_VERTICAL_RATIO:
		return false
	_pending_touches.erase(index)
	if moved.y < 0.0:
		cube.request_dash()
	else:
		cube.request_stomp()
	return true


## Dedos pendientes que ya cuentan como toque: los que siguen quietos
## pasados TAP_COMMIT_TIME y los que se han movido pero no han llegado a
## deslizamiento en SWIPE_MAX_TIME.
func _commit_pending_touches() -> void:
	var now := Time.get_ticks_msec()
	var height := get_viewport().get_visible_rect().size.y
	for index: int in _pending_touches.keys():
		var info: Dictionary = _pending_touches[index]
		var age := (now - int(info["time"])) / 1000.0
		var moved: Vector2 = info["pos"] - info["start"]
		var still := moved.length() < SWIPE_SLOP * height
		if (still and age >= TAP_COMMIT_TIME) or age >= SWIPE_MAX_TIME:
			_pending_touches.erase(index)
			_touches[index] = info["side"]
			_press_side(info["side"])


func _process(_delta: float) -> void:
	if not _pending_touches.is_empty() and not get_tree().paused:
		_commit_pending_touches()


func _clear_held_sides() -> void:
	_touches.clear()
	_pending_touches.clear()
	for side in _keys_held:
		_keys_held[side] = false
		_side_pressed_at[side] = -100000


func _is_side_held(side: int) -> bool:
	return _keys_held[side] or _touches.values().has(side)


func _toggle_pause() -> void:
	if complete_menu.visible:
		return
	_set_paused(not pause_menu.visible)


## Pausa: menú de pausa y cámara de exploración. Al reanudar, la cámara
## vuelve a su sitio con el juego aún en pausa y después se reanuda.
func _set_paused(paused: bool) -> void:
	if paused:
		if complete_menu.visible or pause_menu.visible or _restarting:
			return
		_stop_speed_ramp()
		get_tree().paused = true
		pause_menu.visible = true
		$UI.visible = false
		_dragging = false
		# En la pausa no llegan las sueltas de teclas y dedos.
		_clear_held_sides()
		camera.start_explore()
		_focus_first(pause_menu)
		return
	if not pause_menu.visible:
		return
	_close_pause_menu()
	camera.end_explore()
	await camera.explore_finished
	# Se ha vuelto a pausar mientras la cámara volvía.
	if pause_menu.visible or complete_menu.visible:
		return
	get_tree().paused = false
	_start_speed_ramp()


## La velocidad del juego sube de 0 a la normal (ease-in cúbica).
func _start_speed_ramp() -> void:
	_stop_speed_ramp()
	Engine.time_scale = 0.0
	_speed_tween = create_tween().set_ignore_time_scale(true)
	_speed_tween.tween_property(Engine, "time_scale", 1.0, RESUME_RAMP_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


func _stop_speed_ramp() -> void:
	if _speed_tween and _speed_tween.is_valid():
		_speed_tween.kill()
	_speed_tween = null
	Engine.time_scale = 1.0


func _exit_tree() -> void:
	# time_scale es global: no debe quedarse a medias al salir de la partida.
	_stop_speed_ramp()


func _close_pause_menu() -> void:
	pause_menu.visible = false
	$UI.visible = true
	_dragging = false
	_clear_held_sides()


## Arrastre del mapa en la pausa (los toques llegan también como clic).
func _on_drag_area_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT:
		_dragging = button.pressed
		_drag_last = button.position
		return
	var motion := event as InputEventMouseMotion
	if motion and _dragging:
		camera.explore_drag(_drag_last, motion.position)
		_drag_last = motion.position


## Reinicio con transición: el juego se detiene, la pantalla funde a negro,
## se reconstruye el nivel y vuelve a aparecer desde negro (ver _play_intro).
func _restart_with_fade() -> void:
	if _restarting or GameState.is_loading:
		return
	_restarting = true
	_stop_speed_ramp()
	get_tree().paused = true
	await GameState.fade_to_black()
	get_tree().paused = false
	_restarting = false
	_restart()


func _restart() -> void:
	# Reconstruir el tablero devuelve a su sitio llaves, puertas y muros.
	level.build()
	cube.reset(level)
	camera.snap()
	_clear_held_sides()
	complete_menu.visible = false
	pause_button.visible = true
	_stop_speed_ramp()
	_play_intro()


## Aparición del tablero y, después, la del cubo; al acabar, los enemigos
## empiezan a moverse. Un reinicio a mitad cancela la secuencia anterior.
func _play_intro() -> void:
	_intro_id += 1
	var id := _intro_id
	level.start_reveal()
	# Toda la pantalla aparece desde negro a la vez que el tablero (al entrar
	# desde la pantalla de carga, cuando esta ya se ha quitado).
	while GameState.is_loading:
		await get_tree().process_frame
	if id != _intro_id:
		return
	GameState.fade_from_black()
	await level.reveal_finished
	if id != _intro_id:
		return
	cube.appear()
	await cube.appeared
	if id != _intro_id:
		return
	level.set_enemies_frozen(false)


## Tras morir, el cubo espera oculto en la salida hasta que la cámara llega
## allí (como mucho RESPAWN_CAMERA_WAIT segundos de juego) y entonces aparece.
func _appear_after_camera() -> void:
	var id := _intro_id
	var waited := 0.0
	await get_tree().process_frame
	while not camera.is_settled() and waited < RESPAWN_CAMERA_WAIT:
		await get_tree().process_frame
		if id != _intro_id:
			return
		if not get_tree().paused:
			waited += get_process_delta_time()
	if id == _intro_id:
		cube.appear()


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
	if pause_menu.visible:
		camera.start_explore()


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
