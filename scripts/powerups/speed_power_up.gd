class_name SpeedPowerUp
extends PowerUp
## Velocidad: cada acumulación suma un 25% a la velocidad base del cubo, hasta
## ×2 (4 acumulaciones). Sin límite de tiempo; el efecto solo se pierde al dar
## media vuelta (o al morir): rebotar contra una pared, el borde del tablero o
## una puerta no lo quita. Mientras está activo, el cubo deja un rastro de polvo que se
## desvanece en unos 2,5 s.

const BONUS_PER_STACK := 0.25
const TRAIL_LIFETIME := 2.5
## Polvo de tono arena para que se vea sobre el suelo claro.
const DUST_COLOR := Color(0.62, 0.55, 0.45)
const PICKUP_COLOR := Color(0.55, 0.9, 1.0, 0.7)

## Nodo del rastro mientras el efecto está activo.
var _trail: CPUParticles3D


func _init() -> void:
	id = "speed"
	display_name = "Velocidad"
	stackable = true
	max_stacks = 4
	duration = 0.0
	ends_on_wall_bounce = false
	ends_on_door_bounce = false
	ends_on_reverse = true
	pickup_spin_axis = Vector3(1, 1, 0.3).normalized()
	pickup_spin_speed = 6.0


func speed_multiplier(stacks: int) -> float:
	return 1.0 + BONUS_PER_STACK * stacks


func describe(stacks: int) -> String:
	return "Velocidad ×%s" % ("%.2f" % speed_multiplier(stacks)).replace(".", ",")


## Cubo pequeño semitransparente (un 30% de transparencia).
func create_pickup_visual() -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.36
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PICKUP_COLOR
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.75, 1.0)
	mat.emission_energy_multiplier = 0.6
	mat.roughness = 0.2
	mesh.material = mat
	var instance := MeshInstance3D.new()
	instance.name = "SpeedPickup"
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func on_activated(cube: Node3D, stacks: int) -> void:
	_trail = _create_trail()
	cube.add_child(_trail)
	_trail.global_position = cube.get_trail_anchor()
	_trail.emitting = true
	on_stacks_changed(cube, stacks)


## Más acumulaciones, rastro más denso y opaco.
func on_stacks_changed(_cube: Node3D, stacks: int) -> void:
	if _trail:
		_trail.color = Color(1, 1, 1, minf(0.55 + 0.15 * stacks, 1.0))


func on_process(cube: Node3D, _stacks: int, _delta: float) -> void:
	if _trail:
		_trail.global_position = cube.get_trail_anchor()


## Deja de emitir y espera a que el polvo ya emitido se desvanezca.
func on_deactivated(cube: Node3D, immediate: bool) -> void:
	if _trail == null:
		return
	var trail := _trail
	_trail = null
	if immediate:
		trail.queue_free()
		return
	trail.emitting = false
	cube.get_tree().create_timer(TRAIL_LIFETIME + 0.2).timeout.connect(trail.queue_free)


func _create_trail() -> CPUParticles3D:
	var trail := CPUParticles3D.new()
	trail.name = "SpeedTrail"
	trail.top_level = true
	trail.local_coords = false
	trail.amount = 90
	trail.lifetime = TRAIL_LIFETIME
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.3
	trail.direction = Vector3.UP
	trail.spread = 70.0
	trail.gravity = Vector3(0, 0.08, 0)
	trail.initial_velocity_min = 0.05
	trail.initial_velocity_max = 0.25
	trail.damping_min = 0.5
	trail.damping_max = 1.0
	trail.scale_amount_min = 0.7
	trail.scale_amount_max = 1.1

	var grow := Curve.new()
	grow.max_value = 2.0
	grow.add_point(Vector2(0, 0.5))
	grow.add_point(Vector2(1, 1.8))
	trail.scale_amount_curve = grow

	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.8))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	trail.color_ramp = fade

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.26
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# Sin esto el billboard ignora la escala de cada partícula: no funciona la
	# curva de crecimiento y las partículas inactivas (escala 0, color negro)
	# se dibujan como cuadrados negros.
	mat.billboard_keep_scale = true
	mat.albedo_color = DUST_COLOR
	quad.material = mat
	trail.mesh = quad
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return trail
