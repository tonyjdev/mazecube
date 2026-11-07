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
## Se ha pedido un giro hacia una casilla bloqueada y se ha descartado.
signal turn_rejected(direction: Vector2i)
signal power_up_picked(power_up: PowerUp, stacks: int)
signal power_up_ended(power_up: PowerUp)

const TURN_LEFT := -1
const TURN_RIGHT := 1
const HALF := 0.5
const ARROW_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const ARROW_REJECTED_COLOR := Color(0.95, 0.2, 0.2, 0.95)
## Altura sobre el suelo de la flecha y de la llave que lleva el cubo.
const ARROW_HEIGHT := 1.35
const HELD_KEY_HEIGHT := 2.05

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
var _rolling := false
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
	_body.mesh = _build_colored_cube(0.98)
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
	_drop_held_key()
	_end_all_power_ups()
	_clear_rejected_flash()
	_rolling = false
	_cooldown = 0.3
	is_finished = false
	global_position = level.cell_to_world(cell)
	_body.transform = Transform3D(Basis.IDENTITY, Vector3(0, HALF, 0))
	_update_arrow(Vector3.ZERO)


## Registra un giro relativo al rumbo actual (izquierda o derecha).
func request_turn(direction: int) -> void:
	if is_finished:
		return
	_clear_rejected_flash()
	_pending_turn = direction
	_update_arrow(_body_offset())


func _process(delta: float) -> void:
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
	# Un giro solo se aplica si la casilla en esa dirección está libre; si no,
	# se descarta y el cubo sigue con su rumbo actual.
	if _pending_turn != 0:
		var candidate := turned(heading, _pending_turn)
		_pending_turn = 0
		if level.is_walkable(cell + candidate):
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
	if not level.is_walkable(ahead):
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
	if level.is_walkable(next):
		_roll_to(next)


func _roll_to(next: Vector2i) -> void:
	_rolling = true
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


func _apply_roll(t: float, start: Transform3D, pivot: Vector3, axis: Vector3, arrow_dir: Vector3, angle: float) -> void:
	var rot := Basis(axis, angle * t)
	_body.transform = Transform3D(rot * start.basis, pivot + rot * (start.origin - pivot))
	_update_arrow(arrow_dir * t)


func _on_roll_finished(next: Vector2i) -> void:
	cell = next
	global_position = level.cell_to_world(cell)
	_body.transform = Transform3D(_snap_basis(_body.transform.basis), Vector3(0, HALF, 0))
	_rolling = false
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


func _clear_rejected_flash() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_rejected_dir = Vector2i.ZERO
	_arrow_mat.albedo_color = ARROW_COLOR


## Flecha flotante sobre el cubo que indica el rumbo, el giro pendiente o,
## en rojo, el giro descartado.
func _update_arrow(offset: Vector3) -> void:
	var shown := heading
	if _pending_turn != 0:
		shown = turned(heading, _pending_turn)
	elif _rejected_dir != Vector2i.ZERO:
		shown = _rejected_dir
	var dir := Vector3(shown.x, 0, shown.y)
	var base := Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.RIGHT, -PI * 0.5)
	_arrow.global_transform = Transform3D(base, global_position + offset + dir * 0.1 + Vector3(0, ARROW_HEIGHT, 0))
	_arrow.visible = show_arrow and not is_finished
	if _held_key_node:
		_held_key_node.global_position = global_position + offset + Vector3(0, HELD_KEY_HEIGHT, 0)


static func _snap_basis(b: Basis) -> Basis:
	var cols: Array[Vector3] = [b.x, b.y, b.z]
	for i in cols.size():
		cols[i] = Vector3(roundf(cols[i].x), roundf(cols[i].y), roundf(cols[i].z))
	return Basis(cols[0], cols[1], cols[2])


## Cubo con un color distinto por cara para que se vea claramente el vuelco.
static func _build_colored_cube(size: float) -> ArrayMesh:
	var h := size * 0.5
	var faces := [
		[Vector3.RIGHT, Color(0.90, 0.30, 0.30)],
		[Vector3.LEFT, Color(0.30, 0.70, 0.95)],
		[Vector3.UP, Color(0.98, 0.85, 0.30)],
		[Vector3.DOWN, Color(0.55, 0.40, 0.85)],
		[Vector3.BACK, Color(0.35, 0.80, 0.45)],
		[Vector3.FORWARD, Color(0.98, 0.60, 0.25)],
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		var n: Vector3 = face[0]
		var color: Color = face[1]
		var u := (n.cross(Vector3.UP) if absf(n.y) < 0.5 else n.cross(Vector3.RIGHT)).normalized()
		var v := n.cross(u)
		var corner := func(a: float, b: float) -> Vector3: return (n + u * a + v * b) * h
		# Orden horario visto desde fuera (cara frontal en Godot).
		for p in [corner.call(-1, -1), corner.call(1, 1), corner.call(1, -1),
				corner.call(-1, -1), corner.call(-1, 1), corner.call(1, 1)]:
			st.set_color(color)
			st.set_normal(n)
			st.add_vertex(p)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.6
	st.set_material(mat)
	return st.commit()


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
