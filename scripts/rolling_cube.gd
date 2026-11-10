class_name RollingCube
extends Node3D
## Cubo que avanza automáticamente volcando 90° sobre la arista inferior.
##
## Estado lógico: casilla actual, rumbo y orientación de las caras (la base
## del nodo Body). El nodo raíz se queda en el centro de la casilla, a ras de
## suelo, y solo Body se anima durante el vuelco.
##
## Llaves y puertas: el cubo coge una llave al llegar a su casilla (solo puede
## llevar una; si ya lleva otra, no pasa nada). Al cogerla, la llave sube desde
## su sitio en el mapa hasta encima del cubo (KEY_LIFT_TIME) y ahí se queda. Una puerta cerrada es un obstáculo como una pared: los
## giros hacia ella se descartan y al chocar de frente el cubo rebota; si lleva
## la llave de su color, la puerta y la llave desaparecen y el cubo rebota.
##
## Muros destructibles: también son obstáculos. Cada choque de frente les
## quita un golpe y el cubo rebota; el golpe que los rompe también rebota,
## pero desde ese momento la casilla ya se puede atravesar.
##
## Botones y barrotes: unos barrotes cerrados son un obstáculo como una
## puerta. Un botón es una pared: al chocar con él de frente el cubo rebota y
## los barrotes asociados cambian de estado (ver Level.press_button).
##
## Media vuelta: el jugador puede pedirla (izquierda y derecha a la vez). Se
## aplica en el siguiente límite entre casillas, como un giro: el rumbo se
## invierte como si el cubo chocara contra una pared (también para los power
## ups), el cubo se queda parado REVERSE_PAUSE segundos y por sus cuatro
## lados sale humo gris.
##
## Dash y pisotón: el jugador los pide (deslizando el dedo arriba o abajo) y,
## como los giros, se aplican en el siguiente límite entre casillas; la última
## petición (giro, media vuelta, dash o pisotón) sustituye a la anterior.
## Fuerza: los dos gastan la misma fuerza (de 0 a 1). Hacer uno la deja a 0
## y solo se puede volver a pedir cualquiera de los dos cuando está llena; se
## recarga en `strength_recharge_time` segundos, sin contar lo que dura la
## acción. Si se piden sin fuerza, se descartan (strength_rejected) sin tocar
## lo que hubiera pendiente.
## - Dash: el cubo se arrastra sin volcar hasta la casilla de delante en
##   DASH_TIME segundos. Antes destruye a cualquier enemigo que la ocupe y, si
##   es un muro destructible, lo rompe de una vez y pasa sin rebotar. Si
##   delante hay una pared, puerta, barrotes o un botón, el dash se queda en un
##   choque normal (rebote). Si es vacío, se cae.
## - Pisotón: salta y cae con fuerza en su casilla (STOMP_TIME en total). Al
##   caer destruye a los enemigos a `stomp_radius` casillas o menos (cuadrado,
##   diagonales incluidas, sin importar las paredes) y quita
##   STOMP_WALL_HITS golpes a los muros destructibles de esa zona.
## Durante el dash y el pisotón el cubo es invulnerable.
##
## Inmunidad: el jugador la pide (botón de arriba en el centro) y también
## gasta toda la fuerza, pero se activa al momento, sin esperar al límite
## entre casillas, y no toca lo pendiente. Durante `immunity_time` segundos
## el cubo no puede morir por enemigos ni armas (sí cayendo al vacío) y se ve
## «disuelto» (CubeDissolve: el efecto entra y sale en IMMUNITY_FADE
## segundos). La fuerza no se recarga mientras dura. Se pierde al morir, al
## reiniciar y al llegar a la meta. Si se pide sin fuerza, se descarta
## (strength_rejected).
##
## Enemigos: si un perseguidor o un patrullero lo toca (lo comprueba Level),
## el cubo explota en pedazos de sus colores (ver CubeExplosion) y, cuando
## termina la explosión, vuelve a su casilla de salida con el rumbo inicial. Conserva la
## llave que llevaba, pierde los power ups y el tablero se queda como estaba.
## Al reaparecer hace la animación de aparición (ver más abajo) y después
## se «disuelve» a medias (ver CubeDissolve) y es invulnerable durante
## RESPAWN_GRACE segundos. Un
## obstáculo es como una pared. Si queda encajonado (bloqueado delante y
## detrás), rebota en su casilla a ritmo de vuelco hasta que se libere el paso.
##
## Vacío: las casillas de vacío no son obstáculos (el cubo no rebota y los
## giros hacia ellas se aceptan). Si el cubo entra en una, vuelca por el
## borde, cae girando y, tras FALL_TIME segundos, explota en el aire; cuando
## termina la explosión vuelve a la salida como si lo hubiera matado un
## enemigo. Se cae aunque esté en el tiempo de invulnerabilidad.
##
## Aparición: tras reset() el cubo espera oculto en la salida (mientras
## aparece el tablero) hasta que se llama a appear(). Durante APPEAR_TIME
## segundos baja girando y creciendo hasta su casilla, se posa con un
## pequeño aplastamiento y una nube de polvo, y entonces empieza a rodar
## (emite appeared). Mientras espera o aparece no se le puede matar.
##
## Teletransporte: al llegar a una casilla de teletransporte (ver Level), el
## cubo se «disuelve» (CubeDissolve) durante TELEPORT_OUT_TIME segundos y
## desaparece; pasa a la casilla pareja y, mientras está oculto
## (TELEPORT_TRAVEL_TIME), la cámara viaja hasta allí (teleport_travel); luego
## reaparece disolviéndose, se queda quieto TELEPORT_IN_TIME segundos, el
## efecto se va en TELEPORT_FADE_TIME y sigue con el mismo rumbo que tenía.
## Durante todo el teletransporte no atiende giros ni acciones (lo pendiente
## se olvida) y es invulnerable. Salir de la casilla de destino rodando no
## lo teletransporta; volver a entrar en ella, sí.
##
## Power ups: al llegar a su casilla el cubo lo coge y se activa su efecto.
## Las reglas de cada tipo (acumulación, duración, fin al rebotar...) las
## define su clase (ver PowerUp); aquí se gestionan de forma genérica.

