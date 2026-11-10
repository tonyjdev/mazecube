class_name Sfx
extends RefCounted
## Efectos de sonido: Sfx.play("nombre") reproduce res://audio/sfx/nombre.wav
## por el bus "SFX" (su volumen se ajusta en Opciones).
##
## Usa un pequeño banco de reproductores (POOL_SIZE) colgados de la raíz del
## árbol, así que los sonidos se solapan, no se cortan al cambiar de escena y
## suenan también con el juego en pausa. Los sonidos se generan con
## tools/make_sfx.py.
##
## Sonidos: roll (vuelco), bounce (rebote), reject (giro descartado), key,
## door, crack (golpe a un muro destructible), break (muro roto), button,
## bars, powerup, reverse (media vuelta), explode (muerte del cubo), goal,
## alert (un perseguidor ha visto al cubo), fall (caída al vacío), dash,
## stomp (pisotón), splat (perseguidor reventado), shatter (enemigo
## sintético roto), teleport (el cubo entra en un portal), teleport_in (sale
## por el otro), spikes (salen los pinchos), laser_beep (aviso del cañón
## láser), laser (disparo), laser_hit (el láser choca), mortar (disparo del
## cañón de bombas), bomb_bounce (bote de una bomba), bomb_fuse (se enciende
## la mecha), bomb_explode (explosión), collect (cubito dorado), star y
## star_miss (estrella conseguida o no en la pantalla final), page (pasar
## página en la enciclopedia) y click (botones de la interfaz).

const POOL_SIZE := 10
## Ajuste de volumen (dB) de cada sonido respecto a los demás.
const VOLUMES := {
	"roll": -14.0,
	"bounce": -6.0,
	"reject": -8.0,
	"click": -6.0,
	"bars": -4.0,
}

static var _streams := {}
static var _players: Array[AudioStreamPlayer] = []
static var _next := 0


## Reproduce un sonido. `pitch_jitter` varía el tono al azar (±) para que los
## sonidos repetidos no suenen idénticos; `pitch` lo cambia a propósito.
static func play(sound: String, pitch_jitter := 0.0, volume_db := 0.0, pitch := 1.0) -> void:
	var stream := _stream(sound)
	if stream == null or not _ensure_players():
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.pitch_scale = pitch * (1.0 + randf_range(-pitch_jitter, pitch_jitter))
	player.volume_db = VOLUMES.get(sound, 0.0) + volume_db
	if player.is_inside_tree():
		player.play()
	else:
		# El banco se acaba de crear y se añade al árbol en diferido.
		player.play.call_deferred()


static func _stream(sound: String) -> AudioStream:
	if not _streams.has(sound):
		var path := "res://audio/sfx/%s.wav" % sound
		_streams[sound] = load(path) if ResourceLoader.exists(path) else null
	return _streams[sound]


static func _ensure_players() -> bool:
	if not _players.is_empty() and is_instance_valid(_players[0]):
		return true
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	_players.clear()
	var holder := Node.new()
	holder.name = "Sfx"
	holder.process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		holder.add_child(player)
		_players.append(player)
	tree.root.add_child.call_deferred(holder)
	return true
