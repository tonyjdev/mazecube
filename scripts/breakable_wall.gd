class_name BreakableWall
extends Node3D
## Muro destructible: un cubo de piedra con grietas que se rompe tras varios golpes.
##
## `hits` es el estado del muro, los golpes que le quedan: de 5 (pocas grietas)
## a 1 (muchas grietas). Cada golpe de frente del cubo lo baja en uno y
## muestra las grietas del nuevo estado. Al llegar a 0 el muro se rompe: el
## bloque desaparece, sus pedazos caen al suelo y se desvanecen, y el nodo se
## libera solo. Desde ese momento la casilla ya se puede atravesar (lo
## gestiona Level).

const MAX_HITS := 5
const SIZE := 0.9
const STONE_COLOR := Color(0.76, 0.66, 0.52)
const CRACK_COLOR := Color(0.16, 0.11, 0.08)
const CRACK_HIGHLIGHT := Color(0.90, 0.82, 0.70)
## Grietas por cara en cada estado (índice = golpes que le quedan). Cada
## estado conserva las grietas del anterior y añade otras nuevas.
const CRACKS_PER_STATE: Array[int] = [0, 10, 7, 5, 3, 1]
## Tamaño en píxeles de cada cara en la textura. BoxMesh reparte sus seis
## caras en una rejilla de 3×2, así que cada cara tiene sus propias grietas.
const TILE := 96
## Al romperse, el bloque se parte en PIECES_PER_SIDE³ pedazos.
const PIECES_PER_SIDE := 3
const GRAVITY := 14.0
const PIECE_LIFETIME := 1.5
const PIECE_SHRINK_TIME := 0.5
## Temblor del bloque al recibir un golpe: varios empujones rápidos en la
## dirección del golpe.
const HIT_NUDGE := 0.05
const HIT_SHAKES := 4
const HIT_NUDGE_OUT_TIME := 0.025
const HIT_NUDGE_BACK_TIME := 0.1

## Materiales compartidos por todos los muros (índice = golpes que le quedan).
static var _materials: Array[StandardMaterial3D] = []

var hits := MAX_HITS
var _mesh: MeshInstance3D
var _hit_tween: Tween
## Pedazos que caen: { "node": MeshInstance3D, "vel": Vector3, "spin": Vector3, "size": float }
var _pieces: Array[Dictionary] = []
var _break_age := 0.0


func _init(initial_hits := MAX_HITS) -> void:
	hits = clampi(initial_hits, 1, MAX_HITS)


func _ready() -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE * SIZE
	_mesh = MeshInstance3D.new()
	_mesh.mesh = box
	_mesh.position = _rest_position()
	_mesh.material_override = material_for(hits)
	add_child(_mesh)
	set_process(false)


## Golpe de frente en la dirección `direction` (del cubo hacia el muro).
## Devuelve los golpes que le quedan; con 0 el muro se rompe.
func hit(direction: Vector3) -> int:
	if hits <= 0:
		return 0
	hits -= 1
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	if hits == 0:
		_shatter()
		return 0
	_mesh.material_override = material_for(hits)
	_mesh.position = _rest_position()
	_hit_tween = create_tween()
	for i in HIT_SHAKES:
		_hit_tween.tween_property(_mesh, "position", _rest_position() + direction * HIT_NUDGE,
				HIT_NUDGE_OUT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_hit_tween.tween_property(_mesh, "position", _rest_position(), HIT_NUDGE_BACK_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return hits


func _rest_position() -> Vector3:
	return Vector3(0, SIZE * 0.5, 0)


## El bloque se sustituye por pedazos que salen despedidos hacia fuera, caen,
## rebotan un poco en el suelo y al final encogen hasta desaparecer.
func _shatter() -> void:
	_mesh.queue_free()
	var mat := material_for(1)
	var rng := RandomNumberGenerator.new()
	var step := SIZE / PIECES_PER_SIDE
	for ix in PIECES_PER_SIDE:
		for iy in PIECES_PER_SIDE:
			for iz in PIECES_PER_SIDE:
				var local := Vector3((ix + 0.5) * step - SIZE * 0.5, (iy + 0.5) * step,
						(iz + 0.5) * step - SIZE * 0.5)
				var size := step * rng.randf_range(0.65, 0.95)
				var box := BoxMesh.new()
				box.size = Vector3.ONE * size
				var piece := MeshInstance3D.new()
				piece.mesh = box
				piece.material_override = mat
				piece.position = local
				piece.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3),
						rng.randf_range(-0.3, 0.3))
				add_child(piece)
				var outward := Vector3(local.x, 0, local.z) * rng.randf_range(1.5, 3.0)
				var vel := outward + Vector3(rng.randf_range(-0.25, 0.25),
						rng.randf_range(0.3, 1.8) * local.y / SIZE, rng.randf_range(-0.25, 0.25))
				var spin := Vector3(rng.randf_range(-7, 7), rng.randf_range(-7, 7), rng.randf_range(-7, 7))
				_pieces.append({"node": piece, "vel": vel, "spin": spin, "size": size})
	_break_age = 0.0
	set_process(true)