signal reached_goal
signal bounced(cell: Vector2i)
signal rolled(cell: Vector2i)
signal key_picked(color: String)
signal door_opened(color: String)
signal breakable_hit(cell: Vector2i, hits_left: int)
signal button_pressed(cell: Vector2i)
## El cubo ha dado media vuelta a petición del jugador.
signal reversed(cell: Vector2i)
## Se ha pedido un giro hacia una casilla bloqueada y se ha descartado.
signal turn_rejected(direction: Vector2i)
## Se ha aplicado un giro pedido (a la izquierda o a la derecha): cuenta para
## la estrella de giros (la media vuelta también cuenta, como dos: ver
## reversed). Los descartados y los rebotes no.
signal turn_applied(direction: Vector2i)
## Ha cogido el cubito dorado del nivel.
signal collectible_picked
signal power_up_picked(power_up: PowerUp, stacks: int)
signal power_up_ended(power_up: PowerUp)
## Un enemigo ha matado al cubo en esa casilla, o ha explotado tras caer al
## vacío desde ella.
signal died(cell: Vector2i)
## El cubo ha empezado a caer al vacío desde esa casilla (explotará después).
signal fell(cell: Vector2i)
## El cubo ha vuelto a la salida tras morir.
signal respawned
## Se ha posado en la salida durante la aparición.
signal landed
## Ha terminado la aparición y empieza a rodar.
signal appeared
## Ha empezado un dash desde `from` hacia `to`.
signal dashed(from: Vector2i, to: Vector2i)
## Ha caído el pisotón en esa casilla.
signal stomped(cell: Vector2i)
## Se ha pedido un dash, un pisotón o la inmunidad sin la fuerza llena.
signal strength_rejected
## Ha empezado la inmunidad, que durará `duration` segundos.
signal immunity_started(duration: float)
## Se ha acabado la inmunidad (por tiempo, al morir, al reiniciar o en la meta).
signal immunity_ended
## Ha entrado en una casilla de teletransporte y empieza a disolverse.
signal teleport_started(from: Vector2i, to: Vector2i)
## Ya ha desaparecido y está en la casilla de destino (`to`): la cámara tiene
## `duration` segundos para llegar hasta allí antes de que reaparezca.
signal teleport_travel(to: Vector2i, duration: float)
## Ha reaparecido en la casilla de destino.
signal teleport_arrived(cell: Vector2i)

const TURN_LEFT := -1
const TURN_RIGHT := 1
## Acción especial pendiente (_pending_ability).
const ABILITY_NONE := 0
const ABILITY_DASH := 1
const ABILITY_STOMP := 2
## Dash: duración del arrastre hasta la casilla de delante y cuánto se estira
## el cubo en el rumbo (y se aplasta en altura) a mitad de camino.
const DASH_TIME := 0.14
const DASH_STRETCH := 0.18
## Pisotón: subida, caída y recuperación del aplastamiento (segundos), altura
## del salto, aplastamiento al caer y golpes que quita a los muros.
const STOMP_RISE_TIME := 0.22
const STOMP_FALL_TIME := 0.1
const STOMP_RECOVER_TIME := 0.16
const STOMP_HEIGHT := 0.9
const STOMP_SQUASH := 0.28
const STOMP_WALL_HITS := 2
## Onda del pisotón: anillo en el suelo que se abre hasta el borde de la zona
## de daño y se desvanece.
const STOMP_WAVE_TIME := 0.35
const STOMP_WAVE_COLOR := Color(1.0, 0.92, 0.75)
const HALF := 0.5
## Altura sobre el suelo de la llave que lleva el cubo.
const HELD_KEY_HEIGHT := 2.05
## Al coger una llave, lo que tarda en subir desde su sitio en el mapa hasta
## encima del cubo.
const KEY_LIFT_TIME := 0.45
## Media vuelta: tiempo que el cubo se queda parado.
const REVERSE_PAUSE := 0.2
## Humo de la media vuelta: bocanadas por cada lado de la base que salen hacia
## fuera, crecen y se desvanecen.
const REVERSE_SMOKE_COLOR := Color(0.38, 0.39, 0.42)
const REVERSE_SMOKE_PUFFS := 10
const REVERSE_SMOKE_LIFETIME := 0.8
## Muerte: invulnerabilidad al reaparecer en la salida, con el efecto de
## disolverse (CubeDissolve): aparece poco a poco durante
## RESPAWN_DISSOLVE_FADE segundos, se mantiene y se va poco a poco en los
## últimos RESPAWN_DISSOLVE_FADE segundos.
const RESPAWN_GRACE := 1.5
const RESPAWN_DISSOLVE_FADE := 0.5
## Inmunidad: lo que tarda el efecto de disolverse en entrar y en salir.
const IMMUNITY_FADE := 0.3
## Aparición: duración, altura desde la que baja, vueltas que da al bajar,
## fracción del tiempo que tarda en posarse (el resto es el aplastamiento) y
## cuánto se aplasta.
const APPEAR_TIME := 2.0
const APPEAR_HEIGHT := 2.5
const APPEAR_SPINS := 1.5
const APPEAR_LAND := 0.75
const APPEAR_SQUASH := 0.18
## Caída al vacío: tiempo de caída libre hasta explotar, gravedad, velocidad
## inicial (hacia delante y hacia abajo) y giro (rad/s) al salir del borde.
const FALL_TIME := 0.6
const FALL_GRAVITY := 11.0
const FALL_FORWARD_SPEED := 1.0
const FALL_DOWN_SPEED := 0.8
const FALL_SPIN := 6.5
## Lado del cubo.
## Teletransporte (ver la descripción de la clase): disolverse hasta
## desaparecer, viaje de la cámara, quieto en el destino y desvanecido del
## efecto; y lo que tarda en desaparecer al final de la ida y en hacerse
## visible al principio de la llegada.
const TELEPORT_OUT_TIME := 1.0
const TELEPORT_TRAVEL_TIME := 1.0
const TELEPORT_IN_TIME := 1.0
const TELEPORT_FADE_TIME := 0.35
const TELEPORT_VANISH_TIME := 0.35

const SIZE := 0.98
## Colores del cubo: todas las caras blancas (la iluminación y las sombras
## distinguen las caras) con las aristas en gris claro.
const FACE_COLOR := Color(1.0, 1.0, 1.0)
const EDGE_COLOR := Color(0.74, 0.75, 0.78)
## Ancho del marco de las aristas en cada cara, como fracción del lado.
const EDGE_WIDTH := 0.07

## Material del humo, compartido (bocanada redonda de bordes suaves).
static var _smoke_material: StandardMaterial3D

