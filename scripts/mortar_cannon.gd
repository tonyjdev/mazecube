class_name MortarCannon
extends Node3D
## Cañón de bombas (mortero) encima de un muro (ver Level, carácter 'M'): una
## base redonda de hierro sobre la que gira una cureña con el cañón, que
## apunta hacia arriba.
##
## Mira hacia `facing` (en casillas) y solo dispara si el cubo está dentro de
## su alcance: hasta RANGE_FORWARD casillas hacia delante y RANGE_SIDE a cada
## lado (lo comprueba Level). Entre disparo y disparo espera entre MIN_WAIT y
## MAX_WAIT segundos; cuando le toca (wants_to_fire) y el cubo está a su
## alcance, Level calcula la trayectoria de la bomba y llama a aim(): la
## cureña gira, el cañón se inclina (AIM_TIME) y dispara: retroceso, destello
## y una bocanada de humo, y emite fired con la posición de la boca y la
## velocidad de salida que le dio Level. La bomba (Bomb) la crea Level.
##
## Level llama a update() en cada fotograma (no mientras aparece el tablero).
## El origen del nodo es el centro de la casilla a la altura de la cara de
## arriba del muro.

signal fired(muzzle: Vector3, velocity: Vector3)

const MIN_WAIT := 10.0
const MAX_WAIT := 15.0
## Espera antes del primer disparo (para que no disparen todos a la vez).
const FIRST_WAIT := Vector2(1.5, 4.0)
## Alcance (en casillas) por defecto y máximo: hacia delante y a cada lado.
const RANGE_FORWARD := 10
const RANGE_SIDE := 5
## Lo que tarda en girar e inclinarse hacia el blanco antes de disparar.
const AIM_TIME := 0.55
## Inclinación del cañón en reposo (radianes sobre la horizontal).
const REST_PITCH := deg_to_rad(55.0)
## Altura del eje de giro del cañón sobre el muro y largo del cañón desde el
## eje hasta la boca.
const PIVOT_HEIGHT := 0.17
const BARREL_LENGTH := 0.34
const BARREL_BACK := 0.1
const BARREL_RADIUS := 0.15
const BASE_RADIUS := 0.32
const BASE_HEIGHT := 0.07
const RECOIL := 0.07
const RECOIL_TIME := 0.07
const RETURN_TIME := 0.45
const FLASH_TIME := 0.14
const FLASH_SIZE := 0.7
const SMOKE_PUFFS := 14
const SMOKE_LIFETIME := 1.1
const SMOKE_COLOR := Color(0.55, 0.55, 0.57)

static var _iron_material: StandardMaterial3D
static var _brass_material: StandardMaterial3D
static var _bore_material: StandardMaterial3D
static var _flash_material: StandardMaterial3D
static var _smoke_material: StandardMaterial3D
static var _base_mesh: CylinderMesh
static var _rim_mesh: CylinderMesh
static var _cheek_mesh: BoxMesh
static var _barrel_mesh: CylinderMesh
static var _ring_mesh: CylinderMesh
static var _breech_mesh: SphereMesh
static var _bore_mesh: ArrayMesh
static var _flash_mesh: QuadMesh
static var _smoke_mesh: QuadMesh

## Hacia dónde mira (en casillas) y su alcance (hacia delante, a cada lado).
var facing := Vector2i.DOWN
var reach := Vector2i(RANGE_FORWARD, RANGE_SIDE)
var _time_left := 0.0
var _aiming := false
var _yaw_pivot: Node3D
var _pitch_pivot: Node3D
var _barrel: Node3D
var _flash: MeshInstance3D
var _smoke: CPUParticles3D


static func create(dir: Vector2i, range_cells: Vector2i) -> MortarCannon:
	var cannon := MortarCannon.new()
	cannon.facing = dir
	cannon.reach = Vector2i(clampi(range_cells.x, 1, RANGE_FORWARD), clampi(range_cells.y, 0, RANGE_SIDE))
	cannon._time_left = randf_range(FIRST_WAIT.x, FIRST_WAIT.y)
	return cannon


## Posición de la boca respecto al origen del cañón con ese giro (yaw, desde
## +Z hacia +X) y esa inclinación.
static func muzzle_offset(yaw: float, pitch: float) -> Vector3:
	return Vector3(0.0, PIVOT_HEIGHT, 0.0) + barrel_direction(yaw, pitch) * BARREL_LENGTH


static func barrel_direction(yaw: float, pitch: float) -> Vector3:
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))


