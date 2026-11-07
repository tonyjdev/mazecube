class_name Translations
extends RefCounted
## Textos del juego en cada idioma. Se registran en TranslationServer al
## arrancar (GameState), de modo que tr("CLAVE") y el texto de los Control
## (que se traduce solo) usan el idioma elegido en Opciones.
##
## Los nombres de los niveles se traducen usando su nombre en español como
## clave (ver Levels.LIST); en español no hace falta entrada (ver register()).

const MESSAGES := {
	"es": {
		"MENU_PLAY": "Jugar",
		"MENU_OPTIONS": "Opciones",
		"MENU_CREDITS": "Créditos",
		"MENU_BACK": "Volver",
		"LEVELS_TITLE": "Elige un nivel",
		"LEVEL_LOCKED": "Bloqueado",
		"LEVEL_DONE": "Completado",
		"OPTIONS_TITLE": "Opciones",
		"OPT_SFX": "Efectos de sonido",
		"OPT_MUSIC": "Música",
		"OPT_AA": "Antialiasing",
		"OPT_LANGUAGE": "Idioma",
		"OPT_VIBRATION": "Vibración",
		"OPT_ARROW": "Flecha de dirección",
		"CREDITS_TITLE": "Créditos",
		"HUD_LEVEL": "Nivel %d",
		"HINT_LEFT": "← Izquierda",
		"HINT_RIGHT": "Derecha →",
		"PAUSE_TITLE": "Pausa",
		"PAUSE_CONTINUE": "Continuar",
		"PAUSE_RESTART": "Reiniciar",
		"PAUSE_QUIT": "Salir",
		"COMPLETE_TITLE": "¡Nivel completado!",
		"COMPLETE_ALL": "¡Has completado todos los niveles!",
		"COMPLETE_NEXT": "Siguiente nivel",
		"COMPLETE_RETRY": "Repetir",
		"COMPLETE_LEVELS": "Niveles",
		"CREDITS_GAME": "Un juego de",
		"CREDITS_DEV": "Diseño y desarrollo",
		"CREDITS_AI": "Desarrollo asistido por IA",
		"CREDITS_ASSETS": "Gráficos",
		"CREDITS_ASSETS_TEXT": "Modelos, texturas y efectos generados por código",
		"CREDITS_AUDIO": "Música y sonido",
		"CREDITS_AUDIO_TEXT": "Próximamente",
		"CREDITS_FONT": "Tipografía",
		"CREDITS_FONT_TEXT": "Tipografía predeterminada de Godot",
		"CREDITS_TOOLS": "Herramientas",
		"CREDITS_ENGINE": "Motor",
		"CREDITS_ENGINE_LICENSE": "Godot Engine se distribuye bajo licencia MIT.\n© 2014-present Godot Engine contributors.\n© 2007-2014 Juan Linietsky, Ariel Manzur.",
		"CREDITS_THANKS": "¡Gracias por jugar!",
	},
	"en": {
		"MENU_PLAY": "Play",
		"MENU_OPTIONS": "Options",
		"MENU_CREDITS": "Credits",
		"MENU_BACK": "Back",
		"LEVELS_TITLE": "Choose a level",
		"LEVEL_LOCKED": "Locked",
		"LEVEL_DONE": "Completed",
		"OPTIONS_TITLE": "Options",
		"OPT_SFX": "Sound effects",
		"OPT_MUSIC": "Music",
		"OPT_AA": "Anti-aliasing",
		"OPT_LANGUAGE": "Language",
		"OPT_VIBRATION": "Vibration",
		"OPT_ARROW": "Direction arrow",
		"CREDITS_TITLE": "Credits",
		"HUD_LEVEL": "Level %d",
		"HINT_LEFT": "← Left",
		"HINT_RIGHT": "Right →",
		"PAUSE_TITLE": "Paused",
		"PAUSE_CONTINUE": "Continue",
		"PAUSE_RESTART": "Restart",
		"PAUSE_QUIT": "Exit",
		"COMPLETE_TITLE": "Level complete!",
		"COMPLETE_ALL": "You've completed every level!",
		"COMPLETE_NEXT": "Next level",
		"COMPLETE_RETRY": "Replay",
		"COMPLETE_LEVELS": "Levels",
		"CREDITS_GAME": "A game by",
		"CREDITS_DEV": "Design and development",
		"CREDITS_AI": "AI-assisted development",
		"CREDITS_ASSETS": "Graphics",
		"CREDITS_ASSETS_TEXT": "Models, textures and effects generated in code",
		"CREDITS_AUDIO": "Music and sound",
		"CREDITS_AUDIO_TEXT": "Coming soon",
		"CREDITS_FONT": "Font",
		"CREDITS_FONT_TEXT": "Godot's default font",
		"CREDITS_TOOLS": "Tools",
		"CREDITS_ENGINE": "Engine",
		"CREDITS_ENGINE_LICENSE": "Godot Engine is distributed under the MIT license.\n© 2014-present Godot Engine contributors.\n© 2007-2014 Juan Linietsky, Ariel Manzur.",
		"CREDITS_THANKS": "Thanks for playing!",
		# Nombres de los niveles.
		"Primer giro": "First Turn",
		"El muro": "The Wall",
		"La llave": "The Key",
		"A toda prisa": "In a Hurry",
		"Escombros": "Rubble",
		"Dos llaves": "Two Keys",
		"Salas": "Halls",
		"El atajo": "The Shortcut",
		"Galerías": "Galleries",
		"La gran travesía": "The Long Journey",
		"El botón": "The Button",
		"Barrotes": "Bars",
		"La fortaleza": "The Fortress",
	},
}


## Las claves que no tienen entrada en un idioma (como los nombres de los
## niveles en español) se registran con su propio texto; si no, Godot usaría
## el texto del idioma de respaldo (inglés).
static func register() -> void:
	var all_keys := {}
	for locale in MESSAGES:
		all_keys.merge(MESSAGES[locale])
	for locale in MESSAGES:
		var translation := Translation.new()
		translation.locale = locale
		var messages: Dictionary = MESSAGES[locale]
		for key in all_keys:
			translation.add_message(key, messages.get(key, key))
		TranslationServer.add_translation(translation)
