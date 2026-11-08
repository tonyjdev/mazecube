class_name HangingBridge
extends Node3D
## Puente colgante ('=' en el mapa): una fila recta de casillas sobre el vacío
## que une dos zonas con suelo.
##
## Cada casilla tiene su propia estabilidad, que empieza en MAX_STABILITY
## (100 %) y baja un punto (25 %) cada vez que el cubo sale de ella (ver
## Level.cube_left_cell). Cuanto menos estable, más a menudo suelta polvo
## que cae al vacío (ver DUST_*); al 25 % además se balancea un poco cada
## pocos segundos (ver SWAY_*). Cuando una casilla llega a 0 se cae el
## puente entero: las casillas se desprenden una tras otra empezando por la
## que se ha roto, y el cubo que siga encima cae con ellas.
##
## Las coordenadas son las del tablero (Level), en casillas.

const MAX_STABILITY := 4
## Retraso entre la caída de una casilla y la de su vecina.
const CELL_FALL_DELAY := 0.09
const FALL_GRAVITY := 9.0
## Segundos que se ve caer cada casilla antes de quitarla.
const FALL_TIME := 2.2
const FALL_SPIN_MAX := 2.5

## Segundos entre dos sueltas de polvo y partículas por suelta, según la
## estabilidad que le queda a la casilla (a MAX_STABILITY no suelta nada).
const DUST_INTERVAL := {3: Vector2(8.0, 10.0), 2: Vector2(4.0, 7.0), 1: Vector2(1.0, 2.0)}
const DUST_AMOUNT := {3: Vector2i(1, 2), 2: Vector2i(2, 4), 1: Vector2i(4, 7)}
const DUST_LIFETIME := 2.4
const DUST_COLOR := Color(0.86, 0.78, 0.64)

## Vaivén de las casillas al 25 % (estabilidad 1): cada SWAY_INTERVAL
## segundos la casilla se balancea suavemente durante SWAY_TIME segundos:
## se ladea sobre el eje del puente, gira un poco sobre sí misma, cabecea y
## se hunde y desplaza de lado. Cada vaivén elige al azar hacia qué lado
## empieza cada giro. Es solo visual: el cubo no se entera.
const SWAY_STABILITY := 1
const SWAY_INTERVAL := Vector2(3.0, 5.0)
const SWAY_TIME := 1.8
## Oscilaciones por vaivén.
const SWAY_WAVES := 1.5
## Giros máximos (radianes): ladeo sobre el eje del puente (~6°), giro sobre
## la vertical (~3,5°) y cabeceo (~2,5°).
const SWAY_ROLL := 0.10
const SWAY_YAW := 0.06
const SWAY_PITCH := 0.045
## Hundimiento y desplazamiento lateral máximos (en casillas).
const SWAY_DIP := 0.05
const SWAY_SHIFT := 0.04

const PLANK_COLORS: Array[Color] = [Color(0.55, 0.38, 0.22), Color(0.49, 0.33, 0.19), Color(0.60, 0.43, 0.26)]
const ROPE_COLOR := Color(0.78, 0.68, 0.48)
const POST_COLOR := Color(0.38, 0.26, 0.15)
const PLANK_THICKNESS := 0.06
## Separación lateral de las cuerdas desde el eje del puente (el cubo mide
## 0,98: las cuerdas quedan justo por fuera).
const ROPE_OFFSET := 0.54
const ROPE_HEIGHT := 0.32
const POST_HEIGHT := 0.5

static var _materials := {}
static var _dust_material: StandardMaterial3D

## Casillas del puente, de un extremo al otro.
var cells: Array[Vector2i] = []
var is_collapsed := false

