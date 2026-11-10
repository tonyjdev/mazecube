class_name TileGlow
extends Node3D
## Luz que sale del suelo de una casilla (la de salida y la de meta):
## - Varios haces de luz transparentes, cilindros abiertos de distinta
##   anchura, altura e intensidad, que se desvanecen hacia arriba, laten
##   cada uno a su ritmo y llevan bandas de luz que suben.
## - Un charco de luz sobre la baldosa.
## - Partículas que salen de abajo, suben en zigzag, se encogen y
##   desaparecen.
## Todo es transparente (se mezcla con lo que hay detrás) y no da sombra.
## El origen del nodo es el centro de la casilla a ras de suelo.
##
## `power` (create) refuerza el efecto: con más de 1 los haces son más altos
## e intensos, el resplandor más grande y con ondas que se abren, se añade un
## haz central más claro y una luz de color que ilumina lo que hay alrededor. La meta usa
## Level.GOAL_GLOW_POWER para que se vea bien desde lejos; la salida, 1.
##
## set_reveal_alpha() lo usa Level durante la aparición del nivel para que el
## efecto aparezca a la vez que su casilla.

## Haces de luz: radio, altura, intensidad, velocidad del latido.
const BEAMS := [
	[0.30, 1.05, 0.75, 1.3],
	[0.40, 0.75, 0.55, 0.9],
	[0.46, 0.45, 0.65, 1.7],
]
const POOL_SIZE := 1.1
const POOL_INTENSITY := 0.75
## Con power > 1: por cada punto de más, cuánto crecen la altura y la
## intensidad de los haces y el tamaño del resplandor.
const POWER_HEIGHT := 0.8
const POWER_INTENSITY := 0.7
const POWER_POOL := 0.6
## Desvanecido de los haces hacia arriba con power > 1 (el normal es 1.8):
## más bajo = la luz llega más arriba.
const POWER_FADE := 1.0
## Las ondas también se abren a la altura de lo alto de los muros (para que
## no las tapen), en un plano de este tamaño.
const RING_PLANE_HEIGHT := 0.52
const RING_PLANE_SIZE := 2.6
## Intensidad de las ondas que se abren sobre el suelo (solo con power > 1).
const RING_INTENSITY := 0.9
## Haz central (solo con power > 1): radio, altura (antes de escalar),
## intensidad y velocidad del latido.
const CORE_BEAM := [0.18, 1.3, 0.9, 1.1]
## Luz de color que ilumina alrededor (solo con power > 1): alcance y
## energía por punto de power de más.
const LIGHT_RANGE := 3.2
const LIGHT_ENERGY := 3.0
const LIGHT_HEIGHT := 0.45

const PARTICLE_COUNT := 18
## Zona de salida de las partículas (radio desde el centro de la casilla).
const PARTICLE_SPREAD := 0.36
const PARTICLE_LIFE := Vector2(1.3, 2.2)
const PARTICLE_RISE := Vector2(0.45, 0.75)
const PARTICLE_SIZE := Vector2(0.08, 0.13)
## Zigzag: separación lateral máxima y tramos por segundo.
const ZIGZAG_AMPLITUDE := Vector2(0.04, 0.08)
const ZIGZAG_RATE := Vector2(2.0, 3.5)

const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform float height = 1.0;
uniform float intensity = 0.5;
uniform float pulse_speed = 1.0;
uniform float phase = 0.0;
uniform float reveal = 1.0;
// Cuánto cuesta desvanecerse al subir (más alto = se apaga antes).
uniform float fade_power = 1.8;
varying float h;

void vertex() {
	h = clamp(VERTEX.y / height + 0.5, 0.0, 1.0);
}

