class_name Bomb
extends Node3D
## Bomba de un cañón de bombas (ver MortarCannon y Level): un dodecaedro negro
## con una mecha blanca corta que echa chispas.
##
## Se mueve con físicas propias (update(), llamado por Level en cada
## fotograma): gravedad, choques con el suelo, los muros, las puertas y los
## barrotes cerrados (cajas que da Level.bomb_boxes) y con el cubo y los
## enemigos (cajas que se mueven y la empujan). Es muy pesada: rebota poco
## (BOUNCE), rueda frenándose deprisa y al pararse se asienta sobre una cara.
## Si cae al vacío, se pierde.
##
## La primera vez que toca el suelo se enciende la cuenta atrás: explota a los
## FUSE_MIN-FUSE_MAX segundos (la mecha se va consumiendo y, al final, la
## bomba se hincha un poco). Mientras tanto, las casillas con suelo a las que
## llega la explosión (Level.BOMB_BLAST_CELLS alrededor de la suya) se tiñen
## de rojo, con un latido cada vez más rápido. Entonces Level llama a explode(): bola de fuego,
## humo, chispas y una mancha de quemado en el suelo.
##
## El nodo está en el centro de la bomba; `velocity` y la posición están en
## coordenadas del tablero (Level), en las que una casilla mide 1.

signal touched_ground
signal bounced(speed: float)

## Radio de la esfera que circunscribe al dodecaedro y de la inscrita (la que
## choca: sobre una cara, la bomba toca el suelo justo).
const RADIUS := 0.23
const INRADIUS := RADIUS * 0.7947
const GRAVITY := 12.0
## Velocidad (vertical) que conserva al rebotar y frenado de lo que se mueve a
## lo largo de la superficie en cada choque.
const BOUNCE := 0.28
const SLIDE_KEEP := 0.3
## Velocidad de choque por debajo de la cual la bomba solo se apoya.
const RESTING_SPEED := 0.8
## Frenado al rodar por el suelo (casillas/s²) y velocidad por debajo de la
## cual se para.
const ROLL_DECEL := 5.0
const REST_SPEED := 0.08
## Pasos de la simulación por fotograma (para no atravesar nada).
const SUBSTEPS := 3
const FUSE_MIN := 2.0
const FUSE_MAX := 3.0
## Hinchado de los últimos segundos de la mecha.
const SWELL_TIME := 0.35
const SWELL_SCALE := 1.18
## Velocidad de choque por debajo de la cual no se oye el golpe.
const BOUNCE_SOUND_SPEED := 1.2
## Por debajo de esta altura se ha perdido en el vacío.
const LOST_HEIGHT := -6.0
const FUSE_LENGTH := 0.1
const FUSE_RADIUS := 0.016
## Explosión.
const FIRE_COLOR := Color(1.0, 0.55, 0.12)
const SMOKE_COLOR := Color(0.2, 0.19, 0.18)
const FLASH_TIME := 0.22
const FLASH_SIZE := 3.2
const SCORCH_SIZE := 1.5
const SCORCH_TIME := 4.0
## Casillas a las que llega la explosión: color, opacidad (mínima y máxima del
## latido) y latidos por segundo al encenderse la mecha y al final.
const ZONE_COLOR := Color(1.0, 0.08, 0.04)
const ZONE_ALPHA := Vector2(0.18, 0.42)
const ZONE_BEATS := Vector2(1.5, 7.0)
const ZONE_TILE := 0.94

static var _body_mesh: ArrayMesh
static var _face_normals: Array[Vector3] = []
static var _fuse_mesh: CylinderMesh
static var _tip_mesh: QuadMesh
static var _shadow_mesh: QuadMesh
static var _body_material: StandardMaterial3D
static var _fuse_material: StandardMaterial3D
static var _tip_material: StandardMaterial3D
static var _shadow_material: StandardMaterial3D
static var _flash_material: StandardMaterial3D
static var _fire_material: StandardMaterial3D
static var _scorch_material: StandardMaterial3D
static var _fire_mesh: QuadMesh
static var _zone_mesh: QuadMesh

