class_name WallButton
extends Node3D
## Botón pegado a la cara de un muro: una placa metálica con un pulsador rojo.
##
## El nodo se coloca en el centro de la cara del muro, a ras de suelo, y el
## pulsador sobresale hacia +Z local (Level lo gira para que mire a la
## casilla libre). Al pulsarlo se hunde en la placa y vuelve a salir.

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

var _pusher: MeshInstance3D
var _rest_z := 0.0
var _tween: Tween


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


## Animación de pulsado: el pulsador se hunde y vuelve a su sitio.
func press() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_pusher, "position:z", _rest_z - PRESS_DEPTH, PRESS_TIME)
	_tween.tween_property(_pusher, "position:z", _rest_z, RELEASE_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
