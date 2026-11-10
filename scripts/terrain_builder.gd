class_name TerrainBuilder
extends RefCounted
## Mallas fusionadas del terreno (muros, baldosas y roca de debajo) para
## pintarlo deprisa durante la partida (ver Level).
##
## El tablero se parte en trozos de CHUNK × CHUNK casillas: cada trozo es una
## MeshInstance3D por bloque y tono (con dos superficies: la cara de arriba y
## los lados, con los materiales de BlockCatalog), así que lo que queda fuera
## de la cámara (y de la sombra) no se pinta. De cada caja solo se añaden las
## caras que se pueden ver: nunca la de abajo, y los lados solo si no están
## pegados a otro bloque que los tape (lo decide quien llama, con `sides`).
##
## Geometría y texturas iguales a BlockCatalog.make_mesh: la cara de arriba,
## girada `turns` cuartos de vuelta (para que no se note la repetición); los
## lados, con la textura empezando en el borde de arriba y el pie oscurecido
## (BlockCatalog.SIDE_BOTTOM_SHADE).
##
## Uso: add_box() por cada caja y build() para crear los nodos.

const CHUNK := 12
## Lados en el orden de `sides`: normal y eje horizontal de cada uno (de
## izquierda a derecha visto desde fuera), como en BlockCatalog.make_mesh.
const SIDES := [
	[Vector3.BACK, Vector3.RIGHT],
	[Vector3.FORWARD, Vector3.LEFT],
	[Vector3.RIGHT, Vector3.FORWARD],
	[Vector3.LEFT, Vector3.BACK],
]

## "trozo|bloque|tono|sombra" -> { "block", "tint", "shadow", "top": Surface, "side": Surface }
var _groups := {}
## "bloque|cara|tono" -> material (compartido entre trozos)
var _materials := {}


## Casilla vecina que puede tapar el lado `i` de SIDES.
static func side_neighbor(cell: Vector2i, i: int) -> Vector2i:
	var n: Vector3 = SIDES[i][0]
	return cell + Vector2i(int(n.x), int(n.z))


## Caja de tamaño `size` centrada en `center`. `top`: si lleva la cara de
## arriba; `sides`: cuáles de los cuatro lados (orden de SIDES) lleva.
func add_box(cell: Vector2i, center: Vector3, size: Vector3, block: String, tint: Color,
		top: bool, sides: Array[bool], turns: int, cast_shadow: bool) -> void:
	if not top and not sides.has(true):
		return
	var chunk := Vector2i(floori(float(cell.x) / CHUNK), floori(float(cell.y) / CHUNK))
	var key := "%d,%d|%s|%s|%s" % [chunk.x, chunk.y, block, tint.to_html(), cast_shadow]
	if not _groups.has(key):
		_groups[key] = {"block": block, "tint": tint, "shadow": cast_shadow,
			"top": Surface.new(), "side": Surface.new()}
	var group: Dictionary = _groups[key]
	var h := size * 0.5
	if top:
		var rot := Basis(Vector3.UP, -turns * PI * 0.5)
		var corners: Array[Vector3] = [Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z),
			Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]
		var uvs: Array[Vector2] = []
		for c in corners:
			var local := rot * c
			uvs.append(Vector2(local.x / size.x + 0.5, local.z / size.z + 0.5))
		_add_quad(group["top"], Vector3.UP, corners, uvs,
			[Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE], center)
	var low := Color(BlockCatalog.SIDE_BOTTOM_SHADE, BlockCatalog.SIDE_BOTTOM_SHADE,
		BlockCatalog.SIDE_BOTTOM_SHADE)
	for i in SIDES.size():
		if not sides[i]:
			continue
		var normal: Vector3 = SIDES[i][0]
		var axis: Vector3 = SIDES[i][1]
		var width := size.x if i < 2 else size.z
		var mid := normal * Vector3(h.x, 0, h.z).abs()
		var half := axis * width * 0.5
		var u0 := 0.5 - width * 0.5
		_add_quad(group["side"], normal,
			[mid - half + Vector3.UP * h.y, mid + half + Vector3.UP * h.y,
				mid + half - Vector3.UP * h.y, mid - half - Vector3.UP * h.y],
			[Vector2(u0, 0), Vector2(u0 + width, 0), Vector2(u0 + width, size.y), Vector2(u0, size.y)],
			[Color.WHITE, Color.WHITE, low, low], center)


## Crea los nodos de los trozos dentro de `parent`.
func build(parent: Node3D) -> void:
	for key: String in _groups:
		var group: Dictionary = _groups[key]
		var mesh := ArrayMesh.new()
		for face: String in ["top", "side"]:
			var surface: Surface = group[face]
			if surface.positions.is_empty():
				continue
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface.arrays())
			mesh.surface_set_material(mesh.get_surface_count() - 1,
				_material(group["block"], face, group["tint"]))
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if group["shadow"] \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(instance)
	_groups.clear()


func _material(block: String, face: String, tint: Color) -> Material:
	var key := "%s|%s|%s" % [block, face, tint.to_html()]
	if not _materials.has(key):
		_materials[key] = BlockCatalog.material(block, face, tint)
	return _materials[key]


## Cuadrilátero de dos triángulos mirando hacia `normal` (mismo orden de
## vértices que BlockCatalog._add_quad).
static func _add_quad(surface: Surface, normal: Vector3, verts: Array[Vector3], uvs: Array[Vector2],
		colors: Array, offset: Vector3) -> void:
	var order := [0, 1, 2, 0, 2, 3]
	if (verts[1] - verts[0]).cross(verts[2] - verts[0]).dot(normal) > 0.0:
		order = [0, 2, 1, 0, 3, 2]
	for i: int in order:
		surface.positions.append(verts[i] + offset)
		surface.normals.append(normal)
		surface.uvs.append(uvs[i])
		surface.colors.append(colors[i])


## Vértices de una superficie (en miembros para que append no copie el array).
class Surface:
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()

	func arrays() -> Array:
		var result := []
		result.resize(Mesh.ARRAY_MAX)
		result[Mesh.ARRAY_VERTEX] = positions
		result[Mesh.ARRAY_NORMAL] = normals
		result[Mesh.ARRAY_TEX_UV] = uvs
		result[Mesh.ARRAY_COLOR] = colors
		return result