## Duración de cada vuelco en segundos.
@export var roll_duration := 0.35
## Pausa entre vuelcos consecutivos.
@export var pause_between_rolls := 0.05
## Alcance del pisotón en casillas (distancia en cuadrado: 2 = zona de 5×5).
## Más adelante podrá aumentar con otras habilidades.
@export var stomp_radius := 2
## Segundos que tarda la fuerza en llenarse tras un dash o un pisotón. Más
## adelante podrá cambiar con otras habilidades.
@export var strength_recharge_time := 2.0
## Segundos que dura la inmunidad. Podrá cambiar con otros eventos del juego
## (se lee al activarla).
@export var immunity_time := 3.0

var level: Level
var cell := Vector2i.ZERO
var heading := Vector2i(1, 0)
var is_finished := false
## Color de la llave que lleva el cubo ("" si no lleva ninguna).
var held_key := ""

## Giro pendiente (TURN_LEFT, TURN_RIGHT o 0). Se aplica en el siguiente
## límite entre casillas si esa dirección está libre; la última pulsación
## sustituye a la anterior.
var _pending_turn := 0
## Media vuelta pendiente: se aplica en el siguiente límite entre casillas y
## sustituye al giro pendiente.
var _pending_reverse := false
## Dash o pisotón pendiente (ABILITY_*), con las mismas reglas que un giro.
var _pending_ability := ABILITY_NONE
## Fuerza para el dash y el pisotón (1 = llena, se pueden pedir).
var _strength := 1.0
## Haciendo un dash (arrastrándose) o un pisotón (en el aire o aplastado).
var _dashing := false
var _stomping := false
## Fase del teletransporte: 0 ninguno, 1 disolviéndose, 2 viaje (oculto),
## 3 en el destino; tiempo dentro de la fase y casilla de destino.
var _teleport_phase := 0
var _teleport_time := 0.0
var _teleport_to := Vector2i.ZERO
## Escala de la llave que lleva al empezar el teletransporte (se encoge al
## desaparecer y crece al aparecer).
var _teleport_key_scale := Vector3.ONE
var _rolling := false
## Casilla hacia la que está volcando (solo vale mientras _rolling).
var _roll_target := Vector2i.ZERO
var _dead := false
## Esperando oculto en la salida a que se llame a appear().
var _waiting := false
## Tiempo de la aparición en curso (negativo si no está apareciendo), si ya
## se ha posado y si al acabar empieza el parpadeo de invulnerabilidad.
var _appear_time := -1.0
var _appear_landed := false
var _grace_after_appear := false
## Cayendo al vacío: vuelco por el borde (_rolling) y caída libre después.
var _falling := false
var _fall_time := 0.0
var _fall_velocity := Vector3.ZERO
var _fall_axis := Vector3.RIGHT
var _explosion: CubeExplosion
## Malla de un pedazo de la explosión (un cubo pequeño con los mismos colores).
var _piece_mesh: Mesh
var _grace_left := 0.0
## Inmunidad: segundos que le quedan (0 = sin inmunidad) y duración total de
## la actual (para el efecto).
var _immunity_left := 0.0
var _immunity_total := 0.0
## Material del efecto de disolverse (se pone en _body solo durante la
## invulnerabilidad).
var _dissolve_material: ShaderMaterial
## Copia del cubo que solo da sombra mientras dura el efecto de disolverse
## (un material transparente no da sombra y la del cubo desaparecería de
## golpe).
var _shadow_caster: MeshInstance3D
var _cooldown := 0.0
var _tween: Tween
var _held_key_node: Node3D
## Subida de la llave recién cogida: progreso (1 = ya encima del cubo) y
## posición de la que sale.
var _key_lift := 1.0
var _key_lift_from := Vector3.ZERO
## Power ups activos: id -> { "power_up": PowerUp, "stacks": int, "time_left": float }
var _power_ups := {}

@onready var _body: MeshInstance3D = $Body


func _ready() -> void:
	_body.mesh = _build_colored_cube(SIZE)
	_shadow_caster = MeshInstance3D.new()
	_shadow_caster.mesh = _body.mesh
	_shadow_caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_shadow_caster.visible = false
	_body.add_child(_shadow_caster)
	_warm_up_dissolve()
	_piece_mesh = _build_colored_cube(SIZE / CubeExplosion.GRID * 0.94)


func reset(target_level: Level) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	level = target_level
	cell = level.start_cell
	heading = level.start_heading
	_clear_pending()
	_strength = 1.0
	_dashing = false
	_stomping = false
	_teleport_phase = 0
	_drop_held_key()
	_end_all_power_ups()
	_rolling = false
	_cooldown = 0.3
	is_finished = false
	_dead = false
	_grace_left = 0.0
	_end_immunity()
	_set_dissolve(0.0)
	_body.visible = true
	if is_instance_valid(_explosion):
		_explosion.queue_free()
	_explosion = null
	_falling = false
	global_position = level.cell_to_world(cell)
	# Oculto (diminuto) hasta que se llame a appear().
	_waiting = true
	_appear_time = -1.0
	_grace_after_appear = false
	_body.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.001), Vector3(0, HALF, 0))
	_update_held_key(Vector3.ZERO)


## Empieza la animación de aparición en la salida; al acabar, el cubo rueda.
func appear() -> void:
	_waiting = false
	_appear_time = 0.0
	_appear_landed = false
	_body.visible = true
	_apply_appear(0.0)
	_update_held_key(Vector3.ZERO)


func is_appearing() -> bool:
	return _waiting or _appear_time >= 0.0


func _process_appear(delta: float) -> void:
	_appear_time += delta
	var t := minf(_appear_time / APPEAR_TIME, 1.0)
	if not _appear_landed and t >= APPEAR_LAND:
		_appear_landed = true
		_spawn_dust(global_position + Vector3(0, 0.1, 0))
		landed.emit()
	_apply_appear(t)
	if t < 1.0:
		return
	_appear_time = -1.0
	_body.transform = Transform3D(Basis.IDENTITY, Vector3(0, HALF, 0))
	if _grace_after_appear:
		_grace_after_appear = false
		_grace_left = RESPAWN_GRACE
	if _held_key_node:
		_held_key_node.visible = true
	_update_held_key(Vector3.ZERO)
	appeared.emit()


## Baja girando y creciendo (con frenada suave) hasta posarse y, después, un
## aplastamiento que se recupera. t va de 0 a 1.
func _apply_appear(t: float) -> void:
	var d := clampf(t / APPEAR_LAND, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - d, 3.0)
	var height := APPEAR_HEIGHT * (1.0 - eased)
	var angle := (1.0 - eased) * TAU * APPEAR_SPINS
	var grow := lerpf(0.15, 1.0, eased)
	var squash := 0.0
	if t > APPEAR_LAND:
		var s := (t - APPEAR_LAND) / (1.0 - APPEAR_LAND)
		squash = sin(s * PI) * APPEAR_SQUASH * (1.0 - s * 0.5)
	var size := Vector3(grow * (1.0 + squash * 0.5), grow * (1.0 - squash), grow * (1.0 + squash * 0.5))
	_body.transform = Transform3D(Basis(Vector3.UP, angle).scaled(size),
		Vector3(0, HALF * size.y + height, 0))