var velocity := Vector3.ZERO
var angular_velocity := Vector3.ZERO
## Segundos que le quedan hasta explotar (INF hasta que toca el suelo).
var fuse_left := INF
var level: Level
var _fuse_total := 1.0
var _on_ground := false
var _lost := false
var _spin: Node3D
var _fuse: MeshInstance3D
var _tip: MeshInstance3D
var _sparks: CPUParticles3D
var _shadow: MeshInstance3D
## Casillas rojas del alcance de la explosión (top_level, en el sitio de
## cada casilla), su material (cada bomba late a su ritmo) y la casilla de la
## bomba con la que se colocaron.
var _zone: Node3D
var _zone_material: StandardMaterial3D
var _zone_cell := Level.NO_CELL
var _zone_phase := 0.0
var _rng := RandomNumberGenerator.new()


## Bomba en `at` (coordenadas del tablero) que sale con `start_velocity`.
static func create(board: Level, at: Vector3, start_velocity: Vector3) -> Bomb:
	var bomb := Bomb.new()
	bomb.level = board
	bomb.position = at
	bomb.velocity = start_velocity
	bomb._rng.randomize()
	# Gira un poco en el aire, más o menos hacia donde va.
	var side := Vector3.UP.cross(Vector3(start_velocity.x, 0.0, start_velocity.z)).normalized()
	bomb.angular_velocity = side * bomb._rng.randf_range(3.0, 6.0) \
		+ Vector3(bomb._rng.randf_range(-1, 1), bomb._rng.randf_range(-1, 1), bomb._rng.randf_range(-1, 1))
	return bomb


func _ready() -> void:
	_ensure_resources()
	_spin = Node3D.new()
	add_child(_spin)
	var body := MeshInstance3D.new()
	body.mesh = _body_mesh
	body.material_override = _body_material
	_spin.add_child(body)
	# Mecha: sale de la cara de arriba (la malla tiene una cara mirando a +Y),
	# un poco inclinada, con una luz en la punta que chisporrotea.
	var fuse_root := Node3D.new()
	fuse_root.position.y = INRADIUS
	fuse_root.rotation.z = 0.35
	_spin.add_child(fuse_root)
	_fuse = MeshInstance3D.new()
	_fuse.mesh = _fuse_mesh
	_fuse.material_override = _fuse_material
	_fuse.position.y = FUSE_LENGTH * 0.5
	_fuse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fuse_root.add_child(_fuse)
	_tip = MeshInstance3D.new()
	_tip.mesh = _tip_mesh
	_tip.material_override = _tip_material
	_tip.position.y = FUSE_LENGTH
	_tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fuse_root.add_child(_tip)
	_sparks = _make_fuse_sparks()
	_tip.add_child(_sparks)
	# Sombra redonda en el suelo de debajo, para ver dónde va a caer.
	_shadow = MeshInstance3D.new()
	_shadow.mesh = _shadow_mesh
	_shadow.material_override = _shadow_material.duplicate()
	_shadow.top_level = true
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)
	_update_visuals(0.0)


## Casilla en la que está.
func board_cell() -> Vector2i:
	return Vector2i(roundi(position.x / Level.CELL_SIZE), roundi(position.z / Level.CELL_SIZE))


func is_lost() -> bool:
	return _lost


## Ha tocado el suelo y la mecha está corriendo.
func is_lit() -> bool:
	return fuse_left != INF


