extends Node3D
## Pantalla de juego: entrada, cámara, pausa y fin de nivel.
##
## El nivel que se juega lo indica GameState.current_level (se elige en el
## selector de niveles del menú).
##
## Sonidos (ver Sfx): vuelcos, rebotes, giros descartados, dash, pisotón,
## monedas, cofres, casillas de inicio,
## inmunidad (chispazo al activarla y zumbido en bucle mientras dura),
## enemigos destruidos, llaves, puertas,
## muros, botones y barrotes, power ups, media vuelta, muerte, meta y botones
## de la interfaz.
##
## Música (ver Music): el tema de la zona del nivel; se amortigua en la pausa
## y al completar el nivel.
##
## Vibración (si está activada en Opciones): al destruir un muro, al pulsar
## un botón, al morir el cubo y, muy suave, al descartarse un giro.
##
## Interfaz: número de nivel arriba a la izquierda, botón de pausa arriba a la
## derecha e indicaciones de giro abajo, con la barra de fuerza entre ellas. La pausa oculta esa interfaz y
## muestra a la izquierda cuatro botones con iconos (Continuar, Enciclopedia,
## Reiniciar, Salir al selector de niveles) y el mapa 2D del nivel sobre la
## partida congelada en una imagen (ver PauseMap; mientras tanto no se dibuja
## el 3D). El botón de la enciclopedia la muestra en lugar del mapa (ver
## Encyclopedia); mientras se ve, los botones de la pausa se esconden y Atrás
## o Esc la cierran (sin salir de la pausa). Al continuar se reanuda el
## juego: la velocidad del juego (Engine.time_scale) sube de 0 a la normal en
## RESUME_RAMP_TIME segundos con una curva ease-in cúbica (empieza muy
## despacio y acelera).
##
## Inicio del nivel (al entrar o reiniciar): la pantalla funde a negro (al
## reiniciar; al entrar ya viene en negro de la pantalla de carga), aparece
## desde negro mientras el tablero aparece en diagonal (Level.start_reveal) y
## después aparece el cubo
## (RollingCube.appear); los enemigos no se mueven hasta que el cubo empieza
## a rodar.
## Estrellas: cada partida tiene tres retos, una estrella por cada uno: no
## morir, usar «star_turns» giros o menos (cuentan los giros aplicados y la
## media vuelta, que vale REVERSE_TURNS; no los descartados ni los rebotes) y coger el cubito
## dorado. Arriba, junto al número de nivel, se ve cómo van: el corazón se
## apaga al morir, los giros («12/20») se ponen rojos al pasarse y el cubito
## se enciende al cogerlo. Reiniciar o repetir empieza la cuenta de cero.
## Al llegar a la meta se guarda el resultado (GameState.record_result: solo
## cuenta la mejor partida) y se muestra la pantalla de nivel completado: las
## tres estrellas aparecen una a una con su reto debajo y los botones Niveles,
## Repetir y Siguiente nivel (que pasa por la pantalla de carga). Para seguir
## hace falta alguna estrella, en esta partida o en una anterior del nivel
## (que el siguiente esté desbloqueado); si no, se avisa.
##
## Monedas (ver Abilities y GameState.coins): las que coge el cubo del suelo
## (salen de los enemigos destruidos y de los cofres, ver Level) se suman al
## momento; arriba, junto a los retos, se ve cuántas se tienen. Al llegar a
## la meta, la recompensa del nivel (Abilities.reward_for_run: 10 más una por
## giro sobrante respecto al reto de giros) se cobra si supera la mejor del
## nivel, y solo la diferencia (GameState.record_reward); la pantalla de
## nivel completado lo cuenta después de las estrellas. Los cofres abiertos
## se apuntan al momento (GameState.open_chest) y no vuelven a salir.
##
## Tienda (ver Shop): al chocar con la tienda del nivel (ver ShopBuilding) el
## juego se detiene y se abre la tienda encima; al salir, se reanuda como
## tras la pausa. Habilidades (ver Abilities): solo girar está siempre
## disponible. Pedir una bloqueada (media vuelta, dash, pisotón o inmunidad)
## no hace nada salvo avisar (sonido de descarte y un letrero abajo); sin
## media vuelta, tocar los dos lados a la vez son dos giros normales. Sin
## dash, pisotón ni inmunidad no se ve la barra de fuerza. Las mejoras
## compradas se aplican al cubo (radio del pisotón, duración de la
## inmunidad, recarga de la fuerza, alcance del imán) al empezar el nivel y
## al salir de la tienda.
##
## Controles:
##   Media vuelta: pulsar izquierda y derecha a la vez (con el otro lado aún
##   pulsado, o con menos de SIMULTANEOUS_WINDOW segundos de diferencia). La
##   primera pulsación ya ha pedido un giro, pero la media vuelta lo sustituye.
##   Al darla, la cámara tiembla y el móvil vibra.
##   Dash, pisotón e inmunidad: deslizar el dedo hacia arriba (dash), hacia
##   abajo (pisotón) o hacia un lado, da igual cuál (inmunidad), en cualquier
##   lado de la pantalla. Un deslizamiento recorre SWIPE_DISTANCE en vertical
##   o en horizontal (claramente más en esa dirección que en la otra:
##   SWIPE_DIRECTION_RATIO) en SWIPE_MAX_TIME segundos o menos desde que se
##   apoya el dedo.
##   Un deslizamiento nunca gira el cubo:
##   - El giro de un toque no se pide al apoyar el dedo sino al levantarlo
##     o, si se deja apoyado sin moverlo (menos de SWIPE_SLOP), a los
##     TAP_COMMIT_TIME segundos.
##   - Si ese dedo apoyado acaba deslizando, el giro que pidió se anula
##     (RollingCube.cancel_turn), a no ser que el cubo ya lo haya hecho.
##   - Un dedo que se mueve (más de SWIPE_SLOP) sin llegar a deslizamiento no
##     cuenta como toque: no hace nada.
##   - Sin fuerza, el deslizamiento se descarta (aviso y la barra de fuerza
##     tiembla), pero el giro también se anula.
##   El dedo que desliza no cuenta para la media vuelta.
##   Fuerza: la barra del centro de la parte inferior (StrengthBar) muestra la
##   fuerza del cubo (RollingCube.strength) y, mientras dura la inmunidad, el
##   tiempo que le queda.
##   Teclado: ←/A gira a la izquierda, →/D a la derecha, ↑/W dash, ↓/S pisotón,
##            Espacio/E inmunidad, R reinicia,
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
## Pantalla de nivel completado: espera antes de la primera estrella y entre
## una y otra, y tono de la campanada de cada estrella conseguida.
const STAR_FIRST_DELAY := 0.35
const STAR_INTERVAL := 0.4
const STAR_PITCHES := [1.0, 1.12, 1.26]
## Giros que cuenta una media vuelta para la estrella de giros.
const REVERSE_TURNS := 2
## Iconos del HUD de los retos: apagados (corazón tras morir, cubito sin coger).
const STAT_OFF := Color(0.45, 0.42, 0.4, 0.55)
const TURNS_OVER_COLOR := Color(1.0, 0.45, 0.4)
## Diferencia máxima entre pulsar izquierda y derecha para que cuente como a
## la vez (media vuelta).
const SIMULTANEOUS_WINDOW := 0.15
## Toque frente a deslizamiento (ver Controles): distancias en fracción del
## alto de la pantalla y tiempos en segundos.
const TAP_COMMIT_TIME := 0.08
const SWIPE_SLOP := 0.02
const SWIPE_DISTANCE := 0.06
const SWIPE_MAX_TIME := 0.5
## Un deslizamiento debe ser al menos así de más vertical que horizontal (o
## al revés).
const SWIPE_DIRECTION_RATIO := 1.5
## Margen (en píxeles) alrededor del botón del mapa que también lo pulsa (el
## botón mide 80; con el margen se puede tocar hasta el borde de la pantalla).
const PAUSE_HIT_MARGIN := 36.0
## Tiempo que tarda el juego en recuperar su velocidad al salir de la pausa.
const RESUME_RAMP_TIME := 1.0
## Tiempo máximo que el cubo espera a la cámara para reaparecer tras morir.
const RESPAWN_CAMERA_WAIT := 3.0
## Distancia (en casillas) del cubo a una bomba que explota a partir de la cual
## no tiembla la cámara.
const BOMB_SHAKE_DISTANCE := 4.0
## Aviso de habilidad bloqueada: segundos que se ve entero y lo que tarda en irse.
const LOCKED_TOAST_TIME := 1.6
const LOCKED_TOAST_FADE := 0.4
## Zumbido de la inmunidad: volumen (dB) y lo que tarda en apagarse al acabar.
const IMMUNITY_HUM_DB := -9.0
const IMMUNITY_HUM_FADE := 0.25