var _cell_size := 1.0
var _along := Vector2i.RIGHT
## casilla -> estabilidad que le queda (0..MAX_STABILITY)
var _stability := {}
## casilla -> Node3D con sus tablones y cuerdas
var _cell_nodes := {}
## casilla -> CPUParticles3D
var _dust := {}
## casilla -> segundos hasta la siguiente suelta de polvo
var _dust_wait := {}
## Casillas cayendo: { "node", "delay", "time", "velocity", "axis", "spin" }
var _falling: Array[Dictionary] = []
## casilla -> segundos hasta el siguiente vaivén (solo casillas al 25 %)
var _sway_wait := {}
## casilla -> vaivén en curso: { "time", "roll", "yaw", "pitch" } (los tres
## últimos, el sentido de cada giro: 1 o -1)
var _swaying := {}
var _rng := RandomNumberGenerator.new()


## Prepara el puente. `bridge_cells` tiene que ser una fila recta y ordenada
## en la dirección `along` (Vector2i.RIGHT o Vector2i.DOWN).
func setup(bridge_cells: Array[Vector2i], along: Vector2i, cell_size: float) -> void:
	cells = bridge_cells
	_along = along
	_cell_size = cell_size
	_rng.randomize()
	for i in cells.size():
		var cell := cells[i]
		_stability[cell] = MAX_STABILITY
		var node := _build_cell(i)
		node.position = Vector3(cell.x, 0, cell.y) * _cell_size
		add_child(node)
		_cell_nodes[cell] = node
		var dust := _build_dust()
		node.add_child(dust)
		_dust[cell] = dust
	_add_posts()


func has_cell(cell: Vector2i) -> bool:
	return _stability.has(cell)


## Estabilidad que le queda a la casilla (0..MAX_STABILITY).
func stability(cell: Vector2i) -> int:
	return _stability.get(cell, 0)


## El cubo ha salido de la casilla: pierde un punto de estabilidad. Devuelve
## true si ha llegado a 0 (el puente tiene que caerse).
func wear(cell: Vector2i) -> bool:
	if is_collapsed or not _stability.has(cell):
		return false
	var left: int = maxi(_stability[cell] - 1, 0)
	_stability[cell] = left
	if left == 0:
		return true
	# Una suelta de polvo nada más perder estabilidad y luego al ritmo que le
	# toca.
	_emit_dust(cell)
	_dust_wait[cell] = _random_interval(left)
	if left == SWAY_STABILITY and not _sway_wait.has(cell):
		_sway_wait[cell] = _rng.randf_range(SWAY_INTERVAL.x, SWAY_INTERVAL.y) * 0.5
	return false


## Tira el puente: las casillas caen una tras otra desde `origin` hacia los
## extremos. `first` (si es una casilla del puente) cae a la vez que `origin`:
## es la del cubo, para que caiga junto con su tablón.
func collapse(origin: Vector2i, first := Vector2i(-9999, -9999)) -> void:
	if is_collapsed:
		return
	is_collapsed = true
	var origin_index := cells.find(origin)
	for i in cells.size():
		var cell := cells[i]
		var delay := absi(i - origin_index) * CELL_FALL_DELAY
		if cell == first:
			delay = 0.0
		_falling.append({
			"node": _cell_nodes[cell],
			"delay": delay + _rng.randf_range(0.0, 0.03),
			"time": 0.0,
			"velocity": Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf_range(0.0, 0.4), _rng.randf_range(-0.3, 0.3)),
			"axis": Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.3, 0.3), _rng.randf_range(-1, 1)).normalized(),
			"spin": _rng.randf_range(0.8, FALL_SPIN_MAX) * (1 if _rng.randf() < 0.5 else -1),
		})
		# El polvo que ya iba cayendo sigue su camino aunque el tablón caiga.
		_emit_dust(cell, 8)
	_dust_wait.clear()
	_sway_wait.clear()
	_swaying.clear()