func _ready() -> void:
	_ensure_resources()
	_add_part(self, _base_mesh, _iron_material, Vector3(0.0, BASE_HEIGHT * 0.5, 0.0))
	_add_part(self, _rim_mesh, _brass_material, Vector3(0.0, BASE_HEIGHT + 0.012, 0.0))
	_yaw_pivot = Node3D.new()
	_yaw_pivot.rotation.y = atan2(facing.x, facing.y)
	add_child(_yaw_pivot)
	# Cureña: dos placas a los lados del cañón con el eje arriba.
	for side in [-1.0, 1.0]:
		_add_part(_yaw_pivot, _cheek_mesh, _iron_material,
			Vector3(side * (BARREL_RADIUS + 0.035), BASE_HEIGHT + 0.06, 0.0))
	_pitch_pivot = Node3D.new()
	_pitch_pivot.position.y = PIVOT_HEIGHT
	_pitch_pivot.rotation.x = -REST_PITCH
	_yaw_pivot.add_child(_pitch_pivot)
	# El cañón va a lo largo de +Z del pivote (girado en X para apuntar arriba).
	_barrel = Node3D.new()
	_pitch_pivot.add_child(_barrel)
	var length := BARREL_LENGTH + BARREL_BACK
	_add_part(_barrel, _barrel_mesh, _iron_material, Vector3(0.0, 0.0, (BARREL_LENGTH - BARREL_BACK) * 0.5), true)
	_add_part(_barrel, _breech_mesh, _iron_material, Vector3(0.0, 0.0, -BARREL_BACK))
	_add_part(_barrel, _ring_mesh, _brass_material, Vector3(0.0, 0.0, BARREL_LENGTH - 0.025), true)
	_add_part(_barrel, _ring_mesh, _brass_material, Vector3(0.0, 0.0, length * 0.18 - BARREL_BACK), true)
	_add_part(_barrel, _bore_mesh, _bore_material, Vector3(0.0, 0.0, BARREL_LENGTH + 0.001), true)
	_flash = _add_part(_barrel, _flash_mesh, _flash_material, Vector3(0.0, 0.0, BARREL_LENGTH + 0.08))
	_flash.visible = false
	_smoke = _make_smoke()
	add_child(_smoke)


func update(delta: float) -> void:
	if not _aiming and _time_left > 0.0:
		_time_left -= delta


## Le toca disparar (Level comprueba si el cubo está a su alcance).
func wants_to_fire() -> bool:
	return not _aiming and _time_left <= 0.0


