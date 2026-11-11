class_name BlockCatalog
extends RefCounted
## Catálogo de materiales de bloque para el suelo, los muros y la roca bajo el
## tablero. Todos están disponibles en cualquier nivel: cada nivel elige los
## suyos (ver Levels, campo "theme") y puede mezclar varios por zonas del
## mapa (campo "theme_regions") para hacer transiciones.
##
## Cada bloque tiene una textura para la cara de arriba y otra para los
## lados (textures/blocks/<id>_top.png y <id>_side.png, generadas con
## tools/make_block_textures.py). La textura lateral empieza en el borde de
## arriba del bloque y cada unidad de altura ocupa la textura entera: un muro
## enseña la mitad de arriba y una baldosa solo la franja superior (el césped
## que cuelga, la nieve...).
##
## Propiedades de cada bloque (todas opcionales salvo "name"):
##   name       nombre para mostrar
##   under      bloque de la roca que va debajo en los niveles con vacío (por
##              defecto, el mismo)
##   spin       giros de 90° al azar de la cara de arriba en cada casilla para
##              que no se note la repetición: 4 = cualquier giro, 2 = solo
##              media vuelta (dibujos con dirección, como tablones), 1 = nunca
##   roughness, metallic, specular   ajustes del StandardMaterial3D
##   emission   intensidad de la luz propia (usa <id>_*_emit.png)

const TEXTURE_DIR := "res://textures/blocks/"

const BLOCKS := {
	"grass": {"name": "Hierba", "under": "dirt"},
	"grass_flowers": {"name": "Hierba con flores", "under": "dirt"},
	"grass_dry": {"name": "Hierba seca", "under": "dirt"},
	"dirt": {"name": "Tierra"},
	"stone": {"name": "Piedra"},
	"stone_bricks": {"name": "Sillería", "spin": 2},
	"mossy_stone": {"name": "Piedra con musgo", "under": "stone", "spin": 2},
	"granite": {"name": "Granito", "spin": 2, "roughness": 0.45, "specular": 0.6},
	"sand": {"name": "Arena", "under": "sandstone"},
	"sandstone": {"name": "Arenisca", "spin": 2},
	"snow": {"name": "Nieve", "under": "stone"},
	"ice": {"name": "Hielo", "roughness": 0.12, "specular": 0.9},
	"lava": {"name": "Lava", "under": "magma", "emission": 1.6},
	"magma": {"name": "Roca volcánica", "emission": 1.4},
	"fire": {"name": "Fuego", "under": "magma", "emission": 1.2},
	"wood_planks": {"name": "Tablones", "spin": 2},
	"wood_log": {"name": "Tronco", "spin": 2},
	"brick": {"name": "Ladrillo", "spin": 2},
	"metal": {"name": "Metal", "spin": 2, "roughness": 0.35, "metallic": 0.55},
	"obsidian": {"name": "Obsidiana", "roughness": 0.2, "specular": 0.8},
	"crystal": {"name": "Cristal", "roughness": 0.25, "specular": 0.8, "emission": 0.7},
	"corrupted": {"name": "Tierra corrompida", "emission": 1.4},
}

## Oscurecimiento del pie de los lados del bloque (sombra de contacto).
const SIDE_BOTTOM_SHADE := 0.72


static func ids() -> Array:
	return BLOCKS.keys()


static func has(id: String) -> bool:
	return BLOCKS.has(id)


static func display_name(id: String) -> String:
	return BLOCKS[id]["name"]


## Bloque que va debajo de `id` (la roca de los niveles con vacío).
static func under(id: String) -> String:
	return BLOCKS[id].get("under", id)


## Giros posibles de la cara de arriba (ver "spin").
static func spin(id: String) -> int:
	return BLOCKS[id].get("spin", 4)