var current_level := 0
var _hint_tweens := {}
var _encyclopedia: Encyclopedia
## Por lado (TURN_LEFT / TURN_RIGHT): momento de la última pulsación
## (Time.get_ticks_msec) y si sigue pulsado (teclas o dedos).
var _side_pressed_at := {RollingCube.TURN_LEFT: -100000, RollingCube.TURN_RIGHT: -100000}
var _keys_held := {RollingCube.TURN_LEFT: false, RollingCube.TURN_RIGHT: false}
## Dedo (índice del toque) -> lado de la pantalla en que se apoyó (solo los
## que ya han contado como toque y siguen apoyados).
var _touches := {}
## Dedos apoyados: índice -> { "side": int, "start": Vector2, "pos": Vector2,
## "time": int (ms), "committed": bool (ya ha pedido su giro), "done": bool
## (ya ha deslizado o se ha descartado: no hace nada más) }.
var _gestures := {}
## Mapa 2D de la pausa (ver PauseMap) e imagen congelada de la partida que
## se ve detrás (mientras tanto no se dibuja el 3D).
var _map: PauseMap
var _snapshot: TextureRect
## Esperando el fotograma sin interfaz para congelar la partida (ver _set_paused).
var _pausing := false
## Casilla del cubo la última vez que se apuntó lo explorado alrededor (para
## el mapa de la pausa, ver _mark_seen).
var _seen_cell := Level.NO_CELL
## Aceleración tras la pausa (anima Engine.time_scale).
var _speed_tween: Tween
## Cuenta de inicios del nivel: un reinicio cancela la secuencia anterior.
var _intro_id := 0
## Fundiendo a negro para reiniciar.
var _restarting := false
## Partida en curso (para las estrellas): giros aplicados, muertes y cubito.
var _run_turns := 0
var _run_deaths := 0
var _run_collected := false
## Monedas cogidas en la partida.
var _run_coins := 0
## Tienda (ver Shop), en su propia capa, y aviso de habilidad bloqueada.
var _shop: Shop
var _locked_toast: Label
var _toast_tween: Tween
## Pantalla de nivel completado: recompensa de la partida y lo ganado.
var _reward_label: Label
var _reward_gained_label: Label
## Monedas que se tienen (arriba, junto a los retos).
var _coins_label: Label
var _coins_icon: TextureRect
var _star_turns := 0
var _stars_tween: Tween
## Zumbido en bucle de la inmunidad (se detiene con la pausa) y su desvanecido.
var _immunity_hum: AudioStreamPlayer
var _hum_tween: Tween

