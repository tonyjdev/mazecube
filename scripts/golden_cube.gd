class_name GoldenCube
extends Node3D
## Coleccionable del nivel: un cubito dorado (la tercera estrella).
##
## - Cubo metálico dorado, algo emisivo, apoyado sobre un vértice como una
##   gema. Flota subiendo y bajando suavemente y gira despacio sobre sí mismo.
## - Detrás, un resplandor de rayos de luz dorada (un plano siempre de cara a
##   la cámara con un shader): los rayos giran despacio y cada uno cambia de
##   intensidad a su ritmo.
## - Una luz dorada que late ilumina el suelo y los muros de alrededor.
##
## collect() hace la animación de recogida (sube, gira deprisa, destella y se
## encoge mientras salta una lluvia de chispas) y después se borra.
## set_reveal_alpha() lo usa Level durante la aparición del nivel.
## El origen del nodo es el centro de la casilla a ras de suelo.

const GOLD := Color(1.0, 0.78, 0.25)
const GOLD_EMISSION := Color(1.0, 0.66, 0.18)
const CUBE_SIZE := 0.32
const FLOAT_HEIGHT := 0.55
## Balanceo vertical: amplitud (m) y velocidad (rad/s).
const BOB_AMOUNT := 0.07
const BOB_SPEED := 2.2
const SPIN_SPEED := 0.9
## Rayos: tamaño del plano, número de rayos e intensidad.
const RAYS_SIZE := 1.7
const RAYS := 7.0
const RAYS_INTENSITY := 0.85
## Luz: alcance, energía media y cuánto late.
const LIGHT_RANGE := 2.4
const LIGHT_ENERGY := 1.3
const LIGHT_PULSE := 0.45
const LIGHT_PULSE_SPEED := 2.6
## Recogida: duración de la subida con destello y del encogido.
const COLLECT_RISE_TIME := 0.35
const COLLECT_SHRINK_TIME := 0.3

const RAYS_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.75, 0.25, 1.0);
uniform float intensity = 1.0;
uniform float rays = 7.0;
uniform float seed = 0.0;

