class_name Music
extends RefCounted
## Música: Music.play("nombre") pone en bucle res://audio/music/nombre.ogg por
## el bus "Music" (su volumen se ajusta en Opciones), con un fundido cruzado
## desde el tema anterior. Si ya suena ese tema, sigue sin cortarse (p. ej. al
## pasar a otro nivel del mismo tramo).
##
## Temas (los compone tools/make_music.py, de unos 2 minutos cada uno): menu
## y, para los niveles, cuatro en la zona I (la que más niveles tiene) y tres
## en cada una de las demás; cada uno suena en un tramo de niveles (TRACKS).
## Cada uno tiene una intro que suena solo al empezar: el bucle vuelve al
## punto que indica audio/music/loops.json.
##
## Music.set_muffled(true) amortigua la música (más baja y sin agudos, con el
## filtro paso bajo y el amplificador del bus "Music"); se usa en la pausa y al
## completar un nivel.
##
## Los reproductores cuelgan del autoload GameState (ver attach()), así que la
## música no se corta al cambiar de escena y sigue sonando con el juego en pausa.

const DIR := "res://audio/music/"
const LOOPS_PATH := "res://audio/music/loops.json"
const BUS := &"Music"
## Volumen de la música respecto a los efectos (dB).
const VOLUME_DB := -8.0
const SILENT_DB := -60.0
const FADE_TIME := 1.5
## Tema de cada tramo de niveles: [primer nivel (índice), tema]. Los tramos
## siguen las zonas del mapa (ui/level_select/map.json) y, dentro de cada
## una, los cambios de paisaje o de mecánicas:
## I: 1-13 aprendizaje, 14-24 enemigos y mapas grandes, 25-30 grandes
## travesías, 31-34 vacío y puentes colgantes; II: 35-42 islas flotantes,
## 43-48 el valle y el bosque, 49-60 montaña y nieve; III: 61-68 portales,
## pinchos, láseres y bombas, 69-71 desierto, 72-75 cuevas de cristal; IV:
## 76-83 tierra corrompida, 84-91 volcán y obsidiana, 92-100 la plaga y el
## abismo; V: 101-104 la fortaleza, 105-108 la fundición y el arsenal,
## 109-115 el final.
const TRACKS := [
	[0, "zone1a"], [13, "zone1b"], [24, "zone1c"], [30, "zone1d"],
	[34, "zone2a"], [42, "zone2c"], [48, "zone2b"],
	[60, "zone3a"], [68, "zone3b"], [71, "zone3c"],
	[75, "zone4a"], [83, "zone4b"], [91, "zone4c"],
	[100, "zone5a"], [104, "zone5c"], [108, "zone5b"],
]
## Amortiguado: frecuencia de corte (Hz), volumen (dB) y duración de la transición.
const MUFFLED_CUTOFF := 700.0
const OPEN_CUTOFF := 20000.0
const MUFFLED_DB := -6.0
const MUFFLE_TIME := 0.4
## Efectos del bus "Music" (ver default_bus_layout.tres).
const LOWPASS_EFFECT := 0
const AMPLIFY_EFFECT := 1

static var _holder: Node
static var _players: Array[AudioStreamPlayer] = []
static var _active := 0
static var _current := ""
static var _loops := {}
static var _fade_tweens: Array[Tween] = [null, null]
static var _muffle_tween: Tween
static var _muffled := false


## Tema del tramo al que pertenece el nivel `index`.
static func track_for_level(index: int) -> String:
	var track: String = TRACKS[0][1]
	for entry: Array in TRACKS:
		if index >= entry[0]:
			track = entry[1]
	return track


static func play(track: String, fade := FADE_TIME) -> void:
	if track == _current or not _ensure_players():
		return
	var stream := _stream(track)
	if stream == null:
		return
	_current = track
	# El tema anterior se apaga y el nuevo entra en el otro reproductor.
	_fade(_active, SILENT_DB, fade, true)
	_active = 1 - _active
	var player := _players[_active]
	player.stream = stream
	player.volume_db = SILENT_DB if fade > 0.0 else VOLUME_DB
	player.play()
	_fade(_active, VOLUME_DB, fade, false)


static func stop(fade := FADE_TIME) -> void:
	if not _ensure_players():
		return
	_current = ""
	_fade(_active, SILENT_DB, fade, true)


## Amortigua la música (pausa, nivel completado) o la devuelve a la normalidad.
static func set_muffled(muffled: bool, time := MUFFLE_TIME) -> void:
	if muffled == _muffled or not _ensure_players():
		return
	_muffled = muffled
	var bus := AudioServer.get_bus_index(BUS)
	if bus < 0:
		return
	var lowpass := AudioServer.get_bus_effect(bus, LOWPASS_EFFECT) as AudioEffectLowPassFilter
	var amplify := AudioServer.get_bus_effect(bus, AMPLIFY_EFFECT) as AudioEffectAmplify
	if lowpass == null or amplify == null:
		return
	if _muffle_tween and _muffle_tween.is_valid():
		_muffle_tween.kill()
	if muffled:
		AudioServer.set_bus_effect_enabled(bus, LOWPASS_EFFECT, true)
	_muffle_tween = _holder.create_tween().set_parallel()
	_muffle_tween.tween_property(lowpass, "cutoff_hz", MUFFLED_CUTOFF if muffled else OPEN_CUTOFF, time) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT if muffled else Tween.EASE_IN)
	_muffle_tween.tween_property(amplify, "volume_db", MUFFLED_DB if muffled else 0.0, time)
	if not muffled:
		# Sin amortiguar, el filtro se quita para no gastar en él.
		_muffle_tween.chain().tween_callback(func() -> void:
			if not _muffled:
				AudioServer.set_bus_effect_enabled(bus, LOWPASS_EFFECT, false))


static func _fade(index: int, to_db: float, time: float, stop_after: bool) -> void:
	var player := _players[index]
	if _fade_tweens[index] and _fade_tweens[index].is_valid():
		_fade_tweens[index].kill()
	if not player.playing:
		return
	if time <= 0.0:
		player.volume_db = to_db
		if stop_after:
			player.stop()
		return
	var tween := _holder.create_tween()
	tween.tween_property(player, "volume_db", to_db, time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if to_db > player.volume_db else Tween.EASE_IN)
	if stop_after:
		tween.tween_callback(player.stop)
	_fade_tweens[index] = tween


static func _stream(track: String) -> AudioStream:
	var path := DIR + track + ".ogg"
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStreamOggVorbis
	if stream == null:
		return null
	if _loops.is_empty() and FileAccess.file_exists(LOOPS_PATH):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(LOOPS_PATH))
		if data is Dictionary:
			_loops = data
	stream.loop = true
	stream.loop_offset = float(_loops.get(track, 0.0))
	return stream


## Crea los reproductores colgando de `parent` (el autoload GameState, así
## están en el árbol desde el principio y no se pierden al cambiar de escena).
static func attach(parent: Node) -> void:
	_players.clear()
	_holder = Node.new()
	_holder.name = "Music"
	_holder.process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = BUS
		_holder.add_child(player)
		_players.append(player)
	parent.add_child(_holder)
	# Sin amortiguar, el filtro paso bajo no hace falta.
	var bus := AudioServer.get_bus_index(BUS)
	if bus >= 0 and AudioServer.get_bus_effect_count(bus) > LOWPASS_EFFECT:
		AudioServer.set_bus_effect_enabled(bus, LOWPASS_EFFECT, false)


static func _ensure_players() -> bool:
	return _holder != null and is_instance_valid(_holder) and _holder.is_inside_tree()
