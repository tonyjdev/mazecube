class_name Blocker
extends Enemy
## Obstáculo: un dodecaedro verde azulado que intenta cortarle el paso al cubo.
##
## No mata: es sólido, como un muro. El cubo rebota contra él, los giros
## hacia él se descartan y los demás enemigos no pueden atravesarlo.
##
## Se anticipa al jugador: calcula el camino más corto del cubo hasta la meta
## (como si las puertas y los muros destructibles estuvieran abiertos, pero
## respetando los barrotes cerrados) y busca la casilla de ese camino a la
## que puede llegar antes que el cubo, la más cercana a él. Si ya está sobre
## el camino, se queda quieto bloqueándolo; cuando el cubo cambia de zona y
## su camino deja de pasar por él, vuelve a moverse. Si no puede ganar la
## carrera a ninguna casilla, va hacia la que menos ventaja le saque el cubo.
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

var _target := Level.NO_CELL
var _think_left := 0.0
var _parked := false
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D


func _init() -> void:
	lethal = false
	solid = true
	step_time = STEP_TIME
	float_height = RADIUS * 0.93


func on_cube_died() -> void:
	_target = Level.NO_CELL
	_think_left = THINK_TIME


func _process(delta: float) -> void:
	_think_left -= delta
	super(delta)


func _choose_next() -> Vector2i:
	if cube == null or not cube.is_alive() or cube.is_finished:
		_set_parked(true)
		return cell
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
	for i in route.size():
		var target := route[i]
		if not mine.has(target):
			continue
		# El cubo llega a route[i] en i + 1 pasos.
		var margin: float = (i + 1) * cube_step - mine[target] * step_time
		var score: float = mine[target] if margin > 0.0 else 100000.0 - margin
		if score < best_score:
			best_score = score
			best = target
	return best


## Casillas por las que pasará el cubo camino de la meta (sin contar la suya).
func _predicted_route() -> Array[Vector2i]:
	var from := cube.cell
	var goal := level.goal_cell
	var route := _path(from, goal, func(c: Vector2i) -> bool:
		return level.has_floor(c) and not level.bars_closed(c))
	if route.is_empty():
		route = _path(from, goal, level.has_floor)
	return route


func _set_parked(parked: bool) -> void:
	if parked == _parked or _mat == null:
		return
	_parked = parked
	_mat.albedo_color = PARKED_COLOR if parked else COLOR


func _build_visual() -> Node3D:
	var root := Node3D.new()
	_mat = _make_material(COLOR)
	_mat.roughness = 0.8
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _build_dodecahedron(RADIUS, _mat)
	root.add_child(_mesh)
	return root


func _animate(delta: float) -> void:
	if _moving:
		# Rueda un poco en la dirección del paso.
		var axis := Vector3.UP.cross(Vector3(heading.x, 0, heading.y))
		if axis.length() > 0.01:
			_mesh.rotate(axis.normalized(), SPIN_SPEED * delta)


## Dodecaedro regular de caras planas con vértices a `radius` del centro.
## Cada cara es la de los cinco vértices más alineados con uno de los doce
## vértices de un icosaedro (las normales de las caras del dodecaedro).
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
			normals.append(Vector3(0, a, b * phi).normalized())
			normals.append(Vector3(a, b * phi, 0).normalized())
			normals.append(Vector3(a * phi, 0, b).normalized())
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