void fragment() {
	// Se desvanece hacia arriba y en los bordes del cilindro (así parece un
	// volumen de luz y no un tubo de cristal).
	float fade = pow(1.0 - h, fade_power);
	float facing = 0.35 + 0.65 * pow(abs(dot(NORMAL, VIEW)), 1.5);
	float pulse = 0.75 + 0.25 * sin(TIME * pulse_speed * 6.2831 + phase);
	float bands = 0.8 + 0.2 * sin((h * 5.0 - TIME * 0.8 * pulse_speed) * 6.2831 + phase);
	ALBEDO = color.rgb;
	ALPHA = clamp(fade * facing * pulse * bands * intensity * reveal, 0.0, 1.0);
}
"""

const POOL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform float intensity = 0.6;
uniform float reveal = 1.0;
// Ondas: anillos que salen del centro y se apagan al abrirse (0 = sin ondas).
uniform float rings = 0.0;
uniform float ring_speed = 0.6;

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float pulse = 0.85 + 0.15 * sin(TIME * 2.0);
	float a = pow(max(1.0 - d, 0.0), 1.5) * intensity * pulse;
	for (int i = 0; i < 2; i++) {
		float t = fract(TIME * ring_speed + float(i) * 0.5);
		float r = 0.15 + 0.85 * t;
		float ring = 1.0 - smoothstep(0.0, 0.07, abs(d - r));
		a += rings * ring * (1.0 - t) * (1.0 - t);
	}
	ALBEDO = color.rgb;
	ALPHA = clamp(a * reveal, 0.0, 1.0);
}
"""

static var _beam_shader: Shader
static var _pool_shader: Shader
static var _dot_texture: Texture2D

var color := Color.WHITE
var power := 1.0
var _light: OmniLight3D
var _materials: Array[ShaderMaterial] = []
var _particle_material: StandardMaterial3D
var _multimesh: MultiMesh
## Por partícula: { "age", "life", "pos", "dir", "rise", "size", "amp", "rate", "phase" }
var _particles: Array[Dictionary] = []
var _reveal := 1.0


static func create(glow_color: Color, glow_power := 1.0) -> TileGlow:
	var glow := TileGlow.new()
	glow.color = glow_color
	glow.power = glow_power
	return glow


func _ready() -> void:
	if _beam_shader == null:
		_beam_shader = Shader.new()
		_beam_shader.code = BEAM_SHADER
		_pool_shader = Shader.new()
		_pool_shader.code = POOL_SHADER
		_dot_texture = _make_dot_texture()
	var extra := maxf(power - 1.0, 0.0)
	var height_scale := 1.0 + POWER_HEIGHT * extra
	var intensity_scale := 1.0 + POWER_INTENSITY * extra
	var beams := BEAMS.duplicate()
	if extra > 0.0:
		beams.append(CORE_BEAM)
	for i in beams.size():
		var beam: Array = beams[i]
		var core: bool = i >= BEAMS.size()
		var height: float = beam[1] * height_scale
		var mesh := CylinderMesh.new()
		mesh.top_radius = beam[0]
		mesh.bottom_radius = beam[0]
		mesh.height = height
		mesh.cap_top = false
		mesh.cap_bottom = false
		mesh.radial_segments = 24
		mesh.rings = 1
		var mat := ShaderMaterial.new()
		mat.shader = _beam_shader
		# Con power, color más saturado: sobre el suelo claro se ve más.
		var beam_color := color.lightened(0.25) if extra <= 0.0 else color
		if core:
			beam_color = color.lightened(0.45)
		mat.set_shader_parameter("color", beam_color)
		mat.set_shader_parameter("height", height)
		mat.set_shader_parameter("intensity", beam[2] * intensity_scale)
		mat.set_shader_parameter("pulse_speed", beam[3])
		mat.set_shader_parameter("phase", i * 2.1)
		if extra > 0.0:
			mat.set_shader_parameter("fade_power", POWER_FADE)
		_add_mesh(mesh, mat, Vector3(0, height * 0.5, 0))
	var pool := PlaneMesh.new()
	var pool_size := POOL_SIZE * (1.0 + POWER_POOL * extra)
	pool.size = Vector2(pool_size, pool_size)
	var pool_mat := ShaderMaterial.new()
	pool_mat.shader = _pool_shader
	pool_mat.set_shader_parameter("color", color.lightened(0.4 if extra <= 0.0 else 0.1))
	pool_mat.set_shader_parameter("intensity", POOL_INTENSITY * intensity_scale)
	pool_mat.set_shader_parameter("rings", RING_INTENSITY * minf(extra, 1.0))
	_add_mesh(pool, pool_mat, Vector3(0, 0.01, 0))
	if extra > 0.0:
		var ring_plane := PlaneMesh.new()
		ring_plane.size = Vector2(RING_PLANE_SIZE, RING_PLANE_SIZE)
		var ring_mat := ShaderMaterial.new()
		ring_mat.shader = _pool_shader
		ring_mat.set_shader_parameter("color", color.lightened(0.1))
		ring_mat.set_shader_parameter("intensity", 0.0)
		ring_mat.set_shader_parameter("rings", RING_INTENSITY * 0.8 * minf(extra, 1.0))
		_add_mesh(ring_plane, ring_mat, Vector3(0, RING_PLANE_HEIGHT, 0))
	if extra > 0.0:
		_light = OmniLight3D.new()
		_light.light_color = color.lightened(0.2)
		_light.omni_range = LIGHT_RANGE
		_light.shadow_enabled = false
		_light.position = Vector3(0, LIGHT_HEIGHT, 0)
		add_child(_light)
	_make_particles()
	_apply_reveal()