## Registra un giro relativo al rumbo actual (izquierda o derecha).
func request_turn(direction: int) -> void:
	if is_finished or is_teleporting():
		return
	_clear_pending()
	_pending_turn = direction
	_update_held_key(_body_offset())


## Registra una media vuelta (sustituye al giro pendiente, si lo hay).
func request_reverse() -> void:
	if is_finished or is_teleporting():
		return
	_clear_pending()
	_pending_reverse = true
	_update_held_key(_body_offset())


## Registra un dash (ver la descripción de la clase).
func request_dash() -> void:
	_request_ability(ABILITY_DASH)


## Registra un pisotón (ver la descripción de la clase).
func request_stomp() -> void:
	_request_ability(ABILITY_STOMP)


func _request_ability(ability: int) -> void:
	if is_finished or _dead or is_appearing() or is_teleporting():
		return
	if _strength < 1.0:
		strength_rejected.emit()
		return
	_clear_pending()
	_pending_ability = ability


## Activa la inmunidad al momento (ver la descripción de la clase).
func request_immunity() -> void:
	if is_finished or _dead or is_appearing():
		return
	# Mientras dura, la fuerza está gastada: también se avisa.
	if _strength < 1.0 or _immunity_left > 0.0:
		strength_rejected.emit()
		return
	_strength = 0.0
	_immunity_total = immunity_time
	_immunity_left = immunity_time
	immunity_started.emit(immunity_time)


func is_immune() -> bool:
	return _immunity_left > 0.0


## Segundos de inmunidad que quedan (0 si no la tiene).
func immunity_left() -> float:
	return _immunity_left


## Quita la inmunidad (sin tocar el efecto: lo hace quien la llama).
func _end_immunity() -> void:
	if _immunity_left <= 0.0:
		return
	_immunity_left = 0.0
	immunity_ended.emit()


## Olvida el giro o la media vuelta pendientes (p. ej. si el toque que los
## pidió resulta ser un deslizamiento).
func cancel_turn() -> void:
	_pending_turn = 0
	_pending_reverse = false


## Fuerza para el dash y el pisotón, de 0 (recién gastada) a 1 (llena).
func strength() -> float:
	return _strength


## Olvida el giro, la media vuelta y la acción especial pendientes.
func _clear_pending() -> void:
	_pending_turn = 0
	_pending_reverse = false
	_pending_ability = ABILITY_NONE


func _process(delta: float) -> void:
	if _falling and not _rolling:
		_process_fall(delta)
	if _dead or _waiting:
		return
	if _appear_time >= 0.0:
		_process_appear(delta)
		return
	if _strength < 1.0 and not _dashing and not _stomping and _immunity_left <= 0.0:
		_strength = minf(_strength + delta / strength_recharge_time, 1.0)
	if _grace_left > 0.0 or _immunity_left > 0.0:
		_process_protection(delta)
	_process_power_ups(delta)
	# La llave que lleva el cubo sigue girando sobre sí misma, como en el mapa.
	if _held_key_node:
		_held_key_node.rotate_y(Level.KEY_SPIN_SPEED * delta)
		if _key_lift < 1.0:
			_key_lift = minf(_key_lift + delta / KEY_LIFT_TIME, 1.0)
			if not _rolling:
				_update_held_key(Vector3.ZERO)
	if _teleport_phase != 0:
		_process_teleport(delta)
		return
	if level == null or _rolling or is_finished:
		return
	if _cooldown > 0.0:
		_cooldown -= delta
		return
	_try_advance()


func _try_advance() -> void:
	if _pending_ability != ABILITY_NONE:
		var ability := _pending_ability
		_pending_ability = ABILITY_NONE
		_strength = 0.0
		if ability == ABILITY_STOMP:
			_stomp()
			return
		# Dash: despeja la casilla de delante (enemigos y muro destructible) y se
		# arrastra hasta ella. Si sigue bloqueada (pared, puerta, barrotes o
		# botón) o es vacío, sigue como un avance normal: choque o caída.
		var target := cell + heading
		level.destroy_enemies_at(target)
		if level.breakable_hits(target) > 0:
			level.smash_breakable(target, heading)
			breakable_hit.emit(target, 0)
		if level.is_walkable(target):
			_dash_to(target)
			return

	# Media vuelta: el rumbo se invierte como al chocar con una pared y el
	# cubo se queda parado un momento antes de seguir.
	if _pending_reverse:
		_pending_reverse = false
		heading = -heading
		_end_power_ups_on_bounce(false)
		_spawn_reverse_smoke()
		_update_held_key(Vector3.ZERO)
		reversed.emit(cell)
		_cooldown = REVERSE_PAUSE
		return

	# Un giro solo se aplica si la casilla en esa dirección está libre; si no,
	# se descarta y el cubo sigue con su rumbo actual.
	if _pending_turn != 0:
		var candidate := turned(heading, _pending_turn)
		_pending_turn = 0
		if level.is_walkable(cell + candidate) or level.is_void(cell + candidate):
			heading = candidate
			turn_applied.emit(candidate)
		else:
			turn_rejected.emit(candidate)
		_update_held_key(Vector3.ZERO)

	# Rebote: si la casilla siguiente es pared, borde o puerta cerrada, el rumbo
	# se invierte al instante y el cubo sigue rodando en sentido contrario.
	# Al chocar con una puerta llevando su llave, la puerta se abre (y la llave
	# se gasta), pero el cubo rebota igualmente.
	# Al chocar con un botón, se pulsa y el cubo rebota.
	var ahead := cell + heading
	if not level.is_walkable(ahead) and not level.is_void(ahead):
		var door := level.door_color(ahead)
		# Para los power ups, los barrotes cuentan como una puerta.
		var door_like := door != "" or level.bars_closed(ahead)
		if door != "" and door == held_key:
			# La llave vuela hasta la puerta (ver Level.open_door).
			var key := _held_key_node
			_held_key_node = null
			held_key = ""
			level.open_door(ahead, key)
			door_opened.emit(door)
		elif level.breakable_hits(ahead) > 0:
			breakable_hit.emit(ahead, level.hit_breakable(ahead, heading))
		elif level.is_button(ahead):
			level.press_button(ahead)
			button_pressed.emit(ahead)
		_end_power_ups_on_bounce(door_like)
		heading = -heading
		bounced.emit(cell)
		_update_held_key(Vector3.ZERO)

	var next := cell + heading
	if level.is_void(next):
		_fall_to(next)
	elif level.is_walkable(next):
		_roll_to(next)
	else:
		# Encajonado (p. ej. entre un obstáculo y un muro): espera lo que
		# tardaría en volcar antes de volver a rebotar.
		_cooldown = step_time()


