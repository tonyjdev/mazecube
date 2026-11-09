class_name Blocker
extends Enemy
## Obstáculo: un dodecaedro verde azulado que intenta cortarle el paso al cubo.
##
## No mata: es sólido, como un muro. El cubo rebota contra él, los giros
## hacia él se descartan y los demás enemigos no pueden atravesarlo.
##
## Se anticipa al jugador: calcula el camino más corto del cubo hasta la meta
## (como si las puertas y los muros destructibles estuvieran abiertos, pero
## respetando los barrotes cerrados, y contando con los teletransportes: al
## entrar en uno, el cubo sigue desde su pareja, y tarda lo que dura el
## teletransporte) y busca la casilla de ese camino a la
## que puede llegar antes que el cubo, la más cercana a él. Si ya está sobre
## el camino, se queda quieto bloqueándolo; cuando el cubo cambia de zona y
## su camino deja de pasar por él, vuelve a moverse. Si no puede ganar la
## carrera a ninguna casilla, va hacia la que menos ventaja le saque el cubo.
##
## No vigila siempre: tiene una paciencia al azar (entre MIN_PATIENCE y
## MAX_BLOCK_TIME segundos). Cuando lleva ese tiempo quieto en la misma
## casilla, se aburre y se va a dar una vuelta por casillas al azar cercanas
## durante ROAM_MIN_TIME-ROAM_MAX_TIME segundos, sin hacer caso al cubo; luego
## vuelve a vigilar. Así nunca bloquea una misma casilla más de
## MAX_BLOCK_TIME segundos seguidos y el jugador siempre tiene ocasión de pasar.
##
## Repiensa su objetivo cada THINK_TIME segundos (su tiempo de reacción). Es
## más lento que el cubo, así que se le puede dejar atrás. Los barrotes lo
## detienen igual que al cubo: sirven para encerrarlo o dejarlo fuera.

const STEP_TIME := 0.55
const THINK_TIME := 0.35
const RADIUS := 0.4
const COLOR := Color(0.22, 0.62, 0.55)
const PARKED_COLOR := Color(0.15, 0.46, 0.41)
## Giro (rad/s) mientras se mueve.
const SPIN_SPEED := 3.0
## Pedazos en los que se rompe al destruirlo (ver _add_debris).
const DEBRIS_PIECES := 12
## Paciencia: segundos que aguanta quieto en una misma casilla (al azar entre
## estos dos valores) antes de irse a dar una vuelta.
const MIN_PATIENCE := 3.0
const MAX_BLOCK_TIME := 8.0
## Duración de la vuelta y distancia (en pasos) de las casillas a las que va.
const ROAM_MIN_TIME := 2.5
const ROAM_MAX_TIME := 5.0
const ROAM_MIN_STEPS := 3
const ROAM_MAX_STEPS := 7

var _target := Level.NO_CELL
var _think_left := 0.0
var _parked := false
var _roaming := false
var _roam_left := 0.0
## Segundos que lleva quieto en la casilla actual.
var _still_time := 0.0
var _patience := 0.0
var _rng := RandomNumberGenerator.new()
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D

## Último camino previsto del cubo (ver _predicted_route), compartido por
## todos los obstáculos: [id del Level, casilla del cubo, Level.topology_version()]
## y el camino.
static var _route_key := []
static var _route_cache: Array[Vector2i] = []

## Malla que comparten todos los obstáculos (el material es de cada uno
## porque se oscurece al quedarse quieto).
static var _shared_mesh: ArrayMesh


func _init() -> void:
	lethal = false
	solid = true
	step_time = STEP_TIME
	float_height = RADIUS * 0.93
	_rng.randomize()
	_patience = _rng.randf_range(MIN_PATIENCE, MAX_BLOCK_TIME)
	# Cada obstáculo piensa en un momento distinto, para que no coincidan
	# todos en el mismo frame.
	_think_left = _rng.randf_range(0.0, THINK_TIME)


func on_cube_died() -> void:
	_target = Level.NO_CELL
	_think_left = THINK_TIME


