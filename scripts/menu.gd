extends Control
## Menú del juego: pantalla principal (Jugar, Opciones, Créditos), selector de
## niveles, opciones y créditos. Solo se ve una pantalla a la vez.
##
## Los textos fijos de la escena son claves de traducción (ver Translations);
## los que se generan aquí se rehacen al cambiar de idioma.
## Atrás (Esc o el botón Atrás de Android) vuelve a la pantalla principal y,
## desde ella, cierra el juego.

const LANGUAGE_NAMES := {"es": "Español", "en": "English"}
const LEVEL_BUTTON_SIZE := Vector2(210, 128)
const DONE_COLOR := Color(0.62, 0.92, 0.55)

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
	for back in [%LevelsBack, %OptionsBack, %CreditsBack]:
		back.pressed.connect(_show.bind("main"))
	_setup_options()
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

## Un botón por nivel: número y nombre. Solo se puede entrar en los niveles
## desbloqueados; los completados se marcan en verde.
func _build_level_grid() -> void:
	var grid: GridContainer = %LevelGrid
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for i in Levels.count():
		var data := Levels.get_level(i)
		var button := Button.new()
		button.custom_minimum_size = LEVEL_BUTTON_SIZE
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.add_theme_font_size_override("font_size", 24)
		var unlocked := GameState.is_unlocked(i)
		var subtitle := tr(data["name"]) if unlocked else tr("LEVEL_LOCKED")
		button.text = "%d\n%s" % [i + 1, subtitle]
		button.disabled = not unlocked
		if GameState.is_completed(i):
			button.add_theme_color_override("font_color", DONE_COLOR)
			button.add_theme_color_override("font_hover_color", DONE_COLOR)
			button.add_theme_color_override("font_focus_color", DONE_COLOR)
			button.tooltip_text = tr("LEVEL_DONE")
		button.pressed.connect(GameState.play_level.bind(i))
		grid.add_child(button)


# --- Opciones ---------------------------------------------------------------

func _setup_options() -> void:
	%SfxSlider.value = GameState.sfx_volume * 100.0
	%MusicSlider.value = GameState.music_volume * 100.0
	%AaToggle.button_pressed = GameState.antialiasing
	var language: OptionButton = %LanguageOption
	language.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	language.clear()
	for locale in GameState.LOCALES:
		language.add_item(LANGUAGE_NAMES[locale])
	language.select(GameState.LOCALES.find(GameState.locale))

	%SfxSlider.value_changed.connect(func(v: float) -> void: GameState.set_sfx_volume(v / 100.0))
	%MusicSlider.value_changed.connect(func(v: float) -> void: GameState.set_music_volume(v / 100.0))
	%AaToggle.toggled.connect(GameState.set_antialiasing)
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
