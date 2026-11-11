extends Node
## Estado global del juego (autoload "GameState").
##
## - Progreso: niveles completados y desbloqueados, y las estrellas de la
##   mejor partida de cada nivel (user://progress.cfg). El nivel 1 siempre
##   está desbloqueado; completar un nivel con al menos una estrella lo marca
##   como completado y desbloquea el siguiente. Las estrellas son tres retos:
##   sin morir, en «star_turns» giros o menos y con el cubito dorado (ver
##   record_result). Solo cuenta la mejor partida (la de más estrellas); no
##   se suman estrellas de partidas distintas.
## - Monedas y habilidades (también en user://progress.cfg, sección "coins"):
##   las monedas que se tienen (coins) suben al recoger monedas del suelo
##   (add_coins, se guardan al momento) y con la recompensa de completar un
##   nivel (ver Abilities.reward_for_run y record_reward: cada nivel guarda
##   su mejor recompensa y repetirlo solo da la diferencia si se mejora), y
##   bajan al comprar en las tiendas. Las habilidades compradas se guardan
##   con su nivel (ver Abilities y buy_ability). Los cofres abiertos de cada
##   nivel no vuelven a salir (ver open_chest y opened_chests).
##   Las partidas de antes de las monedas (sección "points") conservan las
##   habilidades compradas, pero empiezan sin monedas.
## - Ajustes (user://settings.cfg): volumen de efectos y de música (buses
##   "SFX" y "Music", ver default_bus_layout.tres), antialiasing, calidad
##   gráfica, sombras, idioma y vibración.
##   Calidad gráfica (QUALITY_*): resolución a la que se pinta el 3D (la
##   interfaz siempre va a la resolución de la pantalla) y tamaño del mapa de
##   sombras. Por defecto, media en el móvil y alta en el PC.
## - Vibración del móvil (vibrate()), que respeta el ajuste.
## - Traducciones: se registran al arrancar a partir de Translations.
## - Navegación entre el menú y la partida.
## - Fundido a negro de toda la pantalla (fade_to_black / fade_from_black),
##   por encima de todo, para las transiciones al cargar o reiniciar un nivel.
## - Ajuste de la luz según el renderizador (light_scale, setup_environment):
##   en el móvil se usa el renderizador Compatibility (OpenGL ES 3), mucho más
##   rápido en GPU de gama media que Mobile (Vulkan), pero no aplica el
##   tonemap «filmic» y las luces salen unas cuatro veces más fuertes. Las
##   intensidades se calibraron comparando capturas de los dos renderizadores.

const PROGRESS_PATH := "user://progress.cfg"
const SETTINGS_PATH := "user://settings.cfg"
const MENU_SCENE := "res://scenes/menu.tscn"
const GAME_SCENE := "res://scenes/game.tscn"
const LOCALES := ["es", "en"]
## Fotogramas que se deja el nivel construido detrás de la pantalla de carga
## antes de mostrar Continuar (para que se compilen sus materiales).
const LOADING_SETTLE_FRAMES := 4
## Fundidos: hacia negro (antes de cargar o reiniciar) y desde negro.
const FADE_OUT_TIME := 0.35
const FADE_IN_TIME := 0.6
const FADE_LAYER := 120
## Vibraciones: (duración en ms, intensidad de 0 a 1).
const VIBRATION_WALL_BROKEN := Vector2(90, 0.8)
const VIBRATION_TURN_REJECTED := Vector2(18, 0.25)
const VIBRATION_BUTTON := Vector2(40, 0.5)
const VIBRATION_REVERSE := Vector2(70, 0.7)
const VIBRATION_DASH := Vector2(35, 0.5)
const VIBRATION_TELEPORT := Vector2(45, 0.45)
const VIBRATION_STOMP := Vector2(110, 0.9)
const VIBRATION_DEATH := Vector2(160, 1.0)
const VIBRATION_BOMB := Vector2(70, 0.6)
## Al activar la vibración en Opciones, para notar que funciona.
const VIBRATION_PREVIEW := Vector2(60, 0.6)