## Avanza la simulación. `bodies` son las cajas que se mueven y la empujan:
## [{ "box": AABB, "velocity": Vector3 }] (el cubo y los enemigos).
func update(delta: float, bodies: Array) -> void:
	if _lost:
		return
	var step := delta / SUBSTEPS
	var hardest := 0.0
	var grounded := false
	for i in SUBSTEPS:
		velocity.y -= GRAVITY * step
		position += velocity * step
		var cell := Vector2i(roundi(position.x), roundi(position.z))
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				for box: AABB in level.bomb_boxes(cell + Vector2i(dx, dz)):
					var hit := _collide(box, Vector3.ZERO)
					hardest = maxf(hardest, hit.x)
					grounded = grounded or hit.y > 0.0
		for body: Dictionary in bodies:
			var hit := _collide(body["box"], body["velocity"])
			hardest = maxf(hardest, hit.x)
			grounded = grounded or hit.y > 0.0
	if grounded:
		# Rueda por el suelo: se frena y gira según lo que avanza.
		var flat := Vector3(velocity.x, 0.0, velocity.z)
		var speed := flat.length()
		speed = maxf(speed - ROLL_DECEL * delta, 0.0)
		flat = flat.normalized() * speed if speed > 0.0 else Vector3.ZERO
		velocity.x = flat.x
		velocity.z = flat.z
		var rolling := Vector3.UP.cross(flat) / INRADIUS
		angular_velocity = angular_velocity.lerp(rolling, minf(1.0, delta * 12.0))
		if speed < REST_SPEED and absf(velocity.y) < 0.5:
			_settle(delta)
	else:
		angular_velocity *= 1.0 - minf(1.0, delta * 0.3)
	if angular_velocity.length_squared() > 1e-6:
		_spin.basis = Basis(angular_velocity.normalized(), angular_velocity.length() * delta) * _spin.basis
		_spin.basis = _spin.basis.orthonormalized()
	if hardest > BOUNCE_SOUND_SPEED:
		bounced.emit(hardest)
	if grounded and not _on_ground and fuse_left == INF:
		_fuse_total = _rng.randf_range(FUSE_MIN, FUSE_MAX)
		fuse_left = _fuse_total
		touched_ground.emit()
	_on_ground = grounded
	if fuse_left != INF:
		fuse_left -= delta
	if position.y < LOST_HEIGHT:
		_lost = true
	_update_visuals(delta)


## Choca con la caja `box` (que se mueve a `box_velocity`): sale de ella y
## rebota. Devuelve (velocidad del choque, 1 si es un apoyo desde arriba).
func _collide(box: AABB, box_velocity: Vector3) -> Vector2:
	var closest := position.clamp(box.position, box.end)
	var diff := position - closest
	var dist := diff.length()
	if dist >= INRADIUS:
		return Vector2.ZERO
	var normal: Vector3
	var depth: float
	if dist > 1e-5:
		normal = diff / dist
		depth = INRADIUS - dist
	else:
		# El centro está dentro de la caja: sale por la cara más cercana.
		var to_min := position - box.position
		var to_max := box.end - position
		var faces := [to_max.y, to_min.x, to_max.x, to_min.z, to_max.z]
		var normals := [Vector3.UP, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
		var best := 0
		for k in faces.size():
			if faces[k] < faces[best]:
				best = k
		normal = normals[best]
		depth = faces[best] + INRADIUS
	position += normal * depth
	var relative := velocity - box_velocity
	var into := relative.dot(normal)
	if into >= 0.0:
		return Vector2(0.0, 1.0 if normal.y > 0.6 else 0.0)
	var along := relative - normal * into
	if -into < RESTING_SPEED:
		# Apoyada (no es un golpe): solo deja de hundirse y resbala, así no se
		# queda en equilibrio sobre la arista de un muro.
		relative = along
	else:
		relative = along * SLIDE_KEEP - normal * into * BOUNCE
	if box_velocity != Vector3.ZERO:
		# Lo que la empuja la lleva por delante (la bomba pesa, pero el cubo
		# y los enemigos no se paran).
		relative += normal * box_velocity.length() * 0.5
	velocity = relative + box_velocity
	return Vector2(-into, 1.0 if normal.y > 0.6 else 0.0)


## Quieta en el suelo: se va asentando sobre la cara que más mira hacia abajo.
func _settle(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	angular_velocity = Vector3.ZERO
	var lowest := Vector3.UP
	for n in _face_normals:
		var world_n := _spin.basis * n
		if world_n.y < lowest.y:
			lowest = world_n
	if lowest.dot(Vector3.DOWN) > 0.9999:
		return
	var fix := Basis(Quaternion(lowest.normalized(), Vector3.DOWN))
	var target := (fix * _spin.basis).orthonormalized()
	_spin.basis = _spin.basis.slerp(target, minf(1.0, delta * 8.0)).orthonormalized()


func _update_visuals(delta: float) -> void:
	_update_zone(delta)
	# La mecha se consume con la cuenta atrás y la bomba se hincha al final.
	if fuse_left != INF:
		var left := clampf(fuse_left / _fuse_total, 0.0, 1.0)
		var burn := lerpf(0.25, 1.0, left)
		_fuse.scale = Vector3(1.0, burn, 1.0)
		_fuse.position.y = FUSE_LENGTH * burn * 0.5
		_tip.position.y = FUSE_LENGTH * burn
		var swell := 1.0 - clampf(fuse_left / SWELL_TIME, 0.0, 1.0)
		scale = Vector3.ONE * lerpf(1.0, SWELL_SCALE, swell * swell)
	# La punta de la mecha parpadea.
	_tip.scale = Vector3.ONE * _rng.randf_range(0.75, 1.25)
	# Sombra sobre el suelo de debajo: más oscura y pequeña cuanto más cerca.
	var cell := Vector2i(roundi(position.x), roundi(position.z))
	var floor_y := level.bomb_floor_height(cell)
	_shadow.visible = not is_nan(floor_y) and position.y > floor_y
	if _shadow.visible:
		var height := maxf(position.y - INRADIUS - floor_y, 0.0)
		var k := clampf(1.0 - height / 6.0, 0.0, 1.0)
		var origin := level.global_transform * Vector3(position.x, floor_y + 0.015, position.z)
		_shadow.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * lerpf(1.6, 1.0, k)), origin)
		(_shadow.material_override as StandardMaterial3D).albedo_color.a = lerpf(0.12, 0.55, k)