@onready var level: Level = $Level
@onready var cube: RollingCube = $Cube
@onready var camera: FollowCamera = $Camera3D
@onready var level_label: Label = %LevelLabel
@onready var pause_button: Button = %PauseButton
## Hueco libre entre la barra superior y la inferior: ahí se encuadra el tablero.
@onready var play_area: Control = %PlayArea
@onready var left_hint: Label = %LeftHint
@onready var right_hint: Label = %RightHint
@onready var strength_bar: StrengthBar = %StrengthBar
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var complete_menu: CanvasLayer = $CompleteMenu
@onready var complete_title: Label = %CompleteTitle
@onready var next_button: Button = %NextButton
@onready var turns_label: Label = %TurnsLabel
@onready var life_icon: TextureRect = %LifeIcon
@onready var gold_icon: TextureRect = %GoldIcon
@onready var star_icons: Array[StarIcon] = [%Star1, %Star2, %Star3]
@onready var star_labels: Array[Label] = [%StarLabel1, %StarLabel2, %StarLabel3]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.setup_environment($WorldEnvironment.environment, $Sun)
	# Pausa: imagen congelada de la partida y, encima, el mapa 2D (antes de los
	# botones de la pausa, que quedan por encima). Se crean antes de conectar
	# el sonido de los botones para que los del mapa también lo tengan.
	_snapshot = TextureRect.new()
	_snapshot.set_anchors_preset(Control.PRESET_FULL_RECT)
	_snapshot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_snapshot.stretch_mode = TextureRect.STRETCH_SCALE
	_snapshot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_snapshot.visible = false
	pause_menu.add_child(_snapshot)
	pause_menu.move_child(_snapshot, 0)
	_map = PauseMap.new()
	pause_menu.add_child(_map)
	pause_menu.move_child(_map, 1)
	# La cámara se procesa siempre (ver FollowCamera) para explorar en la pausa.
	for node: Node in [level, cube, $UI]:
		node.process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_reward_labels()
	_build_coins_badge()
	_build_locked_toast()

	cube.reached_goal.connect(_on_reached_goal)
	level.cube = cube
	level.bomb_exploded.connect(func(distance: float) -> void:
		# Las explosiones cercanas al cubo hacen temblar la cámara y el móvil.
		if distance <= BOMB_SHAKE_DISTANCE:
			camera.shake()
			GameState.vibrate(GameState.VIBRATION_BOMB))
	cube.respawned.connect(_appear_after_camera)
	cube.died.connect(func(_cell: Vector2i) -> void:
		_add_death()
		Sfx.play("explode")
		level.notify_cube_died()
		camera.shake()
		GameState.vibrate(GameState.VIBRATION_DEATH))
	cube.fell.connect(func(_cell: Vector2i) -> void:
		_add_death()
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
		_run_turns += REVERSE_TURNS
		_update_stats()
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
	cube.strength_rejected.connect(func() -> void:
		Sfx.play("reject")
		strength_bar.reject()
		GameState.vibrate(GameState.VIBRATION_TURN_REJECTED))
	cube.stomped.connect(func(_cell: Vector2i) -> void:
		Sfx.play("stomp", 0.05)
		camera.shake()
		GameState.vibrate(GameState.VIBRATION_STOMP))
	cube.teleport_started.connect(func(_from: Vector2i, _to: Vector2i) -> void:
		Sfx.play("teleport")
		GameState.vibrate(GameState.VIBRATION_TELEPORT))
	cube.teleport_travel.connect(func(_to: Vector2i, duration: float) -> void:
		camera.travel(duration))
	cube.teleport_arrived.connect(func(_cell: Vector2i) -> void: Sfx.play("teleport_in"))
	cube.bounced.connect(func(_cell: Vector2i) -> void: Sfx.play("bounce", 0.1))
	cube.landed.connect(func() -> void: Sfx.play("bounce", 0.1))
	cube.key_picked.connect(func(_color: String) -> void: Sfx.play("key"))
	cube.turn_applied.connect(func(_dir: Vector2i) -> void:
		_run_turns += 1
		_update_stats())
	cube.collectible_picked.connect(func() -> void:
		_run_collected = true
		Sfx.play("collect")
		GameState.vibrate(GameState.VIBRATION_BUTTON)
		_pop_stat(gold_icon)
		_update_stats())
	cube.door_opened.connect(func(_color: String) -> void: Sfx.play("door"))
	cube.immunity_started.connect(func(_duration: float) -> void:
		Sfx.play("immunity")
		GameState.vibrate(GameState.VIBRATION_DASH)
		_start_immunity_hum())
	cube.immunity_ended.connect(_stop_immunity_hum)
	cube.shop_reached.connect(func(_cell: Vector2i) -> void: _open_shop())
	level.coins_collected.connect(func(amount: int) -> void:
		GameState.add_coins(amount)
		_run_coins += amount
		Sfx.play("coin", 0.08)
		_update_coins(true))
	level.chest_opened.connect(func(cell: Vector2i) -> void:
		GameState.open_chest(current_level, cell)
		Sfx.play("chest", 0.05)
		GameState.vibrate(GameState.VIBRATION_BUTTON))
	level.checkpoint_activated.connect(func(_cell: Vector2i) -> void:
		Sfx.play("checkpoint")
		GameState.vibrate(GameState.VIBRATION_BUTTON))
	cube.power_up_picked.connect(func(_power_up: PowerUp, _stacks: int) -> void:
		Sfx.play("powerup"))
	for button in find_children("*", "BaseButton", true, false):
		(button as BaseButton).pressed.connect(func() -> void: Sfx.play("click"))
	_setup_immunity_hum()
	# La enciclopedia pone sus propios sonidos (después de lo de arriba).
	_encyclopedia = Encyclopedia.new()
	pause_menu.add_child(_encyclopedia)
	_encyclopedia.closed.connect(_on_encyclopedia_closed)
	%EncyclopediaButton.pressed.connect(_toggle_encyclopedia)
	# La tienda pone sus propios sonidos (después de lo de arriba), en una capa
	# por encima de la partida.
	var shop_layer := CanvasLayer.new()
	shop_layer.layer = 9
	shop_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(shop_layer)
	_shop = Shop.new()
	shop_layer.add_child(_shop)
	_shop.closed.connect(_on_shop_closed)
	pause_button.pressed.connect(_set_paused.bind(true))
	%ContinueButton.pressed.connect(_set_paused.bind(false))
	%RestartButton.pressed.connect(func() -> void:
		# Sigue en pausa mientras la pantalla funde a negro.
		_close_pause_menu()
		_restart_with_fade())
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
		_update_stats()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and not GameState.is_loading:
		if _encyclopedia.is_open():
			_encyclopedia.close()
		elif _shop.is_open():
			_shop.close()
		else:
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
			if _gestures.has(touch.index):
				var info: Dictionary = _gestures[touch.index]
				info["pos"] = touch.position
				_try_swipe(touch.index)
				# Levantado sin deslizar ni moverse en vertical: es un toque.
				if not info["committed"] and not info["done"] and not _is_swipe_attempt(info):
					_press_side(info["side"])
				_gestures.erase(touch.index)
		elif _is_near_pause_button(touch.position):
			# Margen alrededor del botón del mapa: abre la pausa como el botón.
			pause_button.pressed.emit()
			get_viewport().set_input_as_handled()
		elif not _is_over_buttons(touch.position):
			var half := get_viewport().get_visible_rect().size.x * 0.5
			var side := RollingCube.TURN_LEFT if touch.position.x < half else RollingCube.TURN_RIGHT
			_gestures[touch.index] = {"side": side, "start": touch.position,
				"pos": touch.position, "time": Time.get_ticks_msec(),
				"committed": false, "done": false}
			get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _gestures.has(drag.index):
			_gestures[drag.index]["pos"] = drag.position
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
		_request_ability(Abilities.DASH)
	elif event.is_action_pressed("stomp"):
		_request_ability(Abilities.STOMP)
	elif event.is_action_pressed("immunity"):
		_request_ability(Abilities.IMMUNITY)
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
	# Sin la media vuelta comprada, son dos giros normales.
	if simultaneous and GameState.has_ability(Abilities.REVERSE):
		# Evita que una tercera pulsación cuente otra vez con la misma.
		_side_pressed_at[other] = -100000
		cube.request_reverse()
		_flash_hint(left_hint)
		_flash_hint(right_hint)
	else:
		cube.request_turn(side)
		_flash_hint(left_hint if side == RollingCube.TURN_LEFT else right_hint)


## Deslizamiento del dedo `index`: si en SWIPE_MAX_TIME o menos ha recorrido
## SWIPE_DISTANCE en vertical o en horizontal, anula el giro que hubiera
## pedido ese dedo, pide el dash (arriba), el pisotón (abajo) o la inmunidad
## (a un lado, cualquiera) y el dedo ya no hace nada más.
## Devuelve true si ha deslizado.
func _try_swipe(index: int) -> bool:
	var info: Dictionary = _gestures[index]
	if info["done"] or _gesture_age(info) > SWIPE_MAX_TIME:
		return false
	var moved: Vector2 = info["pos"] - info["start"]
	var distance := SWIPE_DISTANCE * get_viewport().get_visible_rect().size.y
	var vertical := absf(moved.y) >= distance and absf(moved.y) >= absf(moved.x) * SWIPE_DIRECTION_RATIO
	var sideways := absf(moved.x) >= distance and absf(moved.x) >= absf(moved.y) * SWIPE_DIRECTION_RATIO
	if not vertical and not sideways:
		return false
	info["done"] = true
	if info["committed"]:
		cube.cancel_turn()
		_touches.erase(index)
	if sideways:
		_request_ability(Abilities.IMMUNITY)
	elif moved.y < 0.0:
		_request_ability(Abilities.DASH)
	else:
		_request_ability(Abilities.STOMP)
	return true


## Pide el dash, el pisotón o la inmunidad, si se tiene; si no, avisa.
func _request_ability(id: String) -> void:
	if not GameState.has_ability(id):
		_show_locked_toast()
		return
	match id:
		Abilities.DASH:
			cube.request_dash()
		Abilities.STOMP:
			cube.request_stomp()
		Abilities.IMMUNITY:
			cube.request_immunity()


func _show_locked_toast() -> void:
	Sfx.play("reject")
	GameState.vibrate(GameState.VIBRATION_TURN_REJECTED)
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_locked_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(LOCKED_TOAST_TIME)
	_toast_tween.tween_property(_locked_toast, "modulate:a", 0.0, LOCKED_TOAST_FADE)


## Letrero de habilidad bloqueada, abajo en el centro (sobre la barra de fuerza).
func _build_locked_toast() -> void:
	_locked_toast = Label.new()
	_locked_toast.text = "ABILITY_LOCKED"
	_locked_toast.add_theme_font_size_override("font_size", 28)
	_locked_toast.add_theme_constant_override("outline_size", 10)
	_locked_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_locked_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_locked_toast.anchor_left = 0.0
	_locked_toast.anchor_right = 1.0
	_locked_toast.anchor_top = 1.0
	_locked_toast.anchor_bottom = 1.0
	_locked_toast.offset_top = -150.0
	_locked_toast.offset_bottom = -110.0
	_locked_toast.modulate.a = 0.0
	$UI.add_child(_locked_toast)


## Textos de las monedas en la pantalla de nivel completado, bajo las estrellas.
func _build_reward_labels() -> void:
	var stars: Control = $CompleteMenu/Center/Panel/VBox/Stars
	_reward_label = Label.new()
	_reward_label.add_theme_font_size_override("font_size", 26)
	_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_gained_label = Label.new()
	_reward_gained_label.add_theme_font_size_override("font_size", 24)
	_reward_gained_label.add_theme_color_override("font_color", Shop.GOLD)
	_reward_gained_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var box := stars.get_parent()
	box.add_child(_reward_label)
	box.move_child(_reward_label, stars.get_index() + 1)
	box.add_child(_reward_gained_label)
	box.move_child(_reward_gained_label, _reward_label.get_index() + 1)


## Marcador de las monedas que se tienen, junto al de los retos.
func _build_coins_badge() -> void:
	var stats_badge: Control = $UI/Margin/VBox/TopBar/StatsBadge
	var badge := PanelContainer.new()
	badge.theme_type_variation = &"HudBadge"
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(row)
	_coins_icon = TextureRect.new()
	_coins_icon.texture = load("res://ui/hud_coin.svg")
	_coins_icon.custom_minimum_size = Vector2(32, 32)
	_coins_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_coins_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_coins_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_coins_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_coins_icon)
	_coins_label = Label.new()
	_coins_label.add_theme_font_size_override("font_size", 28)
	_coins_label.add_theme_color_override("font_color", Shop.GOLD)
	_coins_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_coins_label)
	stats_badge.add_sibling(badge)


