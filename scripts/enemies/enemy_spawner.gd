class_name EnemySpawner
extends RefCounted
## Punto de origen de enemigos: crea y vuelve a crear los enemigos de un tipo.
##
## Cada enemigo del mapa (x, z, i j k m n) es en realidad un punto de origen
## en esa casilla, sin nada que lo represente en el tablero. Gestiona hasta
## `max_enemies` enemigos activos de su tipo:
## - Al empezar el nivel (cuando el tablero ha terminado de aparecer), cada
##   uno de sus enemigos aparece pasados FIRST_DELAY_MIN-FIRST_DELAY_MAX
##   segundos.
## - Cuando destruyen a uno, vuelve a aparecer otro pasados
##   RESPAWN_DELAY_MIN-RESPAWN_DELAY_MAX segundos.
## - Los enemigos aparecen en una casilla al azar a `radius` casillas de
##   recorrido o menos del origen (contando solo las que pisan los enemigos),
##   libre de otros enemigos, con alguna casilla vecina a la que moverse y a
##   más de CUBE_CLEARANCE casillas de recorrido del cubo. Los patrulleros
##   aparecen siempre en el principio de su ruta (el origen). Si en ese
##   momento no hay ninguna casilla válida, lo vuelve a intentar cada
##   RETRY_TIME segundos.
## - Al aparecer, el enemigo hace su animación de aparición (ver
##   Enemy.start_appearing): 2 s quieto, disolviéndose, sin hacer daño.
##
## El radio, si el nivel no lo fija, se calcula según el espacio que haya
## alrededor del origen (ver auto_radius). El campo "spawners" del nivel
## permite cambiar el número de enemigos y el radio (ver Level).

const MIN_RADIUS := 5
const MAX_RADIUS := 10
## Casillas pisables que debe tener la zona: el radio automático es el menor
## (desde MIN_RADIUS) que llega a esta cantidad, o MAX_RADIUS si no llega.
const AREA_TARGET := 24
const FIRST_DELAY_MIN := 1.0
const FIRST_DELAY_MAX := 2.0
const RESPAWN_DELAY_MIN := 30.0
const RESPAWN_DELAY_MAX := 60.0
const RETRY_TIME := 0.5
## Distancia (en casillas de recorrido) al cubo por debajo de la cual nunca
## aparece un enemigo: tiene que estar a más de esta.
const CUBE_CLEARANCE := 3
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var level: Level
## Símbolo del mapa del tipo de enemigo (ver Level).
var symbol := ""
var origin := Vector2i.ZERO
var max_enemies := 1
var radius := MIN_RADIUS
## Ruta de los patrulleros (ver Patroller.set_route); "" para los demás.
var route := ""
## Enemigos suyos que siguen vivos.
var enemies: Array[Enemy] = []

## Cuenta atrás de cada enemigo que falta por aparecer.
var _pending: Array[float] = []
var _rng := RandomNumberGenerator.new()


func _init(target_level: Level, enemy_symbol: String, cell: Vector2i, count: int,
		area_radius: int, patrol_route := "") -> void:
	level = target_level
	symbol = enemy_symbol
	origin = cell
	max_enemies = maxi(count, 1)
	radius = area_radius
	route = patrol_route
	_rng.randomize()
	for i in max_enemies:
		_pending.append(_rng.randf_range(FIRST_DELAY_MIN, FIRST_DELAY_MAX))


## Es un punto de origen de patrulleros (aparecen siempre en el origen).
func is_patrol() -> bool:
	return Level.PATROL_CHARS.contains(symbol)


func update(delta: float) -> void:
	for i in range(_pending.size() - 1, -1, -1):
		_pending[i] -= delta
		if _pending[i] > 0.0:
			continue
		var cell := _pick_cell()
		if cell == Level.NO_CELL:
			_pending[i] = RETRY_TIME
			continue
		_pending.remove_at(i)
		enemies.append(level.spawn_enemy(self, cell))


## Han destruido a uno de sus enemigos: otro aparecerá dentro de un rato.
func on_enemy_destroyed(enemy: Enemy) -> void:
	enemies.erase(enemy)
	_pending.append(_rng.randf_range(RESPAWN_DELAY_MIN, RESPAWN_DELAY_MAX))


## Casilla al azar donde puede aparecer ahora un enemigo, o Level.NO_CELL.
func _pick_cell() -> Vector2i:
	var near_cube := _cells_near_cube()
	var candidates: Array[Vector2i] = []
	var area: Array = [origin] if is_patrol() \
		else _distances(origin, level.enemy_can_pass, radius).keys()
	for cell: Vector2i in area:
		if level.enemy_can_pass(cell) and not near_cube.has(cell) \
				and not level.enemy_at(cell) and _has_exit(cell):
			candidates.append(cell)
	if candidates.is_empty():
		return Level.NO_CELL
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


## Casillas a CUBE_CLEARANCE pasos o menos del cubo (contando las que ocupa).
func _cells_near_cube() -> Dictionary:
	var cube := level.cube
	if cube == null:
		return {}
	var near := _distances(cube.cell, level.has_floor, CUBE_CLEARANCE)
	near[cube.roll_target()] = 0
	return near


## Tiene al menos una casilla vecina a la que moverse.
func _has_exit(cell: Vector2i) -> bool:
	for dir in DIRS:
		if level.enemy_can_pass(cell + dir) and not level.solid_enemy_at(cell + dir):
			return true
	return false


## Radio según el espacio que hay alrededor de `cell`: el menor entre
## MIN_RADIUS y MAX_RADIUS cuya zona tiene AREA_TARGET casillas pisables por
## los enemigos (con el mapa tal y como empieza).
static func auto_radius(target_level: Level, cell: Vector2i) -> int:
	var dist := _distances(cell, target_level.enemy_can_pass, MAX_RADIUS)
	for r in range(MIN_RADIUS, MAX_RADIUS + 1):
		var count := 0
		for c: Vector2i in dist:
			if dist[c] <= r:
				count += 1
		if count >= AREA_TARGET:
			return r
	return MAX_RADIUS


## Distancias en pasos desde `from` (como mucho `max_steps`) por las casillas
## que acepta `can_pass`. El origen siempre cuenta.
static func _distances(from: Vector2i, can_pass: Callable, max_steps: int) -> Dictionary:
	var dist := {from: 0}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if dist[current] >= max_steps:
			continue
		for dir in DIRS:
			var n := current + dir
			if not dist.has(n) and can_pass.call(n):
				dist[n] = dist[current] + 1
				queue.append(n)
	return dist
