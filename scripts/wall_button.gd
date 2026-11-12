class_name WallButton
extends Node3D
## Botón pegado a la cara de un muro: una placa metálica con un pulsador rojo.
##
## El nodo se coloca en el centro de la cara del muro, a ras de suelo, y el
## pulsador sobresale hacia +Z local (Level lo gira para que mire a la
## casilla libre). Al pulsarlo se hunde en la placa y vuelve a salir.
##
## Encima del muro, junto al borde de la cara del botón, lleva un piloto rojo
## (para verlo desde ángulos en los que la placa queda tapada): siempre está
## apagado salvo LAMP_ON_TIME segundos después de cada pulsación.

const PLATE_SIZE := Vector3(0.42, 0.32, 0.04)
const HEIGHT := 0.25
const PUSHER_RADIUS := 0.11
const PUSHER_DEPTH := 0.07
## Lo que se hunde el pulsador al pulsarlo.
const PRESS_DEPTH := 0.05
const PRESS_TIME := 0.07
const RELEASE_TIME := 0.22
const PLATE_COLOR := Color(0.40, 0.42, 0.46)
const PUSHER_COLOR := Color(0.90, 0.18, 0.15)
## Piloto: radio de la cúpula, distancia al borde del muro, base metálica y
## colores/brillo apagado y encendido.
const LAMP_RADIUS := 0.075
const LAMP_INSET := 0.13
const LAMP_BASE_RADIUS := 0.1
const LAMP_BASE_HEIGHT := 0.025
const LAMP_OFF_COLOR := Color(0.32, 0.06, 0.05)
const LAMP_ON_COLOR := Color(1.0, 0.22, 0.16)
const LAMP_ON_ENERGY := 3.0
const LAMP_ON_TIME := 1.0
## Halo del piloto encendido (sprite aditivo) y su tamaño.
const LAMP_HALO_SIZE := 0.42

var _pusher: MeshInstance3D
var _rest_z := 0.0
var _tween: Tween
var _lamp_mat: StandardMaterial3D
var _halo: MeshInstance3D
var _lamp_tween: Tween


func _ready() -> void:
	var plate_mat := StandardMaterial3D.new()
	plate_mat.albedo_color = PLATE_COLOR
	plate_mat.metallic = 0.7
	plate_mat.roughness = 0.4
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = PLATE_SIZE
	plate_mesh.material = plate_mat
	var plate := MeshInstance3D.new()
	plate.mesh = plate_mesh
	plate.position = Vector3(0, HEIGHT, PLATE_SIZE.z * 0.5)
	add_child(plate)

	var pusher_mat := StandardMaterial3D.new()
	pusher_mat.albedo_color = PUSHER_COLOR
	pusher_mat.roughness = 0.45
	pusher_mat.emission_enabled = true
	pusher_mat.emission = PUSHER_COLOR
	pusher_mat.emission_energy_multiplier = 0.25
	var pusher_mesh := CylinderMesh.new()
	pusher_mesh.top_radius = PUSHER_RADIUS
	pusher_mesh.bottom_radius = PUSHER_RADIUS
	pusher_mesh.height = PUSHER_DEPTH
	pusher_mesh.radial_segments = 20
	pusher_mesh.rings = 1
	pusher_mesh.material = pusher_mat
	_pusher = MeshInstance3D.new()
	_pusher.mesh = pusher_mesh
	# El cilindro va a lo largo de +Y: girado 90° en X apunta a +Z.
	_pusher.rotation.x = PI * 0.5
	_rest_z = PLATE_SIZE.z + PUSHER_DEPTH * 0.5
	_pusher.position = Vector3(0, HEIGHT, _rest_z)
	add_child(_pusher)
	_make_lamp(plate_mat)


## Piloto sobre el muro: base metálica, cúpula roja y halo (oculto).
func _make_lamp(base_mat: StandardMaterial3D) -> void:
	var top := Vector3(0, Level.WALL_HEIGHT, -LAMP_INSET)
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = LAMP_BASE_RADIUS
	base_mesh.bottom_radius = LAMP_BASE_RADIUS
	base_mesh.height = LAMP_BASE_HEIGHT
	base_mesh.radial_segments = 16
	base_mesh.rings = 1
	base_mesh.material = base_mat
	var base := MeshInstance3D.new()
	base.mesh = base_mesh
	base.position = top + Vector3(0, LAMP_BASE_HEIGHT * 0.5, 0)
	add_child(base)

	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.roughness = 0.25
	_lamp_mat.emission_enabled = true
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = LAMP_RADIUS
	dome_mesh.height = LAMP_RADIUS
	dome_mesh.is_hemisphere = true
	dome_mesh.radial_segments = 16
	dome_mesh.rings = 4
	dome_mesh.material = _lamp_mat
	var dome := MeshInstance3D.new()
	dome.mesh = dome_mesh
	dome.position = top + Vector3(0, LAMP_BASE_HEIGHT, 0)
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dome)

	var halo_mat := StandardMaterial3D.new()
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo_mat.albedo_texture = TileGlow.dot_texture()
	halo_mat.albedo_color = Color(LAMP_ON_COLOR, 0.8)
	var halo_mesh := QuadMesh.new()
	halo_mesh.size = Vector2.ONE * LAMP_HALO_SIZE
	halo_mesh.material = halo_mat
	_halo = MeshInstance3D.new()
	_halo.mesh = halo_mesh
	_halo.position = top + Vector3(0, LAMP_BASE_HEIGHT + LAMP_RADIUS * 0.4, 0)
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)
	_set_lamp(false)


func _set_lamp(on: bool) -> void:
	_lamp_mat.albedo_color = LAMP_ON_COLOR if on else LAMP_OFF_COLOR
	_lamp_mat.emission = LAMP_ON_COLOR if on else LAMP_OFF_COLOR
	_lamp_mat.emission_energy_multiplier = LAMP_ON_ENERGY if on else 0.15
	_halo.visible = on


## Animación de pulsado: el pulsador se hunde y vuelve a su sitio.
func press() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_pusher, "position:z", _rest_z - PRESS_DEPTH, PRESS_TIME)
	_tween.tween_property(_pusher, "position:z", _rest_z, RELEASE_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Piloto: se enciende LAMP_ON_TIME segundos (una nueva pulsación reinicia
	# la cuenta).
	if _lamp_tween and _lamp_tween.is_valid():
		_lamp_tween.kill()
	_set_lamp(true)
	_lamp_tween = create_tween()
	_lamp_tween.tween_interval(LAMP_ON_TIME)
	_lamp_tween.tween_callback(_set_lamp.bind(false))
