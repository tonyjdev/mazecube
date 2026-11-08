class_name RollingCube
extends Node3D
## Cubo que avanza automáticamente volcando 90° sobre la arista inferior.
##
## Estado lógico: casilla actual, rumbo y orientación de las caras (la base
## del nodo Body). El nodo raíz se queda en el centro de la casilla, a ras de
## suelo, y solo Body se anima durante el vuelco.
##
## Llaves y puertas: el cubo coge una llave al llegar a su casilla (solo puede
## llevar una; si ya lleva otra, no pasa nada). La llave que lleva se muestra
## encima del cubo. Una puerta cerrada es un obstáculo como una pared: los
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
## Enemigos: si un perseguidor o un patrullero lo toca (lo comprueba Level),
## el cubo explota en pedazos de sus colores (ver CubeExplosion) y, cuando
## termina la explosión, vuelve a su casilla de salida con el rumbo inicial. Conserva la
## llave que llevaba, pierde los power ups y el tablero se queda como estaba.
## Al reaparecer parpadea y es invulnerable durante RESPAWN_GRACE segundos. Un
## obstáculo es como una pared. Si queda encajonado (bloqueado delante y
## detrás), rebota en su casilla a ritmo de vuelco hasta que se libere el paso.
##
## Vacío: las casillas de vacío no son obstáculos (el cubo no rebota y los
## giros hacia ellas se aceptan). Si el cubo entra en una, vuelca por el
## borde, cae girando y, tras FALL_TIME segundos, explota en el aire; cuando
## termina la explosión vuelve a la salida como si lo hubiera matado un
## enemigo. Se cae aunque esté en el tiempo de invulnerabilidad.
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
signal power_up_picked(power_up: PowerUp, stacks: int)
signal power_up_ended(power_up: PowerUp)
## Un enemigo ha matado al cubo en esa casilla, o ha explotado tras caer al
## vacío desde ella.
signal died(cell: Vector2i)
## El cubo ha empezado a caer al vacío desde esa casilla (explotará después).
signal fell(cell: Vector2i)
## El cubo ha vuelto a la salida tras morir.
signal respawned

const TURN_LEFT := -1
const TURN_RIGHT := 1
const HALF := 0.5
const ARROW_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const ARROW_REJECTED_COLOR := Color(0.95, 0.2, 0.2, 0.95)
## Altura sobre el suelo de la flecha y de la llave que lleva el cubo.
const ARROW_HEIGHT := 1.35
const HELD_KEY_HEIGHT := 2.05
## Media vuelta: tiempo que el cubo se queda parado.
const REVERSE_PAUSE := 0.2
## Humo de la media vuelta: bocanadas por cada lado de la base que salen hacia
## fuera, crecen y se desvanecen.
const REVERSE_SMOKE_COLOR := Color(0.38, 0.39, 0.42)
const REVERSE_SMOKE_PUFFS := 10
const REVERSE_SMOKE_LIFETIME := 0.8
## Muerte: invulnerabilidad al reaparecer en la salida
## (con parpadeo de RESPAWN_BLINK segundos por ciclo).
const RESPAWN_GRACE := 1.5
const RESPAWN_BLINK := 0.12
## Caída al vacío: tiempo de caída libre hasta explotar, gravedad, velocidad
## inicial (hacia delante y hacia abajo) y giro (rad/s) al salir del borde.
const FALL_TIME := 0.6
const FALL_GRAVITY := 11.0
const FALL_FORWARD_SPEED := 1.0
const FALL_DOWN_SPEED := 0.8
const FALL_SPIN := 6.5
## Lado del cubo.
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
## Tiempo que la flecha se queda en rojo, señalando el giro descartado.
@export var rejected_turn_flash := 0.35

var level: Level
var cell := Vector2i.ZERO
var heading := Vector2i(1, 0)
var is_finished := false
## Color de la llave que lleva el cubo ("" si no lleva ninguna).
var held_key := ""
## Mostrar la flecha de rumbo sobre el cubo (ajuste de Opciones). Aunque esté
## oculta, los giros descartados se siguen notificando con turn_rejected.
var show_arrow := true:
	set(value):
		show_arrow = value
		if is_node_ready():
			_update_arrow(_body_offset())