## Tiñe de rojo las casillas con suelo a las que llega la explosión mientras
## arde la mecha (y las vuelve a colocar si la bomba cambia de casilla).
func _update_zone(delta: float) -> void:
	if fuse_left == INF:
		return
	if _zone == null:
		_zone = Node3D.new()
		_zone.top_level = true
		add_child(_zone)
		_zone_material = _zone_base_material().duplicate()
	var here := board_cell()
	if here != _zone_cell:
		_zone_cell = here
		for tile in _zone.get_children():
			tile.queue_free()
		_zone.global_transform = level.global_transform
		var reach := Level.BOMB_BLAST_CELLS
		for dz in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var c := here + Vector2i(dx, dz)
				if not level.has_floor(c) or level.is_void(c):
					continue
				var tile := MeshInstance3D.new()
				tile.mesh = _zone_mesh
				tile.material_override = _zone_material
				tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				tile.position = Vector3(c.x * Level.CELL_SIZE, 0.014, c.y * Level.CELL_SIZE)
				_zone.add_child(tile)
	# Latido cada vez más rápido a medida que se acaba la mecha.
	var left := clampf(fuse_left / _fuse_total, 0.0, 1.0)
	_zone_phase += delta * lerpf(ZONE_BEATS.y, ZONE_BEATS.x, left) * TAU
	var beat := 0.5 + 0.5 * sin(_zone_phase)
	_zone_material.albedo_color.a = lerpf(ZONE_ALPHA.x, ZONE_ALPHA.y, beat)


static func _zone_base_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.albedo_color = Color(ZONE_COLOR, ZONE_ALPHA.x)
	return mat