## Gira hacia el blanco, se inclina y dispara la bomba con esa velocidad
## (calculada por Level para ese giro e inclinación).
func aim(yaw: float, pitch: float, velocity: Vector3) -> void:
	_aiming = true
	var from_yaw := _yaw_pivot.rotation.y
	var to_yaw := from_yaw + wrapf(yaw - from_yaw, -PI, PI)
	var tween := create_tween().set_parallel()
	tween.tween_property(_yaw_pivot, "rotation:y", to_yaw, AIM_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_pitch_pivot, "rotation:x", -pitch, AIM_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_callback(_fire.bind(to_yaw, pitch, velocity))


func _fire(yaw: float, pitch: float, velocity: Vector3) -> void:
	_aiming = false
	_time_left = randf_range(MIN_WAIT, MAX_WAIT)
	var muzzle := position + muzzle_offset(yaw, pitch)
	# Retroceso del cañón a lo largo de su eje y vuelta a su sitio.
	var tween := create_tween()
	tween.tween_property(_barrel, "position:z", -RECOIL, RECOIL_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(_barrel, "position:z", 0.0, RETURN_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# Destello de la boca.
	_flash.visible = true
	_flash.scale = Vector3.ONE * FLASH_SIZE * 0.3
	_flash.transparency = 0.0
	var flash := create_tween().set_parallel()
	flash.tween_property(_flash, "scale", Vector3.ONE * FLASH_SIZE, FLASH_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flash.tween_property(_flash, "transparency", 1.0, FLASH_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flash.chain().tween_callback(_flash.hide)
	# Humo que sale de la boca hacia donde apunta y se queda flotando.
	_smoke.position = muzzle - position
	_smoke.direction = barrel_direction(yaw, pitch)
	_smoke.restart()
	fired.emit(muzzle, velocity)


func _add_part(parent: Node3D, mesh: Mesh, material: Material, at: Vector3, along_z := false) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	if along_z:
		# Los cilindros van a lo largo de +Y: girados 90° en X apuntan a +Z.
		part.rotation.x = PI * 0.5
	parent.add_child(part)
	return part


func _make_smoke() -> CPUParticles3D:
	var smoke := make_smoke(SMOKE_PUFFS, SMOKE_LIFETIME, SMOKE_COLOR, 0.9, Vector2(0.6, 1.8),
		Vector2(0.18, 0.32), 2.2)
	smoke.direction = Vector3.UP
	smoke.spread = 35.0
	smoke.emitting = false
	return smoke


## Humo (una bocanada): bolas grises que salen hacia `direction`, se frenan,
## suben un poco, crecen hasta `grow` veces su tamaño y se desvanecen. La
## usan el cañón al disparar y la bomba al explotar.
static func make_smoke(amount: int, lifetime: float, color: Color, alpha: float, speed: Vector2,
		size: Vector2, grow: float) -> CPUParticles3D:
	_ensure_resources()
	var smoke := CPUParticles3D.new()
	smoke.one_shot = true
	smoke.explosiveness = 0.9
	smoke.amount = amount
	smoke.lifetime = lifetime
	smoke.local_coords = false
	smoke.initial_velocity_min = speed.x
	smoke.initial_velocity_max = speed.y
	smoke.damping_min = speed.y * 1.4
	smoke.damping_max = speed.y * 2.0
	smoke.gravity = Vector3(0.0, 0.35, 0.0)
	smoke.angle_min = 0.0
	smoke.angle_max = 360.0
	smoke.scale_amount_min = size.x
	smoke.scale_amount_max = size.y
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0 / grow))
	curve.add_point(Vector2(0.35, 0.75))
	curve.add_point(Vector2(1.0, 1.0))
	smoke.scale_amount_curve = curve
	var fade := Gradient.new()
	fade.set_color(0, Color(color.r, color.g, color.b, alpha))
	fade.add_point(0.5, Color(color.r, color.g, color.b, alpha * 0.6))
	fade.set_color(fade.get_point_count() - 1, Color(color.r, color.g, color.b, 0.0))
	smoke.color_ramp = fade
	smoke.mesh = _smoke_mesh
	smoke.material_override = _smoke_material
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return smoke


## Disco plano en el plano XZ mirando hacia +Y (un triángulo por lado).
static func _make_disc(radius: float, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in segments:
		var a := TAU * i / segments
		var b := TAU * (i + 1) / segments
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(b), 0.0, sin(b)) * radius)
		st.add_vertex(Vector3(cos(a), 0.0, sin(a)) * radius)
	return st.commit()


## Textura de las bocanadas de humo (la usa también el fuego de Bomb).
static func puff_texture() -> Texture2D:
	_ensure_resources()
	return _smoke_material.albedo_texture


## Textura redonda que se difumina hacia el borde, para el humo (mezcla
## normal, no sumada: el humo tapa lo que tiene detrás).
static func _make_puff_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.add_point(0.5, Color(1, 1, 1, 0.7))
	gradient.set_color(gradient.get_point_count() - 1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	return texture


static func _ensure_resources() -> void:
	if _iron_material:
		return
	_iron_material = StandardMaterial3D.new()
	_iron_material.albedo_color = Color(0.2, 0.21, 0.23)
	_iron_material.metallic = 0.55
	_iron_material.roughness = 0.45
	_brass_material = StandardMaterial3D.new()
	_brass_material.albedo_color = Color(0.74, 0.56, 0.24)
	_brass_material.metallic = 0.7
	_brass_material.roughness = 0.35
	_bore_material = StandardMaterial3D.new()
	_bore_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bore_material.albedo_color = Color(0.02, 0.02, 0.02)
	_bore_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_flash_material = LaserCannon.glow_material(Color(1.0, 0.72, 0.35), 1.0)
	_smoke_material = StandardMaterial3D.new()
	_smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_smoke_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_smoke_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_smoke_material.vertex_color_use_as_albedo = true
	_smoke_material.albedo_texture = _make_puff_texture()
	_smoke_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_base_mesh = CylinderMesh.new()
	_base_mesh.top_radius = BASE_RADIUS * 0.9
	_base_mesh.bottom_radius = BASE_RADIUS
	_base_mesh.height = BASE_HEIGHT
	_base_mesh.radial_segments = 14
	_base_mesh.rings = 0
	_base_mesh.cap_bottom = false
	_rim_mesh = CylinderMesh.new()
	_rim_mesh.top_radius = BASE_RADIUS * 0.62
	_rim_mesh.bottom_radius = BASE_RADIUS * 0.66
	_rim_mesh.height = 0.025
	_rim_mesh.radial_segments = 14
	_rim_mesh.rings = 0
	_rim_mesh.cap_bottom = false
	_cheek_mesh = BoxMesh.new()
	_cheek_mesh.size = Vector3(0.04, 0.17, 0.2)
	_barrel_mesh = CylinderMesh.new()
	_barrel_mesh.top_radius = BARREL_RADIUS
	_barrel_mesh.bottom_radius = BARREL_RADIUS * 1.2
	_barrel_mesh.height = BARREL_LENGTH + BARREL_BACK
	_barrel_mesh.radial_segments = 12
	_barrel_mesh.rings = 0
	_barrel_mesh.cap_top = false
	_barrel_mesh.cap_bottom = false
	_ring_mesh = CylinderMesh.new()
	_ring_mesh.top_radius = BARREL_RADIUS * 1.25
	_ring_mesh.bottom_radius = BARREL_RADIUS * 1.25
	_ring_mesh.height = 0.04
	_ring_mesh.radial_segments = 12
	_ring_mesh.rings = 0
	_breech_mesh = SphereMesh.new()
	_breech_mesh.radius = BARREL_RADIUS * 1.2
	_breech_mesh.height = BARREL_RADIUS * 2.4
	_breech_mesh.radial_segments = 12
	_breech_mesh.rings = 6
	_bore_mesh = _make_disc(BARREL_RADIUS * 0.78, 12)
	_flash_mesh = QuadMesh.new()
	_flash_mesh.size = Vector2.ONE
	_smoke_mesh = QuadMesh.new()
	_smoke_mesh.size = Vector2.ONE
