extends Control
## Menú del juego: pantalla principal (Jugar, Opciones, Créditos, Salir), selector de
## niveles, opciones y créditos. Solo se ve una pantalla a la vez.
##
## Los textos fijos de la escena son claves de traducción (ver Translations);
## los que se generan aquí se rehacen al cambiar de idioma.
## Atrás (Esc o el botón Atrás de Android) vuelve a la pantalla principal y,
## desde ella, cierra el juego.
##
## Truco (solo en builds de depuración): tocar 5 veces seguidas el título del
## selector de niveles desbloquea todos los niveles.

const LANGUAGE_NAMES := {"es": "Español", "en": "English"}
## Truco de desbloqueo: toques necesarios y tiempo máximo entre dos toques.
const UNLOCK_TAPS := 5
const UNLOCK_TAP_WINDOW := 0.6

## Créditos: (clave del encabezado, texto o clave). Los textos que no son
## claves (nombres propios) se muestran tal cual.
const CREDITS := [
	["CREDITS_GAME", "tonyjdev"],
	["CREDITS_DEV", "tonyjdev"],
	["CREDITS_AI", "Claude Code (Anthropic)"],
	["CREDITS_ASSETS", "CREDITS_ASSETS_TEXT"],
	["CREDITS_AUDIO", "CREDITS_AUDIO_TEXT"],
	["CREDITS_FONT", "CREDITS_FONT_TEXT"],
	["CREDITS_TOOLS", "Godot Engine 4.7 · Godot AI (MCP)\nPython · Git · Android SDK · Ubuntu"],
	["CREDITS_ENGINE", "CREDITS_ENGINE_LICENSE"],
]

var _screens: Dictionary
var _current := "main"
var _unlock_taps := 0
var _last_unlock_tap := 0.0


func _ready() -> void:
	_screens = {
		"main": %MainScreen,
		"levels": %LevelsScreen,
		"options": %OptionsScreen,
		"credits": %CreditsScreen,
	}
	%PlayButton.pressed.connect(_show.bind("levels"))
	%OptionsButton.pressed.connect(_show.bind("options"))
	%CreditsButton.pressed.connect(_show.bind("credits"))
	%QuitButton.pressed.connect(get_tree().quit)
	%LevelMap.level_chosen.connect(func(index: int) -> void:
		Sfx.play("click")
		GameState.play_level(index))
	for button in find_children("*", "BaseButton", true, false):
		(button as BaseButton).pressed.connect(func() -> void: Sfx.play("click"))
	for back in [%LevelsBack, %OptionsBack, %CreditsBack]:
		back.pressed.connect(_show.bind("main"))
	_setup_options()
	if OS.is_debug_build():
		var title: Label = %LevelsScreen.get_node("VBox/Title")
		title.mouse_filter = Control.MOUSE_FILTER_STOP
		title.gui_input.connect(_on_levels_title_input)
	_show(GameState.menu_screen)
	GameState.menu_screen = "main"


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_build_level_grid()
		_build_credits()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()


func _go_back() -> void:
	if _current == "main":
		get_tree().quit()
	else:
		_show("main")


func _show(screen: String) -> void:
	if not _screens.has(screen):
		screen = "main"
	_current = screen
	for name in _screens:
		_screens[name].visible = name == screen
	match screen:
		"levels":
			_build_level_grid()
		"credits":
			_build_credits()
			%Scroll.scroll_vertical = 0
	if screen == "levels" and not OS.has_feature("mobile"):
		# Con el teclado se elige nivel en el mapa (arriba/abajo e Intro).
		%LevelMap.grab_focus.call_deferred()
	else:
		_focus_first(_screens[screen])


## Da el foco al primer botón de la pantalla para poder usar el teclado (no
## en el móvil, donde solo se vería el recuadro de foco).
func _focus_first(root: Node) -> void:
	if OS.has_feature("mobile"):
		return
	for node in root.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button.visible and not button.disabled:
			button.grab_focus.call_deferred()
			return


# --- Selector de niveles ----------------------------------------------------

## Mapa de niveles con desplazamiento (ver LevelMap): solo se puede entrar
## en los niveles desbloqueados; los completados se marcan en verde.
func _build_level_grid() -> void:
	%LevelMap.refresh()


func _on_levels_title_input(event: InputEvent) -> void:
	# En el móvil los toques llegan también como clic (emulate_mouse_from_touch),
	# así que solo se cuentan los clics para no contar cada toque dos veces.
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	var now := Time.get_ticks_msec() / 1000.0
	_unlock_taps = _unlock_taps + 1 if now - _last_unlock_tap <= UNLOCK_TAP_WINDOW else 1
	_last_unlock_tap = now
	if _unlock_taps >= UNLOCK_TAPS:
		_unlock_taps = 0
		GameState.unlock_all_levels()
		GameState.vibrate(GameState.VIBRATION_PREVIEW)
		_build_level_grid()


# --- Opciones ---------------------------------------------------------------

func _setup_options() -> void:
	%SfxSlider.value = GameState.sfx_volume * 100.0
	%MusicSlider.value = GameState.music_volume * 100.0
	%AaToggle.button_pressed = GameState.antialiasing
	%VibrationToggle.button_pressed = GameState.vibration
	%ArrowToggle.button_pressed = GameState.show_arrow
	var language: OptionButton = %LanguageOption
	language.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	language.clear()
	for locale in GameState.LOCALES:
		language.add_item(LANGUAGE_NAMES[locale])
	language.select(GameState.LOCALES.find(GameState.locale))

	%SfxSlider.value_changed.connect(func(v: float) -> void: GameState.set_sfx_volume(v / 100.0))
	%MusicSlider.value_changed.connect(func(v: float) -> void: GameState.set_music_volume(v / 100.0))
	%AaToggle.toggled.connect(GameState.set_antialiasing)
	%VibrationToggle.toggled.connect(GameState.set_vibration)
	%ArrowToggle.toggled.connect(GameState.set_show_arrow)
	language.item_selected.connect(func(index: int) -> void:
		GameState.set_locale(GameState.LOCALES[index]))


# --- Créditos ---------------------------------------------------------------

func _build_credits() -> void:
	var text := "[center]"
	for entry in CREDITS:
		text += "[font_size=22][color=#d9b98a]%s[/color][/font_size]\n" % tr(entry[0])
		text += "[font_size=30]%s[/font_size]\n\n" % tr(entry[1])
	text += "[font_size=34][color=#fad98c]%s[/color][/font_size][/center]" % tr("CREDITS_THANKS")
	var label: RichTextLabel = %CreditsText
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
