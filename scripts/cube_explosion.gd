class_name CubeExplosion
extends Node3D
## Explosión del cubo al morir: el cubo se hincha un instante y revienta en
## GRID³ pedazos que conservan los colores de sus caras. Los pedazos saltan
## hacia fuera, caen, rebotan en el suelo girando y al final se encogen hasta
## desaparecer. Al terminar emite `finished` y se libera sola. Si el cubo
## explota en el vacío (sin suelo), los pedazos siguen cayendo sin rebotar.
##
## Se crea con create(); el nodo es top_level y se coloca en el centro del
## cubo (en coordenadas globales).

signal finished

## Hinchado previo al reventón.
const SWELL_TIME := 0.12
const SWELL_SCALE := 1.18
const GRID := 3
const GRAVITY := 16.0
## Rebote contra el suelo: fracción de velocidad vertical que conserva y
## frenado horizontal en cada bote.
const BOUNCE := 0.35
const FRICTION := 0.55
const OUT_SPEED_MIN := 1.0
const OUT_SPEED_MAX := 2.4
const UP_SPEED_MIN := 2.5
const UP_SPEED_MAX := 4.5
const SPIN_MAX := 12.0
## Duración total (después del hinchado) y tramo final en que se encogen.
const LIFETIME := 1.5
const SHRINK_TIME := 0.4

var _swell: MeshInstance3D
var _pieces: Array[Dictionary] = []
var _piece_mesh: Mesh
var _body_basis := Basis.IDENTITY
var _size := 1.0
var _has_floor := true
var _time := 0.0
var _burst := false
var _rng := RandomNumberGenerator.new()


## `body_mesh` es la malla del cubo (para el hinchado), `piece_mesh` la de un
## pedazo (un cubo con los mismos colores por cara), `basis` la orientación
## del cubo, `size` su lado y `has_floor` si hay suelo debajo para rebotar.
static func create(body_mesh: Mesh, piece_mesh: Mesh, basis: Basis, size: float,
		has_floor := true) -> CubeExplosion:
	var explosion := CubeExplosion.new()
	explosion._has_floor = has_floor
	explosion.top_level = true
	explosion._piece_mesh = piece_mesh
	explosion._body_basis = basis
	explosion._size = size
	explosion._swell = MeshInstance3D.new()
	explosion._swell.mesh = body_mesh
	explosion._swell.basis = basis
	explosion.add_child(explosion._swell)
	return explosion


func _ready() -> void:
	_rng.randomize()


func _process(delta: float) -> void:
	_time += delta
	if not _burst:
		var t := minf(_time / SWELL_TIME, 1.0)
		_swell.basis = _body_basis.scaled(Vector3.ONE * lerpf(1.0, SWELL_SCALE, t))
		if t >= 1.0:
			_spawn_pieces()
		return
	var age := _time - SWELL_TIME
	var shrink := clampf((LIFETIME - age) / SHRINK_TIME, 0.0, 1.0)
	for piece in _pieces:
		_update_piece(piece, delta, shrink)
	if age >= LIFETIME:
		finished.emit()
		queue_free()


func _spawn_pieces() -> void:
	_burst = true
	_swell.queue_free()
	var step := _size / GRID
	for x in GRID:
		for y in GRID:
			for z in GRID:
				var local := (Vector3(x, y, z) - Vector3.ONE * (GRID - 1) * 0.5) * step
				var offset := _body_basis * local
				var node := MeshInstance3D.new()
				node.mesh = _piece_mesh
				node.basis = _body_basis
				node.position = offset
				add_child(node)
				var out := Vector3(offset.x, 0, offset.z)
				out = out.normalized() if out.length() > 0.01 \
					else Vector3.FORWARD.rotated(Vector3.UP, _rng.randf() * TAU)
				_pieces.append({
					"node": node,
					"velocity": out * _rng.randf_range(OUT_SPEED_MIN, OUT_SPEED_MAX)
						+ Vector3.UP * _rng.randf_range(UP_SPEED_MIN, UP_SPEED_MAX),
					"axis": Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1),
						_rng.randf_range(-1, 1)).normalized(),
					"spin": _rng.randf_range(-SPIN_MAX, SPIN_MAX),
					"half": step * 0.5,
				})


func _update_piece(piece: Dictionary, delta: float, shrink: float) -> void:
	var node: MeshInstance3D = piece["node"]
	var velocity: Vector3 = piece["velocity"]
	velocity.y -= GRAVITY * delta
	node.position += velocity * delta
	# El suelo está a la altura del origen del cubo menos medio lado.
	var floor_y: float = -_size * 0.5 + piece["half"]
	if _has_floor and node.position.y < floor_y and velocity.y < 0.0:
		node.position.y = floor_y
		velocity.y = -velocity.y * BOUNCE
		velocity.x *= FRICTION
		velocity.z *= FRICTION
		piece["spin"] *= FRICTION
	piece["velocity"] = velocity
	node.basis = Basis(piece["axis"], piece["spin"] * delta) * node.basis.orthonormalized()
	node.scale = Vector3.ONE * shrink