## Explota: destello, bola de fuego, humo, chispas y una mancha de quemado en
## el suelo (si hay suelo). La bomba desaparece.
func explode() -> void:
	var parent := get_parent()
	var at := position
	# Destello.
	var flash := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	flash.mesh = quad
	flash.material_override = _flash_material
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.position = at + Vector3(0.0, 0.2, 0.0)
	flash.scale = Vector3.ONE * FLASH_SIZE * 0.3
	parent.add_child(flash)
	var tween := flash.create_tween().set_parallel()
	tween.tween_property(flash, "scale", Vector3.ONE * FLASH_SIZE, FLASH_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "transparency", 1.0, FLASH_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(flash.queue_free)
	# Bola de fuego: llamaradas que salen hacia todos lados y hacia arriba.
	var fire := _make_fire()
	fire.position = at
	parent.add_child(fire)
	fire.emitting = true
	fire.finished.connect(fire.queue_free)
	# Humo oscuro que sube y se queda un rato.
	var smoke := MortarCannon.make_smoke(28, 2.6, SMOKE_COLOR, 1.0, Vector2(0.8, 2.6),
		Vector2(0.9, 1.4), 2.6)
	smoke.direction = Vector3.UP
	smoke.spread = 70.0
	smoke.gravity = Vector3(0.0, 0.7, 0.0)
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.25
	smoke.position = at
	parent.add_child(smoke)
	smoke.emitting = true
	smoke.finished.connect(smoke.queue_free)
	# Chispas y metralla.
	var sparks := LaserCannon.make_sparks(30, 0.6, Vector3.UP, 85.0, 2.5, 5.5)
	sparks.position = at
	parent.add_child(sparks)
	sparks.emitting = true
	sparks.finished.connect(sparks.queue_free)
	# Mancha de quemado en el suelo, que se va borrando.
	var cell := Vector2i(roundi(at.x), roundi(at.z))
	var floor_y := level.bomb_floor_height(cell)
	if not is_nan(floor_y) and at.y - floor_y < 0.8:
		var scorch := MeshInstance3D.new()
		var plane := QuadMesh.new()
		plane.size = Vector2.ONE * SCORCH_SIZE
		scorch.mesh = plane
		scorch.material_override = _scorch_material.duplicate()
		scorch.rotation = Vector3(-PI * 0.5, _rng.randf() * TAU, 0.0)
		scorch.position = Vector3(at.x, floor_y + 0.012, at.z)
		scorch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(scorch)
		var fade := scorch.create_tween()
		fade.tween_interval(SCORCH_TIME * 0.5)
		fade.tween_property(scorch, "transparency", 1.0, SCORCH_TIME * 0.5)
		fade.tween_callback(scorch.queue_free)
	queue_free()


func _make_fire() -> CPUParticles3D:
	var fire := CPUParticles3D.new()
	fire.one_shot = true
	fire.explosiveness = 0.92
	fire.amount = 36
	fire.lifetime = 0.8
	fire.local_coords = false
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 0.2
	fire.direction = Vector3.UP
	fire.spread = 80.0
	fire.initial_velocity_min = 1.2
	fire.initial_velocity_max = 3.4
	fire.damping_min = 3.0
	fire.damping_max = 5.0
	fire.gravity = Vector3(0.0, 1.8, 0.0)
	fire.angle_min = 0.0
	fire.angle_max = 360.0
	fire.scale_amount_min = 0.7
	fire.scale_amount_max = 1.25
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(1.0, 0.35))
	fire.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.92, 0.55, 1.0))
	ramp.add_point(0.18, Color(FIRE_COLOR, 1.0))
	ramp.add_point(0.5, Color(0.8, 0.18, 0.04, 0.9))
	ramp.add_point(0.75, Color(0.25, 0.12, 0.08, 0.6))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.15, 0.12, 0.1, 0.0))
	fire.color_ramp = ramp
	fire.mesh = _fire_mesh
	fire.material_override = _fire_material
	fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return fire


func _make_fuse_sparks() -> CPUParticles3D:
	var sparks := CPUParticles3D.new()
	sparks.amount = 14
	sparks.lifetime = 0.3
	sparks.local_coords = false
	sparks.direction = Vector3.UP
	sparks.spread = 70.0
	sparks.initial_velocity_min = 0.6
	sparks.initial_velocity_max = 1.6
	sparks.gravity = Vector3(0.0, -4.0, 0.0)
	sparks.particle_flag_align_y = true
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 0.9, 1.0))
	fade.add_point(0.3, Color(1.0, 0.75, 0.3, 1.0))
	fade.set_color(fade.get_point_count() - 1, Color(1.0, 0.3, 0.05, 0.0))
	sparks.color_ramp = fade
	var streak := BoxMesh.new()
	streak.size = Vector3(0.008, 0.045, 0.008)
	sparks.mesh = streak
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	sparks.material_override = mat
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return sparks


