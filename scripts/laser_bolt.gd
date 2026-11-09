class_name LaserBolt
extends Node3D
## Proyectil de un cañón láser (ver LaserCannon y Level): un trazo blanco con
## un halo rojo alrededor y un reflejo rojo en el suelo. Level lo mueve
## (board_pos, en casillas) y decide cuándo choca; entonces llama a
## explode(), que deja una ráfaga de chispas donde ha chocado y lo borra.
##
## El nodo está a la altura del cañón (LaserCannon.HEIGHT) y el trazo va a lo
## largo de +Z local, en el sentido de `direction`.

## Largo del trazo (en casillas).
const LENGTH := 0.5
const CORE_RADIUS := 0.032
const HALO_SIZE := Vector2(0.34, 1.05)
const FLOOR_GLOW_SIZE := Vector2(0.8, 1.4)
const GLOW_COLOR := Color(1.0, 0.12, 0.08)
const SPARK_COUNT := 24
const SPARK_LIFETIME := 0.45
const IMPACT_FLASH_TIME := 0.12

static var _core_mesh: CapsuleMesh
static var _core_material: StandardMaterial3D
static var _halo_material: StandardMaterial3D
static var _floor_material: StandardMaterial3D
static var _impact_material: StandardMaterial3D

## Sentido del movimiento en casillas: (1, 0), (-1, 0), (0, 1) o (0, -1).
var direction := Vector2(0, 1)
## Centro del trazo en coordenadas de casilla (x, z).
var board_pos := Vector2.ZERO:
	set(value):
		board_pos = value
		position = Vector3(value.x * Level.CELL_SIZE, LaserCannon.HEIGHT, value.y * Level.CELL_SIZE)


static func create(from: Vector2, dir: Vector2) -> LaserBolt:
	var bolt := LaserBolt.new()
	bolt.direction = dir
	bolt.board_pos = from
	bolt.rotation.y = atan2(dir.x, dir.y)
	return bolt


func _ready() -> void:
	_ensure_resources()
	var core := MeshInstance3D.new()
	core.mesh = _core_mesh
	core.material_override = _core_material
	core.rotation.x = PI * 0.5
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	# Halo: dos planos cruzados a lo largo del trazo (uno vertical y otro
	# horizontal) para que se vea desde la cámara inclinada.
	for vertical in [false, true]:
		var halo := MeshInstance3D.new()
		var quad := QuadMesh.new()
		# El quad está en el plano XY: el horizontal se tumba (su Y pasa a
		# ser Z) y el vertical se gira en Y (su X pasa a ser Z).
		quad.size = Vector2(HALO_SIZE.y, HALO_SIZE.x) if vertical else HALO_SIZE
		halo.mesh = quad
		halo.material_override = _halo_material
		if vertical:
			halo.rotation.y = PI * 0.5
		else:
			halo.rotation.x = PI * 0.5
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(halo)
	# Reflejo rojo en el suelo.
	var glow := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = FLOOR_GLOW_SIZE
	glow.mesh = plane
	glow.material_override = _floor_material
	glow.rotation.x = -PI * 0.5
	glow.position.y = -LaserCannon.HEIGHT + 0.012
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)


## Choca en `at` (coordenadas de casilla): chispas que salen hacia atrás
## desde ese punto y un destello corto. El láser desaparece.
func explode(at: Vector2) -> void:
	var parent := get_parent()
	var world := Vector3(at.x * Level.CELL_SIZE, LaserCannon.HEIGHT, at.y * Level.CELL_SIZE)
	var back := Vector3(-direction.x, 0.25, -direction.y).normalized()
	var sparks := LaserCannon.make_sparks(SPARK_COUNT, SPARK_LIFETIME, back, 75.0, 1.2, 3.4)
	sparks.position = world
	parent.add_child(sparks)
	sparks.emitting = true
	sparks.finished.connect(sparks.queue_free)
	var flash := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.5
	flash.mesh = quad
	flash.material_override = _impact_material
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.position = world
	parent.add_child(flash)
	var tween := flash.create_tween().set_parallel()
	tween.tween_property(flash, "scale", Vector3.ONE * 1.4, IMPACT_FLASH_TIME)
	tween.tween_property(flash, "transparency", 1.0, IMPACT_FLASH_TIME)
	tween.chain().tween_callback(flash.queue_free)
	queue_free()


static func _ensure_resources() -> void:
	if _core_mesh:
		return
	_core_mesh = CapsuleMesh.new()
	_core_mesh.radius = CORE_RADIUS
	_core_mesh.height = LENGTH
	_core_mesh.radial_segments = 6
	_core_mesh.rings = 1
	_core_material = StandardMaterial3D.new()
	_core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_core_material.albedo_color = Color(1.0, 1.0, 1.0)
	_halo_material = LaserCannon.glow_material(GLOW_COLOR, 1.0, false)
	_floor_material = LaserCannon.glow_material(GLOW_COLOR, 0.45, false)
	_impact_material = LaserCannon.glow_material(Color(1.0, 0.7, 0.45), 1.0)