## Material nuevo (cada llamada devuelve uno distinto, para poder tocarlo,
## p. ej. en los fundidos) de la cara "top" o "side" del bloque. `tint`
## multiplica el color de la textura.
static func material(id: String, face: String, tint := Color.WHITE) -> StandardMaterial3D:
	var info: Dictionary = BLOCKS[id]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(TEXTURE_DIR + "%s_%s.png" % [id, face])
	mat.albedo_color = tint
	# El color de los vértices lleva la sombra del pie de los lados y el de
	# las instancias de MultiMesh la opacidad de la aparición del nivel.
	mat.vertex_color_use_as_albedo = true
	mat.roughness = info.get("roughness", 0.9)
	mat.metallic = info.get("metallic", 0.0)
	mat.metallic_specular = info.get("specular", 0.5)
	# Sin el destello directo del sol: con el ángulo de la cámara no se llega
	# a ver y en el móvil cuesta hasta 9 fps en pantallas llenas de bloques.
	# Los reflejos del cielo (lo que da el brillo al metal o al hielo) siguen.
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if info.has("emission"):
		mat.emission_enabled = true
		mat.emission = Color.BLACK
		mat.emission_texture = load(TEXTURE_DIR + "%s_%s_emit.png" % [id, face])
		mat.emission_energy_multiplier = info["emission"]
		mat.emission_operator = BaseMaterial3D.EMISSION_OP_ADD
	return mat


## Caja de tamaño `size` centrada en el origen con los materiales del bloque:
## superficie 0 = cara de arriba, superficie 1 = lados y cara de abajo.
static func make_mesh(id: String, size: Vector3, tint := Color.WHITE) -> ArrayMesh:
	var h := size * 0.5
	var mesh := ArrayMesh.new()

	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_quad(top, Vector3.UP,
		[Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)],
		[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)],
		[Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	top.commit(mesh)
	mesh.surface_set_material(0, material(id, "top", tint))

	var sides := SurfaceTool.new()
	sides.begin(Mesh.PRIMITIVE_TRIANGLES)
	var low := Color(SIDE_BOTTOM_SHADE, SIDE_BOTTOM_SHADE, SIDE_BOTTOM_SHADE)
	var shades := [Color.WHITE, Color.WHITE, low, low]
	# Cada lado: normal, eje horizontal (de izquierda a derecha visto desde
	# fuera) y su anchura. La v va en unidades del mundo desde el borde de
	# arriba, la u también (una casilla = la textura entera).
	for side: Array in [[Vector3.BACK, Vector3.RIGHT, size.x], [Vector3.FORWARD, Vector3.LEFT, size.x],
			[Vector3.RIGHT, Vector3.FORWARD, size.z], [Vector3.LEFT, Vector3.BACK, size.z]]:
		var normal: Vector3 = side[0]
		var axis: Vector3 = side[1]
		var width: float = side[2]
		var center := normal * Vector3(h.x, 0, h.z).abs()
		var half := axis * width * 0.5
		var u0 := 0.5 - width * 0.5
		_add_quad(sides, normal,
			[center - half + Vector3.UP * h.y, center + half + Vector3.UP * h.y,
				center + half - Vector3.UP * h.y, center - half - Vector3.UP * h.y],
			[Vector2(u0, 0), Vector2(u0 + width, 0), Vector2(u0 + width, size.y), Vector2(u0, size.y)],
			shades)
	_add_quad(sides, Vector3.DOWN,
		[Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z)],
		[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)],
		[low, low, low, low])
	sides.commit(mesh)
	mesh.surface_set_material(1, material(id, "side", tint))
	return mesh


## Cuadrilátero de dos triángulos. Ordena los vértices para que la cara
## mire hacia `normal` (Godot toma como cara delantera la que se ve con los
## vértices en el sentido de las agujas del reloj).
static func _add_quad(st: SurfaceTool, normal: Vector3, verts: Array, uvs: Array, colors: Array) -> void:
	var order := [0, 1, 2, 0, 2, 3]
	if (verts[1] - verts[0]).cross(verts[2] - verts[0]).dot(normal) > 0.0:
		order = [0, 2, 1, 0, 3, 2]
	for i: int in order:
		st.set_normal(normal)
		st.set_uv(uvs[i])
		st.set_color(colors[i])
		st.add_vertex(verts[i])