func _process(delta: float) -> void:
	for cell: Vector2i in _dust_wait.keys():
		_dust_wait[cell] -= delta
		if _dust_wait[cell] <= 0.0:
			_emit_dust(cell)
			_dust_wait[cell] = _random_interval(_stability[cell])
	_process_sway(delta)
	for i in range(_falling.size() - 1, -1, -1):
		var item := _falling[i]
		if item["delay"] > 0.0:
			item["delay"] -= delta
			continue
		var node: Node3D = item["node"]
		item["time"] += delta
		var velocity: Vector3 = item["velocity"]
		velocity.y -= FALL_GRAVITY * delta
		item["velocity"] = velocity
		node.position += velocity * delta
		node.rotate(item["axis"], item["spin"] * delta)
		if item["time"] >= FALL_TIME:
			node.queue_free()
			_falling.remove_at(i)


func _process_sway(delta: float) -> void:
	for cell: Vector2i in _sway_wait.keys():
		if _swaying.has(cell):
			continue
		_sway_wait[cell] -= delta
		if _sway_wait[cell] <= 0.0:
			_swaying[cell] = {"time": 0.0, "roll": _random_sign(), "yaw": _random_sign(),
				"pitch": _random_sign()}
	var along := Vector3(_along.x, 0, _along.y)
	var across := Vector3(-_along.y, 0, _along.x)
	for cell: Vector2i in _swaying.keys():
		var node: Node3D = _cell_nodes[cell]
		var sway: Dictionary = _swaying[cell]
		var t: float = sway["time"] + delta
		sway["time"] = t
		var base := Vector3(cell.x, 0, cell.y) * _cell_size
		if t >= SWAY_TIME:
			_swaying.erase(cell)
			_sway_wait[cell] = _rng.randf_range(SWAY_INTERVAL.x, SWAY_INTERVAL.y)
			node.basis = Basis.IDENTITY
			node.position = base
			continue
		# Envolvente suave (empieza y acaba en reposo) por oscilaciones lentas
		# algo desfasadas entre sí para que no parezca un giro rígido.
		var envelope := sin(PI * t / SWAY_TIME)
		var phase := TAU * SWAY_WAVES * t / SWAY_TIME
		var roll: float = SWAY_ROLL * sway["roll"] * envelope * sin(phase)
		var yaw: float = SWAY_YAW * sway["yaw"] * envelope * sin(phase * 0.8 + 0.6)
		var pitch: float = SWAY_PITCH * sway["pitch"] * envelope * sin(phase * 1.3 + 1.2)
		node.basis = Basis(Vector3.UP, yaw) * Basis(along, roll) * Basis(across, pitch)
		node.position = base + Vector3.DOWN * SWAY_DIP * envelope * envelope \
			+ across * SWAY_SHIFT * sway["roll"] * envelope * sin(phase - 0.4) * _cell_size


func _random_sign() -> float:
	return 1.0 if _rng.randf() < 0.5 else -1.0


func _random_interval(left: int) -> float:
	var range_s: Vector2 = DUST_INTERVAL.get(left, Vector2(1.0, 2.0))
	return _rng.randf_range(range_s.x, range_s.y)


func _emit_dust(cell: Vector2i, amount := 0) -> void:
	var dust: CPUParticles3D = _dust.get(cell)
	if dust == null or not is_instance_valid(dust):
		return
	if amount <= 0:
		var span: Vector2i = DUST_AMOUNT.get(_stability.get(cell, 1), Vector2i(4, 7))
		amount = _rng.randi_range(span.x, span.y)
	if dust.amount != amount:
		dust.amount = amount
	dust.restart()


# --- Aspecto -------------------------------------------------------------------