func _add_mesh(mesh: Mesh, mat: ShaderMaterial, pos: Vector3) -> void:
	mesh.surface_set_material(0, mat)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	_materials.append(mat)


## Transparencia de todo el efecto (0 = invisible, 1 = normal).
func set_reveal_alpha(alpha: float) -> void:
	_reveal = alpha
	if is_inside_tree():
		_apply_reveal()


func _apply_reveal() -> void:
	for mat in _materials:
		mat.set_shader_parameter("reveal", _reveal)


# --- Partículas ----------------------------------------------------------------

func _make_particles() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_particle_material = StandardMaterial3D.new()
	_particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_particle_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_particle_material.billboard_keep_scale = true
	_particle_material.vertex_color_use_as_albedo = true
	_particle_material.albedo_texture = _dot_texture
	_particle_material.albedo_color = color.lightened(0.6)
	quad.material = _particle_material
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.mesh = quad
	_multimesh.instance_count = PARTICLE_COUNT
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = _multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	for i in PARTICLE_COUNT:
		var p := {}
		_spawn(p)
		# Repartidas a lo largo de su vida para que no salgan todas a la vez.
		p["age"] = randf() * p["life"]
		_particles.append(p)
	_update_particles(0.0)


func _spawn(p: Dictionary) -> void:
	var angle := randf() * TAU
	var r := sqrt(randf()) * PARTICLE_SPREAD
	p["age"] = 0.0
	p["life"] = randf_range(PARTICLE_LIFE.x, PARTICLE_LIFE.y)
	p["pos"] = Vector3(cos(angle) * r, 0.02, sin(angle) * r)
	var side := randf() * TAU
	p["dir"] = Vector3(cos(side), 0, sin(side))
	p["rise"] = randf_range(PARTICLE_RISE.x, PARTICLE_RISE.y)
	p["size"] = randf_range(PARTICLE_SIZE.x, PARTICLE_SIZE.y)
	p["amp"] = randf_range(ZIGZAG_AMPLITUDE.x, ZIGZAG_AMPLITUDE.y)
	p["rate"] = randf_range(ZIGZAG_RATE.x, ZIGZAG_RATE.y)
	p["phase"] = randf()


func _process(delta: float) -> void:
	_update_particles(delta)
	if _light:
		var pulse := 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.001 * TAU * 0.9)
		_light.light_energy = LIGHT_ENERGY * GameState.light_scale() * (power - 1.0) * pulse * _reveal


func _update_particles(delta: float) -> void:
	for i in _particles.size():
		var p: Dictionary = _particles[i]
		p["age"] += delta
		if p["age"] >= p["life"]:
			_spawn(p)
		var age: float = p["age"]
		var u: float = age / p["life"]
		# Onda triangular: tramos rectos de un lado a otro (zigzag).
		var t: float = age * p["rate"] * 0.5 + p["phase"]
		var zig: float = 4.0 * absf(t - floorf(t + 0.5)) - 1.0
		var pos: Vector3 = p["pos"] + p["dir"] * zig * p["amp"] + Vector3.UP * age * p["rise"]
		var size: float = p["size"] * lerpf(1.0, 0.35, u)
		_multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * size), pos))
		var alpha := smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.55, 1.0, u)) * _reveal
		_multimesh.set_instance_color(i, Color(1, 1, 1, alpha))


## Punto de luz redondo y difuminado para las partículas.
static func _make_dot_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.35, Color(1, 1, 1, 0.8))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture
