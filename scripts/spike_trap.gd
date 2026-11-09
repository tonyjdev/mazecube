class_name SpikeTrap
extends Node3D
## Trampa de pinchos de una casilla (ver Level, carácter '^'): una placa de
## metal sobre la baldosa con cuatro agujeros (lejos de las esquinas) de los
## que salen cuatro lanzas. Esperan escondidas un tiempo al azar entre
## MIN_WAIT y MAX_WAIT segundos, salen de golpe (RISE_TIME), se quedan fuera
## OUT_TIME segundos y vuelven a esconderse (RETRACT_TIME). Los últimos
## WARN_TIME segundos de la espera la placa tiembla como aviso: cada
## fotograma se desplaza al azar entre TREMBLE_MIN_PX y TREMBLE_MAX_PX
## píxeles de pantalla (se calcula con la cámara).
##
## Level llama a update() en cada fotograma (no mientras aparece el tablero) y
## pregunta is_dangerous(): solo matan al cubo cuando están fuera. Emite
## extended al empezar a salir (para el sonido). El origen del nodo es el
## centro de la casilla a ras de suelo.

signal extended

const MIN_WAIT := 3.0
const MAX_WAIT := 8.0
const RISE_TIME := 0.09
const OUT_TIME := 1.0
const RETRACT_TIME := 0.3
const WARN_TIME := 0.25
const TREMBLE_MIN_PX := 1.0
const TREMBLE_MAX_PX := 2.0
## Parte de la subida a partir de la cual (y hasta la misma parte de la
## bajada) las lanzas matan.
const DANGER_FROM := 0.45
## Distancia de cada lanza al centro de la casilla, en x y en z (la casilla
## mide 1: quedan lejos de las esquinas, que están a 0,5).
const SPEAR_OFFSET := 0.22
const PLATE_SIZE := 0.84
const PLATE_HEIGHT := 0.004
const SHAFT_RADIUS := 0.048
const SHAFT_LENGTH := 0.34
const TIP_RADIUS := 0.085
const TIP_LENGTH := 0.24
const TEXTURE_SIZE := 128

enum Phase { HIDDEN, RISING, OUT, RETRACTING }

static var _plate_material: StandardMaterial3D
static var _spear_material: StandardMaterial3D
static var _shaft_mesh: CylinderMesh
static var _tip_mesh: CylinderMesh

var _phase := Phase.HIDDEN
var _time_left := 0.0
## 0 = escondidas, 1 = fuera del todo.
var _extension := 0.0
var _spears: Node3D
var _plate: MeshInstance3D
## Unidades del mundo que mide un píxel de pantalla junto a la trampa (se
## calcula al empezar cada aviso; 0 = aún no).
var _units_per_pixel := 0.0


static func create() -> SpikeTrap:
	var trap := SpikeTrap.new()
	trap._time_left = randf_range(MIN_WAIT, MAX_WAIT)
	return trap


func _ready() -> void:
	_ensure_resources()
	var plate := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * PLATE_SIZE
	plate.mesh = plane
	plate.position.y = PLATE_HEIGHT
	plate.material_override = _plate_material
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plate)
	_plate = plate
	_spears = Node3D.new()
	add_child(_spears)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var shaft := MeshInstance3D.new()
			shaft.mesh = _shaft_mesh
			shaft.material_override = _spear_material
			shaft.position = Vector3(sx * SPEAR_OFFSET, SHAFT_LENGTH * 0.5, sz * SPEAR_OFFSET)
			_spears.add_child(shaft)
			var tip := MeshInstance3D.new()
			tip.mesh = _tip_mesh
			tip.material_override = _spear_material
			tip.position = Vector3(sx * SPEAR_OFFSET, SHAFT_LENGTH + TIP_LENGTH * 0.5, sz * SPEAR_OFFSET)
			_spears.add_child(tip)
	_apply_extension()


func update(delta: float) -> void:
	_time_left -= delta
	match _phase:
		Phase.HIDDEN:
			if _time_left <= WARN_TIME and _time_left > 0.0:
				_tremble()
			if _time_left <= 0.0:
				_units_per_pixel = 0.0
				_plate.position = Vector3(0.0, PLATE_HEIGHT, 0.0)
				_phase = Phase.RISING
				_time_left += RISE_TIME
				extended.emit()
		Phase.RISING:
			_extension = clampf(1.0 - _time_left / RISE_TIME, 0.0, 1.0)
			if _time_left <= 0.0:
				_phase = Phase.OUT
				_time_left += OUT_TIME
				_extension = 1.0
		Phase.OUT:
			if _time_left <= 0.0:
				_phase = Phase.RETRACTING
				_time_left += RETRACT_TIME
		Phase.RETRACTING:
			_extension = clampf(_time_left / RETRACT_TIME, 0.0, 1.0)
			if _time_left <= 0.0:
				_phase = Phase.HIDDEN
				_time_left += randf_range(MIN_WAIT, MAX_WAIT)
				_extension = 0.0
	_apply_extension()


## Aviso de que van a salir: desplaza la placa al azar 1-2 píxeles.
func _tremble() -> void:
	if _units_per_pixel <= 0.0:
		_units_per_pixel = _measure_units_per_pixel()
	var angle := randf() * TAU
	var amount := randf_range(TREMBLE_MIN_PX, TREMBLE_MAX_PX) * _units_per_pixel
	_plate.position = Vector3(cos(angle) * amount, PLATE_HEIGHT, sin(angle) * amount)


## Cuánto mide en el mundo un píxel de pantalla en la casilla de la trampa.
func _measure_units_per_pixel() -> float:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null or camera.is_position_behind(global_position):
		return 0.01
	var a := camera.unproject_position(global_position)
	var b := camera.unproject_position(global_position + Vector3(0.5, 0.0, 0.0))
	var pixels := a.distance_to(b)
	return 0.5 / pixels if pixels > 0.5 else 0.01


## Las lanzas están fuera (lo bastante para matar al cubo).
func is_dangerous() -> bool:
	return _extension >= DANGER_FROM


func _apply_extension() -> void:
	if _spears == null:
		return
	# Al subir, la punta sale primero y frena un poco al final (como un muelle).
	var k := _extension
	if _phase == Phase.RISING:
		k = 1.0 - pow(1.0 - k, 2.0)
	_spears.visible = k > 0.01
	_spears.position.y = -(SHAFT_LENGTH + TIP_LENGTH) * (1.0 - k)


static func _ensure_resources() -> void:
	if _plate_material:
		return
	_plate_material = StandardMaterial3D.new()
	_plate_material.albedo_texture = ImageTexture.create_from_image(_make_plate_image())
	_plate_material.metallic = 0.55
	_plate_material.roughness = 0.55
	_spear_material = StandardMaterial3D.new()
	_spear_material.albedo_color = Color(0.86, 0.87, 0.9)
	_spear_material.metallic = 0.5
	_spear_material.roughness = 0.25
	_shaft_mesh = CylinderMesh.new()
	_shaft_mesh.top_radius = SHAFT_RADIUS
	_shaft_mesh.bottom_radius = SHAFT_RADIUS
	_shaft_mesh.height = SHAFT_LENGTH
	_shaft_mesh.radial_segments = 10
	_shaft_mesh.rings = 1
	_tip_mesh = CylinderMesh.new()
	_tip_mesh.top_radius = 0.0
	_tip_mesh.bottom_radius = TIP_RADIUS
	_tip_mesh.height = TIP_LENGTH
	_tip_mesh.radial_segments = 10
	_tip_mesh.rings = 1


## Placa de acero con el borde biselado, cuatro remaches en las esquinas y
## cuatro agujeros oscuros con un aro brillante donde salen las lanzas.
static func _make_plate_image() -> Image:
	var n := TEXTURE_SIZE
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var base := Color(0.42, 0.44, 0.47)
	var hole_r := TIP_RADIUS * 1.2 / PLATE_SIZE
	var rim_r := hole_r * 1.45
	var holes: Array[Vector2] = []
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			holes.append(Vector2(0.5 + sx * SPEAR_OFFSET / PLATE_SIZE, 0.5 + sz * SPEAR_OFFSET / PLATE_SIZE))
	var rivets: Array[Vector2] = [Vector2(0.09, 0.09), Vector2(0.91, 0.09), Vector2(0.09, 0.91), Vector2(0.91, 0.91)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for y in n:
		for x in n:
			var uv := Vector2((x + 0.5) / n, (y + 0.5) / n)
			var c := base * (0.94 + 0.08 * rng.randf())
			# Rayas finas de metal cepillado.
			c = c * (0.97 + 0.03 * sin(uv.y * 180.0 + sin(uv.x * 9.0)))
			# Bisel: claro arriba a la izquierda, oscuro abajo a la derecha.
			var edge := minf(minf(uv.x, uv.y), minf(1.0 - uv.x, 1.0 - uv.y))
			if edge < 0.045:
				c = c.lightened(0.25) if uv.x + uv.y < 1.0 and (uv.x < 0.045 or uv.y < 0.045) else c.darkened(0.35)
			for r in rivets:
				var d := uv.distance_to(r)
				if d < 0.032:
					var light := clampf(((uv - r) / 0.032).dot(Vector2(-0.7, -0.7)), -1.0, 1.0)
					c = Color(0.6, 0.61, 0.63).lightened(0.25 * light) if light > 0 else Color(0.6, 0.61, 0.63).darkened(-0.3 * light)
			for h in holes:
				var d := uv.distance_to(h)
				if d < hole_r:
					c = Color(0.03, 0.03, 0.035).lerp(Color(0.1, 0.1, 0.11), d / hole_r)
				elif d < rim_r:
					# Aro con luz arriba a la izquierda.
					var light := ((uv - h).normalized()).dot(Vector2(-0.7, -0.7))
					c = Color(0.62, 0.63, 0.66).lightened(0.2 * maxf(light, 0.0)).darkened(0.35 * maxf(-light, 0.0))
			c.a = 1.0
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return img
