class_name EnemyDebris
extends Node3D
## Pedazos de un enemigo destruido (ver Enemy.destroy): salen despedidos,
## caen con gravedad, rebotan o se aplastan en el suelo y, al final, encogen
## hasta desaparecer; después el nodo se libera solo.
##
## - Orgánicos (perseguidor): gotas blandas que giran poco. Al tocar el suelo
##   no rebotan: se aplastan como un charquito y se frenan.
## - Sintéticos (patrullero y obstáculo): piezas rígidas que giran deprisa y
##   rebotan perdiendo velocidad.
##
## El nodo va en el tablero (Level) a ras de suelo: las posiciones de los
## pedazos son relativas a él y el suelo está en y = 0.

const GRAVITY := 11.0
const LIFETIME := 1.6
## Últimos segundos de LIFETIME en los que los pedazos encogen.
const SHRINK_TIME := 0.5
## Sintéticos: velocidad vertical que conservan al rebotar y horizontal que
## conservan en cada bote.
const BOUNCE := 0.38
const FRICTION := 0.6
## Orgánicos: tiempo que tardan en aplastarse al caer, cuánto se aplastan y
## lo que frenan en el suelo (por segundo).
const SPLAT_TIME := 0.12
const SPLAT_FLATTEN := 0.65
const SPLAT_SPREAD := 0.6
const SPLAT_DRAG := 7.0

## { "node": MeshInstance3D, "vel": Vector3, "spin": Vector3, "size": float,
##   "radius": float, "organic": bool, "landed": bool, "splat": float }
var _pieces: Array[Dictionary] = []
var _age := 0.0


## Añade un pedazo: `mesh` con `material` (null = el de la malla) a escala
## `size`, en `at` con velocidad `velocity`. `radius` es su medio alto a
## escala 1 (para apoyarlo en el suelo).
func add_piece(mesh: Mesh, material: Material, at: Vector3, velocity: Vector3,
		size: float, radius: float, organic: bool) -> void:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	if material:
		node.material_override = material
	node.position = at
	node.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	node.scale = Vector3.ONE * size
	add_child(node)
	var axis := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
	var spin := axis * (randf_range(1.0, 3.0) if organic else randf_range(6.0, 14.0))
	_pieces.append({"node": node, "vel": velocity, "spin": spin, "size": size,
		"radius": radius, "organic": organic, "landed": false, "splat": 0.0})


func _process(delta: float) -> void:
	_age += delta
	var shrink := clampf((_age - (LIFETIME - SHRINK_TIME)) / SHRINK_TIME, 0.0, 1.0)
	var grow := maxf(1.0 - shrink, 0.01)
	for piece in _pieces:
		var node: MeshInstance3D = piece["node"]
		var vel: Vector3 = piece["vel"]
		var organic: bool = piece["organic"]
		var size: float = piece["size"] * grow
		if organic and piece["landed"]:
			vel *= maxf(1.0 - SPLAT_DRAG * delta, 0.0)
			piece["splat"] = minf(piece["splat"] + delta / SPLAT_TIME, 1.0)
		else:
			vel.y -= GRAVITY * delta
		node.position += vel * delta
		var splat: float = piece["splat"]
		var floor_y: float = piece["radius"] * size * (1.0 - SPLAT_FLATTEN * splat)
		if node.position.y <= floor_y:
			node.position.y = floor_y
			if organic and not piece["landed"]:
				# Se queda pegado: sin rebote, derecho para aplastarse en vertical.
				piece["landed"] = true
				vel = Vector3(vel.x * 0.3, 0.0, vel.z * 0.3)
				piece["spin"] = Vector3.ZERO
				node.rotation = Vector3.ZERO
			elif not organic and vel.y < 0.0:
				vel = Vector3(vel.x * FRICTION, -vel.y * BOUNCE if vel.y < -1.0 else 0.0, vel.z * FRICTION)
				piece["spin"] *= 0.6
		piece["vel"] = vel
		node.rotation += piece["spin"] * delta
		node.scale = Vector3(size * (1.0 + SPLAT_SPREAD * splat), size * (1.0 - SPLAT_FLATTEN * splat),
			size * (1.0 + SPLAT_SPREAD * splat))
	if _age >= LIFETIME:
		queue_free()