func _roll_to(next: Vector2i) -> void:
	_rolling = true
	_roll_target = next
	var dir := Vector3(heading.x, 0, heading.y)
	var start := _body.transform
	# Arista inferior en la dirección de avance (coordenadas locales del nodo raíz).
	var pivot := dir * HALF
	var axis := Vector3.UP.cross(dir)

	_tween = create_tween()
	_tween.tween_method(_apply_roll.bind(start, pivot, axis, dir, PI * 0.5), 0.0, 1.0,
			roll_duration / speed_multiplier()) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.finished.connect(_on_roll_finished.bind(next))


## Dash: se arrastra sin volcar hasta `next` (libre), estirándose en el rumbo
## y aplastándose un poco a mitad de camino.
func _dash_to(next: Vector2i) -> void:
	_rolling = true
	_dashing = true
	_roll_target = next
	var dir := Vector3(heading.x, 0, heading.y)
	_spawn_dust(global_position - dir * 0.35 + Vector3(0, 0.1, 0))
	_tween = create_tween()
	_tween.tween_method(_apply_dash.bind(_body.transform.basis, dir), 0.0, 1.0, DASH_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.finished.connect(_on_dash_finished.bind(next))
	dashed.emit(cell, next)


func _apply_dash(t: float, start_basis: Basis, dir: Vector3) -> void:
	var s := sin(t * PI) * DASH_STRETCH
	var along := Vector3(absf(dir.x), 0, absf(dir.z))
	var across := Vector3(1, 0, 1) - along
	var size := Vector3.ONE + along * s - across * s * 0.25 - Vector3.UP * s * 0.4
	_body.transform = Transform3D(Basis.from_scale(size) * start_basis,
		dir * t + Vector3(0, HALF * size.y, 0))
	_update_held_key(dir * t)


func _on_dash_finished(next: Vector2i) -> void:
	_dashing = false
	# Un enemigo que haya entrado en la casilla durante el arrastre también cae.
	level.destroy_enemies_at(next)
	_on_roll_finished(next)


## Pisotón: sube, cae con fuerza en su casilla (ver _stomp_impact) y se
## recupera del aplastamiento; después sigue con su rumbo.
func _stomp() -> void:
	_rolling = true
	_stomping = true
	_roll_target = cell
	var start_basis := _body.transform.basis
	_tween = create_tween()
	_tween.tween_method(_apply_stomp_height.bind(start_basis), 0.0, STOMP_HEIGHT, STOMP_RISE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_apply_stomp_height.bind(start_basis), STOMP_HEIGHT, 0.0, STOMP_FALL_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_stomp_impact)
	_tween.tween_method(_apply_stomp_squash.bind(start_basis), 1.0, 0.0, STOMP_RECOVER_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.finished.connect(_on_stomp_finished)


func _apply_stomp_height(height: float, start_basis: Basis) -> void:
	_body.transform = Transform3D(start_basis, Vector3(0, HALF + height, 0))
	_update_held_key(Vector3(0, height, 0))


func _apply_stomp_squash(amount: float, start_basis: Basis) -> void:
	var squash := STOMP_SQUASH * amount
	var size := Vector3(1.0 + squash * 0.5, 1.0 - squash, 1.0 + squash * 0.5)
	_body.transform = Transform3D(Basis.from_scale(size) * start_basis, Vector3(0, HALF * size.y, 0))


## Golpe del pisotón contra el suelo: polvo, onda y daño en la zona.
func _stomp_impact() -> void:
	_spawn_dust(global_position + Vector3(0, 0.1, 0))
	_spawn_stomp_wave()
	level.stomp(cell, stomp_radius, STOMP_WALL_HITS)
	stomped.emit(cell)


func _on_stomp_finished() -> void:
	_stomping = false
	_rolling = false
	_body.transform = Transform3D(_snap_basis(_body.transform.basis.orthonormalized()), Vector3(0, HALF, 0))
	_update_held_key(Vector3.ZERO)
	_cooldown = pause_between_rolls / speed_multiplier()


## Anillo en el suelo que se abre hasta el borde de la zona del pisotón y se
## desvanece.
func _spawn_stomp_wave() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.86
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 6
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = STOMP_WAVE_COLOR
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.top_level = true
	add_child(ring)
	ring.global_position = global_position + Vector3(0, 0.06, 0)
	ring.scale = Vector3(0.3, 0.12, 0.3)
	var reach := (stomp_radius + 0.5) * Level.CELL_SIZE
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3(reach, 0.12, reach), STOMP_WAVE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, STOMP_WAVE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(ring.queue_free)


## Entra en una casilla de vacío: vuelca por el borde acelerando y luego cae
## (ver _process_fall).
func _fall_to(next: Vector2i) -> void:
	_dead = true
	_falling = true
	_fall_time = 0.0
	_rolling = true
	_roll_target = next
	_clear_pending()
	_end_all_power_ups()
	if _held_key_node:
		_held_key_node.visible = false
	var dir := Vector3(heading.x, 0, heading.y)
	var start := _body.transform
	var pivot := dir * HALF
	_fall_axis = Vector3.UP.cross(dir)
	_fall_velocity = dir * FALL_FORWARD_SPEED + Vector3.DOWN * FALL_DOWN_SPEED
	_tween = create_tween()
	_tween.tween_method(_apply_roll.bind(start, pivot, _fall_axis, Vector3.ZERO, PI * 0.5), 0.0, 1.0,
			roll_duration / speed_multiplier()) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.finished.connect(func() -> void: _rolling = false)
	fell.emit(cell)


## El suelo desaparece bajo el cubo (se cae el puente colgante en el que
## está): deja de volcar donde esté y cae en vertical, girando despacio.
func drop() -> void:
	if _dead:
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_dead = true
	_falling = true
	_fall_time = 0.0
	_rolling = false
	_clear_pending()
	_dashing = false
	_stomping = false
	_end_all_power_ups()
	if _held_key_node:
		_held_key_node.visible = false
	var dir := Vector3(heading.x, 0, heading.y)
	_fall_axis = Vector3.UP.cross(dir)
	_fall_velocity = dir * FALL_FORWARD_SPEED * 0.3 + Vector3.DOWN * FALL_DOWN_SPEED * 0.3
	fell.emit(cell)


## Casilla hacia la que está volcando (o la suya si está quieto).
func roll_target() -> Vector2i:
	return _roll_target if _rolling else cell


## Caída libre girando; al acabar FALL_TIME explota en el aire.
func _process_fall(delta: float) -> void:
	_fall_time += delta
	_fall_velocity.y -= FALL_GRAVITY * delta
	_body.position += _fall_velocity * delta
	_body.basis = Basis(_fall_axis, FALL_SPIN * delta) * _body.basis
	if _fall_time >= FALL_TIME:
		_falling = false
		_explode(false)


func _apply_roll(t: float, start: Transform3D, pivot: Vector3, axis: Vector3, body_dir: Vector3, angle: float) -> void:
	var rot := Basis(axis, angle * t)
	_body.transform = Transform3D(rot * start.basis, pivot + rot * (start.origin - pivot))
	_update_held_key(body_dir * t)


func _on_roll_finished(next: Vector2i) -> void:
	var left := cell
	cell = next
	global_position = level.cell_to_world(cell)
	_body.transform = Transform3D(_snap_basis(_body.transform.basis), Vector3(0, HALF, 0))
	_rolling = false
	# Al salir de una casilla de puente colgante, ésta pierde estabilidad; si
	# el puente se cae con el cubo encima, el cubo cae con él (drop()).
	level.cube_left_cell(left)
	if _dead:
		return
	if held_key == "" and level.key_color(cell) != "":
		# La llave sale de donde estaba en el mapa (con el mismo giro) y sube
		# hasta encima del cubo (ver _update_held_key).
		var from := level.key_transform(cell)
		held_key = level.take_key(cell)
		_held_key_node = KeyVisual.create(Level.ITEM_COLORS[held_key])
		_held_key_node.top_level = true
		add_child(_held_key_node)
		_held_key_node.global_transform = from
		_key_lift_from = from.origin
		_key_lift = 0.0
		key_picked.emit(held_key)
	var power_up := level.take_power_up(cell)
	if power_up:
		_pick_power_up(power_up)
	if level.take_collectible(cell):
		collectible_picked.emit()
	_update_held_key(Vector3.ZERO)
	rolled.emit(cell)
	var partner := level.teleport_partner(cell)
	if partner != Level.NO_CELL:
		_start_teleport(partner)
		return
	if cell == level.goal_cell:
		is_finished = true
		# La inmunidad se acaba (el efecto sale poco a poco).
		if _immunity_left > IMMUNITY_FADE:
			_immunity_left = IMMUNITY_FADE
		if _held_key_node:
			_held_key_node.visible = false
		reached_goal.emit()
	else:
		_cooldown = pause_between_rolls / speed_multiplier()


## Segundos que dura un teletransporte entero (desde que entra hasta que
## sigue rodando).
static func teleport_duration() -> float:
	return TELEPORT_OUT_TIME + TELEPORT_TRAVEL_TIME + TELEPORT_IN_TIME + TELEPORT_FADE_TIME


func is_teleporting() -> bool:
	return _teleport_phase != 0


## Está en el aire (en el pisotón) con la base por encima de `height`.
func is_above(height: float) -> bool:
	return _stomping and _body.position.y - HALF > height


func _start_teleport(to: Vector2i) -> void:
	_clear_pending()
	_teleport_phase = 1
	_teleport_time = 0.0
	_teleport_to = to
	if _held_key_node:
		_teleport_key_scale = _held_key_node.scale
	level.pulse_teleport(cell)
	teleport_started.emit(cell, to)


## Avanza el teletransporte (ver la descripción de la clase).
func _process_teleport(delta: float) -> void:
	_teleport_time += delta
	var t := _teleport_time
	match _teleport_phase:
		1:
			# Se disuelve y, al final, desaparece del todo.
			var vanish := 1.0 - smoothstep(TELEPORT_OUT_TIME - TELEPORT_VANISH_TIME,
				TELEPORT_OUT_TIME, t)
			_set_dissolve(smoothstep(0.0, 0.25, t), vanish)
			if _held_key_node:
				_held_key_node.scale = _teleport_key_scale * maxf(vanish, 0.001)
			if t >= TELEPORT_OUT_TIME:
				_teleport_phase = 2
				_teleport_time = 0.0
				_body.visible = false
				if _held_key_node:
					_held_key_node.visible = false
				cell = _teleport_to
				global_position = level.cell_to_world(cell)
				_update_held_key(Vector3.ZERO)
				teleport_travel.emit(cell, TELEPORT_TRAVEL_TIME)
		2:
			if t >= TELEPORT_TRAVEL_TIME:
				_teleport_phase = 3
				_teleport_time = 0.0
				_body.visible = true
				if _held_key_node:
					_held_key_node.visible = true
				_set_dissolve(1.0, 0.0)
				level.pulse_teleport(cell)
				teleport_arrived.emit(cell)
		3:
			# Aparece disuelto, se queda quieto y el efecto se va.
			var appear := smoothstep(0.0, TELEPORT_VANISH_TIME, t)
			_set_dissolve(1.0 - smoothstep(TELEPORT_IN_TIME, TELEPORT_IN_TIME + TELEPORT_FADE_TIME, t),
				appear)
			if _held_key_node:
				_held_key_node.scale = _teleport_key_scale * maxf(appear, 0.001)
			if t >= TELEPORT_IN_TIME + TELEPORT_FADE_TIME:
				_teleport_phase = 0
				_set_dissolve(0.0)
				if _held_key_node:
					_held_key_node.scale = _teleport_key_scale
				_cooldown = pause_between_rolls / speed_multiplier()


## Avanza la invulnerabilidad de después de reaparecer y la inmunidad, y pone
## el efecto de disolverse del que esté más visible (el teletransporte pone
## el suyo encima, porque se procesa después).
func _process_protection(delta: float) -> void:
	var amount := 0.0
	if _grace_left > 0.0:
		_grace_left = maxf(_grace_left - delta, 0.0)
		var elapsed := RESPAWN_GRACE - _grace_left
		amount = minf(smoothstep(0.0, RESPAWN_DISSOLVE_FADE, elapsed),
			smoothstep(0.0, RESPAWN_DISSOLVE_FADE, _grace_left))
	if _immunity_left > 0.0:
		_immunity_left = maxf(_immunity_left - delta, 0.0)
		var elapsed := _immunity_total - _immunity_left
		amount = maxf(amount, minf(smoothstep(0.0, IMMUNITY_FADE, elapsed),
			smoothstep(0.0, IMMUNITY_FADE, _immunity_left)))
		if _immunity_left <= 0.0:
			immunity_ended.emit()
	if not is_teleporting():
		_set_dissolve(amount)


## Gira un rumbo 90° a la izquierda o a la derecha. En el tablero "arriba"
## es -Z, así que la izquierda de (0, -1) es (-1, 0).
static func turned(dir: Vector2i, direction: int) -> Vector2i:
	if direction == TURN_LEFT:
		return Vector2i(dir.y, -dir.x)
	return Vector2i(-dir.y, dir.x)


func _body_offset() -> Vector3:
	return Vector3(_body.position.x, 0, _body.position.z)


## Está en el tablero (no ha explotado esperando a reaparecer).
func is_alive() -> bool:
	return not _dead


## Un enemigo puede matarlo ahora: vivo, sin haber llegado a la meta, sin la
## invulnerabilidad de después de reaparecer, sin la inmunidad y sin estar
## haciendo un dash o un pisotón.
func is_vulnerable() -> bool:
	return not _dead and not is_finished and _grace_left <= 0.0 and _immunity_left <= 0.0 \
		and not is_appearing() \
		and not _dashing and not _stomping and not is_teleporting()


## Casilla en la que está o hacia la que está volcando.
func occupies(target: Vector2i) -> bool:
	return not _dead and (target == cell or (_rolling and target == _roll_target))


## Segundos por casilla al ritmo actual (vuelco y pausa).
func step_time() -> float:
	return (roll_duration + pause_between_rolls) / speed_multiplier()


## Lo ha tocado un enemigo: explota y, cuando termina la explosión, vuelve a
## la salida.
func die() -> void:
	if not is_vulnerable():
		return
	_explode(true)


## Revienta en pedazos donde está Body (en el suelo o cayendo en el vacío) y,
## cuando termina la explosión, vuelve a la salida.
func _explode(on_floor: bool) -> void:
	var at := _body.global_position
	var body_basis := _body.transform.basis.orthonormalized()
	if _tween and _tween.is_valid():
		_tween.kill()
	_dead = true
	_rolling = false
	_clear_pending()
	_dashing = false
	_stomping = false
	_end_immunity()
	_end_all_power_ups()
	_explosion = CubeExplosion.create(_body.mesh, _piece_mesh, body_basis, SIZE, on_floor)
	_explosion.finished.connect(_respawn)
	add_child(_explosion)
	_explosion.global_position = at
	if on_floor:
		_spawn_dust(at)
	_body.visible = false
	_set_dissolve(0.0)
	if _held_key_node:
		_held_key_node.visible = false
	died.emit(cell)


## Dibuja un momento un cubo diminuto con el material de disolverse para que
## el shader se compile al cargar y no la primera vez que se usa (en el móvil
## se notaba una pausa de alrededor de un segundo).
func _warm_up_dissolve() -> void:
	if _dissolve_material == null:
		_dissolve_material = CubeDissolve.make_material()
	var warm := MeshInstance3D.new()
	warm.mesh = _body.mesh
	warm.material_override = _dissolve_material
	warm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	warm.scale = Vector3.ONE * 0.001
	add_child(warm)
	for i in 3:
		await get_tree().process_frame
	warm.queue_free()


## Efecto de disolverse con esa fuerza (0 = cubo normal, sin el material).
## `fade` (0-1) es la opacidad de todo el cubo (0 = invisible; para el
## teletransporte).
func _set_dissolve(strength: float, fade := 1.0) -> void:
	_shadow_caster.visible = strength > 0.0 and fade > 0.5
	if strength <= 0.0 and fade >= 1.0:
		_body.material_override = null
		return
	if _dissolve_material == null:
		_dissolve_material = CubeDissolve.make_material()
	_dissolve_material.set_shader_parameter("strength", strength)
	_dissolve_material.set_shader_parameter("fade", fade)
	_body.material_override = _dissolve_material


func _respawn() -> void:
	if not _dead:
		return
	_explosion = null
	_dead = false
	cell = level.start_cell
	heading = level.start_heading
	global_position = level.cell_to_world(cell)
	_cooldown = 0.3
	# Espera oculto en la salida a que se llame a appear() (cuando la cámara
	# ya ha llegado); la llave que lleva se vuelve a ver al acabar la aparición.
	_waiting = true
	_body.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.001), Vector3(0, HALF, 0))
	_grace_after_appear = true
	respawned.emit()


