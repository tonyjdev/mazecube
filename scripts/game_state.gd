extends Node
## Estado global del juego (autoload "GameState").
##
## - Progreso: niveles completados y desbloqueados (user://progress.cfg). El
##   nivel 1 siempre está desbloqueado; completar un nivel desbloquea el
##   siguiente.
## - Ajustes (user://settings.cfg): volumen de efectos y de música (buses
##   "SFX" y "Music", ver default_bus_layout.tres), antialiasing, idioma
##   y vibración.
## - Vibración del móvil (vibrate()), que respeta el ajuste.
## - Traducciones: se registran al arrancar a partir de Translations.
## - Navegación entre el menú y la partida.
## - Fundido a negro de toda la pantalla (fade_to_black / fade_from_black),
##   por encima de todo, para las transiciones al cargar o reiniciar un nivel.

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
## Al activar la vibración en Opciones, para notar que funciona.
const VIBRATION_PREVIEW := Vector2(60, 0.6)

## Nivel que se va a jugar (índice en Levels.LIST).
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
var locale := "es"
var vibration := true

var _completed: Array[int] = []
## Truco para pruebas: todos los niveles desbloqueados (ver unlock_all_levels).
var _all_unlocked := false
## Capa negra de los fundidos y su animación en curso.
var _fade_rect: ColorRect
var _fade_tween: Tween


func _ready() -> void:
	Translations.register()
	_load_settings()
	_load_progress()
	apply_settings()
	_build_fader()


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


func mark_completed(index: int) -> void:
	if not _completed.has(index):
		_completed.append(index)
		_completed.sort()
		_save_progress()


func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PROGRESS_PATH) != OK:
		return
	_all_unlocked = cfg.get_value("progress", "all_unlocked", false)
	if cfg.has_section_key("progress", "completed"):
		for value in cfg.get_value("progress", "completed", []):
			_completed.append(int(value))
	elif cfg.has_section_key("progress", "current_level"):
		# Progreso de versiones anteriores (solo guardaban el nivel actual):
		# se dan por completados los niveles anteriores a él.
		for i in int(cfg.get_value("progress", "current_level", 0)):
			_completed.append(i)
		_save_progress()


func _save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "completed", _completed)
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
	TranslationServer.set_locale(locale)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("video", "antialiasing", antialiasing)
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


func _apply_antialiasing() -> void:
	get_tree().root.msaa_3d = Viewport.MSAA_4X if antialiasing else Viewport.MSAA_DISABLED


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