## Nivel que se va a jugar (índice en Levels.LIST).
## Renderizador Compatibility: intensidad de todas las luces respecto a
## Mobile y luz ambiente (de color fijo: la del cielo no se puede ajustar).
const COMPAT_LIGHT_SCALE := 0.26
const COMPAT_AMBIENT_COLOR := Color(0.92, 0.95, 1.0)
const COMPAT_AMBIENT_ENERGY := 0.22
## Calidad gráfica: baja, media y alta. Escala del 3D y mapa de sombras.
const QUALITY_LOW := 0
const QUALITY_MEDIUM := 1
const QUALITY_HIGH := 2
const QUALITY_3D_SCALES := [0.6, 0.75, 1.0]
const QUALITY_SHADOW_SIZES := [1024, 2048, 4096]

var current_level := 0
## Pantalla del menú que se abre al volver de la partida ("main" o "levels").
var menu_screen := "main"
## Se está mostrando la pantalla de carga de un nivel: el juego de debajo
## está en pausa y no debe atender a la entrada.
var is_loading := false

## Volúmenes de 0.0 a 1.0.
var sfx_volume := 1.0
var music_volume := 1.0
var antialiasing := true
var graphics_quality := QUALITY_MEDIUM if OS.has_feature("mobile") else QUALITY_HIGH
var shadows := true
var locale := "es"
var vibration := true

var _completed: Array[int] = []
## Índice del nivel -> estrellas de su mejor partida: [sin morir, giros, cubito].
var _stars := {}
## Truco para pruebas: todos los niveles desbloqueados (ver unlock_all_levels).
var _all_unlocked := false
## Monedas que se tienen.
var _coins := 0
## Índice del nivel -> mejor recompensa cobrada por completarlo.
var _level_rewards := {}
## Índice del nivel -> casillas de sus cofres ya abiertos.
var _opened_chests := {}
## Hay cambios sin guardar (las monedas se guardan una vez por fotograma).
var _save_queued := false
## Habilidad -> nivel comprado (las que no están, nivel 0: bloqueadas).
var _abilities := {}
## Capa negra de los fundidos y su animación en curso.
var _fade_rect: ColorRect
var _fade_tween: Tween


func _ready() -> void:
	Translations.register()
	_load_settings()
	_load_progress()
	apply_settings()
	_build_fader()
	Music.attach(self)


# --- Fundidos a negro -------------------------------------------------------

func _build_fader() -> void:
	var layer := CanvasLayer.new()
	layer.layer = FADE_LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade_rect)


## Oscurece la pantalla hasta negro absoluto (se puede esperar con await).
## Mientras está negra no deja pasar toques ni clics.
func fade_to_black(duration := FADE_OUT_TIME) -> void:
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_start_fade(1.0, duration)
	await _fade_tween.finished


## Aclara la pantalla desde negro absoluto (se puede esperar con await).
func fade_from_black(duration := FADE_IN_TIME) -> void:
	_fade_rect.color.a = 1.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start_fade(0.0, duration)
	await _fade_tween.finished


func _start_fade(alpha: float, duration: float) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = _fade_rect.create_tween().set_ignore_time_scale(true)
	_fade_tween.tween_property(_fade_rect, "color:a", alpha, duration)


# --- Progreso ---------------------------------------------------------------

func is_completed(index: int) -> bool:
	return _completed.has(index)


func is_unlocked(index: int) -> bool:
	return _all_unlocked or index == 0 or is_completed(index) or is_completed(index - 1)


## Truco para pruebas: desbloquea todos los niveles (sin marcarlos como
## completados) y lo guarda. Se activa desde el selector de niveles.
func unlock_all_levels() -> void:
	_all_unlocked = true
	_save_progress()


## Estrellas de la mejor partida del nivel: [sin morir, giros, cubito]
## (vacío si no hay ninguna partida con estrellas).
func best_stars(index: int) -> Array:
	return _stars.get(index, [])


func star_count(index: int) -> int:
	return best_stars(index).count(true)


