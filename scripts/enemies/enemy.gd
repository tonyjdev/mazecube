class_name Enemy
extends Node3D
## Base de los enemigos: se mueven de casilla en casilla por el tablero.
##
## Cada enemigo decide su siguiente casilla con _choose_next() cuando está
## quieto en una casilla y se desliza hasta ella en `step_time` segundos.
## Mientras se mueve ocupa las dos casillas (la de salida y la de llegada).
##
## Reglas comunes:
## - Solo pisan casillas libres sin puerta, barrotes cerrados ni muro
##   destructible en pie (Level.is_terrain_walkable), y nunca la salida, la
##   meta ni los puentes colgantes (no los desgastan).
## - El obstáculo es sólido para todos: los demás enemigos no entran en sus
##   casillas. Perseguidores y patrulleros sí pueden cruzarse entre ellos.
## - `lethal`: si toca al cubo, el cubo explota (lo comprueba Level).
##
## El nodo es hijo de Level, así que `position` está en coordenadas del
## tablero (casilla * CELL_SIZE).

const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
## Tiempo de espera antes de volver a intentar moverse si el paso está cortado.
const RETRY_TIME := 0.15

var level: Level
## Cubo del jugador (lo asigna Level).
var cube: RollingCube
var cell := Vector2i.ZERO
## Rumbo del último paso (para no dar media vuelta sin motivo y orientar el visual).
var heading := Vector2i.ZERO
## Si toca al cubo, lo mata.
var lethal := true
## Si los demás enemigos y el cubo lo tratan como un obstáculo.
var solid := false
## Segundos que tarda en pasar de una casilla a la siguiente.
var step_time := 0.5
## Altura del centro del visual sobre el suelo.
var float_height := 0.35

var _moving := false
var _from := Vector2i.ZERO
var _to := Vector2i.ZERO
var _t := 0.0
var _wait := 0.0
var _visual: Node3D


func setup(target_level: Level, start: Vector2i) -> void:
	level = target_level
	cell = start
	_from = start
	_to = start
	_visual = _build_visual()
	add_child(_visual)
	_place(Vector2(start))


func _process(delta: float) -> void:
	if level == null:
		return
	if _moving:
		_t = minf(_t + delta / step_time, 1.0)
		var eased := _t * _t * (3.0 - 2.0 * _t)
		_place(Vector2(_from).lerp(Vector2(_to), eased))
		if _t >= 1.0:
			_moving = false
			cell = _to
			_from = _to
			_on_arrived()
	if not _moving:
		if _wait > 0.0:
			_wait -= delta
		else:
			var next := _choose_next()
			if next != cell and _can_enter(next):
				_start_move(next)
			else:
				_wait = RETRY_TIME
	_animate(delta)


## Lo ha alcanzado un dash o un pisotón del cubo (Level ya lo ha quitado de
## su lista): revienta en pedazos (EnemyDebris, que cada tipo llena en
## _add_debris), suena su rotura (_destroy_sound) y desaparece.
func destroy() -> void:
	if level == null:
		return
	var debris := EnemyDebris.new()
	debris.position = position
	level.add_child(debris)
	_add_debris(debris, _visual.position if _visual else Vector3(0, float_height, 0))
	Sfx.play(_destroy_sound(), 0.1)
	level = null
	queue_free()


## Llena `debris` con los pedazos del enemigo; `center` es el centro del
## visual relativo al suelo de su casilla.
func _add_debris(_debris: EnemyDebris, _center: Vector3) -> void:
	pass


## Sonido (ver Sfx) al reventar.
func _destroy_sound() -> String:
	return "shatter"


## Lanza `count` pedazos de `mesh` desde `center` hacia fuera y algo hacia
## arriba: salen a `spread` del centro con una velocidad entre `speed_min` y
## `speed_max` y una escala entre `size_min` y `size_max`.
static func _burst(debris: EnemyDebris, mesh: Mesh, material: Material, center: Vector3,
		count: int, size_min: float, size_max: float, radius: float, spread: float,
		speed_min: float, speed_max: float, organic: bool) -> void:
	for i in count:
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1)).normalized()
		var vel := dir * randf_range(speed_min, speed_max) + Vector3.UP * randf_range(0.8, 2.0)
		debris.add_piece(mesh, material, center + dir * spread, vel,
			randf_range(size_min, size_max), radius, organic)


