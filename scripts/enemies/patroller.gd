class_name Patroller
extends Enemy
## Patrullero: un octaedro flotante que recorre siempre la misma ruta.
##
## La ruta se escribe como tramos rectos desde su casilla del mapa, separados
## por espacios: una letra de dirección (R derecha, L izquierda, U arriba,
## D abajo) y el número de casillas. Por ejemplo "R3 D2 L3 U2".
## - Si la ruta acaba en la casilla de partida, es circular: la repite en
##   el mismo sentido sin parar ("R3 D2 L3 U2").
## - Si no, es de ida y vuelta: al llegar al final la recorre al revés
##   ("R4" es una línea recta; "R3 D2" un trayecto con una esquina).
## Su ruta debe tener al menos tres salidas, una de ellas lateral (lo comprueba
## tools/level_solver.py validate), para que el cubo siempre pueda esquivarlo.
## Nunca se sale de la ruta: si la siguiente casilla está cortada (puerta,
## barrotes cerrados, muro destructible u obstáculo), espera a que se libere.

const DIR_LETTERS := {"R": Vector2i.RIGHT, "L": Vector2i.LEFT, "U": Vector2i.UP, "D": Vector2i.DOWN}
const STEP_TIME := 0.55
const SIZE := 0.36
const COLOR := Color(0.62, 0.28, 0.92)
const HOVER_HEIGHT := 0.55
const HOVER_AMPLITUDE := 0.06
const HOVER_SPEED := 3.0
const SPIN_SPEED := 2.2
## Pedazos en los que se rompe al destruirlo (ver _add_debris).
const DEBRIS_PIECES := 12

## Casillas de la ruta, empezando por la de partida. En una ruta circular no
## se repite la de partida al final.
var route: Array[Vector2i] = []
var is_loop := false

var _index := 0
## Índice de la casilla a la que va (se fija al elegirla).
var _next_index := 0
var _direction := 1
var _time := 0.0
var _mesh: MeshInstance3D


func _init() -> void:
	lethal = true
	step_time = STEP_TIME
	float_height = HOVER_HEIGHT


## Convierte la descripción de la ruta en casillas. Devuelve "" si es válida
## o el motivo por el que no lo es.
func set_route(start: Vector2i, description: String) -> String:
	route = [start]
	is_loop = false
	var current := start
	for part in description.split(" ", false):
		var letter := part.substr(0, 1).to_upper()
		var count := part.substr(1).to_int()
		if not DIR_LETTERS.has(letter) or count <= 0:
			return "tramo '%s' no válido" % part
		for i in count:
			current += DIR_LETTERS[letter]
			route.append(current)
	if route.size() > 2 and route[-1] == start:
		route.pop_back()
		is_loop = true
	_index = 0
	_next_index = 0
	_direction = 1
	return ""


func _choose_next() -> Vector2i:
	if route.size() < 2:
		return cell
	var next := _index + _direction
	if is_loop:
		next = posmod(next, route.size())
	elif next < 0 or next >= route.size():
		_direction = -_direction
		next = _index + _direction
	_next_index = next
	return route[next]


func _on_arrived() -> void:
	_index = _next_index


func _build_visual() -> Node3D:
	var root := Node3D.new()
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _build_octahedron(SIZE)
	root.add_child(_mesh)
	return root


## Sintético: se rompe en octaedros pequeños (su misma forma) con un sonido
## de cristal y metal.
func _add_debris(debris: EnemyDebris, center: Vector3) -> void:
	_burst(debris, _mesh.mesh, null, center, DEBRIS_PIECES, 0.22, 0.45, SIZE, SIZE * 0.4, 2.0, 4.2, false)


func _animate(delta: float) -> void:
	_time += delta
	_visual.position.y = float_height + sin(_time * HOVER_SPEED) * HOVER_AMPLITUDE
	_mesh.rotate_y(SPIN_SPEED * delta)


## Octaedro de caras planas con vértices a `radius` del centro.
static func _build_octahedron(radius: float) -> ArrayMesh:
	var top := Vector3.UP * radius
	var bottom := Vector3.DOWN * radius
	var ring: Array[Vector3] = [Vector3.RIGHT * radius, Vector3.BACK * radius,
		Vector3.LEFT * radius, Vector3.FORWARD * radius]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var a := ring[i]
		var b := ring[(i + 1) % 4]
		_add_flat_triangle(st, top, a, b)
		_add_flat_triangle(st, bottom, a, b)
	st.set_material(_make_material(COLOR, 0.5))
	return st.commit()