## Velocidad actual respecto a la base (producto de los power ups activos).
func speed_multiplier() -> float:
	var mult := 1.0
	for entry in _power_ups.values():
		mult *= entry["power_up"].speed_multiplier(entry["stacks"])
	return mult


## Acumulaciones activas de un tipo de power up (0 si no está activo).
func power_up_stacks(id: String) -> int:
	return _power_ups[id]["stacks"] if _power_ups.has(id) else 0


## Punto bajo el cubo, a ras de suelo, que sigue el vuelco: para rastros.
func get_trail_anchor() -> Vector3:
	return global_position + _body_offset() + Vector3(0, 0.12, 0)


func _pick_power_up(power_up: PowerUp) -> void:
	if _power_ups.has(power_up.id):
		var entry: Dictionary = _power_ups[power_up.id]
		var active: PowerUp = entry["power_up"]
		if active.stackable:
			entry["stacks"] = mini(entry["stacks"] + 1, active.max_stacks)
			active.on_stacks_changed(self, entry["stacks"])
		entry["time_left"] = active.duration
		power_up_picked.emit(active, entry["stacks"])
		return
	_power_ups[power_up.id] = {"power_up": power_up, "stacks": 1, "time_left": power_up.duration}
	power_up.on_activated(self, 1)
	power_up_picked.emit(power_up, 1)