## Casillas que ocupa ahora mismo (dos mientras se mueve).
func occupies(target: Vector2i) -> bool:
	return target == cell or (_moving and target == _to)


## Posición actual en el tablero (en casillas, con decimales mientras se mueve).
func board_position() -> Vector2:
	return Vector2(position.x, position.z) / Level.CELL_SIZE


## El cubo ha muerto y vuelve a la salida.
func on_cube_died() -> void:
	pass


## Casilla a la que quiere ir (la suya para quedarse quieto). Se vuelve a
## pedir cada RETRY_TIME si la casilla elegida no está libre.
func _choose_next() -> Vector2i:
	return cell


func _on_arrived() -> void:
	pass


## Camino más corto de `cell` a `goal` (sin incluir `cell`; vacío si no hay
## camino).
func _path(from: Vector2i, goal: Vector2i, can_pass: Callable) -> Array[Vector2i]:
	var came := {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty() and not came.has(goal):
		var current: Vector2i = queue.pop_front()
		for dir in DIRS:
			var n := current + dir
			if not came.has(n) and can_pass.call(n):
				came[n] = current
				queue.append(n)
	var path: Array[Vector2i] = []
	if not came.has(goal) or goal == from:
		return path
	var step := goal
	while step != from:
		path.push_front(step)
		step = came[step]
	return path


## Se crea al preparar el enemigo; se coloca a `float_height` del suelo.
func _build_visual() -> Node3D:
	return Node3D.new()


func _animate(_delta: float) -> void:
	pass


## Casilla por la que puede pasar (sin contar a los demás enemigos).
func _passable(target: Vector2i) -> bool:
	return level.is_terrain_walkable(target) and target != level.start_cell \
		and target != level.goal_cell and not level.is_bridge(target)


func _can_enter(target: Vector2i) -> bool:
	return _passable(target) and not level.solid_enemy_at(target, self)


func _start_move(next: Vector2i) -> void:
	heading = next - cell
	_from = cell
	_to = next
	_t = 0.0
	_moving = true


func _place(board: Vector2) -> void:
	position = Vector3(board.x * Level.CELL_SIZE, 0.0, board.y * Level.CELL_SIZE)
	if _visual:
		_visual.position.y = float_height


## Distancias en pasos desde `origin` hasta cada casilla alcanzable (como
## mucho `max_steps`; -1 sin límite) usando `can_pass` para decidir por dónde
## se puede ir. El origen siempre cuenta, aunque `can_pass` lo rechace.
func _distances(origin: Vector2i, can_pass: Callable, max_steps := -1) -> Dictionary:
	var dist := {origin: 0}
	var queue: Array[Vector2i] = [origin]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if max_steps >= 0 and dist[current] >= max_steps:
			continue
		for dir in DIRS:
			var n := current + dir
			if not dist.has(n) and can_pass.call(n):
				dist[n] = dist[current] + 1
				queue.append(n)
	return dist


## Primer paso del camino más corto de `cell` a `goal` (o `cell` si no hay
## camino). Va hacia atrás desde la meta siguiendo las distancias.
func _first_step_towards(goal: Vector2i, can_pass: Callable) -> Vector2i:
	if goal == cell:
		return cell
	var dist := _distances(goal, can_pass)
	var best := cell
	var best_dist: int = 1 << 30
	for dir in DIRS:
		var n := cell + dir
		if dist.has(n) and dist[n] < best_dist:
			best = n
			best_dist = dist[n]
	return best


## Añade a `st` un triángulo plano de un poliedro centrado en el origen, con
## la normal hacia fuera y en orden horario visto desde fuera (cara frontal en
## Godot), sea cual sea el orden en que lleguen los vértices.
static func _add_flat_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	# En orden horario visto desde fuera, este producto apunta hacia dentro.
	if normal.dot(a + b + c) > 0.0:
		var swap := b
		b = c
		c = swap
	else:
		normal = -normal
	for p: Vector3 in [a, b, c]:
		st.set_normal(normal)
		st.add_vertex(p)


static func _make_material(color: Color, emission := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.45
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat
