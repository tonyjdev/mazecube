class_name LaserCannon
extends Node3D
## Cañón láser incrustado en un muro (ver Level, carácter 'L'): la casilla es
## en sus tres cuartas partes muro y en el cuarto que da a su única casilla
## libre está el cañón, del tamaño de un botón, sobre una placa con un aro de
## luces rojas.
##
## Espera un tiempo al azar entre MIN_WAIT y MAX_WAIT segundos y dispara. Los
## últimos WARN_TIME segundos de la espera las luces se apagan y se encienden
## BLINKS veces (emite beeped cada vez que se vuelven a encender, para el
## pitido); al disparar emite fired, hace un destello con chispas en la boca
## y las luces se quedan otra vez en rojo fijo. El proyectil (LaserBolt) lo
## crea y lo mueve Level.
##
## Level llama a update() en cada fotograma (no mientras aparece el tablero).
## El origen del nodo es el centro de la casilla a ras de suelo y el cañón
## apunta hacia +Z local (Level lo gira hacia la casilla libre); la boca está
## en el borde de la casilla (z = 0,5).

signal beeped
signal fired

const MIN_WAIT := 2.5
const MAX_WAIT := 4.5
const WARN_TIME := 0.5
const BLINKS := 4
## Altura del eje del cañón (la misma que la del botón) y del láser.
const HEIGHT := 0.25
## Parte de la casilla que ocupa el muro (el resto, hacia +Z, es del cañón).
const WALL_DEPTH := 0.75
const PLATE_SIZE := Vector3(0.44, 0.42, 0.03)
const HOUSING_RADIUS := 0.11
const HOUSING_LENGTH := 0.13
const BARREL_RADIUS := 0.05
const LIGHT_COUNT := 8
const LIGHT_RING_RADIUS := 0.165
const LIGHT_RADIUS := 0.022
const LIGHT_COLOR := Color(1.0, 0.08, 0.05)
const LIGHT_OFF_COLOR := Color(0.16, 0.03, 0.03)
## Destello de la boca al disparar.
const FLASH_TIME := 0.16
const FLASH_SIZE := 0.75

static var _metal_material: StandardMaterial3D
static var _dark_material: StandardMaterial3D
static var _flash_material: StandardMaterial3D
static var _spark_material: StandardMaterial3D
static var _glow_texture: GradientTexture2D
## Mallas compartidas por todos los cañones, con los polígonos justos: los
## cilindros sin las tapas que quedan tapadas y las luces y la boca como
## discos planos.
static var _plate_mesh: BoxMesh
static var _housing_mesh: CylinderMesh
static var _barrel_mesh: CylinderMesh
static var _lens_mesh: ArrayMesh
static var _light_mesh: ArrayMesh
static var _halo_mesh: QuadMesh
static var _flash_mesh: QuadMesh
## "bloque|tamaño|tinte" -> ArrayMesh (muros y suelos recortados).
static var _block_meshes := {}

var _time_left := 0.0
var _wall_block := "stone_bricks"
var _floor_block := "grass"
## Luces y su halo: cada cañón tiene los suyos para poder parpadear solo.
var _light_material: StandardMaterial3D
var _halo_material: StandardMaterial3D
var _lights_on := true
var _flash: MeshInstance3D
var _muzzle_sparks: CPUParticles3D


## `wall_block` y `floor_block` son los bloques del catálogo (BlockCatalog)
## del muro y del suelo que queda delante de él, bajo el cañón.
static func create(wall_block: String, floor_block: String) -> LaserCannon:
	var cannon := LaserCannon.new()
	cannon._wall_block = wall_block
	cannon._floor_block = floor_block
	cannon._time_left = randf_range(MIN_WAIT, MAX_WAIT)
	return cannon


