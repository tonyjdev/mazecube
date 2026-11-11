class_name TreasureChest
extends Node3D
## Cofre del mapa (ver Level, campo "chests" del nivel): un baúl de madera con
## herrajes dorados sobre una casilla libre. Es un obstáculo como un muro (el
## cubo rebota) que solo se abre con un dash contra él o con un pisotón que
## lo alcance (ver Level.open_chest y Level.stomp).
##
## Al abrirse (open) la tapa se levanta de golpe, sale un destello dorado y
## Level suelta las monedas; OPEN_LINGER segundos después el cofre encoge y
## se hunde hasta desaparecer (emite vanished, y entonces la casilla queda
## libre). Un cofre abierto no vuelve a salir en ese nivel (ver
## GameState.open_chest).
##
## El nodo va en el centro de la casilla, a ras de suelo, girado para que el
## cierre (su +Z local) mire hacia la casilla libre de al lado.

signal vanished

const WOOD := Color(0.55, 0.32, 0.16)
const WOOD_DARK := Color(0.38, 0.21, 0.1)
const METAL := Color(0.95, 0.74, 0.25)
const BASE_SIZE := Vector3(0.66, 0.36, 0.46)
const LID_HEIGHT := 0.16
## Apertura: lo que tarda la tapa en abrirse y cuánto gira.
const OPEN_TIME := 0.3
const OPEN_ANGLE := -1.95
## Segundos que se queda abierto antes de desaparecer, y lo que tarda en irse.
const OPEN_LINGER := 2.0
const VANISH_TIME := 0.45
const FLASH_COLOR := Color(1.0, 0.86, 0.35)

static var _materials := {}

var is_open := false
var _lid: Node3D
var _flash: MeshInstance3D


func _ready() -> void:
	var half := BASE_SIZE * 0.5
	# Caja de madera con una tira oscura abajo, dos flejes dorados y esquinas.
	_box(BASE_SIZE, Vector3(0, half.y, 0), WOOD)
	_box(Vector3(BASE_SIZE.x + 0.02, 0.05, BASE_SIZE.z + 0.02), Vector3(0, 0.025, 0), WOOD_DARK)
	for x: float in [-0.2, 0.2]:
		_box(Vector3(0.06, BASE_SIZE.y + 0.01, BASE_SIZE.z + 0.02), Vector3(x, half.y, 0), METAL)
	# Tapa (gira sobre el borde de atrás).
	_lid = Node3D.new()
	_lid.position = Vector3(0, BASE_SIZE.y, -half.z)
	add_child(_lid)
	var lid_box := _box(Vector3(BASE_SIZE.x + 0.02, LID_HEIGHT, BASE_SIZE.z + 0.02),
		Vector3(0, LID_HEIGHT * 0.5, half.z), WOOD, _lid)
	lid_box.name = "LidBox"
	for x: float in [-0.2, 0.2]:
		_box(Vector3(0.07, LID_HEIGHT + 0.02, BASE_SIZE.z + 0.04), Vector3(x, LID_HEIGHT * 0.5, half.z),
			METAL, _lid)
	# Cierre dorado en la cara de delante.
	_box(Vector3(0.12, 0.13, 0.04), Vector3(0, BASE_SIZE.y - 0.02, half.z + 0.02), METAL)
	# Destello de la apertura (oculto hasta abrir).
	_flash = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	sphere.radial_segments = 16
	sphere.rings = 8
	_flash.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = FLASH_COLOR
	_flash.material_override = mat
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.position = Vector3(0, BASE_SIZE.y + 0.1, 0)
	_flash.visible = false
	add_child(_flash)


## Se abre: la tapa salta, destello y, al rato, desaparece (vanished).
func open() -> void:
	if is_open:
		return
	is_open = true
	var lid := create_tween()
	lid.tween_property(_lid, "rotation:x", OPEN_ANGLE, OPEN_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash.visible = true
	_flash.scale = Vector3.ONE * 0.3
	var mat := _flash.material_override as StandardMaterial3D
	mat.albedo_color.a = 0.9
	var flash := create_tween().set_parallel()
	flash.tween_property(_flash, "scale", Vector3.ONE * 2.2, 0.45) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	flash.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	flash.chain().tween_callback(_flash.hide)
	var vanish := create_tween()
	vanish.tween_interval(OPEN_LINGER)
	vanish.tween_property(self, "scale", Vector3(1.15, 1.15, 1.15), 0.12)
	vanish.tween_property(self, "scale", Vector3.ONE * 0.01, VANISH_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	vanish.tween_callback(func() -> void:
		vanished.emit()
		queue_free())


func _box(size: Vector3, at: Vector3, color: Color, parent: Node3D = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	parent.add_child(instance)
	return instance


static func _material(color: Color) -> StandardMaterial3D:
	if _materials.has(color):
		return _materials[color]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.4 if color == METAL else 0.8
	mat.metallic = 0.5 if color == METAL else 0.0
	if color != METAL:
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_materials[color] = mat
	return mat