func _process(delta: float) -> void:
	_break_age += delta
	var shrink := clampf((_break_age - (PIECE_LIFETIME - PIECE_SHRINK_TIME)) / PIECE_SHRINK_TIME, 0.0, 1.0)
	var scale_factor := maxf(1.0 - shrink, 0.01)
	for piece in _pieces:
		var node: MeshInstance3D = piece["node"]
		var vel: Vector3 = piece["vel"]
		vel.y -= GRAVITY * delta
		node.position += vel * delta
		var floor_y: float = piece["size"] * 0.5 * scale_factor
		if node.position.y < floor_y:
			node.position.y = floor_y
			# Rebote amortiguado: pierde casi toda la velocidad al tocar el suelo.
			vel = Vector3(vel.x * 0.5, -vel.y * 0.25 if vel.y < -1.0 else 0.0, vel.z * 0.5)
			piece["spin"] *= 0.5
		piece["vel"] = vel
		node.rotation += piece["spin"] * delta
		node.scale = Vector3.ONE * scale_factor
	if _break_age >= PIECE_LIFETIME:
		queue_free()


## Material con las grietas del estado `state` (golpes que le quedan, 1-5).
static func material_for(state: int) -> StandardMaterial3D:
	if _materials.is_empty():
		_build_materials()
	return _materials[clampi(state, 1, MAX_HITS)]


## Genera una textura por estado. Las grietas se dibujan de forma acumulativa
## y con semilla fija: cada estado tiene las del anterior más otras nuevas.
static func _build_materials() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261107
	var img := Image.create(TILE * 3, TILE * 2, false, Image.FORMAT_RGBA8)
	# Piedra con algo de ruido y un borde más oscuro en cada cara.
	for y in TILE * 2:
		for x in TILE * 3:
			var tx := x % TILE
			var ty := y % TILE
			var edge := mini(mini(tx, TILE - 1 - tx), mini(ty, TILE - 1 - ty))
			var shade := rng.randf_range(-0.035, 0.035)
			if edge < 4:
				shade -= 0.16 - edge * 0.04
			img.set_pixel(x, y, Color(STONE_COLOR.r + shade, STONE_COLOR.g + shade, STONE_COLOR.b + shade))

	var max_cracks: int = CRACKS_PER_STATE[1]
	var cracks := []
	for face in 6:
		var list := []
		for i in max_cracks:
			list.append(_random_crack(rng))
		cracks.append(list)

	_materials.resize(MAX_HITS + 1)
	var drawn := 0
	for state in range(MAX_HITS, 0, -1):
		var target: int = CRACKS_PER_STATE[state]
		for face in 6:
			var origin := Vector2i((face % 3) * TILE, (face / 3) * TILE)
			for i in range(drawn, target):
				_draw_crack(img, origin, cracks[face][i])
		drawn = target
		var copy := img.duplicate() as Image
		copy.generate_mipmaps()
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = ImageTexture.create_from_image(copy)
		mat.roughness = 0.95
		_materials[state] = mat


## Una grieta es una línea quebrada con, a veces, una rama más fina.
## Devuelve una lista de trazos: { "points": PackedVector2Array, "width": int }.
static func _random_crack(rng: RandomNumberGenerator) -> Array:
	var strokes := []
	var start := Vector2(rng.randf_range(10, TILE - 10), rng.randf_range(10, TILE - 10))
	var main := _random_polyline(rng, start, rng.randf() * TAU, rng.randi_range(4, 8), 6.0, 12.0)
	strokes.append({"points": main, "width": 3})
	if main.size() > 3 and rng.randf() < 0.7:
		var from := main[rng.randi_range(1, main.size() - 2)]
		var branch := _random_polyline(rng, from, rng.randf() * TAU, rng.randi_range(2, 4), 4.0, 9.0)
		strokes.append({"points": branch, "width": 2})
	return strokes


static func _random_polyline(rng: RandomNumberGenerator, start: Vector2, angle: float,
		segments: int, min_len: float, max_len: float) -> PackedVector2Array:
	var points := PackedVector2Array([start])
	var p := start
	for i in segments:
		angle += rng.randf_range(-0.7, 0.7)
		p += Vector2.from_angle(angle) * rng.randf_range(min_len, max_len)
		p = p.clamp(Vector2(5, 5), Vector2(TILE - 6, TILE - 6))
		points.append(p)
	return points


## Dibuja la grieta en la cara que empieza en `origin`: primero un reflejo
## claro desplazado (da sensación de profundidad) y encima el trazo oscuro.
static func _draw_crack(img: Image, origin: Vector2i, strokes: Array) -> void:
	for pass_index in 2:
		var color := CRACK_HIGHLIGHT if pass_index == 0 else CRACK_COLOR
		var shift := Vector2(1, 1) if pass_index == 0 else Vector2.ZERO
		for stroke in strokes:
			var points: PackedVector2Array = stroke["points"]
			var width: int = stroke["width"]
			for i in points.size() - 1:
				var a := points[i] + shift
				var b := points[i + 1] + shift
				var steps := int(ceil(a.distance_to(b) * 2.0))
				for s in steps + 1:
					var p := a.lerp(b, float(s) / maxf(steps, 1))
					# El trazo se estrecha hacia el final de la grieta.
					var w := maxi(1, width - int(float(i) / points.size() * width))
					for ox in w:
						for oy in w:
							var x := clampi(int(p.x) + ox - w / 2, 0, TILE - 1)
							var y := clampi(int(p.y) + oy - w / 2, 0, TILE - 1)
							img.set_pixel(origin.x + x, origin.y + y, color)