## Monedas que se tienen en el marcador; con `pop`, el icono da un salto.
func _update_coins(pop := false) -> void:
	_coins_label.text = str(GameState.coins())
	if pop:
		_pop_stat(_coins_icon)


## Aplica al cubo las mejoras compradas y enseña la barra de fuerza solo si
## hay alguna habilidad que la gaste.
func _apply_abilities() -> void:
	if GameState.has_ability(Abilities.STOMP):
		cube.stomp_radius = GameState.ability_value(Abilities.STOMP)
	if GameState.has_ability(Abilities.IMMUNITY):
		cube.immunity_time = GameState.ability_value(Abilities.IMMUNITY)
	cube.strength_recharge_time = GameState.ability_value(Abilities.RECHARGE)
	cube.magnet_radius = GameState.ability_value(Abilities.MAGNET)
	var uses_strength := false
	for id: String in [Abilities.DASH, Abilities.STOMP, Abilities.IMMUNITY]:
		uses_strength = uses_strength or GameState.has_ability(id)
	strength_bar.modulate.a = 1.0 if uses_strength else 0.0


## La tienda: el juego se detiene (como en la pausa, pero sin el menú).
func _open_shop() -> void:
	if _shop.is_open() or complete_menu.visible or pause_menu.visible or _restarting \
			or _pausing or GameState.is_loading:
		return
	_stop_speed_ramp()
	get_tree().paused = true
	Music.set_muffled(true)
	$UI.visible = false
	_clear_held_sides()
	_shop.open()


