class_name LoadingScreen
extends CanvasLayer
## Pantalla de carga de un nivel: fondo negro, el cubo del juego volcando en
## el centro, el número y nombre del nivel, «Cargando…» y debajo un consejo
## elegido al azar de TIPS. Cuando el nivel está listo (mark_loaded), el texto
## de carga se cambia por el botón Continuar; al pulsarlo se emite continued
## (GameState funde a negro y la quita).
##
## No pertenece a ninguna escena: GameState la añade a la raíz para que siga
## visible mientras se cambia de escena (ver GameState.play_level).

signal continued

## Claves de traducción de los consejos (ver Translations).
const TIPS: Array[String] = [
	"TIP_TURN", "TIP_TURN_EARLY", "TIP_TURN_BLOCKED", "TIP_BOUNCE", "TIP_REVERSE",
	"TIP_START", "TIP_KEY_ONE", "TIP_DOOR", "TIP_BREAKABLE",
	"TIP_SPEED", "TIP_BUTTON", "TIP_BARS", "TIP_RESTART", "TIP_CHASER", "TIP_PATROL",
	"TIP_BLOCKER", "TIP_VOID", "TIP_BRIDGE", "TIP_TELEPORT", "TIP_SPIKES",
	"TIP_LASER", "TIP_BOMBS", "TIP_STARS", "TIP_GOLD", "TIP_IMMUNITY", "TIP_SHOP", "TIP_POINTS",
	"TIP_CHESTS", "TIP_CHECKPOINTS",
]
const LAYER := 100
const CUBE_VIEW_SIZE := 240
## Vuelco del cubo: duración de cada giro de 90° y pausa entre giros.
const ROLL_TIME := 0.35
const ROLL_PAUSE := 0.12
const TIP_WIDTH := 880.0
const DIM_TEXT := Color(0.62, 0.62, 0.66)
## Luz del cubo en el renderizador Compatibility (ver GameState.light_scale).
const LIGHT_COMPAT := 0.6
const AMBIENT_COMPAT := 1.0

## Último consejo mostrado, para no repetirlo dos veces seguidas.
static var _last_tip := -1

var _level_index := 0
var _cube: MeshInstance3D
var _status: Label
var _continue_button: Button
var _roll_tween: Tween


func _init(level_index := 0) -> void:
	_level_index = level_index
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	# Fondo que además bloquea los toques y clics al juego que hay debajo.
	var root := ColorRect.new()
	root.color = Color.BLACK
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 22)
	center.add_child(column)

	column.add_child(_build_cube_view())

	var data := Levels.get_level(_level_index)
	var title := _make_label("%s · %s" % [tr("HUD_LEVEL") % (_level_index + 1), tr(data["name"])], 40)
	column.add_child(title)

	# El texto de carga y el botón ocupan el mismo hueco para que nada salte.
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(360, 80)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(slot)
	_status = _make_label("LOADING", 30, DIM_TEXT)
	_status.set_anchors_preset(Control.PRESET_FULL_RECT)
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot.add_child(_status)
	_continue_button = Button.new()
	_continue_button.text = "PAUSE_CONTINUE"
	_continue_button.theme_type_variation = &"PrimaryButton"
	_continue_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	_continue_button.visible = false
	_continue_button.pressed.connect(_on_continue)
	_continue_button.pressed.connect(func() -> void: Sfx.play("click"))
	slot.add_child(_continue_button)

	var tip_title := _make_label("LOADING_TIP", 26, DIM_TEXT)
	column.add_child(tip_title)
	var tip := _make_label(_pick_tip(), 30)
	tip.custom_minimum_size = Vector2(TIP_WIDTH, 0)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(tip)

	_roll_next()


## El nivel ya está listo: se cambia «Cargando…» por el botón Continuar.
func mark_loaded() -> void:
	_status.visible = false
	_continue_button.visible = true
	if not OS.has_feature("mobile"):
		_continue_button.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	# Intro / Esc / Atrás también continúan una vez cargado; mientras tanto no
	# llega nada al juego de debajo.
	if _continue_button.visible and (event.is_action_pressed("ui_accept") or event.is_action_pressed("next_level")):
		_on_continue()
	get_viewport().set_input_as_handled()


func _on_continue() -> void:
	if not _continue_button.visible:
		return
	_continue_button.visible = false
	continued.emit()


## Vista 3D propia (con su mundo) en la que vuelca el cubo del juego.
func _build_cube_view() -> Control:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2.ONE * CUBE_VIEW_SIZE
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(viewport)

	var camera := Camera3D.new()
	camera.fov = 40.0
	# Todavía no está en el árbol, así que no se puede usar look_at().
	var eye := Vector3(0, 1.6, 2.5)
	camera.transform = Transform3D(Basis.looking_at(-eye), eye)
	viewport.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 35, 0)
	viewport.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	# En Compatibility la luz se calibra aparte (ver GameState.light_scale).
	if GameState.is_compatibility():
		light.light_energy = LIGHT_COMPAT
		env.environment.ambient_light_energy = AMBIENT_COMPAT
	viewport.add_child(env)

	_cube = MeshInstance3D.new()
	_cube.mesh = RollingCube._build_colored_cube(1.0)
	viewport.add_child(_cube)
	return container


## El cubo vuelca 90° sobre sí mismo hacia un lado al azar, como en el juego,
## y vuelve a empezar tras una pausa breve.
func _roll_next() -> void:
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]
	var axis: Vector3 = axes[randi() % axes.size()]
	var start := _cube.basis
	_roll_tween = create_tween()
	_roll_tween.tween_method(func(t: float) -> void:
		_cube.basis = Basis(axis, PI * 0.5 * t) * start, 0.0, 1.0, ROLL_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_roll_tween.tween_callback(func() -> void:
		_cube.basis = _snap(_cube.basis))
	_roll_tween.tween_interval(ROLL_PAUSE)
	_roll_tween.tween_callback(_roll_next)


func _pick_tip() -> String:
	var index := randi() % TIPS.size()
	if index == _last_tip:
		index = (index + 1) % TIPS.size()
	_last_tip = index
	return TIPS[index]


func _make_label(text: String, font_size: int, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


static func _snap(b: Basis) -> Basis:
	return Basis(b.x.round(), b.y.round(), b.z.round())