void vertex() {
	// Siempre de cara a la cámara, conservando la escala del nodo.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
		MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float t = TIME + seed;
	// Dos coronas de rayos que giran en sentidos contrarios; cada rayo late
	// con su propia fase.
	float s1 = a * rays + t * 0.35;
	float i1 = 0.55 + 0.45 * sin(t * 1.9 + floor(s1 / 6.2831 + 0.5) * 2.3);
	float r1 = pow(max(cos(s1), 0.0), 10.0) * i1;
	float s2 = a * (rays + 2.0) - t * 0.22 + 1.1;
	float i2 = 0.5 + 0.5 * sin(t * 1.3 + floor(s2 / 6.2831 + 0.5) * 1.7);
	float r2 = pow(max(cos(s2), 0.0), 16.0) * i2 * 0.7;
	float beams = (r1 + r2) * smoothstep(1.0, 0.2, r) * smoothstep(0.05, 0.25, r);
	float core = exp(-r * r * 14.0) * 0.9;
	float k = (beams + core) * intensity;
	ALBEDO = color.rgb * k;
}
"""

static var _rays_shader: Shader
static var _cube_mesh: BoxMesh
static var _cube_material: StandardMaterial3D
static var _rays_mesh: QuadMesh

var _bob: Node3D
var _spin: Node3D
var _rays: MeshInstance3D
var _rays_material: ShaderMaterial
var _light: OmniLight3D
var _time := 0.0
var _reveal := 1.0
## Intensidad extra de la recogida (destello) y si ya se ha recogido.
var _flash := 0.0
var _collected := false


func _init() -> void:
	name = "GoldenCube"
	if _rays_shader == null:
		_rays_shader = Shader.new()
		_rays_shader.code = RAYS_SHADER
		_cube_mesh = BoxMesh.new()
		_cube_mesh.size = Vector3.ONE * CUBE_SIZE
		_cube_material = StandardMaterial3D.new()
		_cube_material.albedo_color = GOLD
		_cube_material.metallic = 0.9
		_cube_material.roughness = 0.22
		_cube_material.emission_enabled = true
		_cube_material.emission = GOLD_EMISSION
		_cube_material.emission_energy_multiplier = 0.55
		_rays_mesh = QuadMesh.new()
		_rays_mesh.size = Vector2.ONE * RAYS_SIZE

	_bob = Node3D.new()
	_bob.position.y = FLOAT_HEIGHT
	add_child(_bob)
	_spin = Node3D.new()
	_bob.add_child(_spin)
	var cube := MeshInstance3D.new()
	cube.mesh = _cube_mesh
	cube.material_override = _cube_material
	# Apoyado sobre un vértice: la diagonal del cubo queda vertical.
	# (45° sobre Z y luego -35,26° sobre X llevan el vértice (1, 1, 1) arriba.)
	cube.basis = Basis(Vector3.RIGHT, -atan(1.0 / sqrt(2.0))) * Basis(Vector3.BACK, deg_to_rad(45.0))
	cube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spin.add_child(cube)

	_rays_material = ShaderMaterial.new()
	_rays_material.shader = _rays_shader
	_rays_material.set_shader_parameter("color", GOLD)
	_rays_material.set_shader_parameter("rays", RAYS)
	_rays_material.set_shader_parameter("seed", randf() * 100.0)
	_rays = MeshInstance3D.new()
	_rays.mesh = _rays_mesh
	_rays.material_override = _rays_material
	_rays.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bob.add_child(_rays)

	_light = OmniLight3D.new()
	_light.light_color = GOLD
	_light.omni_range = LIGHT_RANGE
	_light.shadow_enabled = false
	_bob.add_child(_light)
	_time = randf() * TAU
	_update(0.0)


func _process(delta: float) -> void:
	_time += delta
	_update(delta)


func _update(delta: float) -> void:
	if not _collected:
		_bob.position.y = FLOAT_HEIGHT + sin(_time * BOB_SPEED) * BOB_AMOUNT
		_spin.rotate_y(SPIN_SPEED * delta)
	var pulse := 1.0 + sin(_time * LIGHT_PULSE_SPEED) * LIGHT_PULSE
	_light.light_energy = LIGHT_ENERGY * pulse * _reveal * (1.0 + _flash * 2.0)
	_rays_material.set_shader_parameter("intensity", RAYS_INTENSITY * _reveal * (1.0 + _flash * 1.5))


func set_reveal_alpha(alpha: float) -> void:
	_reveal = alpha
	_update(0.0)


## Animación de recogida; al terminar, el nodo se borra solo.
func collect() -> void:
	if _collected:
		return
	_collected = true
	_spawn_sparks()
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(_bob, "position:y", _bob.position.y + 0.55, COLLECT_RISE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_spin, "scale", Vector3.ONE * 1.6, COLLECT_RISE_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_spin, "rotation:y", _spin.rotation.y + TAU * 1.5,
		COLLECT_RISE_TIME + COLLECT_SHRINK_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_flash", 1.0, COLLECT_RISE_TIME * 0.5)
	tween.chain().set_parallel()
	tween.tween_property(_spin, "scale", Vector3.ZERO, COLLECT_SHRINK_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_rays, "scale", Vector3.ONE * 0.01, COLLECT_SHRINK_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "_reveal", 0.0, COLLECT_SHRINK_TIME)
	tween.chain().tween_interval(0.6)
	tween.chain().tween_callback(queue_free)


## Lluvia de chispas doradas que saltan y caen.
func _spawn_sparks() -> void:
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.emitting = false
	sparks.amount = 28
	sparks.lifetime = 0.9
	sparks.explosiveness = 0.95
	sparks.direction = Vector3.UP
	sparks.spread = 70.0
	sparks.initial_velocity_min = 1.6
	sparks.initial_velocity_max = 3.2
	sparks.gravity = Vector3(0, -6.0, 0)
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	sparks.scale_amount_curve = curve
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.05
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.5)
	mesh.material = mat
	sparks.mesh = mesh
	sparks.position = _bob.position
	add_child(sparks)
	sparks.emitting = true
