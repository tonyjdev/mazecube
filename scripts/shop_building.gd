class_name ShopBuilding
extends Node3D
## Tienda en el mapa: una casita blanca con toldo de rayas rojas y blancas,
## escaparate y puerta. Ocupa una casilla de muro (lo tapa entero) y mira hacia
## la casilla libre desde la que se entra: al chocar con ella de frente se
## abre la tienda (ver Level.is_shop, RollingCube.shop_reached y Shop).
##
## El nodo va en el centro de la casilla, a ras de suelo, girado para que su
## +Z local mire hacia la entrada (como WallButton).

const BODY_COLOR := Color(0.93, 0.92, 0.89)
const RED := Color(0.86, 0.22, 0.22)
const WHITE := Color(0.97, 0.96, 0.94)
const WOOD := Color(0.78, 0.47, 0.25)
const GLASS := Color(0.36, 0.68, 0.9)
const BODY_HEIGHT := 0.95
## Toldo: rayas, cuánto sale por delante y cuánto baja.
const AWNING_STRIPES := 7
const AWNING_OUT := 0.32
const AWNING_DROP := 0.16

static var _materials := {}


func _ready() -> void:
	var front := 0.51
	# Cuerpo: un poco más grande que la casilla para tapar el muro de debajo.
	_box(Vector3(1.02, BODY_HEIGHT, 1.02), Vector3(0, BODY_HEIGHT * 0.5, 0), BODY_COLOR)
	# Cornisa roja arriba.
	_box(Vector3(1.06, 0.06, 1.06), Vector3(0, BODY_HEIGHT + 0.03, 0), RED)
	# Escalón de madera delante.
	_box(Vector3(1.04, 0.05, 0.1), Vector3(0, 0.025, front + 0.05), WOOD)
	# Escaparate (izquierda) con su repisa.
	_box(Vector3(0.38, 0.32, 0.03), Vector3(-0.22, 0.5, front + 0.01), WOOD)
	_box(Vector3(0.31, 0.25, 0.03), Vector3(-0.22, 0.5, front + 0.025), GLASS)
	_box(Vector3(0.44, 0.03, 0.06), Vector3(-0.22, 0.33, front + 0.03), WOOD)
	# Puerta (derecha) con su travesaño y el pomo.
	_box(Vector3(0.3, 0.62, 0.03), Vector3(0.24, 0.36, front + 0.01), WOOD)
	_box(Vector3(0.23, 0.55, 0.03), Vector3(0.24, 0.36, front + 0.025), GLASS)
	_box(Vector3(0.23, 0.025, 0.035), Vector3(0.24, 0.36, front + 0.03), WOOD)
	_box(Vector3(0.03, 0.03, 0.03), Vector3(0.16, 0.36, front + 0.05), WHITE)
	_add_awning(front)


## Toldo inclinado de rayas rojas y blancas que sale por delante, con un
## festón de medias bolas en el borde.
func _add_awning(front: float) -> void:
	var width := 1.1
	var stripe := width / AWNING_STRIPES
	var slope := Vector2(AWNING_OUT, AWNING_DROP)
	var angle := atan2(AWNING_DROP, AWNING_OUT)
	var top := Vector3(0, BODY_HEIGHT - 0.02, front)
	for i in AWNING_STRIPES:
		var color := RED if i % 2 == 0 else WHITE
		var x := -width * 0.5 + stripe * (i + 0.5)
		var mid := top + Vector3(x, -AWNING_DROP * 0.5, AWNING_OUT * 0.5)
		var piece := _box(Vector3(stripe, 0.025, slope.length()), mid, color)
		piece.rotation.x = angle
		var scallop := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = stripe * 0.5
		ball.height = stripe * 0.5
		ball.radial_segments = 10
		ball.rings = 3
		ball.is_hemisphere = true
		ball.material = _material(color)
		scallop.mesh = ball
		scallop.rotation.x = PI
		scallop.position = top + Vector3(x, -AWNING_DROP, AWNING_OUT)
		add_child(scallop)


func _box(size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	add_child(instance)
	return instance


static func _material(color: Color) -> StandardMaterial3D:
	if _materials.has(color):
		return _materials[color]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.75
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_materials[color] = mat
	return mat