func _ready() -> void:
	_ensure_resources()
	var face := WALL_DEPTH - 0.5
	# Muro recortado (de z = -0,5 a la cara) y suelo bajo el cañón, en el
	# cuarto de casilla que deja libre el muro.
	_add_part(_block_mesh(_wall_block, Vector3(1.0, Level.WALL_HEIGHT, WALL_DEPTH), Color.WHITE), null,
		Vector3(0.0, Level.WALL_HEIGHT * 0.5, (WALL_DEPTH - 1.0) * 0.5))
	_add_part(_block_mesh(_floor_block, Vector3(1.0, Level.FLOOR_THICKNESS, 1.0 - WALL_DEPTH),
		Level.FLOOR_DARK_TINT), null,
		Vector3(0.0, -Level.FLOOR_THICKNESS * 0.5, face + (1.0 - WALL_DEPTH) * 0.5))
	# Placa metálica pegada a la cara del muro, cuerpo del cañón y cañón, a lo
	# largo de +Z.
	_add_part(_plate_mesh, _metal_material, Vector3(0.0, HEIGHT, face + PLATE_SIZE.z * 0.5))
	_add_part(_housing_mesh, _metal_material,
		Vector3(0.0, HEIGHT, face + PLATE_SIZE.z + HOUSING_LENGTH * 0.5), true)
	_add_part(_barrel_mesh, _dark_material, Vector3(0.0, HEIGHT, 0.5 - _barrel_mesh.height * 0.5), true)
	# Boca: un disco rojo que se enciende y se apaga con las luces.
	_light_material = StandardMaterial3D.new()
	_light_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_light_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_part(_lens_mesh, _light_material, Vector3(0.0, HEIGHT, 0.501), true)
	# Aro de luces rojas (discos planos sobre la placa) con un halo de luz
	# sumada.
	_halo_material = _make_glow_material(LIGHT_COLOR, 0.9)
	var light_z := face + PLATE_SIZE.z + 0.002
	for i in LIGHT_COUNT:
		var angle := TAU * i / LIGHT_COUNT + PI / LIGHT_COUNT
		var at := Vector3(cos(angle) * LIGHT_RING_RADIUS, HEIGHT + sin(angle) * LIGHT_RING_RADIUS, light_z)
		_add_part(_light_mesh, _light_material, at, true)
		_add_part(_halo_mesh, _halo_material, at + Vector3(0.0, 0.0, LIGHT_RADIUS))
	# Destello de la boca (escondido hasta que dispara).
	_flash = _add_part(_flash_mesh, _flash_material, Vector3(0.0, HEIGHT, 0.55))
	_flash.visible = false
	_muzzle_sparks = _make_muzzle_sparks()
	add_child(_muzzle_sparks)
	_set_lights(true)


func update(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		_time_left += randf_range(MIN_WAIT, MAX_WAIT)
		_set_lights(true)
		_fire_effect()
		fired.emit()
		return
	if _time_left > WARN_TIME:
		return
	# Cada parpadeo: apagadas la primera mitad y encendidas la segunda.
	var period := WARN_TIME / BLINKS
	var t := WARN_TIME - _time_left
	var on := fmod(t, period) >= period * 0.5
	if on != _lights_on:
		_set_lights(on)
		if on:
			beeped.emit()


func _set_lights(on: bool) -> void:
	_lights_on = on
	_light_material.albedo_color = LIGHT_COLOR if on else LIGHT_OFF_COLOR
	_halo_material.albedo_color.a = 0.9 if on else 0.0


## Destello blanco y rojo que crece y se apaga, y chispas hacia delante.
func _fire_effect() -> void:
	_flash.visible = true
	_flash.scale = Vector3.ONE * FLASH_SIZE * 0.3
	_flash.transparency = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(_flash, "scale", Vector3.ONE * FLASH_SIZE, FLASH_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_flash, "transparency", 1.0, FLASH_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(_flash.hide)
	_muzzle_sparks.restart()


func _add_part(mesh: Mesh, material: Material, at: Vector3, along_z := false) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	if material:
		part.material_override = material
	part.position = at
	if along_z:
		# Los cilindros van a lo largo de +Y: girados 90° en X apuntan a +Z.
		part.rotation.x = PI * 0.5
	add_child(part)
	return part


func _make_muzzle_sparks() -> CPUParticles3D:
	var sparks := make_sparks(10, 0.28, Vector3.BACK, 30.0, 1.8, 3.8)
	sparks.position = Vector3(0.0, HEIGHT, 0.5)
	sparks.emitting = false
	return sparks


## Chispas sueltas (una ráfaga): rayitas de luz naranja que salen hacia
## `direction` (en coordenadas del padre), caen y se apagan. La usan el
## cañón al disparar y LaserBolt al chocar.
static func make_sparks(amount: int, lifetime: float, direction: Vector3, spread: float,
		speed_min: float, speed_max: float) -> CPUParticles3D:
	_ensure_resources()
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.explosiveness = 0.95
	sparks.amount = amount
	sparks.lifetime = lifetime
	sparks.local_coords = false
	sparks.direction = direction
	sparks.spread = spread
	sparks.initial_velocity_min = speed_min
	sparks.initial_velocity_max = speed_max
	sparks.gravity = Vector3(0.0, -7.0, 0.0)
	sparks.damping_min = 1.0
	sparks.damping_max = 2.0
	sparks.particle_flag_align_y = true
	sparks.scale_amount_min = 0.6
	sparks.scale_amount_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 0.9, 1.0))
	fade.add_point(0.18, Color(1.0, 0.55, 0.15, 1.0))
	fade.set_color(fade.get_point_count() - 1, Color(1.0, 0.15, 0.05, 0.0))
	sparks.color_ramp = fade
	var streak := BoxMesh.new()
	streak.size = Vector3(0.014, 0.09, 0.014)
	sparks.mesh = streak
	sparks.material_override = _spark_material
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return sparks


