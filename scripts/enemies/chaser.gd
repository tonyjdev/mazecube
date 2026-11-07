class_name Chaser
extends Enemy
## Perseguidor: una esfera roja con ojos que busca al cubo por el laberinto.
##
## No sabe dónde está el cubo: mientras no lo ve, deambula al azar por los
## pasillos (sin dar media vuelta salvo en un callejón sin salida). Cuando el
## cubo entra en su radio de acción (DETECT_RADIUS casillas de recorrido, no en
## línea recta), lo persigue por el camino más corto, algo más deprisa. Si el
## cubo se aleja más de LOSE_RADIUS casillas, le pierde la pista y vuelve a
## deambular. Al morir el cubo, también le pierde la pista y no vuelve a
## buscarlo hasta pasados FORGET_TIME segundos (así no acampa en la salida).
##
## Los ojos miran hacia donde va; al perseguir, se clavan en el cubo y la
## esfera se enciende.

const DETECT_RADIUS := 4
const LOSE_RADIUS := 8
const FORGET_TIME := 3.0
const WANDER_STEP_TIME := 0.6
const CHASE_STEP_TIME := 0.46
const RADIUS := 0.32
const CALM_COLOR := Color(0.78, 0.22, 0.30)
const ANGRY_COLOR := Color(1.0, 0.12, 0.10)
const BOUNCE_HEIGHT := 0.05
const BOUNCE_SPEED := 9.0

var is_chasing := false

var _body_mat: StandardMaterial3D
var _eyes: Node3D
var _time := 0.0
var _forget_left := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	lethal = true
	step_time = WANDER_STEP_TIME
	float_height = RADIUS + 0.02


func on_cube_died() -> void:
	_set_chasing(false)
	_forget_left = FORGET_TIME


func _choose_next() -> Vector2i:
	_update_awareness()
	if is_chasing:
		return _first_step_towards(cube.cell, _can_enter)
	return _wander()


func _update_awareness() -> void:
	if cube == null or not cube.is_alive() or cube.is_finished or _forget_left > 0.0:
		_set_chasing(false)
		return
	var radius := LOSE_RADIUS if is_chasing else DETECT_RADIUS
	# El cubo puede estar en la salida, por donde los enemigos no pasan:
	# se mide desde el cubo hacia el perseguidor.
	var dist := _distances(cube.cell, _passable, radius)
	_set_chasing(dist.has(cell))


func _set_chasing(chasing: bool) -> void:
	is_chasing = chasing
	step_time = CHASE_STEP_TIME if chasing else WANDER_STEP_TIME
	if _body_mat:
		_body_mat.albedo_color = ANGRY_COLOR if chasing else CALM_COLOR
		_body_mat.emission = _body_mat.albedo_color
		_body_mat.emission_energy_multiplier = 0.9 if chasing else 0.25


## Sigue el pasillo; en los cruces elige al azar, y solo da media vuelta si
## no le queda otra.
func _wander() -> Vector2i:
	var options: Array[Vector2i] = []
	for dir in DIRS:
		if dir != -heading and _can_enter(cell + dir):
			options.append(cell + dir)
	if options.is_empty():
		return cell - heading if heading != Vector2i.ZERO and _can_enter(cell - heading) else cell
	return options[_rng.randi_range(0, options.size() - 1)]


func _build_visual() -> Node3D:
	var root := Node3D.new()
	_body_mat = _make_material(CALM_COLOR, 0.25)
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.material = _body_mat
	var body := MeshInstance3D.new()
	body.mesh = sphere
	root.add_child(body)

	# Ojos: dos esferas blancas con pupila negra, en la cara que mira a -Z
	# local; el conjunto gira para mirar hacia donde va.
	_eyes = Node3D.new()
	root.add_child(_eyes)
	var white := _make_material(Color(0.97, 0.97, 0.97))
	var black := _make_material(Color(0.05, 0.05, 0.08))
	for side: float in [-1.0, 1.0]:
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = RADIUS * 0.3
		eye_mesh.height = RADIUS * 0.6
		eye_mesh.material = white
		var eye := MeshInstance3D.new()
		eye.mesh = eye_mesh
		eye.position = Vector3(side * RADIUS * 0.38, RADIUS * 0.3, -RADIUS * 0.82)
		_eyes.add_child(eye)
		var pupil_mesh := SphereMesh.new()
		pupil_mesh.radius = RADIUS * 0.14
		pupil_mesh.height = RADIUS * 0.28
		pupil_mesh.material = black
		var pupil := MeshInstance3D.new()
		pupil.mesh = pupil_mesh
		pupil.position = Vector3(0, 0, -RADIUS * 0.2)
		eye.add_child(pupil)
	_set_chasing(is_chasing)
	return root


func _animate(delta: float) -> void:
	_time += delta
	_forget_left -= delta
	# Botecitos mientras se mueve, más rápidos al perseguir.
	var speed := BOUNCE_SPEED * (1.4 if is_chasing else 1.0)
	_visual.position.y = float_height + absf(sin(_time * speed)) * BOUNCE_HEIGHT
	var look := Vector3(heading.x, 0, heading.y)
	if is_chasing and cube:
		var to_cube := level.to_local(cube.get_trail_anchor()) - position
		to_cube.y = 0.0
		if to_cube.length() > 0.01:
			look = to_cube.normalized()
	if look.length() > 0.01:
		var target_yaw := atan2(-look.x, -look.z)
		_eyes.rotation.y = lerp_angle(_eyes.rotation.y, target_yaw, minf(1.0, delta * 10.0))
