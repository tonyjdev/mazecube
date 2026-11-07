class_name RollingCube
extends Node3D
## Cubo que avanza automáticamente volcando 90° sobre la arista inferior.
##
## Estado lógico: casilla actual, rumbo y orientación de las caras (la base
## del nodo Body). El nodo raíz se queda en el centro de la casilla, a ras de
## suelo, y solo Body se anima durante el vuelco.

signal reached_goal
signal bounced(cell: Vector2i)
signal rolled(cell: Vector2i)

const TURN_LEFT := -1
const TURN_RIGHT := 1
const HALF := 0.5
const ARROW_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const ARROW_REJECTED_COLOR := Color(0.95, 0.2, 0.2, 0.95)

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

	# Rebote: si la casilla siguiente es pared o borde, el rumbo se invierte
	# al instante y el cubo sigue rodando en sentido contrario, sin pararse.
	if not level.is_walkable(cell + heading):
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
	_tween.tween_method(_apply_roll.bind(start, pivot, axis, dir, PI * 0.5), 0.0, 1.0, roll_duration) \
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
	_update_arrow(Vector3.ZERO)
	rolled.emit(cell)
	if cell == level.goal_cell:
		is_finished = true
		_arrow.visible = false
		reached_goal.emit()
	else:
		_cooldown = pause_between_rolls


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
	_flash_tween = create_tween()
	_flash_tween.tween_interval(rejected_turn_flash)
	_flash_tween.tween_callback(func() -> void:
		_clear_rejected_flash()
		_update_arrow(_body_offset()))


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
	_arrow.global_transform = Transform3D(base, global_position + offset + dir * 0.1 + Vector3(0, 1.35, 0))
	_arrow.visible = not is_finished


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
