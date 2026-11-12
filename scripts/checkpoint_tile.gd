class_name CheckpointTile
extends Node3D
## Casilla de inicio (ver Level: la salida 'A' y las del campo "checkpoints"
## del nivel). Tiene dos estados: activada (baldosa azul de la salida con su
## luz, TileGlow) y desactivada (baldosa gris con ondas suaves, como gotas
## cayendo en un charco, y unas pocas partículas blancas que suben poco, para
## que se vea que es una casilla especial y apetezca ir a ella). Solo una
## está activada a la vez: el cubo reaparece en ella al morir. Al pasar el
## cubo por una desactivada, se activa (con un destello que crece desde la
## baldosa) y las demás se apagan (ver Level.cube_entered).
##
## El nodo va en el centro de la casilla, a ras de suelo.

const OFF_COLOR := Color(0.5, 0.5, 0.52)
## Ondas de la casilla desactivada: intensidad y segundos entre gotas.
const RIPPLE_INTENSITY := 0.55
const RIPPLE_PERIOD := 2.2
## Partículas de la casilla desactivada.
const IDLE_PARTICLE_COUNT := 7
const IDLE_PARTICLE_SPREAD := 0.34
const IDLE_PARTICLE_LIFE := Vector2(1.4, 2.2)
const IDLE_PARTICLE_RISE := Vector2(0.12, 0.22)
const IDLE_PARTICLE_SIZE := Vector2(0.045, 0.075)

const RIPPLE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float intensity = 0.5;
uniform float period = 2.2;
uniform float phase = 0.0;
uniform float reveal = 1.0;