func _process(delta: float) -> void:
	_think_left -= delta
	_roam_left -= delta
	_still_time = 0.0 if _moving else _still_time + delta
	super(delta)


func _choose_next() -> Vector2i:
	if cube == null or not cube.is_alive() or cube.is_finished:
		_set_parked(true)
		return cell
	if not _roaming and _still_time >= _patience:
		_roaming = true
		_roam_left = _rng.randf_range(ROAM_MIN_TIME, ROAM_MAX_TIME)
		_target = cell
	if _roaming:
		if _roam_left <= 0.0:
			# Vuelve a vigilar con una paciencia nueva.
			_roaming = false
			_patience = _rng.randf_range(MIN_PATIENCE, MAX_BLOCK_TIME)
			_target = Level.NO_CELL
		else:
			_set_parked(false)
			# Al llegar (o si se queda atascado), elige otra casilla.
			if _target == cell or _still_time >= 1.0:
				_target = _pick_roam_target()
			return _first_step_towards(_target, _can_enter)
	if _think_left <= 0.0 or _target == Level.NO_CELL:
		_think_left = THINK_TIME
		_target = _pick_target()
	_set_parked(_target == cell)
	if _target == cell:
		return cell
	return _first_step_towards(_target, _can_enter)


## Nunca entra en las casillas del cubo (ni en la que está ni en la que va).
func _can_enter(target: Vector2i) -> bool:
	return super(target) and not (cube and cube.occupies(target))


func _pick_target() -> Vector2i:
	var route := _predicted_route()
	if route.is_empty() or route.has(cell):
		return cell
	var mine := _distances(cell, _passable)
	var cube_step := cube.step_time()
	var best := cell
	var best_score := INF
	# Lo que tarda el cubo en llegar a cada casilla del camino: un paso por
	# casilla y, al pasar por un teletransporte, lo que dura en lugar del paso
	# de la casilla de destino.
	var cube_time := 0.0
	for i in route.size():
		var target := route[i]
		if i > 0 and level.teleport_partner(route[i - 1]) == target:
			cube_time += RollingCube.teleport_duration()
		else:
			cube_time += cube_step
		if not mine.has(target):
			continue
		var margin: float = cube_time - mine[target] * step_time
		var score: float = mine[target] if margin > 0.0 else 100000.0 - margin
		if score < best_score:
			best_score = score
			best = target
	return best


## Casilla al azar a la que ir de paseo: a entre ROAM_MIN_STEPS y
## ROAM_MAX_STEPS pasos, mejor si está fuera del camino del cubo. Si no hay
## ninguna así, cualquier otra alcanzable; si no puede ir a ninguna, la suya.
func _pick_roam_target() -> Vector2i:
	var dist := _distances(cell, _can_enter, ROAM_MAX_STEPS)
	var route := _predicted_route()
	var preferred: Array[Vector2i] = []
	var others: Array[Vector2i] = []
	for target: Vector2i in dist:
		if target == cell:
			continue
		if dist[target] >= ROAM_MIN_STEPS and not route.has(target):
			preferred.append(target)
		else:
			others.append(target)
	var pool := preferred if not preferred.is_empty() else others
	if pool.is_empty():
		return cell
	return pool[_rng.randi_range(0, pool.size() - 1)]


## Casillas por las que pasará el cubo camino de la meta (sin contar la suya).
## Solo depende de la casilla del cubo y de los barrotes y puentes, así que se
## reutiliza mientras no cambien.
func _predicted_route() -> Array[Vector2i]:
	var key := [level.get_instance_id(), cube.cell, level.topology_version()]
	if key != _route_key:
		_route_key = key
		_route_cache = _compute_route()
	return _route_cache


func _compute_route() -> Array[Vector2i]:
	var from := cube.cell
	var goal := level.goal_cell
	var route := _cube_path(from, goal, func(c: Vector2i) -> bool:
		return level.has_floor(c) and not level.bars_closed(c))
	if route.is_empty():
		route = _cube_path(from, goal, level.has_floor)
	return route