## Dodecaedro regular de circunradio RADIUS con una cara mirando hacia +Y y
## caras planas (normales por cara). Guarda las normales de las caras para
## asentarlo (ver _settle).
static func _make_dodecahedron() -> ArrayMesh:
	var phi := (1.0 + sqrt(5.0)) * 0.5
	var verts: Array[Vector3] = []
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				verts.append(Vector3(sx, sy, sz))
	for a in [-1.0, 1.0]:
		for b in [-1.0, 1.0]:
			verts.append(Vector3(0.0, a / phi, b * phi))
			verts.append(Vector3(a / phi, b * phi, 0.0))
			verts.append(Vector3(a * phi, 0.0, b / phi))
	# Las caras miran hacia los vértices de un icosaedro.
	var normals: Array[Vector3] = []
	for a in [-1.0, 1.0]:
		for b in [-1.0, 1.0]:
			normals.append(Vector3(0.0, a, b * phi).normalized())
			normals.append(Vector3(a, b * phi, 0.0).normalized())
			normals.append(Vector3(a * phi, 0.0, b).normalized())
	# Gira todo para que la primera cara quede hacia arriba.
	var up := Basis(Quaternion(normals[0], Vector3.UP))
	var scale_k := RADIUS / sqrt(3.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_face_normals.clear()
	for n in normals:
		# Los cinco vértices más cercanos a la normal, ordenados alrededor.
		var ring := verts.duplicate()
		ring.sort_custom(func(p: Vector3, q: Vector3) -> bool: return p.dot(n) > q.dot(n))
		ring.resize(5)
		var center := Vector3.ZERO
		for p: Vector3 in ring:
			center += p
		center /= 5.0
		var first: Vector3 = ring[0]
		var ref: Vector3 = (first - center).normalized()
		var side: Vector3 = n.cross(ref)
		ring.sort_custom(func(p: Vector3, q: Vector3) -> bool:
			var dp: Vector3 = p - center
			var dq: Vector3 = q - center
			return atan2(dp.dot(side), dp.dot(ref)) < atan2(dq.dot(side), dq.dot(ref)))
		var world_n := up * n
		_face_normals.append(world_n)
		st.set_normal(world_n)
		for k in range(1, 4):
			# Abanico desde el primer vértice, en sentido horario visto desde
			# fuera (el orden de Godot para las caras delanteras).
			var a: Vector3 = up * ring[0] * scale_k
			var b: Vector3 = up * ring[k] * scale_k
			var c: Vector3 = up * ring[k + 1] * scale_k
			if (b - a).cross(c - a).dot(world_n) > 0.0:
				var swap := b
				b = c
				c = swap
			st.add_vertex(a)
			st.add_vertex(b)
			st.add_vertex(c)
	return st.commit()


static func _ensure_resources() -> void:
	if _body_mesh:
		return
	_body_mesh = _make_dodecahedron()
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = Color(0.045, 0.045, 0.05)
	_body_material.metallic = 0.35
	_body_material.roughness = 0.32
	_fuse_mesh = CylinderMesh.new()
	_fuse_mesh.top_radius = FUSE_RADIUS * 0.85
	_fuse_mesh.bottom_radius = FUSE_RADIUS
	_fuse_mesh.height = FUSE_LENGTH
	_fuse_mesh.radial_segments = 6
	_fuse_mesh.rings = 0
	_fuse_mesh.cap_bottom = false
	_fuse_material = StandardMaterial3D.new()
	_fuse_material.albedo_color = Color(0.95, 0.94, 0.9)
	_fuse_material.roughness = 0.9
	_tip_mesh = QuadMesh.new()
	_tip_mesh.size = Vector2.ONE * 0.13
	_tip_material = LaserCannon.glow_material(Color(1.0, 0.8, 0.4), 1.0)
	_shadow_mesh = QuadMesh.new()
	_shadow_mesh.size = Vector2.ONE * RADIUS * 2.4
	_shadow_mesh.orientation = PlaneMesh.FACE_Y
	_shadow_material = StandardMaterial3D.new()
	_shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_shadow_material.albedo_color = Color(0.0, 0.0, 0.0, 0.5)
	_shadow_material.albedo_texture = _soft_dot()
	_flash_material = LaserCannon.glow_material(Color(1.0, 0.75, 0.4), 1.0)
	# Fuego con mezcla normal (no sumada): sumado se pierde sobre suelos claros.
	_fire_material = StandardMaterial3D.new()
	_fire_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fire_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fire_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_fire_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_fire_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_fire_material.vertex_color_use_as_albedo = true
	_fire_material.albedo_texture = MortarCannon.puff_texture()
	_fire_mesh = QuadMesh.new()
	_fire_mesh.size = Vector2.ONE
	_zone_mesh = QuadMesh.new()
	_zone_mesh.size = Vector2.ONE * ZONE_TILE * Level.CELL_SIZE
	_zone_mesh.orientation = PlaneMesh.FACE_Y
	_scorch_material = StandardMaterial3D.new()
	_scorch_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_scorch_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_scorch_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_scorch_material.albedo_color = Color(0.05, 0.04, 0.03, 0.7)
	_scorch_material.albedo_texture = _soft_dot()


## Círculo negro que se difumina hacia el borde (sombra y quemado).
static func _soft_dot() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.add_point(0.45, Color(1, 1, 1, 0.75))
	gradient.set_color(gradient.get_point_count() - 1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	return texture