void fragment() {
	// Cada gota (una por periodo) abre tres anillos concéntricos que se
	// separan y se apagan al crecer, como en un charco.
	float d = length(UV - vec2(0.5)) * 2.0;
	float t = fract(TIME / period + phase);
	float a = 0.0;
	for (int i = 0; i < 3; i++) {
		float r = t * 1.15 - float(i) * 0.16;
		if (r > 0.0) {
			float ring = 1.0 - smoothstep(0.0, 0.05, abs(d - r));
			a += ring * (1.0 - float(i) * 0.3);
		}
	}
	a *= (1.0 - t) * (1.0 - t) * (1.0 - smoothstep(0.85, 1.0, d));
	ALBEDO = vec3(1.0);
	ALPHA = clamp(a * intensity * reveal, 0.0, 1.0);
}
"""

static var _ripple_shader: Shader
## Destello al activarse: lo que dura y hasta dónde crece.
const PULSE_TIME := 0.5
const PULSE_SCALE := 1.6

static var _materials := {}

var active := false
var _tile: MeshInstance3D
var _glow: TileGlow
var _ring: MeshInstance3D
## Efecto de la casilla desactivada (ondas y partículas).
var _idle: Node3D
var _ripple_mat: ShaderMaterial
var _idle_mat: StandardMaterial3D
var _idle_multimesh: MultiMesh
## Por partícula: { "age", "life", "pos", "rise", "size" }
var _idle_particles: Array[Dictionary] = []
var _reveal := 1.0


func _ready() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(Level.CELL_SIZE * 0.96, Level.FLOOR_THICKNESS, Level.CELL_SIZE * 0.96)
	_tile = MeshInstance3D.new()
	_tile.mesh = mesh
	_tile.position.y = -Level.FLOOR_THICKNESS * 0.5
	add_child(_tile)
	_glow = TileGlow.create(Level.START_COLOR)
	add_child(_glow)
	_make_idle()
	_apply()


## Activa o desactiva la casilla; con `animate`, el destello de activación.
func set_active(value: bool, animate := false) -> void:
	active = value
	if is_node_ready():
		_apply()
	if animate and value:
		_pulse()


## Fundido de la aparición del nivel (ver Level._apply_reveal).
func set_reveal_alpha(alpha: float) -> void:
	_reveal = alpha
	_glow.set_reveal_alpha(alpha)
	if _ripple_mat:
		_ripple_mat.set_shader_parameter("reveal", alpha)


func _apply() -> void:
	(_tile.mesh as BoxMesh).material = _material(Level.START_COLOR if active else OFF_COLOR)
	_glow.visible = active
	_idle.visible = not active
	set_process(not active)


# --- Efecto de la casilla desactivada ------------------------------------------

func _make_idle() -> void:
	if _ripple_shader == null:
		_ripple_shader = Shader.new()
		_ripple_shader.code = RIPPLE_SHADER
	_idle = Node3D.new()
	add_child(_idle)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * Level.CELL_SIZE * 0.94
	_ripple_mat = ShaderMaterial.new()
	_ripple_mat.shader = _ripple_shader
	_ripple_mat.set_shader_parameter("intensity", RIPPLE_INTENSITY)
	_ripple_mat.set_shader_parameter("period", RIPPLE_PERIOD)
	# Cada casilla a su ritmo, para que no caigan todas las gotas a la vez.
	_ripple_mat.set_shader_parameter("phase", randf())
	plane.material = _ripple_mat
	var ripple := MeshInstance3D.new()
	ripple.mesh = plane
	ripple.position.y = 0.006
	ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_idle.add_child(ripple)

	var quad := QuadMesh.new()
	_idle_mat = StandardMaterial3D.new()
	_idle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_idle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_idle_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_idle_mat.billboard_keep_scale = true
	_idle_mat.vertex_color_use_as_albedo = true
	_idle_mat.albedo_texture = TileGlow.dot_texture()
	quad.material = _idle_mat
	_idle_multimesh = MultiMesh.new()
	_idle_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_idle_multimesh.use_colors = true
	_idle_multimesh.mesh = quad
	_idle_multimesh.instance_count = IDLE_PARTICLE_COUNT
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = _idle_multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_idle.add_child(instance)
	for i in IDLE_PARTICLE_COUNT:
		var p := {}
		_spawn_idle(p)
		p["age"] = randf() * p["life"]
		_idle_particles.append(p)
	_update_idle(0.0)


func _spawn_idle(p: Dictionary) -> void:
	var angle := randf() * TAU
	var r := sqrt(randf()) * IDLE_PARTICLE_SPREAD
	p["age"] = 0.0
	p["life"] = randf_range(IDLE_PARTICLE_LIFE.x, IDLE_PARTICLE_LIFE.y)
	p["pos"] = Vector3(cos(angle) * r, 0.02, sin(angle) * r)
	p["rise"] = randf_range(IDLE_PARTICLE_RISE.x, IDLE_PARTICLE_RISE.y)
	p["size"] = randf_range(IDLE_PARTICLE_SIZE.x, IDLE_PARTICLE_SIZE.y)


func _process(delta: float) -> void:
	_update_idle(delta)


func _update_idle(delta: float) -> void:
	for i in _idle_particles.size():
		var p: Dictionary = _idle_particles[i]
		p["age"] += delta
		if p["age"] >= p["life"]:
			_spawn_idle(p)
		var u: float = p["age"] / p["life"]
		var pos: Vector3 = p["pos"] + Vector3.UP * u * p["rise"]
		var size: float = p["size"] * lerpf(1.0, 0.5, u)
		_idle_multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * size), pos))
		var alpha := smoothstep(0.0, 0.15, u) * (1.0 - smoothstep(0.5, 1.0, u)) * 0.9 * _reveal
		_idle_multimesh.set_instance_color(i, Color(1, 1, 1, alpha))


## Anillo de luz que se abre desde la baldosa y se desvanece.
func _pulse() -> void:
	if _ring == null:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.38
		torus.outer_radius = 0.48
		torus.rings = 32
		torus.ring_segments = 6
		_ring = MeshInstance3D.new()
		_ring.mesh = torus
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Level.START_COLOR.lightened(0.3)
		_ring.material_override = mat
		_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ring.position.y = 0.05
		add_child(_ring)
	var ring_mat := _ring.material_override as StandardMaterial3D
	_ring.visible = true
	_ring.scale = Vector3(0.6, 0.3, 0.6)
	ring_mat.albedo_color.a = 1.0
	var tween := _ring.create_tween().set_parallel()
	tween.tween_property(_ring, "scale", Vector3(PULSE_SCALE, 0.3, PULSE_SCALE), PULSE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring_mat, "albedo_color:a", 0.0, PULSE_TIME)
	tween.chain().tween_callback(_ring.hide)


static func _material(color: Color) -> StandardMaterial3D:
	if _materials.has(color):
		return _materials[color]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	_materials[color] = mat
	return mat