func _on_shop_closed() -> void:
	_apply_abilities()
	_update_coins()
	$UI.visible = true
	_clear_held_sides()
	Music.set_muffled(false)
	get_tree().paused = false
	_start_speed_ramp()


## El dedo se ha movido más de SWIPE_SLOP: intenta deslizar, así que no debe
## contar como toque.
func _is_swipe_attempt(info: Dictionary) -> bool:
	var moved: Vector2 = info["pos"] - info["start"]
	return moved.length() >= SWIPE_SLOP * get_viewport().get_visible_rect().size.y


func _gesture_age(info: Dictionary) -> float:
	return (Time.get_ticks_msec() - int(info["time"])) / 1000.0


## Dedos apoyados que ya cuentan como toque (piden su giro): los que siguen
## quietos pasados TAP_COMMIT_TIME. Los que se han movido sin llegar a
## deslizamiento en SWIPE_MAX_TIME se descartan.
func _update_gestures() -> void:
	var height := get_viewport().get_visible_rect().size.y
	for index: int in _gestures.keys():
		var info: Dictionary = _gestures[index]
		if info["committed"] or info["done"]:
			continue
		var age := _gesture_age(info)
		var moved: Vector2 = info["pos"] - info["start"]
		var still := moved.length() < SWIPE_SLOP * height
		if age >= SWIPE_MAX_TIME and _is_swipe_attempt(info):
			info["done"] = true
		elif (still and age >= TAP_COMMIT_TIME) or age >= SWIPE_MAX_TIME:
			info["committed"] = true
			_touches[index] = info["side"]
			_press_side(info["side"])


