class_name Chaser
extends Enemy
## Perseguidor: una esfera roja con ojos que busca al cubo por el laberinto.
##
## No sabe dónde está el cubo: mientras no lo ve, deambula al azar por los
## pasillos (sin dar media vuelta salvo en un callejón sin salida). Cuando el
## cubo entra en su radio de acción (DETECT_RADIUS casillas de recorrido, no en
## línea recta), primero se queda quieto en su casilla ALERT_TIME segundos
## temblando (aviso de que va a por él) y después lo persigue por el camino
## más corto, algo más deprisa. Si el
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
## Aviso al detectar al cubo: tiempo que tiembla sin moverse, amplitud y
## frecuencia (rad/s) del temblor.
const ALERT_TIME := 0.5
const ALERT_SHAKE := 0.05
const ALERT_SHAKE_SPEED := 70.0
## Gotas en las que revienta al destruirlo (ver _add_debris).
const DEBRIS_DROPS := 26
## Resolución de las esferas (meridianos, paralelos): las de serie de
## SphereMesh (64×32) son demasiados triángulos para muchos enemigos en el
## móvil.
const BODY_SEGMENTS := Vector2i(20, 10)
const EYE_SEGMENTS := Vector2i(12, 6)
const PUPIL_SEGMENTS := Vector2i(8, 4)

## Mallas y materiales que comparten todos los perseguidores (el material
## del cuerpo es de cada uno porque cambia de color al perseguir).
static var _body_mesh: SphereMesh
static var _eye_mesh: SphereMesh
static var _pupil_mesh: SphereMesh
static var _drop_mesh: SphereMesh
static var _white_mat: StandardMaterial3D

var is_chasing := false

var _body_mat: StandardMaterial3D
var _eyes: Node3D
var _time := 0.0
var _forget_left := 0.0
## Tiempo que le queda de temblor antes de empezar a perseguir.
var _alert_left := 0.0
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
	if _alert_left > 0.0:
		return cell
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
	if chasing and not is_chasing:
		Sfx.play("alert")
		_alert_left = ALERT_TIME
	elif not chasing:
		_alert_left = 0.0
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


func _dissolve_color() -> Color:
	return CALM_COLOR.lightened(0.35)


func _build_visual() -> Node3D:
	_init_shared()
	var root := Node3D.new()
	_body_mat = _make_material(CALM_COLOR, 0.25)
	var body := MeshInstance3D.new()
	body.mesh = _body_mesh
	body.set_surface_override_material(0, _body_mat)
	root.add_child(body)

	# Ojos: dos esferas blancas con pupila negra, en la cara que mira a -Z
	# local; el conjunto gira para mirar hacia donde va.
	_eyes = Node3D.new()
	root.add_child(_eyes)
	# Los ojos son pequeños y quedan sobre el cuerpo: no proyectan sombra.
	for side: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.mesh = _eye_mesh
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eye.position = Vector3(side * RADIUS * 0.38, RADIUS * 0.3, -RADIUS * 0.82)
		_eyes.add_child(eye)
		var pupil := MeshInstance3D.new()
		pupil.mesh = _pupil_mesh
		pupil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pupil.position = Vector3(0, 0, -RADIUS * 0.2)
		eye.add_child(pupil)
	_set_chasing(is_chasing)
	return root


## Criatura orgánica: revienta en muchas gotitas de su color (y sus dos ojos)
## que se aplastan al caer, con un estallido acuoso.
func _add_debris(debris: EnemyDebris, center: Vector3) -> void:
	_burst(debris, _drop_mesh, _body_mat, center, DEBRIS_DROPS, RADIUS * 0.15, RADIUS * 0.38, 1.0,
		RADIUS * 0.5, 1.2, 3.2, true)
	_burst(debris, _drop_mesh, _white_mat, center, 2, RADIUS * 0.28,
		RADIUS * 0.3, 1.0, RADIUS * 0.6, 1.5, 2.5, true)


## Crea (la primera vez) las mallas y materiales compartidos.
static func _init_shared() -> void:
	if _body_mesh:
		return
	_white_mat = _make_material(Color(0.97, 0.97, 0.97))
	_body_mesh = _make_sphere(RADIUS, BODY_SEGMENTS, null)
	_eye_mesh = _make_sphere(RADIUS * 0.3, EYE_SEGMENTS, _white_mat)
	_pupil_mesh = _make_sphere(RADIUS * 0.14, PUPIL_SEGMENTS,
		_make_material(Color(0.05, 0.05, 0.08)))
	_drop_mesh = _make_sphere(1.0, Vector2i(12, 6), null)


static func _make_sphere(radius: float, segments: Vector2i, mat: Material) -> SphereMesh:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = segments.x
	sphere.rings = segments.y
	sphere.material = mat
	return sphere


func _destroy_sound() -> String:
	return "splat"


func _animate(delta: float) -> void:
	_time += delta
	_forget_left -= delta
	# Temblor rápido de aviso (la esfera, sin mover la casilla).
	_alert_left = maxf(_alert_left - delta, 0.0)
	var shake := ALERT_SHAKE if _alert_left > 0.0 else 0.0
	_visual.position.x = sin(_time * ALERT_SHAKE_SPEED) * shake
	_visual.position.z = cos(_time * ALERT_SHAKE_SPEED * 1.3) * shake
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
