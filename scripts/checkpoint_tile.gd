class_name CheckpointTile
extends Node3D
## Casilla de inicio (ver Level: la salida 'A' y las del campo "checkpoints"
## del nivel). Tiene dos estados: activada (baldosa azul de la salida con su
## luz, TileGlow) y desactivada (baldosa azul apagada, sin luz). Solo una
## está activada a la vez: el cubo reaparece en ella al morir. Al pasar el
## cubo por una desactivada, se activa (con un destello que crece desde la
## baldosa) y las demás se apagan (ver Level.cube_entered).
##
## El nodo va en el centro de la casilla, a ras de suelo.

const OFF_COLOR := Color(0.36, 0.42, 0.52)
## Destello al activarse: lo que dura y hasta dónde crece.
const PULSE_TIME := 0.5
const PULSE_SCALE := 1.6

static var _materials := {}

var active := false
var _tile: MeshInstance3D
var _glow: TileGlow
var _ring: MeshInstance3D


func _ready() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(Level.CELL_SIZE * 0.96, Level.FLOOR_THICKNESS, Level.CELL_SIZE * 0.96)
	_tile = MeshInstance3D.new()
	_tile.mesh = mesh
	_tile.position.y = -Level.FLOOR_THICKNESS * 0.5
	add_child(_tile)
	_glow = TileGlow.create(Level.START_COLOR)
	add_child(_glow)
	_apply()


## Activa o desactiva la casilla; con `animate`, el destello de activación.
func set_active(value: bool, animate := false) -> void:
	active = value
	if is_node_ready():
		_apply()
	if animate and value:
		_pulse()


## Fundido de la aparición del nivel (ver Level._apply_reveal).
func set_reveal_alpha(alpha: float) -> void:
	_glow.set_reveal_alpha(alpha)


func _apply() -> void:
	(_tile.mesh as BoxMesh).material = _material(Level.START_COLOR if active else OFF_COLOR)
	_glow.visible = active


## Anillo de luz que se abre desde la baldosa y se desvanece.
func _pulse() -> void:
	if _ring == null:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.38
		torus.outer_radius = 0.48
		torus.rings = 32
		torus.ring_segments = 6
		_ring = MeshInstance3D.new()
		_ring.mesh = torus
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Level.START_COLOR.lightened(0.3)
		_ring.material_override = mat
		_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ring.position.y = 0.05
		add_child(_ring)
	var ring_mat := _ring.material_override as StandardMaterial3D
	_ring.visible = true
	_ring.scale = Vector3(0.6, 0.3, 0.6)
	ring_mat.albedo_color.a = 1.0
	var tween := _ring.create_tween().set_parallel()
	tween.tween_property(_ring, "scale", Vector3(PULSE_SCALE, 0.3, PULSE_SCALE), PULSE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring_mat, "albedo_color:a", 0.0, PULSE_TIME)
	tween.chain().tween_callback(_ring.hide)


static func _material(color: Color) -> StandardMaterial3D:
	if _materials.has(color):
		return _materials[color]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	_materials[color] = mat
	return mat