## Como _path, pero por donde puede ir el cubo: al entrar en una casilla de
## teletransporte sigue desde su pareja (el camino incluye las dos).
func _cube_path(from: Vector2i, goal: Vector2i, can_pass: Callable) -> Array[Vector2i]:
	var came := {from: from}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size() and not came.has(goal):
		var current: Vector2i = queue[head]
		head += 1
		for dir in DIRS:
			var n := current + dir
			if came.has(n) or not can_pass.call(n):
				continue
			came[n] = current
			var partner := level.teleport_partner(n)
			if partner == Level.NO_CELL:
				queue.append(n)
			elif not came.has(partner):
				came[partner] = n
				queue.append(partner)
	var path: Array[Vector2i] = []
	if not came.has(goal) or goal == from:
		return path
	var step := goal
	while step != from:
		path.push_front(step)
		step = came[step]
	return path


func _set_parked(parked: bool) -> void:
	if parked == _parked or _mat == null:
		return
	_parked = parked
	_mat.albedo_color = PARKED_COLOR if parked else COLOR


func _dissolve_color() -> Color:
	return COLOR.lightened(0.35)


func _build_visual() -> Node3D:
	var root := Node3D.new()
	_mat = _make_material(COLOR)
	_mat.roughness = 0.8
	if _shared_mesh == null:
		_shared_mesh = _build_dodecahedron(RADIUS, null)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _shared_mesh
	_mesh.set_surface_override_material(0, _mat)
	root.add_child(_mesh)
	return root


## Sintético: se rompe en dodecaedros pequeños (su misma forma) con un sonido
## de cristal y metal.
func _add_debris(debris: EnemyDebris, center: Vector3) -> void:
	_burst(debris, _mesh.mesh, _mat, center, DEBRIS_PIECES, 0.2, 0.42, RADIUS, RADIUS * 0.4, 1.8, 3.8, false)


func _animate(delta: float) -> void:
	if _moving:
		# Rueda un poco en la dirección del paso.
		var axis := Vector3.UP.cross(Vector3(heading.x, 0, heading.y))
		if axis.length() > 0.01:
			_mesh.rotate(axis.normalized(), SPIN_SPEED * delta)


## Dodecaedro regular de caras planas con vértices a `radius` del centro.
## Cada cara es la de los cinco vértices más alineados con su normal: las
## doce normales son (0, ±φ, ±1), (±φ, ±1, 0) y (±1, 0, ±φ) (un icosaedro).
static func _build_dodecahedron(radius: float, mat: Material) -> ArrayMesh:
	var phi := (1.0 + sqrt(5.0)) * 0.5
	var inv := 1.0 / phi
	var verts: Array[Vector3] = []
	for x: float in [-1.0, 1.0]:
		for y: float in [-1.0, 1.0]:
			for z: float in [-1.0, 1.0]:
				verts.append(Vector3(x, y, z))
	for a: float in [-1.0, 1.0]:
		for b: float in [-1.0, 1.0]:
			verts.append(Vector3(0, a * inv, b * phi))
			verts.append(Vector3(a * inv, b * phi, 0))
			verts.append(Vector3(a * phi, 0, b * inv))
	var normals: Array[Vector3] = []
	for a: float in [-1.0, 1.0]:
		for b: float in [-1.0, 1.0]:
			normals.append(Vector3(0, a * phi, b).normalized())
			normals.append(Vector3(a * phi, b, 0).normalized())
			normals.append(Vector3(a, 0, b * phi).normalized())
	var factor := radius / sqrt(3.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in normals:
		var face: Array[Vector3] = verts.duplicate()
		face.sort_custom(func(p: Vector3, q: Vector3) -> bool: return p.dot(n) > q.dot(n))
		face.resize(5)
		# Ordena los vértices alrededor de la normal y triangula en abanico.
		var first: Vector3 = face[0]
		var u := (first - n * first.dot(n)).normalized()
		var v := n.cross(u)
		face.sort_custom(func(p: Vector3, q: Vector3) -> bool:
			return atan2(p.dot(v), p.dot(u)) < atan2(q.dot(v), q.dot(u)))
		for i in range(1, 4):
			_add_flat_triangle(st, face[0] * factor, face[i] * factor, face[i + 1] * factor)
	st.set_material(mat)
	return st.commit()