## Material de luz sumada con un círculo que se difumina hacia el borde (en
## un quad estirado sale una elipse). `billboard`: siempre de cara a la cámara.
static func _make_glow_material(color: Color, alpha: float, billboard := true) -> StandardMaterial3D:
	_ensure_glow_texture()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.albedo_texture = _glow_texture
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	if billboard:
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.billboard_keep_scale = true
	return mat


static func glow_material(color: Color, alpha: float, billboard := true) -> StandardMaterial3D:
	return _make_glow_material(color, alpha, billboard)


static func _ensure_glow_texture() -> void:
	if _glow_texture:
		return
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.add_point(0.35, Color(1, 1, 1, 0.45))
	gradient.set_color(gradient.get_point_count() - 1, Color(1, 1, 1, 0))
	_glow_texture = GradientTexture2D.new()
	_glow_texture.gradient = gradient
	_glow_texture.fill = GradientTexture2D.FILL_RADIAL
	_glow_texture.fill_from = Vector2(0.5, 0.5)
	_glow_texture.fill_to = Vector2(0.5, 0.0)
	_glow_texture.width = 64
	_glow_texture.height = 64


static func _block_mesh(block: String, size: Vector3, tint: Color) -> ArrayMesh:
	var key := "%s|%s|%s" % [block, size, tint]
	if not _block_meshes.has(key):
		_block_meshes[key] = BlockCatalog.make_mesh(block, size, tint)
	return _block_meshes[key]


## Disco plano de `segments` lados en el plano XZ, mirando hacia +Y (un
## triángulo por lado).
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


static func _ensure_resources() -> void:
	if _metal_material:
		return
	_plate_mesh = BoxMesh.new()
	_plate_mesh.size = PLATE_SIZE
	_housing_mesh = CylinderMesh.new()
	_housing_mesh.top_radius = HOUSING_RADIUS * 0.85
	_housing_mesh.bottom_radius = HOUSING_RADIUS
	_housing_mesh.height = HOUSING_LENGTH
	_housing_mesh.radial_segments = 10
	_housing_mesh.rings = 0
	_housing_mesh.cap_bottom = false
	_barrel_mesh = CylinderMesh.new()
	_barrel_mesh.top_radius = BARREL_RADIUS
	_barrel_mesh.bottom_radius = BARREL_RADIUS * 1.15
	_barrel_mesh.height = 0.5 - (WALL_DEPTH - 0.5 + PLATE_SIZE.z + HOUSING_LENGTH)
	_barrel_mesh.radial_segments = 8
	_barrel_mesh.rings = 0
	_barrel_mesh.cap_bottom = false
	_lens_mesh = _make_disc(BARREL_RADIUS * 0.6, 8)
	_light_mesh = _make_disc(LIGHT_RADIUS, 6)
	_halo_mesh = QuadMesh.new()
	_halo_mesh.size = Vector2.ONE * LIGHT_RADIUS * 7.0
	_flash_mesh = QuadMesh.new()
	_flash_mesh.size = Vector2.ONE
	_metal_material = StandardMaterial3D.new()
	_metal_material.albedo_color = Color(0.5, 0.52, 0.56)
	_metal_material.metallic = 0.45
	_metal_material.roughness = 0.45
	_dark_material = StandardMaterial3D.new()
	_dark_material.albedo_color = Color(0.12, 0.12, 0.14)
	_dark_material.metallic = 0.6
	_dark_material.roughness = 0.35
	# Destello: centro blanco con un borde rojizo (el color de la textura
	# multiplica al rojo claro).
	_flash_material = _make_glow_material(Color(1.0, 0.75, 0.7), 1.0)
	_spark_material = StandardMaterial3D.new()
	_spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spark_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_spark_material.vertex_color_use_as_albedo = true