func _build_cell(index: int) -> Node3D:
	var root := Node3D.new()
	var along := Vector3(_along.x, 0, _along.y)
	var across := Vector3(-_along.y, 0, _along.x)
	# Tres tablones atravesados, con una rendija entre ellos.
	for k in 3:
		var plank := _box(_plank_size(along, across), _material(PLANK_COLORS[(index + k) % PLANK_COLORS.size()]))
		plank.position = along * ((k - 1) * 0.33) * _cell_size + Vector3.UP * -PLANK_THICKNESS * 0.5
		# Tablones un poco torcidos para que no parezcan suelo.
		plank.rotate_y(_rng.randf_range(-0.05, 0.05))
		root.add_child(plank)
	# Cuerdas a los lados y tirantes hasta los tablones.
	for side in [-1, 1]:
		var rope := _box(_oriented(along, across, 1.0, 0.035, 0.035), _material(ROPE_COLOR))
		rope.position = across * side * ROPE_OFFSET * _cell_size + Vector3.UP * ROPE_HEIGHT
		root.add_child(rope)
		var hanger := _box(Vector3(0.025, ROPE_HEIGHT, 0.025), _material(ROPE_COLOR))
		hanger.position = across * side * ROPE_OFFSET * _cell_size + Vector3.UP * ROPE_HEIGHT * 0.5
		root.add_child(hanger)
	# Dos largueros bajo los tablones.
	for side in [-1, 1]:
		var beam := _box(_oriented(along, across, 1.0, 0.05, 0.05), _material(POST_COLOR))
		beam.position = across * side * 0.4 * _cell_size + Vector3.UP * (-PLANK_THICKNESS - 0.025)
		root.add_child(beam)
	return root


## Postes en los dos extremos, sobre el borde del suelo (no se caen).
func _add_posts() -> void:
	if cells.is_empty():
		return
	var along := Vector3(_along.x, 0, _along.y)
	var across := Vector3(-_along.y, 0, _along.x)
	var ends := [[cells[0], -1.0], [cells[-1], 1.0]]
	for end in ends:
		var cell: Vector2i = end[0]
		var sign_along: float = end[1]
		var base := Vector3(cell.x, 0, cell.y) * _cell_size + along * sign_along * 0.56 * _cell_size
		for side in [-1, 1]:
			var post := _box(Vector3(0.09, POST_HEIGHT, 0.09), _material(POST_COLOR))
			post.position = base + across * side * ROPE_OFFSET * _cell_size + Vector3.UP * POST_HEIGHT * 0.5
			add_child(post)


func _plank_size(along: Vector3, across: Vector3) -> Vector3:
	return _oriented(along, across, 0.28, PLANK_THICKNESS, 1.06)


## Tamaño de una caja con `length` a lo largo del puente y `width` a lo ancho.
func _oriented(along: Vector3, _across: Vector3, length: float, height: float, width: float) -> Vector3:
	if absf(along.x) > 0.5:
		return Vector3(length, height, width) * Vector3(_cell_size, 1, _cell_size)
	return Vector3(width, height, length) * Vector3(_cell_size, 1, _cell_size)


func _box(size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	return instance


static func _material(color: Color) -> StandardMaterial3D:
	if _materials.has(color):
		return _materials[color]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	_materials[color] = mat
	return mat


## Polvo bajo los tablones: motas pequeñas que caen despacio al vacío.
func _build_dust() -> CPUParticles3D:
	var dust := CPUParticles3D.new()
	dust.local_coords = false
	dust.one_shot = true
	dust.emitting = false
	dust.explosiveness = 0.5
	dust.amount = 2
	dust.lifetime = DUST_LIFETIME
	dust.position = Vector3.UP * (-PLANK_THICKNESS - 0.02)
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(0.42, 0.01, 0.42) * _cell_size
	dust.direction = Vector3.DOWN
	dust.spread = 25.0
	dust.initial_velocity_min = 0.05
	dust.initial_velocity_max = 0.25
	dust.gravity = Vector3(0, -1.6, 0)
	dust.damping_min = 0.2
	dust.damping_max = 0.5
	dust.scale_amount_min = 0.6
	dust.scale_amount_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.95))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	dust.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.1
	quad.material = _get_dust_material()
	dust.mesh = quad
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return dust


static func _get_dust_material() -> StandardMaterial3D:
	if _dust_material:
		return _dust_material
	_dust_material = StandardMaterial3D.new()
	_dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dust_material.vertex_color_use_as_albedo = true
	_dust_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_dust_material.billboard_keep_scale = true
	_dust_material.albedo_color = DUST_COLOR
	return _dust_material
