class_name Coin
extends Node3D
## Moneda que el cubo puede coger (ver Level: spawn_coins, _update_coins).
##
## Sale disparada al azar desde donde se crea (un enemigo destruido o un
## cofre abierto) y se mueve con físicas sencillas: gravedad, botes contra el
## suelo, rozamiento y rebotes contra las casillas por las que no se puede
## pasar (muros, puertas, barrotes, cofres y el vacío, que la frenan como una
## pared invisible). Nunca se aleja más de MAX_SPREAD casillas de su origen.
## Al pararse se queda girando y flotando un poco. Si el suelo desaparece
## bajo ella (cae un puente colgante), cae y desaparece.
##
## El cubo la coge al pasar por encima (a partir de PICKUP_DELAY segundos de
## crearse, para que se vea salir) y, con el imán (Abilities.MAGNET), las
## que están a su alcance vuelan hacia él (attract). Al cogerla sube,
## encoge y desaparece (collect).
##
## Todo en unidades del tablero (1 = una casilla), con el origen del nodo en
## el centro de la moneda.

const RADIUS := 0.19
const THICKNESS := 0.055
const GOLD := Color(1.0, 0.78, 0.18)
const GOLD_LIGHT := Color(1.0, 0.9, 0.45)
const GRAVITY := 14.0
## Velocidad vertical que se conserva en cada bote (y por debajo de la cual
## deja de botar).
const BOUNCE := 0.45
const MIN_BOUNCE_SPEED := 0.9
## Rebote contra una casilla bloqueada (fracción de velocidad conservada).
const WALL_BOUNCE := 0.5
## Frenada en el suelo (fracción de la velocidad horizontal que pierde por
## segundo).
const FRICTION := 4.0
const MAX_SPREAD := 2.6
## Altura del centro de la moneda en reposo (de canto, flotando un poco).
const REST_HEIGHT := RADIUS + 0.06
const PICKUP_DELAY := 0.35
const SPIN_SPEED := 3.2
const HOVER := 0.04
const HOVER_TIME := 1.6
## Velocidad (casillas/s) con la que vuela hacia el cubo con el imán: empieza
## en la primera y acelera hasta la segunda.
const MAGNET_SPEED := Vector2(3.0, 9.0)
const COLLECT_TIME := 0.25

static var _body_mesh: CylinderMesh
static var _face_mesh: CylinderMesh

## Velocidad (casillas/s) y origen en el tablero (x, z).
var velocity := Vector3.ZERO
var origin := Vector2.ZERO
var age := 0.0
var resting := false
## Volando hacia el cubo (imán) y velocidad del vuelo.
var magnetized := false
var _magnet_speed := 0.0
var collected := false
var falling := false
var _spin: Node3D
var _hover_time := 0.0


static func create(at: Vector3, start_velocity: Vector3) -> Coin:
	var coin := Coin.new()
	coin.position = at
	coin.origin = Vector2(at.x, at.z)
	coin.velocity = start_velocity
	return coin


func _ready() -> void:
	if _body_mesh == null:
		_body_mesh = CylinderMesh.new()
		_body_mesh.top_radius = RADIUS
		_body_mesh.bottom_radius = RADIUS
		_body_mesh.height = THICKNESS
		_body_mesh.radial_segments = 18
		_body_mesh.rings = 1
		_body_mesh.material = _make_material(GOLD, 0.25)
		_face_mesh = CylinderMesh.new()
		_face_mesh.top_radius = RADIUS * 0.62
		_face_mesh.bottom_radius = RADIUS * 0.62
		_face_mesh.height = THICKNESS * 1.5
		_face_mesh.radial_segments = 14
		_face_mesh.rings = 1
		_face_mesh.material = _make_material(GOLD_LIGHT, 0.35)
	_spin = Node3D.new()
	_spin.rotation.y = randf() * TAU
	add_child(_spin)
	for mesh: Mesh in [_body_mesh, _face_mesh]:
		var part := MeshInstance3D.new()
		part.mesh = mesh
		# De canto: el eje del cilindro en horizontal.
		part.rotation.x = PI * 0.5
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_spin.add_child(part)
	_hover_time = randf() * HOVER_TIME


## Avanza la física. `blocked` dice si una casilla frena la moneda y
## `has_floor` si tiene suelo debajo.
func update(delta: float, blocked: Callable, has_floor: Callable) -> void:
	age += delta
	_spin.rotate_y(SPIN_SPEED * delta)
	if collected or magnetized:
		return
	var cell := _cell_of(position)
	if not falling and not has_floor.call(cell):
		falling = true
		resting = false
	if falling:
		velocity.y -= GRAVITY * delta
		position += velocity * delta
		if position.y < -4.0:
			queue_free()
		return
	if resting:
		_hover_time = fmod(_hover_time + delta, HOVER_TIME)
		position.y = REST_HEIGHT + sin(TAU * _hover_time / HOVER_TIME) * HOVER
		return
	velocity.y -= GRAVITY * delta
	var next := position + velocity * delta
	# Rebote contra las casillas bloqueadas, por ejes.
	for axis in [0, 2]:
		var probe := position
		probe[axis] = next[axis] + signf(velocity[axis]) * RADIUS
		var probe_cell := _cell_of(probe)
		if probe_cell != cell and blocked.call(probe_cell):
			next[axis] = position[axis]
			velocity[axis] *= -WALL_BOUNCE
	# Sin alejarse demasiado del origen.
	var flat := Vector2(next.x, next.z) - origin
	if flat.length() > MAX_SPREAD:
		flat = flat.normalized() * MAX_SPREAD
		next.x = origin.x + flat.x
		next.z = origin.y + flat.y
		velocity.x *= 0.2
		velocity.z *= 0.2
	if next.y <= REST_HEIGHT:
		next.y = REST_HEIGHT
		if -velocity.y > MIN_BOUNCE_SPEED:
			velocity.y = -velocity.y * BOUNCE
		else:
			velocity.y = 0.0
		var keep := maxf(1.0 - FRICTION * delta, 0.0)
		velocity.x *= keep
		velocity.z *= keep
		if velocity.length() < 0.08:
			velocity = Vector3.ZERO
			resting = true
			_hover_time = 0.0
	position = next


## Se puede coger ya.
func can_pick() -> bool:
	return not collected and not falling and age >= PICKUP_DELAY


## Vuela hacia `target` (el cubo, con el imán), cada vez más deprisa.
## Devuelve la distancia que le queda.
func attract(target: Vector3, delta: float) -> float:
	if not magnetized:
		magnetized = true
		_magnet_speed = MAGNET_SPEED.x
	_magnet_speed = minf(_magnet_speed + (MAGNET_SPEED.y - MAGNET_SPEED.x) * 3.0 * delta, MAGNET_SPEED.y)
	var to := target - position
	var distance := to.length()
	position += to / maxf(distance, 0.001) * minf(_magnet_speed * delta, distance)
	return maxf(distance - _magnet_speed * delta, 0.0)


## La ha cogido el cubo: sube, encoge y desaparece.
func collect() -> void:
	collected = true
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "position:y", position.y + 0.6, COLLECT_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3.ONE * 0.05, COLLECT_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


## Posición en el tablero (x, z).
func board_position() -> Vector2:
	return Vector2(position.x, position.z)


static func _cell_of(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x / Level.CELL_SIZE), roundi(p.z / Level.CELL_SIZE))


static func _make_material(color: Color, glow: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.3
	mat.roughness = 0.35
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = glow
	return mat