func _process_power_ups(delta: float) -> void:
	for id in _power_ups.keys():
		var entry: Dictionary = _power_ups[id]
		var power_up: PowerUp = entry["power_up"]
		power_up.on_process(self, entry["stacks"], delta)
		if power_up.duration > 0.0:
			entry["time_left"] -= delta
			if entry["time_left"] <= 0.0:
				_end_power_up(id)


func _end_power_ups_on_bounce(is_door: bool) -> void:
	for id in _power_ups.keys():
		var power_up: PowerUp = _power_ups[id]["power_up"]
		if (is_door and power_up.ends_on_door_bounce) or (not is_door and power_up.ends_on_wall_bounce):
			_end_power_up(id)


func _end_power_up(id: String, immediate := false) -> void:
	var power_up: PowerUp = _power_ups[id]["power_up"]
	_power_ups.erase(id)
	power_up.on_deactivated(self, immediate)
	power_up_ended.emit(power_up)


func _end_all_power_ups() -> void:
	for id in _power_ups.keys():
		_end_power_up(id, true)


func _drop_held_key() -> void:
	held_key = ""
	if _held_key_node:
		_held_key_node.queue_free()
		_held_key_node = null


## Ráfaga de humo gris desde cada uno de los cuatro lados de la base.
func _spawn_reverse_smoke() -> void:
	for dir: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var smoke := CPUParticles3D.new()
		smoke.top_level = true
		smoke.local_coords = false
		smoke.one_shot = true
		smoke.explosiveness = 0.85
		smoke.amount = REVERSE_SMOKE_PUFFS
		smoke.lifetime = REVERSE_SMOKE_LIFETIME
		# Las bocanadas nacen a lo largo de la arista inferior de ese lado.
		var along := Vector3(absf(dir.z), 0, absf(dir.x))
		smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		smoke.emission_box_extents = along * 0.45 + Vector3(0.03, 0.03, 0.03)
		smoke.direction = (dir + Vector3.UP * 0.35).normalized()
		smoke.spread = 25.0
		smoke.initial_velocity_min = 0.9
		smoke.initial_velocity_max = 1.6
		smoke.damping_min = 2.5
		smoke.damping_max = 3.5
		smoke.gravity = Vector3(0, 0.25, 0)
		smoke.angle_min = 0.0
		smoke.angle_max = 360.0
		smoke.scale_amount_min = 0.8
		smoke.scale_amount_max = 1.2
		var grow := Curve.new()
		grow.max_value = 3.0
		grow.add_point(Vector2(0, 0.6))
		grow.add_point(Vector2(1, 2.4))
		smoke.scale_amount_curve = grow
		var fade := Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 0.75))
		fade.set_color(1, Color(1, 1, 1, 0.0))
		smoke.color_ramp = fade
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * 0.4
		quad.material = _get_smoke_material()
		smoke.mesh = quad
		smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(smoke)
		smoke.global_position = global_position + dir * HALF + Vector3(0, 0.12, 0)
		smoke.emitting = true
		smoke.finished.connect(smoke.queue_free)


