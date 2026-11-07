class_name Bars
extends Node3D
## Barrotes: cinco lanzas horizontales de metal que cierran un pasillo de muro
## a muro, apiladas en altura y con la punta en sentido alterno.
##
## Al abrirse, cada lanza se desliza hacia el lado contrario a su punta hasta
## quedar escondida dentro del muro de ese lado; al cerrarse vuelve a salir.
## El nodo se coloca en el centro de la casilla y las lanzas van a lo largo
## del eje X local: Level lo gira 90° si el pasillo va de izquierda a derecha.
## El estado lógico (si se puede pasar) lo gestiona Level y cambia al
## instante; aquí solo se anima.

const SPEARS := 5
const LENGTH := 0.98
const TIP_LENGTH := 0.18
const SHAFT_RADIUS := 0.045
const TIP_RADIUS := 0.075
## Altura de la lanza inferior y separación entre lanzas. La superior queda
## por debajo de la altura de los muros para esconderse entera en ellos.
const BOTTOM_HEIGHT := 0.08
const SPACING := 0.085
const COLOR := Color(0.62, 0.64, 0.68)
const MOVE_TIME := 0.3
## Retraso entre una lanza y la siguiente al abrir o cerrar.
const STAGGER := 0.035

static var _material: StandardMaterial3D

var is_open := false
var _spears: Array[Node3D] = []
var _tween: Tween


func _init(open := false) -> void:
	is_open = open


func _ready() -> void:
	for i in SPEARS:
		var spear := _build_spear()
		# Las lanzas pares apuntan a +X y las impares a -X.
		if i % 2 == 1:
			spear.rotation.y = PI
		spear.position = Vector3(_x_for(i, is_open), BOTTOM_HEIGHT + SPACING * i, 0.0)
		spear.visible = not is_open
		add_child(spear)
		_spears.append(spear)


## Abre o cierra los barrotes con animación.
func set_open(open: bool) -> void:
	if open == is_open:
		return
	is_open = open
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel()
	for i in _spears.size():
		var spear := _spears[i]
		spear.visible = true
		var step := _tween.tween_property(spear, "position:x", _x_for(i, open), MOVE_TIME) \
			.set_delay(STAGGER * i).set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_IN if open else Tween.EASE_OUT)
		if open:
			# Ya escondida en el muro, se oculta para que no asome.
			step.finished.connect(spear.hide)


## Posición X de la lanza `i`: centrada si está cerrada, o desplazada una
## casilla hacia el lado contrario a su punta si está abierta.
func _x_for(i: int, open: bool) -> float:
	if not open:
		return 0.0
	var tip_dir := 1.0 if i % 2 == 0 else -1.0
	return -tip_dir * Level.CELL_SIZE


## Lanza con la punta hacia +X: un asta cilíndrica y una punta cónica.
func _build_spear() -> Node3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_color = COLOR
		_material.metallic = 0.85
		_material.roughness = 0.35
	var spear := Node3D.new()
	var shaft_length := LENGTH - TIP_LENGTH
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = SHAFT_RADIUS
	shaft_mesh.bottom_radius = SHAFT_RADIUS
	shaft_mesh.height = shaft_length
	shaft_mesh.radial_segments = 10
	shaft_mesh.rings = 1
	shaft_mesh.material = _material
	var shaft := MeshInstance3D.new()
	shaft.mesh = shaft_mesh
	shaft.rotation.z = -PI * 0.5
	shaft.position.x = -LENGTH * 0.5 + shaft_length * 0.5
	spear.add_child(shaft)
	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = 0.0
	tip_mesh.bottom_radius = TIP_RADIUS
	tip_mesh.height = TIP_LENGTH
	tip_mesh.radial_segments = 10
	tip_mesh.rings = 1
	tip_mesh.material = _material
	var tip := MeshInstance3D.new()
	tip.mesh = tip_mesh
	# El cilindro va a lo largo de +Y: girado -90° en Z su "arriba" mira a +X.
	tip.rotation.z = -PI * 0.5
	tip.position.x = LENGTH * 0.5 - TIP_LENGTH * 0.5
	spear.add_child(tip)
	return spear
