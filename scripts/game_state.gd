extends Node
## Estado global del juego (autoload "GameState").
##
## - Progreso: niveles completados y desbloqueados (user://progress.cfg). El
##   nivel 1 siempre está desbloqueado; completar un nivel desbloquea el
##   siguiente.
## - Ajustes (user://settings.cfg): volumen de efectos y de música (buses
##   "SFX" y "Music", ver default_bus_layout.tres), antialiasing e idioma.
## - Traducciones: se registran al arrancar a partir de Translations.
## - Navegación entre el menú y la partida.

const PROGRESS_PATH := "user://progress.cfg"
const SETTINGS_PATH := "user://settings.cfg"
const MENU_SCENE := "res://scenes/menu.tscn"
const GAME_SCENE := "res://scenes/game.tscn"
const LOCALES := ["es", "en"]

## Nivel que se va a jugar (índice en Levels.LIST).
var current_level := 0
## Pantalla del menú que se abre al volver de la partida ("main" o "levels").
var menu_screen := "main"

## Volúmenes de 0.0 a 1.0.
var sfx_volume := 1.0
var music_volume := 1.0
var antialiasing := true
var locale := "es"

var _completed: Array[int] = []


func _ready() -> void:
	Translations.register()
	_load_settings()
	_load_progress()
	apply_settings()


# --- Progreso ---------------------------------------------------------------

func is_completed(index: int) -> bool:
	return _completed.has(index)


func is_unlocked(index: int) -> bool:
	return index == 0 or is_completed(index) or is_completed(index - 1)


func mark_completed(index: int) -> void:
	if not _completed.has(index):
		_completed.append(index)
		_completed.sort()
		_save_progress()


func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PROGRESS_PATH) != OK:
		return
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

func play_level(index: int) -> void:
	current_level = clampi(index, 0, Levels.count() - 1)
	_change_scene(GAME_SCENE)


## Vuelve al menú, abriendo la pantalla indicada ("main" o "levels").
func go_to_menu(screen := "main") -> void:
	menu_screen = screen
	_change_scene(MENU_SCENE)


func _change_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(path)