## Resultado de una partida: `stars` = [sin morir, giros, cubito]. Si consigue
## más estrellas que la mejor partida, pasa a ser la mejor. Con al menos una
## estrella el nivel queda completado (y se desbloquea el siguiente).
## Devuelve true si es un nuevo récord.
func record_result(index: int, stars: Array) -> bool:
	var count := stars.count(true)
	var record := count > star_count(index)
	if record:
		_stars[index] = stars.duplicate()
	if count > 0 and not _completed.has(index):
		_completed.append(index)
		_completed.sort()
	if record or count > 0:
		_save_progress()
	return record


# --- Monedas y habilidades -------------------------------------------------

## Monedas para gastar en las tiendas.
func coins() -> int:
	return _coins


## Suma monedas (recogidas del suelo) y las guarda.
func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	_coins += amount
	_queue_save()


## Mejor recompensa cobrada por completar el nivel.
func best_reward(index: int) -> int:
	return _level_rewards.get(index, 0)


## Recompensa de una partida completada (ver Abilities.reward_for_run): si
## supera la mejor del nivel, pasa a serlo y se cobran las monedas de
## diferencia. Devuelve las monedas ganadas (0 si no la supera).
func record_reward(index: int, earned: int) -> int:
	var gained := earned - best_reward(index)
	if gained <= 0:
		return 0
	_level_rewards[index] = earned
	_coins += gained
	_save_progress()
	return gained


## Casillas de los cofres ya abiertos del nivel.
func opened_chests(index: int) -> Array:
	return _opened_chests.get(index, [])


## Apunta el cofre de esa casilla como abierto (no vuelve a salir).
func open_chest(index: int, cell: Vector2i) -> void:
	var list: Array = _opened_chests.get(index, [])
	if list.has(cell):
		return
	list.append(cell)
	_opened_chests[index] = list
	_queue_save()


## Nivel comprado de la habilidad (0 = bloqueada; ver Abilities).
func ability_level(id: String) -> int:
	return _abilities.get(id, 0)


func has_ability(id: String) -> bool:
	return ability_level(id) > 0


## Valor del efecto de la habilidad con el nivel comprado (ver Abilities.value).
func ability_value(id: String) -> Variant:
	return Abilities.value(id, ability_level(id))


## Se puede comprar el siguiente nivel de la habilidad: no está al máximo,
## se tiene alguna de las que necesita y hay monedas suficientes.
func can_buy_ability(id: String) -> bool:
	var current := ability_level(id)
	if current >= Abilities.max_level(id) or not meets_ability_needs(id):
		return false
	return _coins >= Abilities.price(id, current)


func meets_ability_needs(id: String) -> bool:
	var needed := Abilities.needs(id)
	if needed.is_empty():
		return true
	for other: String in needed:
		if has_ability(other):
			return true
	return false


## Compra el siguiente nivel de la habilidad. Devuelve true si se ha podido.
func buy_ability(id: String) -> bool:
	if not can_buy_ability(id):
		return false
	var current := ability_level(id)
	_coins -= Abilities.price(id, current)
	_abilities[id] = current + 1
	_save_progress()
	return true


func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PROGRESS_PATH) != OK:
		return
	_all_unlocked = cfg.get_value("progress", "all_unlocked", false)
	var saved_stars: Variant = cfg.get_value("progress", "stars", {})
	if saved_stars is Dictionary:
		for key: Variant in saved_stars:
			var value: Variant = saved_stars[key]
			if value is Array and value.size() == 3:
				_stars[int(key)] = [bool(value[0]), bool(value[1]), bool(value[2])]
	_coins = maxi(int(cfg.get_value("coins", "coins", 0)), 0)
	var saved_rewards: Variant = cfg.get_value("coins", "levels", {})
	if saved_rewards is Dictionary:
		for key: Variant in saved_rewards:
			_level_rewards[int(key)] = int(saved_rewards[key])
	var saved_chests: Variant = cfg.get_value("coins", "chests", {})
	if saved_chests is Dictionary:
		for key: Variant in saved_chests:
			var cells: Array = []
			for cell: Variant in saved_chests[key]:
				if cell is Vector2i:
					cells.append(cell)
			_opened_chests[int(key)] = cells
	# Las habilidades se guardan en "coins"; las partidas de antes de las
	# monedas las tenían en "points".
	var section := "coins" if cfg.has_section_key("coins", "abilities") else "points"
	var saved_abilities: Variant = cfg.get_value(section, "abilities", {})
	if saved_abilities is Dictionary:
		for key: Variant in saved_abilities:
			var id := str(key)
			if Abilities.max_level(id) > 0:
				_abilities[id] = clampi(int(saved_abilities[key]), 0, Abilities.max_level(id))
	if cfg.has_section_key("progress", "completed"):
		for value in cfg.get_value("progress", "completed", []):
			_completed.append(int(value))
	elif cfg.has_section_key("progress", "current_level"):
		# Progreso de versiones anteriores (solo guardaban el nivel actual):
		# se dan por completados los niveles anteriores a él.
		for i in int(cfg.get_value("progress", "current_level", 0)):
			_completed.append(i)
		_save_progress()


