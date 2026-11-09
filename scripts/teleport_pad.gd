class_name TeleportPad
extends Node3D
## Aspecto de una casilla de teletransporte (ver Level): un remolino de luz
## de su color que gira sobre la baldosa, con un aro brillante, y un haz bajo
## de luz que sube con bandas. Las dos casillas de una pareja tienen el mismo
## color. Todo es luz sumada (sin sombra ni profundidad).
##
## pulse() lo hace brillar con fuerza un momento (cuando el cubo entra o
## sale por él). set_reveal_alpha() lo usa Level durante la aparición del
## nivel. El origen del nodo es el centro de la casilla a ras de suelo.

const DISK_SIZE := 0.92
const DISK_HEIGHT := 0.012
const BEAM_RADIUS := 0.4
const BEAM_HEIGHT := 0.55
## Brillo extra al usarlo y lo que tarda en apagarse.
const PULSE_BOOST := 2.2
const PULSE_TIME := 0.8

const DISK_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(0.3, 0.9, 1.0);
uniform float intensity = 1.0;
uniform float reveal = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	// Brazos del remolino que giran hacia dentro.
	float spiral = 0.5 + 0.5 * sin(a * 3.0 + r * 11.0 - TIME * 5.0);
	spiral = pow(spiral, 2.0) * smoothstep(0.08, 0.55, r);
	float disk = 1.0 - smoothstep(0.82, 0.97, r);
	float rim = smoothstep(0.76, 0.88, r) * (1.0 - smoothstep(0.9, 1.0, r));
	float core = 1.0 - smoothstep(0.0, 0.45, r);
	float pulse = 0.85 + 0.15 * sin(TIME * 3.0);
	float v = disk * (spiral * 0.75 + core * 0.55) * pulse + rim * 1.3;
	ALBEDO = mix(color, vec3(1.0), core * 0.35) * intensity;
	ALPHA = clamp(v * reveal, 0.0, 1.0);
}
"""

const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(0.3, 0.9, 1.0);
uniform float intensity = 1.0;
uniform float reveal = 1.0;
uniform float height = 0.55;

varying float h;

void vertex() {
	h = clamp(VERTEX.y / height + 0.5, 0.0, 1.0);
}

void fragment() {
	float fade = pow(1.0 - h, 2.2);
	float bands = 0.55 + 0.45 * sin(h * 22.0 - TIME * 4.5);
	ALBEDO = color * intensity;
	ALPHA = clamp(fade * bands * 0.55 * reveal, 0.0, 1.0);
}
"""

static var _disk_shader: Shader
static var _beam_shader: Shader

var _color := Color.WHITE
var _materials: Array[ShaderMaterial] = []
var _pulse := 0.0


static func create(pad_color: Color) -> TeleportPad:
	var pad := TeleportPad.new()
	pad._color = pad_color
	return pad


func _ready() -> void:
	if _disk_shader == null:
		_disk_shader = Shader.new()
		_disk_shader.code = DISK_SHADER
		_beam_shader = Shader.new()
		_beam_shader.code = BEAM_SHADER
	var disk := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * DISK_SIZE
	disk.mesh = plane
	disk.position.y = DISK_HEIGHT
	disk.material_override = _make_material(_disk_shader)
	disk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disk)
	var beam := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = BEAM_RADIUS
	cylinder.bottom_radius = BEAM_RADIUS
	cylinder.height = BEAM_HEIGHT
	cylinder.radial_segments = 24
	cylinder.rings = 1
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	beam.mesh = cylinder
	beam.position.y = BEAM_HEIGHT * 0.5
	var beam_mat := _make_material(_beam_shader)
	beam_mat.set_shader_parameter("height", BEAM_HEIGHT)
	beam.material_override = beam_mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)


func _make_material(shader: Shader) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("color", _color)
	_materials.append(mat)
	return mat


## Brilla con fuerza un momento (el cubo entra o sale por aquí).
func pulse() -> void:
	_pulse = 1.0
	set_process(true)


func set_reveal_alpha(alpha: float) -> void:
	for mat in _materials:
		mat.set_shader_parameter("reveal", alpha)


func _process(delta: float) -> void:
	_pulse = maxf(_pulse - delta / PULSE_TIME, 0.0)
	var boost := 1.0 + PULSE_BOOST * _pulse * _pulse
	for mat in _materials:
		mat.set_shader_parameter("intensity", boost)
	if _pulse <= 0.0:
		set_process(false)