## Giro pendiente (TURN_LEFT, TURN_RIGHT o 0). Se aplica en el siguiente
## límite entre casillas si esa dirección está libre; la última pulsación
## sustituye a la anterior.
var _pending_turn := 0
## Media vuelta pendiente: se aplica en el siguiente límite entre casillas y
## sustituye al giro pendiente.
var _pending_reverse := false
var _rolling := false
## Casilla hacia la que está volcando (solo vale mientras _rolling).
var _roll_target := Vector2i.ZERO
var _dead := false
## Cayendo al vacío: vuelco por el borde (_rolling) y caída libre después.
var _falling := false
var _fall_time := 0.0
var _fall_velocity := Vector3.ZERO
var _fall_axis := Vector3.RIGHT
var _explosion: CubeExplosion
## Malla de un pedazo de la explosión (un cubo pequeño con los mismos colores).
var _piece_mesh: Mesh
var _grace_left := 0.0
var _cooldown := 0.0
var _tween: Tween
## Dirección del último giro descartado mientras la flecha está en rojo.
var _rejected_dir := Vector2i.ZERO
var _flash_tween: Tween
var _arrow_mat: StandardMaterial3D
var _held_key_node: Node3D
## Power ups activos: id -> { "power_up": PowerUp, "stacks": int, "time_left": float }
var _power_ups := {}

@onready var _body: MeshInstance3D = $Body
@onready var _arrow: MeshInstance3D = $HeadingArrow


func _ready() -> void:
	_body.mesh = _build_colored_cube(SIZE)
	_piece_mesh = _build_colored_cube(SIZE / CubeExplosion.GRID * 0.94)
	_arrow.top_level = true
	_arrow.mesh = _build_arrow_mesh()
	_arrow_mat = _arrow.mesh.material


func reset(target_level: Level) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	level = target_level
	cell = level.start_cell
	heading = level.start_heading
	_pending_turn = 0
	_pending_reverse = false
	_drop_held_key()
	_end_all_power_ups()
	_clear_rejected_flash()
	_rolling = false
	_cooldown = 0.3
	is_finished = false
	_dead = false
	_grace_left = 0.0
	_body.visible = true
	if is_instance_valid(_explosion):
		_explosion.queue_free()
	_explosion = null
	_falling = false
	global_position = level.cell_to_world(cell)
	_body.transform = Transform3D(Basis.IDENTITY, Vector3(0, HALF, 0))
	_update_arrow(Vector3.ZERO)


## Registra un giro relativo al rumbo actual (izquierda o derecha).
func request_turn(direction: int) -> void:
	if is_finished:
		return
	_clear_rejected_flash()
	_pending_turn = direction
	_pending_reverse = false
	_update_arrow(_body_offset())


## Registra una media vuelta (sustituye al giro pendiente, si lo hay).
func request_reverse() -> void:
	if is_finished:
		return
	_clear_rejected_flash()
	_pending_turn = 0
	_pending_reverse = true
	_update_arrow(_body_offset())


func _process(delta: float) -> void:
	if _falling and not _rolling:
		_process_fall(delta)
	if _dead:
		return
	if _grace_left > 0.0:
		_grace_left -= delta
		_body.visible = _grace_left <= 0.0 or fmod(_grace_left, RESPAWN_BLINK * 2.0) > RESPAWN_BLINK
	_process_power_ups(delta)
	# La llave que lleva el cubo sigue girando sobre sí misma, como en el mapa.
	if _held_key_node:
		_held_key_node.rotate_y(Level.KEY_SPIN_SPEED * delta)
	if level == null or _rolling or is_finished:
		return
	if _cooldown > 0.0:
		_cooldown -= delta
		return
	_try_advance()


func _try_advance() -> void:
	# Media vuelta: el rumbo se invierte como al chocar con una pared y el
	# cubo se queda parado un momento antes de seguir.
	if _pending_reverse:
		_pending_reverse = false
		heading = -heading
		_end_power_ups_on_bounce(false)
		_spawn_reverse_smoke()
		_update_arrow(Vector3.ZERO)
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
		else:
			_flash_rejected_turn(candidate)
		_update_arrow(Vector3.ZERO)

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
			level.open_door(ahead)
			_drop_held_key()
			door_opened.emit(door)
		elif level.breakable_hits(ahead) > 0:
			breakable_hit.emit(ahead, level.hit_breakable(ahead, heading))
		elif level.is_button(ahead):
			level.press_button(ahead)
			button_pressed.emit(ahead)
		_end_power_ups_on_bounce(door_like)
		heading = -heading
		bounced.emit(cell)
		_update_arrow(Vector3.ZERO)

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


## Entra en una casilla de vacío: vuelca por el borde acelerando y luego cae
## (ver _process_fall).
func _fall_to(next: Vector2i) -> void:
	_dead = true
	_falling = true
	_fall_time = 0.0
	_rolling = true
	_roll_target = next
	_pending_turn = 0
	_pending_reverse = false
	_clear_rejected_flash()
	_end_all_power_ups()
	_arrow.visible = false
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
	_pending_turn = 0
	_pending_reverse = false
	_clear_rejected_flash()
	_end_all_power_ups()
	_arrow.visible = false
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


func _apply_roll(t: float, start: Transform3D, pivot: Vector3, axis: Vector3, arrow_dir: Vector3, angle: float) -> void:
	var rot := Basis(axis, angle * t)
	_body.transform = Transform3D(rot * start.basis, pivot + rot * (start.origin - pivot))
	_update_arrow(arrow_dir * t)


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
		held_key = level.take_key(cell)
		_held_key_node = KeyVisual.create(Level.ITEM_COLORS[held_key])
		_held_key_node.top_level = true
		_held_key_node.scale = Vector3.ONE * Level.KEY_SCALE
		add_child(_held_key_node)
		key_picked.emit(held_key)
	var power_up := level.take_power_up(cell)
	if power_up:
		_pick_power_up(power_up)
	_update_arrow(Vector3.ZERO)
	rolled.emit(cell)
	if cell == level.goal_cell:
		is_finished = true
		_arrow.visible = false
		if _held_key_node:
			_held_key_node.visible = false
		reached_goal.emit()
	else:
		_cooldown = pause_between_rolls / speed_multiplier()


## Gira un rumbo 90° a la izquierda o a la derecha. En el tablero "arriba"
## es -Z, así que la izquierda de (0, -1) es (-1, 0).
static func turned(dir: Vector2i, direction: int) -> Vector2i:
	if direction == TURN_LEFT:
		return Vector2i(dir.y, -dir.x)
	return Vector2i(-dir.y, dir.x)


func _body_offset() -> Vector3:
	return Vector3(_body.position.x, 0, _body.position.z)


## La flecha se queda un momento en rojo señalando el giro que no se ha
## podido hacer y luego vuelve al rumbo actual con su color normal.
func _flash_rejected_turn(dir: Vector2i) -> void:
	_clear_rejected_flash()
	_rejected_dir = dir
	_arrow_mat.albedo_color = ARROW_REJECTED_COLOR
	turn_rejected.emit(dir)
	_flash_tween = create_tween()
	_flash_tween.tween_interval(rejected_turn_flash)
	_flash_tween.tween_callback(func() -> void:
		_clear_rejected_flash()
		_update_arrow(_body_offset()))


## Está en el tablero (no ha explotado esperando a reaparecer).
func is_alive() -> bool:
	return not _dead


## Un enemigo puede matarlo ahora: vivo, sin haber llegado a la meta y sin la
## invulnerabilidad de después de reaparecer.
func is_vulnerable() -> bool:
	return not _dead and not is_finished and _grace_left <= 0.0


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
	_pending_turn = 0
	_pending_reverse = false
	_clear_rejected_flash()
	_end_all_power_ups()
	_explosion = CubeExplosion.create(_body.mesh, _piece_mesh, body_basis, SIZE, on_floor)
	_explosion.finished.connect(_respawn)
	add_child(_explosion)
	_explosion.global_position = at
	if on_floor:
		_spawn_dust(at)
	_body.visible = false
	_arrow.visible = false
	if _held_key_node:
		_held_key_node.visible = false
	died.emit(cell)


func _respawn() -> void:
	if not _dead:
		return
	_explosion = null
	_dead = false
	cell = level.start_cell
	heading = level.start_heading
	global_position = level.cell_to_world(cell)
	_body.transform = Transform3D(Basis.IDENTITY, Vector3(0, HALF, 0))
	_body.visible = true
	if _held_key_node:
		_held_key_node.visible = true
	_grace_left = RESPAWN_GRACE
	_cooldown = 0.3
	_update_arrow(Vector3.ZERO)
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


func _clear_rejected_flash() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_rejected_dir = Vector2i.ZERO
	_arrow_mat.albedo_color = ARROW_COLOR


## Flecha flotante sobre el cubo que indica el rumbo, el giro pendiente o,
## en rojo, el giro descartado.
func _update_arrow(offset: Vector3) -> void:
	var shown := heading
	if _pending_reverse:
		shown = -heading
	elif _pending_turn != 0:
		shown = turned(heading, _pending_turn)
	elif _rejected_dir != Vector2i.ZERO:
		shown = _rejected_dir
	var dir := Vector3(shown.x, 0, shown.y)
	var base := Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.RIGHT, -PI * 0.5)
	_arrow.global_transform = Transform3D(base, global_position + offset + dir * 0.1 + Vector3(0, ARROW_HEIGHT, 0))
	_arrow.visible = show_arrow and not is_finished and not _dead
	if _held_key_node:
		_held_key_node.global_position = global_position + offset + Vector3(0, HELD_KEY_HEIGHT, 0)


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


static func _build_arrow_mesh() -> PrismMesh:
	var prism := PrismMesh.new()
	prism.size = Vector3(0.45, 0.4, 0.03)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = ARROW_COLOR
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	prism.material = mat
	return prism