func _process(_delta: float) -> void:
	if not get_tree().paused:
		_mark_seen()
	strength_bar.value = cube.strength()
	strength_bar.immunity = cube.immunity_left() / maxf(cube.immunity_time, 0.001)
	if not _gestures.is_empty() and not get_tree().paused:
		_update_gestures()


func _clear_held_sides() -> void:
	_touches.clear()
	_gestures.clear()
	for side in _keys_held:
		_keys_held[side] = false
		_side_pressed_at[side] = -100000


func _is_side_held(side: int) -> bool:
	return _keys_held[side] or _touches.values().has(side)


func _toggle_pause() -> void:
	if complete_menu.visible or _shop.is_open():
		return
	_set_paused(not pause_menu.visible)


## Pausa: menú de pausa con el mapa 2D encima de la partida congelada. Al
## reanudar, la partida sigue con la aceleración de _start_speed_ramp.
func _set_paused(paused: bool) -> void:
	if paused:
		if complete_menu.visible or pause_menu.visible or _restarting or _pausing \
				or _shop.is_open():
			return
		_stop_speed_ramp()
		get_tree().paused = true
		Music.set_muffled(true)
		$UI.visible = false
		# En la pausa no llegan las sueltas de teclas y dedos.
		_clear_held_sides()
		# Un fotograma sin la interfaz para congelar la partida en una imagen.
		_pausing = true
		await RenderingServer.frame_post_draw
		_pausing = false
		if not is_inside_tree() or not get_tree().paused or _restarting or complete_menu.visible:
			return
		_freeze_backdrop()
		pause_menu.visible = true
		_mark_seen()
		_map.open(level, cube.cell)
		_focus_first(pause_menu)
		return
	if not pause_menu.visible:
		return
	_close_pause_menu()
	Music.set_muffled(false)
	get_tree().paused = false
	_start_speed_ramp()