## Borra todo el progreso (niveles, estrellas, monedas, cofres abiertos y
## habilidades) para empezar desde cero. Los ajustes no se tocan.
func reset_progress() -> void:
	_completed.clear()
	_stars.clear()
	_all_unlocked = false
	_coins = 0
	_level_rewards.clear()
	_opened_chests.clear()
	_abilities.clear()
	current_level = 0
	_save_progress()


## Guarda el progreso al final del fotograma (varias monedas seguidas, una
## sola escritura).
func _queue_save() -> void:
	if _save_queued:
		return
	_save_queued = true
	_save_progress.call_deferred()


func _save_progress() -> void:
	_save_queued = false
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "completed", _completed)
	cfg.set_value("progress", "stars", _stars)
	cfg.set_value("coins", "coins", _coins)
	cfg.set_value("coins", "levels", _level_rewards)
	cfg.set_value("coins", "chests", _opened_chests)
	cfg.set_value("coins", "abilities", _abilities)
	if _all_unlocked:
		cfg.set_value("progress", "all_unlocked", true)
	cfg.save(PROGRESS_PATH)


# --- Ajustes ----------------------------------------------------------------

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume("SFX", sfx_volume)
	save_settings()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume("Music", music_volume)
	save_settings()


func set_antialiasing(enabled: bool) -> void:
	antialiasing = enabled
	_apply_antialiasing()
	save_settings()


func set_graphics_quality(value: int) -> void:
	graphics_quality = clampi(value, QUALITY_LOW, QUALITY_HIGH)
	_apply_graphics()
	save_settings()


func set_shadows(enabled: bool) -> void:
	shadows = enabled
	save_settings()


func set_locale(value: String) -> void:
	locale = value if LOCALES.has(value) else LOCALES[0]
	TranslationServer.set_locale(locale)
	save_settings()


func set_vibration(enabled: bool) -> void:
	vibration = enabled
	save_settings()
	if enabled:
		vibrate(VIBRATION_PREVIEW)


## Hace vibrar el móvil (si la vibración está activada). `strength` va de 0 a
## 1; en los móviles que no permiten regular la intensidad solo cuenta la
## duración.
func vibrate(pattern: Vector2) -> void:
	if vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(int(pattern.x), pattern.y)


func apply_settings() -> void:
	_apply_bus_volume("SFX", sfx_volume)
	_apply_bus_volume("Music", music_volume)
	_apply_antialiasing()
	_apply_graphics()
	TranslationServer.set_locale(locale)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("video", "antialiasing", antialiasing)
	cfg.set_value("video", "quality", graphics_quality)
	cfg.set_value("video", "shadows", shadows)
	cfg.set_value("general", "locale", locale)
	cfg.set_value("general", "vibration", vibration)
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	# Por defecto, el idioma del sistema si está disponible; si no, inglés.
	var system := OS.get_locale_language()
	locale = system if LOCALES.has(system) else "en"
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	sfx_volume = float(cfg.get_value("audio", "sfx_volume", sfx_volume))
	music_volume = float(cfg.get_value("audio", "music_volume", music_volume))
	antialiasing = bool(cfg.get_value("video", "antialiasing", antialiasing))
	graphics_quality = clampi(int(cfg.get_value("video", "quality", graphics_quality)),
		QUALITY_LOW, QUALITY_HIGH)
	shadows = bool(cfg.get_value("video", "shadows", shadows))
	vibration = bool(cfg.get_value("general", "vibration", vibration))
	var saved := str(cfg.get_value("general", "locale", locale))
	if LOCALES.has(saved):
		locale = saved


