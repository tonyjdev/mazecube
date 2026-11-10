class_name EncyclopediaData
extends RefCounted
## Contenido de la enciclopedia (ver Encyclopedia): pestañas y páginas.
##
## Cada pestaña tiene su título (clave de traducción) y sus páginas, en el
## orden en que se leen. Cada página es un elemento del juego:
## - "id": nombre del elemento. De él salen su dibujo
##   (res://ui/encyclopedia/<id>.png, ver tools/make_encyclopedia_art.py) y
##   sus textos (ver EncyclopediaTexts): ENC_<ID>_NAME (nombre),
##   ENC_<ID>_DESC (descripción) y ENC_<ID>_FACTS (curiosidades, una por
##   línea).
## - "symbols": caracteres del mapa que lo representan (ver Level). Con ellos
##   se busca el primer nivel en el que aparece. Vacío = está desde el
##   principio (habilidades, cubito dorado).
##
## Para añadir un elemento nuevo: añadir su página aquí, sus textos en
## EncyclopediaTexts (en todos los idiomas) y su dibujo en
## tools/make_encyclopedia_art.py (o un PNG de 720×600 con ese nombre).

const IMAGE_DIR := "res://ui/encyclopedia/"

const TABS: Array[Dictionary] = [
	{"id": "enemies", "title": "ENC_TAB_ENEMIES", "pages": [
		{"id": "chaser", "symbols": "x"},
		{"id": "patroller", "symbols": "ijkmn"},
		{"id": "blocker", "symbols": "z"},
	]},
	{"id": "abilities", "title": "ENC_TAB_ABILITIES", "pages": [
		{"id": "turn", "symbols": ""},
		{"id": "reverse", "symbols": ""},
		{"id": "dash", "symbols": ""},
		{"id": "stomp", "symbols": ""},
	]},
	{"id": "items", "title": "ENC_TAB_ITEMS", "pages": [
		{"id": "golden_cube", "symbols": ""},
		{"id": "key", "symbols": "yorug"},
		{"id": "speed", "symbols": "s"},
	]},
	{"id": "obstacles", "title": "ENC_TAB_OBSTACLES", "pages": [
		{"id": "door", "symbols": "YORUG"},
		{"id": "breakable", "symbols": "12345"},
		{"id": "bars", "symbols": "cdefhCDEFHpqtvw"},
		{"id": "void", "symbols": "~"},
		{"id": "bridge", "symbols": "="},
		{"id": "teleport", "symbols": "6789"},
		{"id": "spikes", "symbols": "^"},
		{"id": "laser", "symbols": "L"},
		{"id": "mortar", "symbols": "M"},
	]},
]

## Primer nivel (índice) de cada juego de símbolos, calculado una vez.
static var _first_level := {}


static func image_path(page: Dictionary) -> String:
	return IMAGE_DIR + page["id"] + ".png"


static func text_key(page: Dictionary, field: String) -> String:
	return "ENC_%s_%s" % [String(page["id"]).to_upper(), field]


## Índice del primer nivel cuyo mapa tiene alguno de los símbolos de la
## página; 0 si no tiene símbolos y -1 si no sale en ningún nivel.
static func first_level(page: Dictionary) -> int:
	var symbols: String = page["symbols"]
	if symbols.is_empty():
		return 0
	if _first_level.has(symbols):
		return _first_level[symbols]
	var found := -1
	for i in Levels.count():
		for row: String in Levels.LIST[i]["layout"]:
			for c in symbols:
				if row.contains(c):
					found = i
					break
			if found >= 0:
				break
		if found >= 0:
			break
	_first_level[symbols] = found
	return found