## Apunta como explorado lo que rodea al cubo (si ha cambiado de casilla
## desde la última vez).
func _mark_seen() -> void:
	if cube.cell == _seen_cell:
		return
	_seen_cell = cube.cell
	level.mark_seen_around(cube.cell)


## Detrás del mapa se ve la partida tal como estaba, en una imagen: mientras
## dura la pausa no se dibuja el 3D (la GPU casi no trabaja).
func _freeze_backdrop() -> void:
	var image := get_viewport().get_texture().get_image()
	if image == null:
		return
	_snapshot.texture = ImageTexture.create_from_image(image)
	_snapshot.visible = true
	get_viewport().disable_3d = true


func _unfreeze_backdrop() -> void:
	get_viewport().disable_3d = false
	_snapshot.visible = false
	_snapshot.texture = null


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
	# Igual que el 3D del viewport principal (apagado en la pausa).
	get_viewport().disable_3d = false


## Muestra u oculta la enciclopedia en lugar del mapa (en la pausa).
func _toggle_encyclopedia() -> void:
	if _encyclopedia.is_open():
		_encyclopedia.close()
		return
	%Buttons.visible = false
	%ExploreHint.visible = false
	_map.visible = false
	_encyclopedia.open()


func _on_encyclopedia_closed() -> void:
	%Buttons.visible = true
	%ExploreHint.visible = true
	_map.visible = true
	_focus_first(pause_menu)


func _close_pause_menu() -> void:
	if _encyclopedia.is_open():
		_encyclopedia.close()
	pause_menu.visible = false
	_map.close()
	_unfreeze_backdrop()
	$UI.visible = true
	_clear_held_sides()


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
	# Reconstruir el tablero devuelve a su sitio llaves, puertas y muros (los
	# cofres ya abiertos no vuelven).
	level.opened_chests = GameState.opened_chests(current_level)
	level.build()
	cube.reset(level)
	camera.snap()
	# El nivel ha olvidado lo explorado: se vuelve a apuntar aunque el cubo
	# siga en la misma casilla.
	_seen_cell = Level.NO_CELL
	_clear_held_sides()
	complete_menu.visible = false
	pause_button.visible = true
	_stop_speed_ramp()
	Music.set_muffled(false)
	_run_turns = 0
	_run_deaths = 0
	_run_collected = false
	_run_coins = 0
	_apply_abilities()
	_update_stats()
	_update_coins()
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
	_star_turns = Levels.star_turns(current_level)
	Music.play(Music.track_for_level(current_level))
	_update_level_label()
	_restart()
	camera.frame_level(data.get("camera_distance", 0.0))


func _update_level_label() -> void:
	level_label.text = tr("HUD_LEVEL") % (current_level + 1)


func _next_level() -> void:
	if not _can_continue():
		return
	if current_level >= Levels.count() - 1:
		GameState.go_to_menu("levels")
	else:
		GameState.play_level(current_level + 1)


func _on_reached_goal() -> void:
	Sfx.play("goal")
	Music.set_muffled(true)
	var stars := [_run_deaths == 0, _run_turns <= _star_turns,
		_run_collected or not level.has_collectible()]
	var record := GameState.record_result(current_level, stars)
	var reward := Abilities.reward_for_run(_run_turns, _star_turns)
	var gained := GameState.record_reward(current_level, reward["total"])
	_update_coins(gained > 0)
	pause_button.visible = false
	await get_tree().create_timer(COMPLETE_MENU_DELAY).timeout
	if cube.is_finished:
		_show_complete_menu(stars, record, reward, gained)