func _apply_bus_volume(bus_name: String, value: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, value <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(value, 0.001)))


## Factor por el que se multiplican las intensidades de las luces (1 en
## Mobile/Forward+, COMPAT_LIGHT_SCALE en Compatibility).
static func light_scale() -> float:
	return COMPAT_LIGHT_SCALE if is_compatibility() else 1.0


static func is_compatibility() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"


## Adapta un entorno y su luz principal al renderizador (ver light_scale) y
## a los ajustes (sombras).
func setup_environment(environment: Environment, sun: DirectionalLight3D) -> void:
	sun.shadow_enabled = shadows
	if not is_compatibility():
		return
	sun.light_energy *= COMPAT_LIGHT_SCALE
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = COMPAT_AMBIENT_COLOR
	environment.ambient_light_energy = COMPAT_AMBIENT_ENERGY


## Antialiasing: MSAA 4x solo con el 3D a resolución completa; con el 3D
## escalado (calidad baja o media) se usa FXAA. MSAA con el 3D escalado pierde
## memoria en cada fotograma con el driver de Mali (unos 6 MB/s en un Redmi
## Note 11S, Godot 4.7.2 Compatibility) hasta que Android cierra el juego.
func _apply_antialiasing() -> void:
	var root := get_tree().root
	var msaa := antialiasing and is_equal_approx(QUALITY_3D_SCALES[graphics_quality], 1.0)
	root.msaa_3d = Viewport.MSAA_4X if msaa else Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if antialiasing and not msaa \
		else Viewport.SCREEN_SPACE_AA_DISABLED


func _apply_graphics() -> void:
	get_tree().root.scaling_3d_scale = QUALITY_3D_SCALES[graphics_quality]
	RenderingServer.directional_shadow_atlas_set_size(QUALITY_SHADOW_SIZES[graphics_quality], true)
	_apply_antialiasing()


# --- Navegación -------------------------------------------------------------

## Juega un nivel pasando por la pantalla de carga (ver LoadingScreen):
## 1. La pantalla de carga aparece al momento, por encima de todo.
## 2. La escena del juego se carga en otro hilo, así que la pantalla de carga
##    sigue animándose.
## 3. Se cambia a la escena del juego, que se construye en pausa detrás de la
##    pantalla de carga, y se dejan pasar unos fotogramas para que se preparen
##    sus materiales.
## 4. Aparece el botón Continuar; al pulsarlo, la pantalla funde a negro, se
##    quita la pantalla de carga y el juego se reanuda (la partida aparece
##    después desde negro, ver Game).
## Antes de todo, la pantalla actual funde a negro.
func play_level(index: int) -> void:
	if is_loading:
		return
	current_level = clampi(index, 0, Levels.count() - 1)
	is_loading = true
	var tree := get_tree()
	await fade_to_black()
	tree.paused = false
	var screen := LoadingScreen.new(current_level)
	tree.root.add_child(screen)
	fade_from_black()
	# Dos fotogramas para que la pantalla de carga se vea antes de cargar nada.
	await tree.process_frame
	await tree.process_frame

	var packed: PackedScene = null
	if ResourceLoader.load_threaded_request(GAME_SCENE) == OK:
		while ResourceLoader.load_threaded_get_status(GAME_SCENE) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await tree.process_frame
		packed = ResourceLoader.load_threaded_get(GAME_SCENE) as PackedScene
	if packed == null:
		packed = load(GAME_SCENE)

	tree.paused = true
	tree.change_scene_to_packed(packed)
	for i in LOADING_SETTLE_FRAMES:
		await tree.process_frame
	screen.mark_loaded()
	await screen.continued
	await fade_to_black()
	screen.queue_free()
	tree.paused = false
	is_loading = false


## Vuelve al menú, abriendo la pantalla indicada ("main" o "levels").
func go_to_menu(screen := "main") -> void:
	menu_screen = screen
	_change_scene(MENU_SCENE)


func _change_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(path)
