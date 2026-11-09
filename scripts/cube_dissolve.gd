class_name CubeDissolve
extends RefCounted
## Material de «disolverse» para el cubo durante la invulnerabilidad tras
## reaparecer (ver RollingCube.RESPAWN_GRACE), en lugar de parpadear.
##
## Un ruido 3D pegado al cubo (en sus coordenadas locales, así que gira con
## él al rodar) y que sube despacio decide qué partes se disuelven: donde el
## ruido queda por debajo del umbral, el cubo se vuelve muy translúcido
## (nunca del todo invisible, ver MIN_ALPHA). En la frontera entre lo
## disuelto y lo sólido hay un borde que brilla (smoothstep sobre el ruido).
## El resto del cubo también es algo transparente (BODY_ALPHA). El umbral
## oscila un poco para que el dibujo se mueva, sin llegar a disolver mucho
## (MAX_DISSOLVE).
##
## `strength` (0-1) mezcla del cubo normal (0) al efecto completo (1):
## RollingCube la sube al empezar y la baja al acabar para que no haya
## saltos.
##
## Los enemigos usan el mismo efecto al aparecer (ver Enemy): make_material()
## acepta el color del objeto (`albedo`, que multiplica al color de vértice),
## su brillo propio (`base_emission`, en lineal) y el color del borde; `fade` (0-1)
## multiplica la opacidad final para que puedan surgir de la nada.

const MAX_DISSOLVE := 0.40
const MIN_ALPHA := 0.25
const BODY_ALPHA := 0.75
const EDGE_WIDTH := 0.07
const EDGE_COLOR := Color(0.35, 0.72, 1.0)
const EDGE_ENERGY := 2.6
const NOISE_SCALE := 4.0
const NOISE_SPEED := 0.5

const SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back;

uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float max_dissolve = 0.42;
uniform float min_alpha = 0.25;
uniform float body_alpha = 0.75;
uniform float edge_width = 0.06;
uniform vec3 edge_color : source_color = vec3(0.55, 0.85, 1.0);
uniform float edge_energy = 2.2;
uniform float noise_scale = 4.0;
uniform float noise_speed = 0.5;
uniform float roughness_value = 0.6;
uniform vec3 albedo : source_color = vec3(1.0);
uniform vec3 base_emission = vec3(0.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.11, 0.17, 0.13));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float value_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

void fragment() {
	vec3 p = local_pos * noise_scale + vec3(0.0, -TIME * noise_speed, 0.0);
	float n = 0.65 * value_noise(p) + 0.35 * value_noise(p * 2.3 + 7.1);
	// Umbral: cuánto se disuelve (oscila un poco para que se mueva).
	float amount = max_dissolve * strength * (0.8 + 0.2 * sin(TIME * 2.6));
	// 0 = disuelto, 1 = sólido, con la transición del smoothstep.
	float solid = smoothstep(amount, amount + 0.025, n);
	// Borde brillante justo por encima del umbral.
	// El borde se enciende y se apaga con strength (sin saltos).
	float edge = (1.0 - smoothstep(0.0, edge_width, n - amount)) * step(amount, n)
		* smoothstep(0.0, 0.6, strength);
	ALBEDO = mix(COLOR.rgb * albedo, edge_color, edge * 0.6);
	ROUGHNESS = roughness_value;
	EMISSION = base_emission + edge_color * edge * edge_energy;
	float a = mix(min_alpha, body_alpha, solid);
	a = max(a, edge * 0.95);
	ALPHA = mix(1.0, a, strength) * fade;
}
"""

static var _shader: Shader


## Material nuevo del efecto, con strength = 0 (cubo normal). `color` es el
## del objeto, `emission` su brillo propio y `edge` el color del borde.
static func make_material(color := Color.WHITE, emission := Color.BLACK,
		edge := EDGE_COLOR) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("strength", 0.0)
	mat.set_shader_parameter("max_dissolve", MAX_DISSOLVE)
	mat.set_shader_parameter("min_alpha", MIN_ALPHA)
	mat.set_shader_parameter("body_alpha", BODY_ALPHA)
	mat.set_shader_parameter("edge_width", EDGE_WIDTH)
	mat.set_shader_parameter("edge_color", edge)
	mat.set_shader_parameter("albedo", color)
	mat.set_shader_parameter("base_emission", emission)
	mat.set_shader_parameter("edge_energy", EDGE_ENERGY)
	mat.set_shader_parameter("noise_scale", NOISE_SCALE)
	mat.set_shader_parameter("noise_speed", NOISE_SPEED)
	return mat