## Pantalla de nivel completado: las estrellas aparecen una a una (con su
## campanada, o un golpe apagado si no se ha conseguido) y luego el aviso de
## récord.
func _show_complete_menu(stars: Array, record: bool, reward: Dictionary, gained: int) -> void:
	var last := current_level >= Levels.count() - 1
	complete_title.text = "COMPLETE_ALL" if last else "COMPLETE_TITLE"
	next_button.visible = not last
	next_button.disabled = not _can_continue()
	%NoStarsLabel.visible = stars.count(true) == 0 and not _can_continue()
	%RecordLabel.visible = false
	var texts := [tr("STAR_NO_DEATH"), tr("STAR_TURNS") % [_run_turns, _star_turns], tr("STAR_GOLD")]
	for i in 3:
		star_icons[i].reset()
		star_labels[i].text = texts[i]
		star_labels[i].modulate = Color(1, 1, 1, 0)
	_reward_label.text = tr("COMPLETE_REWARD") % [reward["total"], reward["level"], reward["spare"],
		_run_coins]
	_reward_gained_label.text = tr("COMPLETE_COINS_GAINED") % [gained, GameState.coins()] if gained > 0 \
		else tr("COMPLETE_COINS_BEST") % [GameState.best_reward(current_level), GameState.coins()]
	_reward_label.modulate.a = 0.0
	_reward_gained_label.modulate.a = 0.0
	complete_menu.visible = true
	_focus_first(complete_menu)
	if _stars_tween and _stars_tween.is_valid():
		_stars_tween.kill()
	_stars_tween = complete_menu.create_tween()
	_stars_tween.tween_interval(STAR_FIRST_DELAY)
	for i in 3:
		var got: bool = stars[i]
		_stars_tween.tween_callback(func() -> void:
			star_icons[i].reveal(got)
			if got:
				Sfx.play("star", 0.0, 0.0, STAR_PITCHES[i])
			else:
				Sfx.play("star_miss"))
		_stars_tween.tween_property(star_labels[i], "modulate",
			Color(1, 1, 1, 1.0) if got else Color(1, 1, 1, 0.5), 0.2)
		_stars_tween.tween_interval(STAR_INTERVAL - 0.2)
	_stars_tween.tween_property(_reward_label, "modulate:a", 1.0, 0.2)
	_stars_tween.tween_property(_reward_gained_label, "modulate:a", 1.0, 0.2)
	if gained > 0:
		_stars_tween.tween_callback(func() -> void:
			Sfx.play("coin")
			_pop_stat(_reward_gained_label))
	if record and stars.count(true) > 0:
		_stars_tween.tween_callback(func() -> void:
			%RecordLabel.visible = true
			_pop_stat(%RecordLabel))


## Se puede pasar al siguiente nivel si está desbloqueado: hace falta alguna
## estrella en esta partida o en la mejor anterior.
func _can_continue() -> bool:
	return current_level >= Levels.count() - 1 or GameState.is_unlocked(current_level + 1)


func _add_death() -> void:
	_run_deaths += 1
	_update_stats()


## Marcador de los retos de la partida (arriba, junto al número de nivel).
func _update_stats() -> void:
	if not is_node_ready():
		return
	turns_label.text = tr("HUD_TURNS") % [_run_turns, _star_turns]
	turns_label.add_theme_color_override("font_color",
		TURNS_OVER_COLOR if _run_turns > _star_turns else Color(0.965, 0.937, 0.886))
	life_icon.modulate = Color.WHITE if _run_deaths == 0 else STAT_OFF
	gold_icon.modulate = Color.WHITE if _run_collected else STAT_OFF
	gold_icon.visible = level.has_collectible()


## Pequeño salto de un icono o texto del marcador.
func _pop_stat(control: Control) -> void:
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2.ONE * 1.4, 0.12).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(control, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)


func _on_play_area_resized() -> void:
	camera.refresh_layout()
	camera.snap()


## Los toques sobre los botones no cuentan como giro.
func _is_over_buttons(pos: Vector2) -> bool:
	return pause_button.visible and pause_button.get_global_rect().has_point(pos)


## Toque en el margen de PAUSE_HIT_MARGIN alrededor del botón del mapa (fuera
## del botón: dentro, lo recoge el propio botón). El botón se ve igual de
## grande, pero así es más fácil acertar y no se gira el cubo sin querer.
func _is_near_pause_button(pos: Vector2) -> bool:
	return pause_button.visible and not pause_button.get_global_rect().has_point(pos) \
		and pause_button.get_global_rect().grow(PAUSE_HIT_MARGIN).has_point(pos)


## Reproductor del zumbido de la inmunidad, con el sonido en bucle.
func _setup_immunity_hum() -> void:
	_immunity_hum = AudioStreamPlayer.new()
	_immunity_hum.bus = &"SFX"
	# Se detiene en la pausa (como el cubo) y sigue al reanudar.
	_immunity_hum.process_mode = Node.PROCESS_MODE_PAUSABLE
	var stream := load("res://audio/sfx/immunity_hum.wav") as AudioStreamWAV
	if stream:
		stream = stream.duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		_immunity_hum.stream = stream
	add_child(_immunity_hum)


func _start_immunity_hum() -> void:
	if _hum_tween and _hum_tween.is_valid():
		_hum_tween.kill()
	_immunity_hum.volume_db = IMMUNITY_HUM_DB
	_immunity_hum.play()


func _stop_immunity_hum() -> void:
	if _hum_tween and _hum_tween.is_valid():
		_hum_tween.kill()
	# En la pausa (p. ej. al reiniciar desde ella) el reproductor está
	# detenido: se corta del todo para que no siga al reanudar.
	if get_tree().paused:
		_immunity_hum.stop()
		return
	_hum_tween = create_tween()
	_hum_tween.tween_property(_immunity_hum, "volume_db", -60.0, IMMUNITY_HUM_FADE)
	_hum_tween.tween_callback(_immunity_hum.stop)


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