## Nube de polvo de la explosión.
func _spawn_dust(at: Vector3) -> void:
	var dust := CPUParticles3D.new()
	dust.top_level = true
	dust.local_coords = false
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.amount = 14
	dust.lifetime = 0.9
	dust.direction = Vector3.UP
	dust.spread = 180.0
	dust.initial_velocity_min = 0.8
	dust.initial_velocity_max = 1.6
	dust.damping_min = 2.0
	dust.damping_max = 3.0
	dust.angle_max = 360.0
	var grow := Curve.new()
	grow.max_value = 3.0
	grow.add_point(Vector2(0, 1.0))
	grow.add_point(Vector2(1, 2.6))
	dust.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.7))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	dust.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.5
	quad.material = _get_smoke_material()
	dust.mesh = quad
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dust)
	dust.global_position = at
	dust.emitting = true
	dust.finished.connect(dust.queue_free)


static func _get_smoke_material() -> StandardMaterial3D:
	if _smoke_material:
		return _smoke_material
	# Círculo blanco que se difumina hacia el borde.
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	_smoke_material = StandardMaterial3D.new()
	_smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_smoke_material.vertex_color_use_as_albedo = true
	_smoke_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# Necesario para que el billboard respete la escala de cada partícula (ver
	# el rastro de SpeedPowerUp).
	_smoke_material.billboard_keep_scale = true
	_smoke_material.albedo_color = REVERSE_SMOKE_COLOR
	_smoke_material.albedo_texture = texture
	return _smoke_material


## Coloca la llave que lleva el cubo sobre él (offset: desplazamiento del
## cuerpo durante el vuelco).
func _update_held_key(offset: Vector3) -> void:
	if _held_key_node:
		var target := global_position + offset + Vector3(0, HELD_KEY_HEIGHT, 0)
		if _key_lift < 1.0:
			var k := 1.0 - pow(1.0 - _key_lift, 3.0)
			target = _key_lift_from.lerp(target, k)
		_held_key_node.global_position = target


static func _snap_basis(b: Basis) -> Basis:
	var cols: Array[Vector3] = [b.x, b.y, b.z]
	for i in cols.size():
		cols[i] = Vector3(roundf(cols[i].x), roundf(cols[i].y), roundf(cols[i].z))
	return Basis(cols[0], cols[1], cols[2])


## Cubo blanco con las aristas en gris claro: cada cara es un cuadrado
## blanco rodeado de un marco gris (cuatro trapecios hasta el borde).
static func _build_colored_cube(size: float) -> ArrayMesh:
	var h := size * 0.5
	var inner := 1.0 - EDGE_WIDTH * 2.0
	var normals: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN,
		Vector3.BACK, Vector3.FORWARD]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in normals:
		var u := (n.cross(Vector3.UP) if absf(n.y) < 0.5 else n.cross(Vector3.RIGHT)).normalized()
		var v := n.cross(u)
		var corner := func(a: float, b: float) -> Vector3: return (n + u * a + v * b) * h
		# Esquinas exteriores e interiores, en el mismo sentido de giro.
		var outer_pts: Array[Vector3] = [corner.call(-1, -1), corner.call(1, -1),
			corner.call(1, 1), corner.call(-1, 1)]
		var inner_pts: Array[Vector3] = [corner.call(-inner, -inner), corner.call(inner, -inner),
			corner.call(inner, inner), corner.call(-inner, inner)]
		_add_quad(st, n, FACE_COLOR, inner_pts[0], inner_pts[1], inner_pts[2], inner_pts[3])
		for k in 4:
			var k2 := (k + 1) % 4
			_add_quad(st, n, EDGE_COLOR, outer_pts[k], outer_pts[k2], inner_pts[k2], inner_pts[k])
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.6
	st.set_material(mat)
	return st.commit()


## Cuadrilátero a-b-c-d (esquinas en orden antihorario visto desde fuera de
## la cara de normal `n`), en dos triángulos con el orden de Godot.
static func _add_quad(st: SurfaceTool, n: Vector3, color: Color,
		a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for p in [a, c, b, a, d, c]:
		st.set_color(color)
		st.set_normal(n)
		st.add_vertex(p)
