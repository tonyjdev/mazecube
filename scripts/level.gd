class_name Level
extends Node3D
## Tablero del laberinto construido a partir de un mapa de texto.
##
## Leyenda del mapa:
##   '#' pared   '.' casilla libre   'A' inicio   'B' meta
##   Llaves (minúscula) y su puerta (mayúscula), del mismo color:
##   y/Y amarillo   o/O naranja   r/R rojo   u/U azul   g/G verde
##   Power ups: ver PowerUpCatalog (s = velocidad).
##   Muros destructibles: '1'..'5' = golpes que aguanta (5 pocas grietas,
##   1 muchas grietas). Ver BreakableWall.
##   Barrotes: c d e f h = grupo de barrotes; en minúscula empiezan abiertos y
##   en mayúscula cerrados. Ver Bars.
##   Botones: p q t v w = muro con un botón en la cara que da a su única
##   casilla libre. `button_links` indica qué grupos de barrotes cambia cada
##   botón ({"p": "cd"}). Ver WallButton.
##   Enemigos (sobre una casilla libre): x perseguidor (ver Chaser),
##   z obstáculo (ver Blocker), i j k m n patrulleros (ver Patroller); la ruta
##   de cada patrullero se indica en `patrol_routes` ({"i": "R3 D2 L3 U2"}).
##   Cada enemigo del mapa es un punto de origen (EnemySpawner), invisible,
##   que crea sus enemigos cuando el tablero termina de aparecer y los vuelve
##   a crear un rato después de que los destruyan. Por defecto gestiona un
##   enemigo y su radio se calcula solo; `spawner_settings` (campo
##   "spawners" del nivel) lo cambia por tipo de enemigo o por casilla:
##   {"x": {"count": 2}, Vector2i(10, 4): {"count": 3, "radius": 7}}
##   ("count" = enemigos que gestiona; "radius" = casillas de recorrido
##   alrededor del origen donde aparecen; lo de la casilla gana al del tipo).
##   Vacío: '~' = ni suelo ni pared. Si el cubo entra en el vacío, se cae y
##   explota (ver RollingCube). Fuera del mapa también es vacío. En los
##   niveles con vacío, bajo cada casilla con suelo o pared se dibuja un
##   bloque de roca para que el tablero parezca flotar.
##   Puente colgante: '=' = casilla de puente sobre el vacío. Las casillas '='
##   seguidas forman un puente recto, con vacío a ambos lados y suelo en los
##   dos extremos. Cada casilla aguanta HangingBridge.MAX_STABILITY salidas
##   del cubo; cuando una llega a 0 el puente entero cae y sus casillas pasan
##   a ser vacío (ver HangingBridge).
##   Teletransporte: '6' '7' '8' '9' = parejas de casillas conectadas (las dos
##   casillas con el mismo número). Cuando el cubo entra en una, se
##   teletransporta a la otra y sigue con el mismo rumbo (ver RollingCube).
##   Los enemigos no las pisan. Cada casilla debe tener al lado (no en
##   diagonal) un muro o el borde del suelo. Ver TeleportPad.
##   Pinchos: '^' = casilla con una trampa de pinchos. Salen del suelo cada
##   3-8 s (al azar), se quedan fuera 1 s y vuelven a esconderse; solo matan
##   al cubo mientras están fuera. Los enemigos no las pisan. Ver SpikeTrap.
##   Cañón láser: 'L' = muro con un cañón incrustado en la cara que da a su
##   única casilla libre. Dispara cada 2,5-4,5 s (al azar) un láser que
##   avanza en línea recta hasta chocar con un muro, una puerta, unos
##   barrotes cerrados, un enemigo o el cubo (al que mata). Pasa por encima
##   del vacío. Ver LaserCannon y LaserBolt.
##   Cañón de bombas: 'M' = muro con un cañón encima. Mira hacia `facing` y
##   solo dispara (cada 10-15 s, al azar) si el cubo está a su alcance: hasta
##   10 casillas hacia delante y 5 a cada lado. Lanza bombas con una
##   trayectoria calculada para que caigan en una casilla libre del camino
##   del cubo; las bombas se mueven con físicas, rebotan un poco y explotan a
##   los 2-3 s de tocar el suelo, matando al cubo si está a 2 casillas o
##   menos (en cuadrado, diagonales incluidas; esas casillas se ven rojas
##   mientras arde la mecha). A los enemigos no les hacen nada. `mortar_settings` (campo "mortars" del
##   nivel) fija hacia dónde mira y el alcance de cada cañón:
##   {Vector2i(10, 0): {"facing": Vector2i(0, 1), "range": Vector2i(14, 4)}}
##   ("range" = casillas hacia delante y a cada lado). Si no se indica, mira
##   hacia donde tiene más casillas libres a su alcance. Ver MortarCannon y
##   Bomb.
## Coleccionable: el campo "collectible" del nivel es la casilla del cubito
##   dorado (GoldenCube; lo colocan tools/place_collectibles.py). El cubo lo
##   coge al llegar a su casilla (take_collectible) y no vuelve a salir hasta
##   reiniciar el nivel.
## Materiales (ver BlockCatalog): el campo "theme" del nivel elige el bloque
## del suelo ("floor"), de los muros ("wall") y, opcionalmente, de la roca de
## debajo ("foundation"; si no se da, la que va bajo el suelo). Lo que falte
## sale de DEFAULT_THEME. "theme_regions" cambia los bloques en zonas del mapa
## (para transiciones): lista de { "rect": Rect2i(x, z, ancho, alto), y las
## mismas claves que "theme" }; si se solapan, gana la última.
## Las filas crecen hacia +Z (hacia abajo en pantalla) y las columnas hacia +X.
##
## Aparición (start_reveal): al empezar o reiniciar el nivel, el tablero se
## dibuja casilla a casilla en diagonal, de arriba a la izquierda a abajo a
## la derecha, en REVEAL_TIME segundos: cada
## casilla (suelo, pared, roca y lo que haya encima) aparece en su sitio y
## con su tamaño, pasando de transparente a opaca. Mientras tanto los enemigos están
## quietos (ver set_enemies_frozen). Al acabar emite reveal_finished.

signal reveal_finished
## Ha explotado una bomba a `distance` casillas del cubo (INF si no está).
signal bomb_exploded(distance: float)

const CELL_SIZE := 1.0
## Tipo de caja del terreno (ver _add_terrain_box).
const TERRAIN_WALL := 0
const TERRAIN_FLOOR := 1
const TERRAIN_FOUNDATION := 2
const WALL_HEIGHT := 0.5
const FLOOR_THICKNESS := 0.1
const KEY_CHARS := "yorug"
const BREAKABLE_CHARS := "12345"
const BAR_CHARS := "cdefh"
const BUTTON_CHARS := "pqtvw"
const CHASER_CHAR := "x"
const BLOCKER_CHAR := "z"
const PATROL_CHARS := "ijkmn"
const VOID_CHAR := "~"
const BRIDGE_CHAR := "="
const TELEPORT_CHARS := "6789"
const SPIKE_CHAR := "^"
## Distancia (en casillas, en x y en z) entre el centro del cubo y el de una
## casilla con los pinchos fuera a partir de la cual el cubo muere (las
## lanzas están a SpikeTrap.SPEAR_OFFSET del centro).
const SPIKE_HIT_DISTANCE := 0.7
## Los pinchos solo se oyen a esta distancia del cubo o menos (en casillas);
## cada casilla más lejos suenan SPIKE_SOUND_FALLOFF dB más bajo.
const SPIKE_SOUND_RADIUS := 7.0
const SPIKE_SOUND_FALLOFF := 2.2
const LASER_CHAR := "L"
## Velocidad del láser (casillas por segundo; el cubo va a 2,5).
const LASER_SPEED := 5.0
## Distancia (en casillas, de lado) entre el eje del láser y el centro del
## cubo o de un enemigo a partir de la cual chocan.
const LASER_CUBE_RADIUS := 0.42
const LASER_ENEMY_RADIUS := 0.38
## Los cañones solo se oyen a esta distancia del cubo o menos (en casillas);
## cada casilla más lejos suenan LASER_SOUND_FALLOFF dB más bajo.
const LASER_SOUND_RADIUS := 9.0
const LASER_SOUND_FALLOFF := 1.6
const MORTAR_CHAR := "M"
## Alcance de la explosión: casillas alrededor de la de la bomba (en
## cuadrado, diagonales incluidas, sin que lo frenen los muros). Mata al cubo
## si está en alguna de ellas; Bomb las marca en rojo mientras arde la mecha.
const BOMB_BLAST_CELLS := 2
## Al explotar, empuja a las demás bombas que estén a esta distancia o menos.
const BOMB_PUSH_RADIUS := 1.6
## Inclinaciones del cañón que se prueban para que la bomba no choque con los
## muros por el camino (de la más baja a la más alta).
const MORTAR_PITCHES: Array[float] = [55.0, 62.0, 69.0, 75.0, 80.0]
## Las bombas y los cañones solo se oyen a esta distancia del cubo o menos;
## cada casilla más lejos suenan MORTAR_SOUND_FALLOFF dB más bajo.
const MORTAR_SOUND_RADIUS := 14.0
const MORTAR_SOUND_FALLOFF := 1.2
## Tamaño (en casillas) de las cajas con las que chocan las bombas: el cubo y
## los enemigos.
const BOMB_CUBE_BOX := Vector3(0.96, 0.96, 0.96)
const BOMB_ENEMY_BOX := Vector3(0.6, 0.7, 0.6)
## Color de cada pareja de teletransporte.
const TELEPORT_COLORS := {
	"6": Color(0.25, 0.85, 1.0),
	"7": Color(1.0, 0.35, 0.9),
	"8": Color(0.65, 1.0, 0.25),
	"9": Color(1.0, 0.6, 0.35),
}
## Profundidad del bloque de roca bajo las casillas en los niveles con vacío.
const FOUNDATION_DEPTH := 0.9
## Distancia (en casillas) entre el centro del cubo y el de un enemigo letal a
## partir de la cual el cubo muere.
const ENEMY_HIT_DISTANCE := 0.72
## Bloques por defecto de los niveles sin "theme" (ver BlockCatalog).
const DEFAULT_THEME := {"floor": "grass", "wall": "stone_bricks"}
## Tono de las baldosas oscuras del ajedrezado del suelo y de la roca de
## debajo que no da al vacío (la del borde se deja con su color).
const FLOOR_DARK_TINT := Color(0.88, 0.88, 0.88)
const FOUNDATION_INNER_TINT := Color(0.78, 0.78, 0.78)
## Color de las casillas de salida y meta y de su luz (ver TileGlow).
const START_COLOR := Color(0.35, 0.60, 0.95)
const GOAL_COLOR := Color(0.30, 0.80, 0.45)
## La luz de la meta es más fuerte que la de la salida (TileGlow.power).
const GOAL_GLOW_POWER := 2.0
const ITEM_COLORS := {
	"y": Color(0.98, 0.80, 0.12),
	"o": Color(1.00, 0.50, 0.08),
	"r": Color(0.88, 0.16, 0.16),
	"u": Color(0.18, 0.42, 0.95),
	"g": Color(0.18, 0.70, 0.28),
}
## La puerta es un bloque estrecho que cierra el pasillo de muro a muro.
const DOOR_THICKNESS := 0.24
const DOOR_HEIGHT := 0.8
## Duración de la animación de la puerta hundiéndose al abrirse.
const DOOR_SINK_TIME := 0.6
## Al abrir una puerta, lo que tarda la llave en volar hasta ella
## encogiéndose (la puerta se hunde cuando llega).
const KEY_TO_DOOR_TIME := 0.4
## Altura y velocidad de giro (rad/s) de las llaves que están en el mapa.
const KEY_FLOAT_HEIGHT := 0.5
const KEY_SCALE := 1.6
const KEY_SPIN_SPEED := 1.2
const POWER_UP_FLOAT_HEIGHT := 0.5
## Casillas de recorrido (contando la de delante del botón) en las que el cubo
## se considera cerca de un botón. Ver button_near().
const BUTTON_APPROACH_CELLS := 4
const NO_CELL := Vector2i(-9999, -9999)
## Aparición del tablero: duración total y lo que tarda cada casilla en
## pasar de transparente a opaca.
const REVEAL_TIME := 1.3
const REVEAL_FADE_TIME := 0.45

@export var layout: PackedStringArray = PackedStringArray([
	"#######",
	"#A....#",
	"#.###.#",
	"#...#.#",
	"###.#.#",
	"#...#.#",
	"#.#####",
	"#....B#",
	"#######",
])
## Rumbo inicial del cubo en coordenadas de casilla (x, z). (0, 1) = abajo.
@export var start_heading := Vector2i(0, 1)
## Grupos de barrotes que cambia cada botón: {"p": "cd"} (campo "buttons" del
## nivel). Pulsar un botón abre los barrotes cerrados de esos grupos y cierra
## los abiertos.
@export var button_links := {}
## Ruta de cada patrullero (campo "patrols" del nivel): {"i": "R3 D2 L3 U2"}.
## Ver Patroller.set_route.
@export var patrol_routes := {}
## Bloques del nivel (campo "theme") y por zonas ("theme_regions"). Ver la
## leyenda del principio.
@export var block_theme := {}
## Ajustes de los puntos de origen de enemigos (campo "spawners"). Ver la
## leyenda del principio.
@export var spawner_settings := {}
@export var block_regions: Array = []
## Hacia dónde mira y alcance de los cañones de bombas (campo "mortars"). Ver
## la leyenda del principio.
@export var mortar_settings := {}
## Casilla del cubito dorado (campo "collectible"); NO_CELL si no hay.
var collectible_cell := NO_CELL
## Cubito dorado del mapa (null si no hay o ya se ha cogido).
var _collectible: GoldenCube
## Cubo del jugador: los enemigos lo buscan y lo matan.
var cube: RollingCube:
	set(value):
		cube = value
		for enemy in _enemies:
			enemy.cube = value

var start_cell := Vector2i.ZERO
var goal_cell := Vector2i.ZERO
var _walkable := {}
## Casillas de vacío ('~').
var _void := {}
## casilla -> { "color": String, "node": Node3D }
var _keys := {}
var _doors := {}
## casilla -> { "power_up": PowerUp, "node": Node3D }
var _power_ups := {}
## casilla -> BreakableWall (solo los que siguen en pie)
var _breakables := {}
## casilla -> { "group": String, "node": Bars }
var _bars := {}
## casilla -> { "symbol": String, "node": WallButton, "front": Vector2i,
##             "near": { casilla: casillas de recorrido hasta el botón } }
var _buttons := {}
var _enemies: Array[Enemy] = []
## Casillas ocupadas por enemigos sólidos: casilla -> [Enemy]. Se rehace al
## consultarla si _solid_dirty (ver solid_cells_changed).
var _solid_cells := {}
var _solid_dirty := true
## Cambia cada vez que cambia por dónde se puede ir sin contar puertas ni
## muros destructibles (al construir, al pulsar un botón y al caer un puente):
## sirve para reutilizar cálculos de caminos (ver Blocker).
var _topology_version := 0
var _spawners: Array[EnemySpawner] = []
## Los enemigos están quietos (ver set_enemies_frozen).
var _enemies_frozen := false
## casilla -> { "partner": Vector2i, "symbol": String, "node": TeleportPad }
var _teleports := {}
## casilla -> SpikeTrap
var _spikes := {}
## casilla -> { "node": LaserCannon, "facing": Vector2i }
var _cannons := {}
## Láseres en vuelo.
var _lasers: Array[LaserBolt] = []
## casilla -> MortarCannon
var _mortars := {}
## Bombas en juego.
var _bombs: Array[Bomb] = []
## Posición (en el tablero) del cubo y de cada enemigo en el fotograma
## anterior, para saber a qué velocidad empujan a las bombas.
var _body_positions := {}
## casilla -> HangingBridge (solo los que siguen en pie)
var _bridges := {}
## Aparición en curso: tiempo transcurrido, retraso de cada casilla,
## MultiMesh ({ "multimesh", "materials", "cells" }; la opacidad de cada
## casilla va en el color de su instancia) y nodos sueltos ({ "delay", "node",
## "materials": [...] }, ver _fade_materials).
var _revealing := false
var _reveal_time := 0.0
var _reveal_delays := {}
var _reveal_multimeshes: Array[Dictionary] = []
var _reveal_nodes: Array[Dictionary] = []
## Terreno en mallas fusionadas por trozos (ver TerrainBuilder): sustituye a
## los MultiMesh al acabar la aparición. Casillas de muro (tapan los lados de
## lo que tienen al lado).
var _terrain: Node3D
## Efectos ya precalentados en esta ejecución ("mortar", "laser"; ver
## _warm_up_effects).
static var _warmed := {}
var _terrain_builder: TerrainBuilder
var _wall_set := {}


func _ready() -> void:
	build()


## Prepara el tablero de un nivel de Levels.LIST (se construye con build()).
func configure(data: Dictionary) -> void:
	layout = PackedStringArray(data["layout"])
	start_heading = data["start_heading"]
	button_links = data.get("buttons", {})
	patrol_routes = data.get("patrols", {})
	spawner_settings = data.get("spawners", {})
	block_theme = data.get("theme", {})
	block_regions = data.get("theme_regions", [])
	mortar_settings = data.get("mortars", {})
	collectible_cell = data.get("collectible", NO_CELL)


func build() -> void:
	for child in get_children():
		child.queue_free()
	_revealing = false
	_reveal_multimeshes.clear()
	_reveal_nodes.clear()
	_walkable.clear()
	_void.clear()
	_keys.clear()
	_doors.clear()
	_power_ups.clear()
	_collectible = null
	_breakables.clear()
	_bars.clear()
	_buttons.clear()
	_enemies.clear()
	_solid_dirty = true
	_topology_version += 1
	_spawners.clear()
	_bridges.clear()
	_teleports.clear()
	_spikes.clear()
	_cannons.clear()
	_lasers.clear()
	_mortars.clear()
	_bombs.clear()
	_body_positions.clear()
	var enemy_cells := {}
	var mortar_cells: Array[Vector2i] = []
	## símbolo -> casillas de teletransporte
	var teleport_cells := {}
	var bridge_cells := {}

	_terrain_builder = TerrainBuilder.new()
	_wall_set.clear()
	var start_mat := _make_material(START_COLOR)
	var goal_mat := _make_material(GOAL_COLOR)
	# Muros y baldosas normales se dibujan con MultiMesh (una llamada de dibujo
	# por tipo de bloque): los mapas grandes tienen miles de casillas.
	var wall_cells: Array[Vector2i] = []
	## "bloque" -> casillas; las del suelo, "bloque|0" y "bloque|1" (ajedrezado).
	var wall_groups := {}
	var floor_groups := {}

	for z in layout.size():
		var row: String = layout[z]
		for x in row.length():
			var cell := Vector2i(x, z)
			var symbol := row[x]
			if symbol == VOID_CHAR:
				_void[cell] = true
				continue
			if symbol == LASER_CHAR:
				# El muro recortado lo dibuja el propio cañón.
				wall_cells.append(cell)
				_add_cannon(cell)
				continue
			if symbol == "#" or BUTTON_CHARS.contains(symbol) or symbol == MORTAR_CHAR:
				wall_cells.append(cell)
				_group(wall_groups, _block_at(cell, "wall"), cell)
				if symbol == MORTAR_CHAR:
					mortar_cells.append(cell)
				elif symbol != "#":
					_add_button(cell, symbol)
				continue
			_walkable[cell] = true
			if symbol == BRIDGE_CHAR:
				bridge_cells[cell] = true
				continue
			var tile := Vector3(CELL_SIZE * 0.96, FLOOR_THICKNESS, CELL_SIZE * 0.96)
			if symbol == "A":
				start_cell = cell
				_add_box(cell, tile, -FLOOR_THICKNESS * 0.5, start_mat)
				_add_glow(cell, START_COLOR)
			elif symbol == "B":
				goal_cell = cell
				_add_box(cell, tile, -FLOOR_THICKNESS * 0.5, goal_mat)
				_add_glow(cell, GOAL_COLOR, GOAL_GLOW_POWER)
			else:
				_group(floor_groups, "%s|%d" % [_block_at(cell, "floor"), (x + z) % 2], cell)
			if KEY_CHARS.contains(symbol):
				_add_key(cell, symbol)
			elif KEY_CHARS.to_upper().contains(symbol):
				_add_door(cell, symbol.to_lower())
			elif PowerUpCatalog.has_symbol(symbol):
				_add_power_up(cell, symbol)
			elif BREAKABLE_CHARS.contains(symbol):
				_add_breakable(cell, int(symbol))
			elif BAR_CHARS.contains(symbol.to_lower()):
				_add_bars(cell, symbol)
			elif symbol == CHASER_CHAR or symbol == BLOCKER_CHAR or PATROL_CHARS.contains(symbol):
				enemy_cells[cell] = symbol
			elif TELEPORT_CHARS.contains(symbol):
				_group(teleport_cells, symbol, cell)
			elif symbol == SPIKE_CHAR:
				_add_spikes(cell)
	# Los cañones láser no tapan: su muro está recortado y deja ver el lado
	# del muro de al lado.
	for cell in wall_cells:
		if layout[cell.y][cell.x] != LASER_CHAR:
			_wall_set[cell] = true
	for id: String in wall_groups:
		_add_multimesh(wall_groups[id], id, Vector3(CELL_SIZE, WALL_HEIGHT, CELL_SIZE),
			WALL_HEIGHT * 0.5, Color.WHITE, TERRAIN_WALL)
	var tile_size := Vector3(CELL_SIZE * 0.96, FLOOR_THICKNESS, CELL_SIZE * 0.96)
	for key: String in floor_groups:
		var parts := key.split("|")
		_add_multimesh(floor_groups[key], parts[0], tile_size, -FLOOR_THICKNESS * 0.5,
			FLOOR_DARK_TINT if parts[1] == "1" else Color.WHITE, TERRAIN_FLOOR)
	if not _void.is_empty():
		_add_foundations(wall_cells)
	# Terreno para la partida (se ve al acabar la aparición, ver _finish_reveal).
	_terrain = Node3D.new()
	_terrain.name = "Terrain"
	_terrain.visible = false
	add_child(_terrain)
	_terrain_builder.build(_terrain)
	_terrain_builder = null
	_add_bridges(bridge_cells)
	_add_teleports(teleport_cells)
	if _walkable.has(collectible_cell):
		_collectible = GoldenCube.new()
		_collectible.position = Vector3(collectible_cell.x * CELL_SIZE, 0.0, collectible_cell.y * CELL_SIZE)
		add_child(_collectible)
	for cell: Vector2i in enemy_cells:
		_add_spawner(cell, enemy_cells[cell])
	for cell in mortar_cells:
		_add_mortar(cell)
	for button in _buttons.values():
		button["near"] = _cells_within(button["front"], BUTTON_APPROACH_CELLS)
	_warm_up_effects.call_deferred()


## Precalentamiento de efectos: en el renderizador Compatibility cada tipo
## de material se compila la primera vez que se pinta, y en el móvil eso
## congelaba el juego un momento al disparar el primer cañón. Al cargar un
## nivel con cañones de bombas o láser se pintan unos fotogramas, en la
## casilla de salida (mientras lo tapa la pantalla de carga o el fundido),
## una bomba real que se enciende y explota, el humo y el destello del
## cañón, y un láser que choca, con sus chispas. Después se borra todo. Solo
## la primera vez en cada ejecución (los shaders quedan compilados).
func _warm_up_effects() -> void:
	var mortar := not _mortars.is_empty() and not _warmed.has("mortar")
	var laser := not _cannons.is_empty() and not _warmed.has("laser")
	if not mortar and not laser:
		return
	var at := Vector3(start_cell.x * CELL_SIZE, 0.0, start_cell.y * CELL_SIZE)
	var made: Array[Node] = []
	var bomb: Bomb
	var bolt: LaserBolt
	var cannon: LaserCannon
	if mortar:
		_warmed["mortar"] = true
		bomb = Bomb.create(self, at + Vector3(0.0, 0.5, 0.0), Vector3.ZERO)
		made.append(bomb)
		add_child(bomb)
		# Mecha encendida: casillas rojas de la zona.
		bomb._fuse_total = 1.0
		bomb.fuse_left = 1.0
		bomb._update_visuals(0.016)
		var smoke := MortarCannon.make_smoke(6, 0.5, Color.GRAY, 1.0, Vector2.ONE, Vector2.ONE, 1.5)
		smoke.position = at
		smoke.emitting = true
		made.append(smoke)
		add_child(smoke)
		var flash := MeshInstance3D.new()
		flash.mesh = MortarCannon._flash_mesh
		flash.material_override = MortarCannon._flash_material
		flash.position = at + Vector3(0.0, 0.5, 0.0)
		flash.transparency = 0.5
		made.append(flash)
		add_child(flash)
	if laser:
		_warmed["laser"] = true
		bolt = LaserBolt.create(Vector2(start_cell), Vector2(1, 0))
		bolt.position = at + Vector3(0.0, LaserCannon.HEIGHT, 0.0)
		made.append(bolt)
		add_child(bolt)
		cannon = _cannons.values()[0]["node"]
		cannon.process_mode = Node.PROCESS_MODE_ALWAYS
		cannon._fire_effect()
	for node in made:
		node.process_mode = Node.PROCESS_MODE_ALWAYS
	var before := get_children()
	await _warm_up_frames(3)
	if is_instance_valid(bomb):
		bomb.explode()
	if is_instance_valid(bolt):
		bolt.explode(Vector2(start_cell))
	# Lo que han creado las explosiones (fuego, humo, chispas, destellos y la
	# mancha de quemado) también se procesa en la pausa de la carga.
	for node in get_children():
		if not before.has(node):
			node.process_mode = Node.PROCESS_MODE_ALWAYS
			made.append(node)
	await _warm_up_frames(4)
	if is_instance_valid(cannon):
		cannon.process_mode = Node.PROCESS_MODE_INHERIT
	for node in made:
		if is_instance_valid(node):
			node.queue_free()


func _warm_up_frames(count: int) -> void:
	for i in count:
		if not is_inside_tree():
			return
		await RenderingServer.frame_post_draw


func _process(delta: float) -> void:
	if _revealing:
		_update_reveal(delta)
	else:
		for spawner in _spawners:
			spawner.update(delta)
		for trap: SpikeTrap in _spikes.values():
			trap.update(delta)
		for item: Dictionary in _cannons.values():
			item["node"].update(delta)
		_update_lasers(delta)
		_update_mortars(delta)
		_update_bombs(delta)
	_check_enemy_hits()
	_check_spike_hits()
	for item in _keys.values():
		item["node"].rotate_y(KEY_SPIN_SPEED * delta)
	for item in _power_ups.values():
		var power_up: PowerUp = item["power_up"]
		item["node"].rotate(power_up.pickup_spin_axis, power_up.pickup_spin_speed * delta)


## Casilla por la que puede pasar el cubo: como is_terrain_walkable() y,
## además, sin un obstáculo (enemigo sólido) en ella.
func is_walkable(cell: Vector2i) -> bool:
	return is_terrain_walkable(cell) and not solid_enemy_at(cell)


## Casilla libre, sin puerta ni barrotes cerrados y sin muro destructible en
## pie (sin tener en cuenta a los enemigos).
func is_terrain_walkable(cell: Vector2i) -> bool:
	return _walkable.has(cell) and not _doors.has(cell) and not _breakables.has(cell) \
		and not bars_closed(cell)


## Casilla de vacío ('~' o fuera del mapa): el cubo que entra en ella se cae.
func is_void(cell: Vector2i) -> bool:
	if _void.has(cell):
		return true
	return cell.y < 0 or cell.y >= layout.size() or cell.x < 0 or cell.x >= layout[cell.y].length()


## Casilla de un puente colgante que sigue en pie.
func is_bridge(cell: Vector2i) -> bool:
	return _bridges.has(cell)


## Estabilidad que le queda a una casilla de puente (0..MAX_STABILITY), o -1
## si no es un puente en pie.
func bridge_stability(cell: Vector2i) -> int:
	return _bridges[cell].stability(cell) if _bridges.has(cell) else -1


## El cubo acaba de salir de `cell` (ya está en otra casilla): si era un
## puente, pierde estabilidad y, si llega a 0, el puente entero cae, con el
## cubo si sigue encima.
func cube_left_cell(cell: Vector2i) -> void:
	if not _bridges.has(cell):
		return
	var bridge: HangingBridge = _bridges[cell]
	if not bridge.wear(cell):
		Sfx.play("creak", 0.1, -4.0 * bridge.stability(cell))
		return
	var cube_cell := NO_CELL
	if cube and cube.is_alive() and (bridge.has_cell(cube.cell) or bridge.has_cell(cube.roll_target())):
		cube_cell = cube.cell if bridge.has_cell(cube.cell) else cube.roll_target()
	for c in bridge.cells:
		_bridges.erase(c)
		_walkable.erase(c)
		_void[c] = true
	_topology_version += 1
	bridge.collapse(cell, cube_cell)
	Sfx.play("collapse")
	if cube_cell != NO_CELL:
		cube.drop()


## Casilla con suelo (no es pared), haya lo que haya en ella.
func has_floor(cell: Vector2i) -> bool:
	return _walkable.has(cell)


## Casilla por la que pueden pasar los enemigos (sin contar a los demás
## enemigos): libre, sin puerta, barrotes cerrados ni muro destructible, y
## que no sea la salida, la meta ni un puente colgante.
func enemy_can_pass(cell: Vector2i) -> bool:
	return is_terrain_walkable(cell) and cell != start_cell and cell != goal_cell \
		and not is_bridge(cell) and not _teleports.has(cell) and not _spikes.has(cell)


## Casilla de teletransporte conectada con `cell`, o NO_CELL si `cell` no es
## de teletransporte.
func teleport_partner(cell: Vector2i) -> Vector2i:
	return _teleports[cell]["partner"] if _teleports.has(cell) else NO_CELL


func is_teleport(cell: Vector2i) -> bool:
	return _teleports.has(cell)


## El cubo entra o sale por la casilla de teletransporte: brilla un momento.
func pulse_teleport(cell: Vector2i) -> void:
	if _teleports.has(cell):
		_teleports[cell]["node"].pulse()


## Hay algún enemigo (de cualquier tipo) ocupando la casilla.
func enemy_at(cell: Vector2i) -> bool:
	for enemy in _enemies:
		if enemy.occupies(cell):
			return true
	return false


## Hay un enemigo sólido (obstáculo) ocupando la casilla, sin contar `except`.
## Se consulta muchísimo (en cada búsqueda de camino), así que usa la tabla
## _solid_cells en lugar de recorrer los enemigos.
func solid_enemy_at(cell: Vector2i, except: Enemy = null) -> bool:
	if _solid_dirty:
		_solid_dirty = false
		_solid_cells.clear()
		for enemy in _enemies:
			if enemy.solid:
				for c: Vector2i in [enemy.cell, enemy.target_cell()]:
					if not _solid_cells.has(c):
						_solid_cells[c] = []
					if not _solid_cells[c].has(enemy):
						_solid_cells[c].append(enemy)
	var found: Array = _solid_cells.get(cell, [])
	for enemy in found:
		if enemy != except:
			return true
	return false


## Un enemigo sólido ha cambiado las casillas que ocupa.
func solid_cells_changed() -> void:
	_solid_dirty = true


func topology_version() -> int:
	return _topology_version


## El cubo ha muerto: los enemigos le pierden la pista.
func notify_cube_died() -> void:
	for enemy in _enemies:
		enemy.on_cube_died()


## Si un enemigo letal toca al cubo, el cubo explota.
func _check_enemy_hits() -> void:
	if cube == null or not cube.is_vulnerable():
		return
	var anchor := to_local(cube.get_trail_anchor())
	var cube_pos := Vector2(anchor.x, anchor.z) / CELL_SIZE
	for enemy in _enemies:
		if enemy.can_hurt() and enemy.board_position().distance_to(cube_pos) < ENEMY_HIT_DISTANCE:
			cube.die()
			return


func is_spikes(cell: Vector2i) -> bool:
	return _spikes.has(cell)


## Si el cubo está sobre una casilla con los pinchos fuera (o volcando hacia
## ella o desde ella lo bastante cerca), el cubo explota.
func _check_spike_hits() -> void:
	if _spikes.is_empty() or cube == null or not cube.is_vulnerable():
		return
	var anchor := to_local(cube.get_trail_anchor())
	var cube_pos := Vector2(anchor.x, anchor.z) / CELL_SIZE
	for c: Vector2i in [cube.cell, cube.roll_target()]:
		var trap: SpikeTrap = _spikes.get(c)
		if trap == null or not trap.is_dangerous():
			continue
		var d := (cube_pos - Vector2(c)).abs()
		if maxf(d.x, d.y) < SPIKE_HIT_DISTANCE:
			cube.die()
			return


func _add_spikes(cell: Vector2i) -> void:
	var trap := SpikeTrap.create()
	trap.position = Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)
	add_child(trap)
	_spikes[cell] = trap
	trap.extended.connect(_on_spikes_extended.bind(cell))


## Sonido de los pinchos al salir, más bajo cuanto más lejos del cubo (y nada
## si están lejos, para que no suenen todos los del mapa).
func _on_spikes_extended(cell: Vector2i) -> void:
	if cube == null:
		return
	var distance := Vector2(cube.cell).distance_to(Vector2(cell))
	if distance <= SPIKE_SOUND_RADIUS:
		Sfx.play("spikes", 0.08, -SPIKE_SOUND_FALLOFF * distance)


func is_cannon(cell: Vector2i) -> bool:
	return _cannons.has(cell)


## El cañón se mete en el muro y apunta a su única casilla libre (como los
## botones).
func _add_cannon(cell: Vector2i) -> void:
	var facing := _free_side(cell)
	if facing == Vector2i.ZERO:
		push_warning("Cañón láser en %s sin casilla libre al lado" % cell)
		facing = Vector2i.DOWN
	var cannon := LaserCannon.create(_block_at(cell, "wall"), _block_at(cell, "floor"))
	cannon.position = Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)
	cannon.rotation.y = atan2(facing.x, facing.y)
	add_child(cannon)
	_cannons[cell] = {"node": cannon, "facing": facing}
	cannon.fired.connect(_on_cannon_fired.bind(cell))
	cannon.beeped.connect(_on_cannon_beeped.bind(cell))


## Primera casilla de al lado (no en diagonal) que no es muro, botón, cañón
## ni vacío, o Vector2i.ZERO si no hay.
func _free_side(cell: Vector2i) -> Vector2i:
	for dir: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var n := cell + dir
		if n.y >= 0 and n.y < layout.size() and n.x >= 0 and n.x < layout[n.y].length() \
				and not "#~".contains(layout[n.y][n.x]) and not BUTTON_CHARS.contains(layout[n.y][n.x]) \
				and layout[n.y][n.x] != LASER_CHAR and layout[n.y][n.x] != MORTAR_CHAR:
			return dir
	return Vector2i.ZERO


## Volumen (dB) de un sonido de cañón según lo lejos que esté del cubo, o NAN
## si está demasiado lejos para oírse.
func _cannon_volume(cell: Vector2i) -> float:
	if cube == null:
		return NAN
	var distance := Vector2(cube.cell).distance_to(Vector2(cell))
	return -LASER_SOUND_FALLOFF * distance if distance <= LASER_SOUND_RADIUS else NAN


func _on_cannon_beeped(cell: Vector2i) -> void:
	var volume := _cannon_volume(cell)
	if not is_nan(volume):
		Sfx.play("laser_beep", 0.0, volume)


## Sale un láser por la boca del cañón (en el borde de su casilla).
func _on_cannon_fired(cell: Vector2i) -> void:
	var dir := Vector2(_cannons[cell]["facing"])
	var bolt := LaserBolt.create(Vector2(cell) + dir * 0.5, dir)
	add_child(bolt)
	_lasers.append(bolt)
	var volume := _cannon_volume(cell)
	if not is_nan(volume):
		Sfx.play("laser", 0.06, volume)


## Mueve los láseres y hace chocar los que tocan algo.
func _update_lasers(delta: float) -> void:
	if _lasers.is_empty():
		return
	var grid := get_grid_size()
	for bolt: LaserBolt in _lasers.duplicate():
		bolt.board_pos += bolt.direction * LASER_SPEED * delta
		var p := bolt.board_pos
		if p.x < -2.0 or p.y < -2.0 or p.x > grid.x + 1.0 or p.y > grid.y + 1.0:
			# Se ha ido por el vacío de fuera del mapa.
			_lasers.erase(bolt)
			bolt.queue_free()
			continue
		var impact := _laser_impact(bolt)
		if is_nan(impact.x):
			continue
		_lasers.erase(bolt)
		bolt.explode(impact)
		var volume := _cannon_volume(Vector2i(roundi(impact.x), roundi(impact.y)))
		if not is_nan(volume):
			Sfx.play("laser_hit", 0.1, volume)


## Punto (en casillas) donde choca el láser en este fotograma, o (NAN, NAN)
## si no choca con nada. Si toca al cubo y es vulnerable, el cubo explota.
func _laser_impact(bolt: LaserBolt) -> Vector2:
	var dir := bolt.direction
	var front := bolt.board_pos + dir * LaserBolt.LENGTH * 0.5
	var best := Vector2(NAN, NAN)
	var best_along := INF
	# Lo que haya en la casilla de la punta: muro, puerta o barrotes.
	var cell := Vector2i(roundi(front.x), roundi(front.y))
	var stop := _laser_stop(cell)
	if stop >= 0.0:
		var face := Vector2(cell) - dir * stop
		if (front - face).dot(dir) >= 0.0:
			best = face
			best_along = (face - bolt.board_pos).dot(dir)
	# El cubo (salvo si está cayendo del cielo, saltando por encima o
	# teletransportándose).
	var hit_cube := false
	if cube and cube.is_alive() and not cube.is_appearing() and not cube.is_teleporting() \
			and not cube.is_above(LaserCannon.HEIGHT + LaserBolt.CORE_RADIUS):
		var anchor := to_local(cube.get_trail_anchor())
		var along := _laser_touch(bolt, Vector2(anchor.x, anchor.z) / CELL_SIZE, LASER_CUBE_RADIUS)
		if along < best_along:
			best_along = along
			best = bolt.board_pos + dir * along
			hit_cube = true
	for enemy in _enemies:
		if enemy.is_appearing():
			continue
		var along := _laser_touch(bolt, enemy.board_position(), LASER_ENEMY_RADIUS)
		if along < best_along:
			best_along = along
			best = bolt.board_pos + dir * along
			hit_cube = false
	if hit_cube:
		cube.die()
	return best


## Si el láser toca un cuerpo de radio `radius` con centro en `center`
## (casillas), la distancia a lo largo del láser desde su centro hasta el
## punto de choque; si no, INF.
func _laser_touch(bolt: LaserBolt, center: Vector2, radius: float) -> float:
	var offset := center - bolt.board_pos
	var along := offset.dot(bolt.direction)
	if absf(offset.cross(bolt.direction)) >= radius or absf(along) >= radius + LaserBolt.LENGTH * 0.5:
		return INF
	return maxf(along - radius, -LaserBolt.LENGTH * 0.5)


## Distancia desde el centro de la casilla hasta la cara contra la que choca
## un láser que entra en ella, o -1 si el láser la atraviesa (casillas libres,
## vacío, puentes y fuera del mapa).
func _laser_stop(cell: Vector2i) -> float:
	if cell.y < 0 or cell.y >= layout.size() or cell.x < 0 or cell.x >= layout[cell.y].length():
		return -1.0
	if _is_wall(cell) and not BREAKABLE_CHARS.contains(layout[cell.y][cell.x]):
		return CELL_SIZE * 0.5
	if _breakables.has(cell):
		return CELL_SIZE * 0.5
	if _doors.has(cell):
		return DOOR_THICKNESS * 0.5
	if bars_closed(cell):
		return 0.06
	return -1.0


# --- Cañones de bombas -------------------------------------------------------

func is_mortar(cell: Vector2i) -> bool:
	return _mortars.has(cell)


## Cañón de bombas encima del muro de `cell`, con lo que diga mortar_settings
## o, si no, mirando hacia donde tiene más casillas libres a su alcance.
func _add_mortar(cell: Vector2i) -> void:
	var settings: Dictionary = mortar_settings.get(cell, {})
	var reach: Vector2i = settings.get("range", Vector2i(MortarCannon.RANGE_FORWARD, MortarCannon.RANGE_SIDE))
	var facing: Vector2i = settings.get("facing", Vector2i.ZERO)
	if facing == Vector2i.ZERO:
		var best := -1
		for dir: Vector2i in [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]:
			var count := 0
			for c: Vector2i in _walkable:
				if _in_reach(cell, dir, reach, c):
					count += 1
			if count > best:
				best = count
				facing = dir
	var cannon := MortarCannon.create(facing, reach)
	cannon.position = Vector3(cell.x * CELL_SIZE, WALL_HEIGHT, cell.y * CELL_SIZE)
	add_child(cannon)
	_mortars[cell] = cannon
	cannon.fired.connect(_on_mortar_fired.bind(cell))


## La casilla `target` está al alcance de un cañón en `cell` que mira hacia
## `facing` con alcance `reach` (hacia delante, a cada lado).
static func _in_reach(cell: Vector2i, facing: Vector2i, reach: Vector2i, target: Vector2i) -> bool:
	var offset := target - cell
	var forward := offset.x * facing.x + offset.y * facing.y
	var side := offset.x * facing.y - offset.y * facing.x
	return forward >= 1 and forward <= reach.x and absi(side) <= reach.y


## El cubo está en el tablero y se le puede apuntar.
func _cube_targetable() -> bool:
	return cube != null and cube.is_alive() and not cube.is_finished and not cube.is_appearing() \
		and not cube.is_teleporting()


func _update_mortars(delta: float) -> void:
	for cell: Vector2i in _mortars:
		var cannon: MortarCannon = _mortars[cell]
		cannon.update(delta)
		if cannon.wants_to_fire() and _cube_targetable() \
				and _in_reach(cell, cannon.facing, cannon.reach, cube.cell):
			var target := _mortar_target(cell, cannon)
			if target == NO_CELL:
				continue
			var shot := _plan_mortar_shot(cell, target)
			if not shot.is_empty():
				cannon.aim(shot["yaw"], shot["pitch"], shot["velocity"])


## Casilla donde caerá la bomba: la del camino previsto del cubo en la que
## estará más o menos cuando la bomba lleve un rato en el suelo (o un poco
## antes), siempre libre y al alcance del cañón. NO_CELL si no hay ninguna.
func _mortar_target(cell: Vector2i, cannon: MortarCannon) -> Vector2i:
	var path := _predict_cube_path(24)
	var step := cube.step_time()
	var extra := randf_range(-0.6, 1.4)
	var index := 0
	# Dos pasadas: el tiempo de vuelo depende de la casilla elegida.
	var flight := 1.5
	for i in 2:
		index = clampi(roundi((MortarCannon.AIM_TIME + flight + extra) / step), 0, path.size() - 1)
		var shot := _plan_mortar_shot(cell, path[index])
		if not shot.is_empty():
			flight = shot["time"]
	for k in range(index, -1, -1):
		var c: Vector2i = path[k]
		if _bomb_target_ok(c) and _in_reach(cell, cannon.facing, cannon.reach, c):
			return c
	return NO_CELL


## Casilla en la que puede caer una bomba: libre (por donde pasan el cubo y
## los enemigos), sin ser la salida ni la meta.
func _bomb_target_ok(cell: Vector2i) -> bool:
	return is_terrain_walkable(cell) and cell != start_cell and cell != goal_cell and not _void.has(cell)


## Casillas por las que pasará el cubo si nadie gira, empezando por la suya:
## sigue recto y, al chocar, rebota (hasta `count` casillas).
func _predict_cube_path(count: int) -> Array[Vector2i]:
	var path: Array[Vector2i] = [cube.cell]
	var dir := cube.heading
	var current := cube.cell
	while path.size() < count:
		var next := current + dir
		if not is_terrain_walkable(next):
			dir = -dir
			next = current + dir
			if not is_terrain_walkable(next):
				break
		path.append(next)
		current = next
	return path


## Trayectoria de una bomba desde el cañón de `cell` hasta el centro de
## `target`: giro, inclinación, velocidad de salida y tiempo de vuelo
## ({ "yaw", "pitch", "velocity", "time" }), con la inclinación más baja de
## MORTAR_PITCHES que no choca con ningún muro por el camino (o la más alta si
## todas chocan). Vacío si no hay trayectoria.
func _plan_mortar_shot(cell: Vector2i, target: Vector2i) -> Dictionary:
	var origin := Vector3(cell.x * CELL_SIZE, WALL_HEIGHT, cell.y * CELL_SIZE)
	var land := Vector3(target.x * CELL_SIZE, Bomb.INRADIUS, target.y * CELL_SIZE)
	var yaw := atan2(land.x - origin.x, land.z - origin.z)
	var result := {}
	for degrees in MORTAR_PITCHES:
		var pitch := deg_to_rad(degrees)
		var muzzle := origin + MortarCannon.muzzle_offset(yaw, pitch)
		var flat := Vector2(land.x - muzzle.x, land.z - muzzle.z)
		var d := flat.length()
		var drop := muzzle.y - land.y
		var denom := 2.0 * cos(pitch) * cos(pitch) * (d * tan(pitch) + drop)
		if d < 0.05 or denom <= 0.0:
			continue
		# Tiro parabólico con ese ángulo: v² = g·d² / (2·cos²θ·(d·tanθ + h)).
		var speed := sqrt(Bomb.GRAVITY * d * d / denom)
		var dir := flat / d
		var velocity := Vector3(dir.x * speed * cos(pitch), speed * sin(pitch), dir.y * speed * cos(pitch))
		result = {"yaw": yaw, "pitch": pitch, "velocity": velocity, "time": d / (speed * cos(pitch))}
		if _arc_clear(cell, muzzle, velocity, result["time"]):
			break
	return result


## La bomba que sale de `muzzle` con `velocity` no choca con nada en los
## primeros `time` segundos (salvo con el muro de su propio cañón).
func _arc_clear(cell: Vector2i, muzzle: Vector3, velocity: Vector3, time: float) -> bool:
	const SAMPLES := 24
	for i in range(1, SAMPLES):
		var t := time * i / SAMPLES
		var p := muzzle + velocity * t + Vector3.DOWN * Bomb.GRAVITY * t * t * 0.5
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var c := Vector2i(roundi(p.x / CELL_SIZE), roundi(p.z / CELL_SIZE)) + Vector2i(dx, dz)
				if c == cell:
					continue
				for box: AABB in bomb_boxes(c):
					if box.end.y > 0.01 and _point_box_distance(p, box) < Bomb.INRADIUS:
						return false
	return true


static func _point_box_distance(p: Vector3, box: AABB) -> float:
	return p.distance_to(p.clamp(box.position, box.end))


## El cañón de `cell` ha disparado: sale la bomba.
func _on_mortar_fired(muzzle: Vector3, velocity: Vector3, cell: Vector2i) -> void:
	var bomb := Bomb.create(self, muzzle, velocity)
	add_child(bomb)
	_bombs.append(bomb)
	bomb.touched_ground.connect(func() -> void: _bomb_sound(bomb, "bomb_fuse", 0.05))
	bomb.bounced.connect(func(speed: float) -> void:
		_bomb_sound(bomb, "bomb_bounce", 0.12, clampf((speed - 6.0) * 1.5, -14.0, 0.0)))
	var volume := _mortar_volume(Vector2(cell))
	if not is_nan(volume):
		Sfx.play("mortar", 0.08, volume)


## Volumen (dB) de un sonido de cañón o bomba según lo lejos que esté del
## cubo, o NAN si está demasiado lejos para oírse.
func _mortar_volume(at: Vector2) -> float:
	if cube == null:
		return NAN
	var distance := Vector2(cube.cell).distance_to(at)
	return -MORTAR_SOUND_FALLOFF * distance if distance <= MORTAR_SOUND_RADIUS else NAN


func _bomb_sound(bomb: Bomb, sound: String, jitter: float, extra_db := 0.0) -> void:
	if not is_instance_valid(bomb):
		return
	var volume := _mortar_volume(Vector2(bomb.position.x, bomb.position.z) / CELL_SIZE)
	if not is_nan(volume):
		Sfx.play(sound, jitter, volume + extra_db)


## Mueve las bombas, las hace chocar entre ellas y hace explotar las que
## han agotado la mecha.
func _update_bombs(delta: float) -> void:
	if _bombs.is_empty():
		_body_positions.clear()
		return
	var bodies := _bomb_bodies(delta)
	for bomb: Bomb in _bombs.duplicate():
		bomb.update(delta, bodies)
		if bomb.is_lost():
			_bombs.erase(bomb)
			bomb.queue_free()
		elif bomb.fuse_left <= 0.0:
			_explode_bomb(bomb)
	# Choques entre bombas: se separan y se pasan la velocidad que llevan la
	# una hacia la otra.
	for i in _bombs.size():
		for j in range(i + 1, _bombs.size()):
			var a := _bombs[i]
			var b := _bombs[j]
			var diff := b.position - a.position
			var dist := diff.length()
			if dist >= Bomb.INRADIUS * 2.0 or dist < 1e-5:
				continue
			var normal := diff / dist
			var push := (Bomb.INRADIUS * 2.0 - dist) * 0.5
			a.position -= normal * push
			b.position += normal * push
			var closing := (a.velocity - b.velocity).dot(normal)
			if closing > 0.0:
				var impulse := normal * closing * (1.0 + Bomb.BOUNCE) * 0.5
				a.velocity -= impulse
				b.velocity += impulse


## Cajas del cubo y de los enemigos para los choques de las bombas, con su
## velocidad: [{ "box": AABB, "velocity": Vector3 }].
func _bomb_bodies(delta: float) -> Array:
	var bodies := []
	var seen := {}
	if cube and cube.is_alive() and not cube.is_appearing() and not cube.is_teleporting():
		var anchor := to_local(cube.get_trail_anchor())
		_add_bomb_body(bodies, seen, "cube", Vector2(anchor.x, anchor.z), BOMB_CUBE_BOX, delta)
	for enemy in _enemies:
		if not enemy.is_appearing():
			_add_bomb_body(bodies, seen, enemy.get_instance_id(), enemy.board_position() * CELL_SIZE,
				BOMB_ENEMY_BOX, delta)
	_body_positions = seen
	return bodies


func _add_bomb_body(bodies: Array, seen: Dictionary, id: Variant, at: Vector2, size: Vector3,
		delta: float) -> void:
	var velocity := Vector3.ZERO
	if _body_positions.has(id) and delta > 0.0:
		var moved: Vector2 = (at - _body_positions[id]) / delta
		# Un salto grande (reaparecer, teletransporte) no es velocidad.
		if moved.length() < 12.0:
			velocity = Vector3(moved.x, 0.0, moved.y)
	seen[id] = at
	var box := AABB(Vector3(at.x - size.x * 0.5, 0.0, at.y - size.z * 0.5), size)
	bodies.append({"box": box, "velocity": velocity})


## La bomba explota: si el cubo está cerca, muere (con las inmunidades de
## siempre); las bombas de alrededor salen despedidas.
func _explode_bomb(bomb: Bomb) -> void:
	_bombs.erase(bomb)
	var at := bomb.position
	var flat := Vector2(at.x, at.z)
	var distance := INF
	if cube and cube.is_alive():
		var anchor := to_local(cube.get_trail_anchor())
		distance = Vector2(anchor.x, anchor.z).distance_to(flat) / CELL_SIZE
		var offset := Vector2i(roundi(anchor.x / CELL_SIZE), roundi(anchor.z / CELL_SIZE)) - bomb.board_cell()
		if maxi(absi(offset.x), absi(offset.y)) <= BOMB_BLAST_CELLS and at.y < WALL_HEIGHT + 0.8 \
				and not cube.is_above(0.6):
			cube.die()
	for other in _bombs:
		var offset := other.position - at
		var d := offset.length()
		if d < BOMB_PUSH_RADIUS:
			var away := Vector3(offset.x, 0.0, offset.z).normalized() if d > 0.01 else Vector3.ZERO
			other.velocity += away * (BOMB_PUSH_RADIUS - d) * 3.0 + Vector3.UP * (BOMB_PUSH_RADIUS - d) * 2.5
	bomb.explode()
	var volume := _mortar_volume(flat / CELL_SIZE)
	if not is_nan(volume):
		Sfx.play("bomb_explode", 0.08, volume * 0.6)
	bomb_exploded.emit(distance)


## Cajas (en el tablero) con las que chocan las bombas en `cell`: el suelo
## (hasta y = 0), los muros (hasta WALL_HEIGHT, con el cañón de bombas
## encima si lo hay), las puertas y los barrotes cerrados. En el vacío y
## fuera del mapa, ninguna.
func bomb_boxes(cell: Vector2i) -> Array[AABB]:
	var boxes: Array[AABB] = []
	if cell.y < 0 or cell.y >= layout.size() or cell.x < 0 or cell.x >= layout[cell.y].length() \
			or _void.has(cell):
		return boxes
	var corner := Vector3((cell.x - 0.5) * CELL_SIZE, -1.0, (cell.y - 0.5) * CELL_SIZE)
	var symbol := layout[cell.y][cell.x]
	if (_is_wall(cell) and not BREAKABLE_CHARS.contains(symbol)) or _breakables.has(cell):
		boxes.append(AABB(corner, Vector3(CELL_SIZE, 1.0 + WALL_HEIGHT, CELL_SIZE)))
		if _mortars.has(cell):
			var r := MortarCannon.BASE_RADIUS * 0.8
			boxes.append(AABB(Vector3(cell.x * CELL_SIZE - r, WALL_HEIGHT, cell.y * CELL_SIZE - r),
				Vector3(r * 2.0, MortarCannon.PIVOT_HEIGHT, r * 2.0)))
		return boxes
	boxes.append(AABB(corner, Vector3(CELL_SIZE, 1.0, CELL_SIZE)))
	var center := Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)
	if _doors.has(cell):
		var size: Vector3 = (_doors[cell]["node"].mesh as BoxMesh).size
		boxes.append(AABB(center - Vector3(size.x * 0.5, 0.0, size.z * 0.5), size))
	elif bars_closed(cell):
		var across_x: bool = is_zero_approx(_bars[cell]["node"].rotation.y)
		var size := Vector3(CELL_SIZE, 0.55, 0.16) if across_x else Vector3(0.16, 0.55, CELL_SIZE)
		boxes.append(AABB(center - Vector3(size.x * 0.5, 0.0, size.z * 0.5), size))
	return boxes


## Altura del suelo (o de la cara de arriba del muro) de la casilla para las
## bombas, o NAN si es vacío.
func bomb_floor_height(cell: Vector2i) -> float:
	var top := NAN
	for box in bomb_boxes(cell):
		if box.size.x >= CELL_SIZE * 0.99 and box.size.z >= CELL_SIZE * 0.99:
			top = box.end.y if is_nan(top) else maxf(top, box.end.y)
	return top


## Hay barrotes cerrados en la casilla.
func bars_closed(cell: Vector2i) -> bool:
	return _bars.has(cell) and not _bars[cell]["node"].is_open


## Hay un muro con botón en la casilla.
func is_button(cell: Vector2i) -> bool:
	return _buttons.has(cell)


## Botón cerca de la casilla (a BUTTON_APPROACH_CELLS casillas de recorrido o
## menos de la casilla de delante del botón), o NO_CELL si no hay ninguno. Si
## hay varios, el más cercano.
func button_near(cell: Vector2i) -> Vector2i:
	var best := NO_CELL
	var best_steps := BUTTON_APPROACH_CELLS + 1
	for button_cell in _buttons:
		var near: Dictionary = _buttons[button_cell]["near"]
		if near.has(cell) and near[cell] < best_steps:
			best = button_cell
			best_steps = near[cell]
	return best


## Casilla libre de delante del botón.
func button_front(button_cell: Vector2i) -> Vector2i:
	return _buttons[button_cell]["front"] if _buttons.has(button_cell) else NO_CELL


## Casillas de todos los barrotes que cambia el botón.
func button_bars(button_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not _buttons.has(button_cell):
		return cells
	var groups: String = button_links.get(_buttons[button_cell]["symbol"], "")
	for bar_cell in _bars:
		if groups.contains(_bars[bar_cell]["group"]):
			cells.append(bar_cell)
	return cells


## Pulsa el botón de la casilla: todos los barrotes de sus grupos cambian de
## estado al instante (los abiertos se cierran y los cerrados se abren).
func press_button(cell: Vector2i) -> void:
	if not _buttons.has(cell):
		return
	_buttons[cell]["node"].press()
	var groups: String = button_links.get(_buttons[cell]["symbol"], "")
	for item in _bars.values():
		if groups.contains(item["group"]):
			var bars: Bars = item["node"]
			bars.set_open(not bars.is_open)
	_topology_version += 1


## Golpes que le quedan al muro destructible de la casilla (0 si no hay).
func breakable_hits(cell: Vector2i) -> int:
	return _breakables[cell].hits if _breakables.has(cell) else 0


## Golpea de frente el muro destructible de la casilla en la dirección
## `heading`. Devuelve los golpes que le quedan; con 0 el muro se rompe y la
## casilla pasa a ser libre al instante, aunque los pedazos sigan cayendo.
func hit_breakable(cell: Vector2i, heading: Vector2i) -> int:
	if not _breakables.has(cell):
		return 0
	var left: int = _breakables[cell].hit(Vector3(heading.x, 0, heading.y))
	if left == 0:
		_breakables.erase(cell)
	return left


## Rompe de una vez el muro destructible de la casilla (dash del cubo).
func smash_breakable(cell: Vector2i, heading: Vector2i) -> void:
	while hit_breakable(cell, heading) > 0:
		pass


## Destruye a todos los enemigos que ocupan la casilla (de cualquier tipo).
## Devuelve cuántos.
func destroy_enemies_at(cell: Vector2i) -> int:
	var destroyed := 0
	for enemy in _enemies.duplicate():
		if enemy.occupies(cell):
			_destroy_enemy(enemy)
			destroyed += 1
	return destroyed


## Pisotón del cubo en `center`: destruye a los enemigos que ocupan alguna
## casilla a `radius` o menos (en cuadrado, diagonales incluidas, sin que lo
## frenen las paredes) y quita `wall_hits` golpes a los muros destructibles
## de esa zona.
func stomp(center: Vector2i, radius: int, wall_hits: int) -> void:
	for enemy in _enemies.duplicate():
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if is_instance_valid(enemy) and _enemies.has(enemy) \
						and enemy.occupies(center + Vector2i(dx, dy)):
					_destroy_enemy(enemy)
	var broke := false
	var cracked := false
	for cell: Vector2i in _breakables.keys():
		var offset := cell - center
		if maxi(absi(offset.x), absi(offset.y)) > radius:
			continue
		var away := Vector2i(signi(offset.x), signi(offset.y))
		var left := 1
		for i in wall_hits:
			left = hit_breakable(cell, away)
			if left == 0:
				break
		broke = broke or left == 0
		cracked = cracked or left > 0
	if broke:
		Sfx.play("break", 0.08)
		GameState.vibrate(GameState.VIBRATION_WALL_BROKEN)
	elif cracked:
		Sfx.play("crack", 0.08)


func _destroy_enemy(enemy: Enemy) -> void:
	_enemies.erase(enemy)
	_solid_dirty = true
	enemy.destroy()


## Color de la puerta cerrada de la casilla, o "" si no hay.
func door_color(cell: Vector2i) -> String:
	return _doors[cell]["color"] if _doors.has(cell) else ""


## Color de la llave que hay en la casilla, o "" si no hay.
func key_color(cell: Vector2i) -> String:
	return _keys[cell]["color"] if _keys.has(cell) else ""


## Quita la llave del mapa y devuelve su color.
## Posición y giro (globales) de la llave de esa casilla en el mapa.
func key_transform(cell: Vector2i) -> Transform3D:
	return _keys[cell]["node"].global_transform if _keys.has(cell) else Transform3D()


func take_key(cell: Vector2i) -> String:
	var color := key_color(cell)
	if color != "":
		_keys[cell]["node"].queue_free()
		_keys.erase(cell)
	return color


## Power up que hay en la casilla, o null si no hay.
func power_up_at(cell: Vector2i) -> PowerUp:
	return _power_ups[cell]["power_up"] if _power_ups.has(cell) else null


## Coge el cubito dorado si está en `cell` (animación de recogida).
func take_collectible(cell: Vector2i) -> bool:
	if _collectible == null or cell != collectible_cell:
		return false
	_collectible.collect()
	_collectible = null
	return true


func has_collectible() -> bool:
	return collectible_cell != NO_CELL


## Quita el power up del mapa y lo devuelve (null si no había).
func take_power_up(cell: Vector2i) -> PowerUp:
	var power_up := power_up_at(cell)
	if power_up:
		_power_ups[cell]["node"].queue_free()
		_power_ups.erase(cell)
	return power_up


## Abre la puerta: la casilla pasa a ser libre al instante y la puerta se
## hunde en el suelo hasta desaparecer.
## Abre la puerta (deja de ser obstáculo al momento). Si se pasa la llave
## (`key`, el nodo que lleva el cubo), primero vuela desde donde está hasta
## la puerta encogiéndose hasta desaparecer, y entonces la puerta se hunde.
func open_door(cell: Vector2i, key: Node3D = null) -> void:
	if not _doors.has(cell):
		return
	var door: Node3D = _doors[cell]["node"]
	_doors.erase(cell)
	var tween := door.create_tween()
	if key:
		# La llave pasa a ser del tablero: si se reinicia el nivel, se va con él.
		var from := key.global_transform
		key.reparent(self)
		key.top_level = false
		key.global_transform = from
		var fly := key.create_tween().set_parallel()
		fly.tween_property(key, "position", door.position, KEY_TO_DOOR_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		fly.tween_property(key, "scale", Vector3.ONE * 0.01, KEY_TO_DOOR_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fly.tween_property(key, "rotation:y", key.rotation.y + TAU, KEY_TO_DOOR_TIME)
		fly.chain().tween_callback(key.queue_free)
		tween.tween_interval(KEY_TO_DOOR_TIME)
	tween.tween_property(door, "position:y", door.position.y - DOOR_HEIGHT - FLOOR_THICKNESS,
			DOOR_SINK_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(door.queue_free)


func cell_to_world(cell: Vector2i) -> Vector3:
	return global_transform * Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)


func get_center() -> Vector3:
	var size := get_grid_size()
	return global_transform * Vector3((size.x - 1) * CELL_SIZE * 0.5, 0.0, (size.y - 1) * CELL_SIZE * 0.5)


func get_grid_size() -> Vector2i:
	var width := 0
	for row in layout:
		width = maxi(width, row.length())
	return Vector2i(width, layout.size())


# --- Aparición del tablero -----------------------------------------------------

## Oculta el tablero y lo hace aparecer casilla a casilla en diagonal, desde
## arriba a la izquierda (ver REVEAL_TIME).
## Los enemigos se quedan quietos hasta set_enemies_frozen(false).
func start_reveal() -> void:
	_reveal_time = 0.0
	_reveal_delays.clear()
	var max_delay := REVEAL_TIME - REVEAL_FADE_TIME
	var grid := get_grid_size()
	# Cada diagonal (x + z constante) empieza algo después de la anterior.
	var diagonals := maxf(1.0, grid.x + grid.y - 2)
	for z in layout.size():
		for x in layout[z].length():
			_reveal_delays[Vector2i(x, z)] = (x + z) / diagonals * max_delay
	# Los materiales del fundido escriben profundidad: si no, el suelo y las
	# paredes (un solo objeto transparente cada uno) taparían lo que tienen
	# encima según el orden en que se dibujen.
	for entry in _reveal_multimeshes:
		for mat: BaseMaterial3D in entry["materials"]:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	_reveal_nodes.clear()
	for child in get_children():
		var node := child as Node3D
		if node == null or node is MultiMeshInstance3D or node == _terrain or node.is_queued_for_deletion():
			continue
		var cell := Vector2i(roundi(node.position.x / CELL_SIZE), roundi(node.position.z / CELL_SIZE))
		_reveal_nodes.append({"delay": _reveal_delays.get(cell, 0.0),
			"materials": _fade_materials(node), "node": node})
	set_enemies_frozen(true)
	_revealing = true
	# Todo empieza transparente.
	_apply_reveal()


func is_revealing() -> bool:
	return _revealing


## Detiene o reanuda a los enemigos (durante la aparición del nivel y del
## cubo). Los que están apareciendo terminan su aparición, pero no se mueven.
func set_enemies_frozen(frozen: bool) -> void:
	_enemies_frozen = frozen


func are_enemies_frozen() -> bool:
	return _enemies_frozen


func _update_reveal(delta: float) -> void:
	_reveal_time += delta
	_apply_reveal()
	if _reveal_time >= REVEAL_TIME:
		_finish_reveal()
		reveal_finished.emit()


## Deja todo opaco, con los materiales del juego normales, y cambia los
## MultiMesh del terreno por el terreno fusionado (mucho más ligero de pintar).
func _finish_reveal() -> void:
	_revealing = false
	for entry in _reveal_multimeshes:
		(entry["instance"] as Node).queue_free()
	_reveal_multimeshes.clear()
	if _terrain:
		_terrain.visible = true
	for entry in _reveal_nodes:
		if is_instance_valid(entry["node"]) and entry["node"].has_method("set_reveal_alpha"):
			entry["node"].set_reveal_alpha(1.0)
		for item: Dictionary in entry["materials"]:
			var mesh_instance: MeshInstance3D = item["node"]
			if not is_instance_valid(mesh_instance):
				continue
			if item["surface"] < 0:
				mesh_instance.material_override = item["original"]
			else:
				mesh_instance.set_surface_override_material(item["surface"], item["original"])
	_reveal_nodes.clear()


## Opacidad de cada casilla según su progreso: de transparente a opaca.
func _apply_reveal() -> void:
	for entry in _reveal_multimeshes:
		var multimesh: MultiMesh = entry["multimesh"]
		var cells: Array = entry["cells"]
		for i in cells.size():
			var k := _reveal_progress(_reveal_delays.get(cells[i], 0.0))
			if k >= 0.0:
				multimesh.set_instance_color(i, Color(1, 1, 1, k))
	for entry in _reveal_nodes:
		var k := _reveal_progress(entry["delay"])
		if k < 0.0:
			continue
		for item: Dictionary in entry["materials"]:
			var mat: BaseMaterial3D = item["material"]
			mat.albedo_color.a = item["alpha"] * k
		if is_instance_valid(entry["node"]) and entry["node"].has_method("set_reveal_alpha"):
			entry["node"].set_reveal_alpha(k)


## Pone a las mallas de `node` (y sus descendientes) copias transparentes
## de sus materiales para el fundido. Devuelve lo necesario para animarlas
## y restaurarlas: { "node", "surface" (-1 = material_override), "original",
## "material", "alpha" }.
func _fade_materials(node: Node3D) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var found: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		found.append(node)
	for mesh_instance: MeshInstance3D in found:
		if mesh_instance.material_override:
			var fade := _fade_copy(mesh_instance.material_override)
			if fade:
				items.append({"node": mesh_instance, "surface": -1,
					"original": mesh_instance.material_override, "material": fade,
					"alpha": fade.albedo_color.a})
				mesh_instance.material_override = fade
			continue
		if mesh_instance.mesh == null:
			continue
		for i in mesh_instance.mesh.get_surface_count():
			var fade := _fade_copy(mesh_instance.get_active_material(i))
			if fade == null:
				continue
			items.append({"node": mesh_instance, "surface": i,
				"original": mesh_instance.get_surface_override_material(i), "material": fade,
				"alpha": fade.albedo_color.a})
			mesh_instance.set_surface_override_material(i, fade)
	return items


static func _fade_copy(material: Material) -> BaseMaterial3D:
	var base := material as BaseMaterial3D
	if base == null:
		return null
	var fade := base.duplicate() as BaseMaterial3D
	if fade.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
		fade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fade.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	return fade


## Opacidad (0-1, suavizada) de una casilla con ese retraso; -1 si ya ha
## terminado y no hay que tocarla (para no repintar miles de casillas en
## cada fotograma).
func _reveal_progress(delay: float) -> float:
	if _reveal_time - delay > REVEAL_FADE_TIME + 0.1:
		return -1.0
	return smoothstep(0.0, 1.0, (_reveal_time - delay) / REVEAL_FADE_TIME)


## Un mismo bloque del catálogo (BlockCatalog) repetido en varias casillas,
## en un solo MultiMesh (para la aparición del tablero) y, además, en el
## terreno fusionado de la partida (TerrainBuilder, ver _add_terrain_box).
## La cara de arriba de cada casilla va girada al azar (siempre igual en la
## misma casilla) para que no se note la repetición.
func _add_multimesh(cells: Array, block: String, size: Vector3, y: float, tint: Color,
		kind: int) -> void:
	if cells.is_empty():
		return
	var mesh := BlockCatalog.make_mesh(block, size, tint)
	var materials: Array[BaseMaterial3D] = []
	for i in mesh.get_surface_count():
		materials.append(mesh.surface_get_material(i))
	var spin := BlockCatalog.spin(block)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	# El color de cada instancia (blanco) lleva su opacidad en la aparición.
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = cells.size()
	for i in cells.size():
		var cell: Vector2i = cells[i]
		var turns := 0
		if spin > 1:
			turns = (_cell_hash(cell) % spin) * (4 / spin)
		multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, turns * PI * 0.5),
			Vector3(cell.x * CELL_SIZE, y, cell.y * CELL_SIZE)))
		multimesh.set_instance_color(i, Color.WHITE)
		_add_terrain_box(cell, block, size, y, tint, kind, turns)
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	if kind != TERRAIN_WALL:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	_reveal_multimeshes.append({"multimesh": multimesh, "materials": materials,
		"cells": cells.duplicate(), "instance": instance})


## Añade una caja al terreno fusionado solo con las caras que se pueden ver:
## - Muros: arriba y los lados que no dan a otro muro.
## - Baldosas: arriba y los lados que no dan a un muro (asoman por las juntas).
## - Roca de debajo (niveles con vacío): arriba solo bajo las baldosas (se ve
##   por las juntas) y los lados que dan al vacío.
## Ni el suelo ni la roca dan sombra: caería donde no se ve.
func _add_terrain_box(cell: Vector2i, block: String, size: Vector3, y: float, tint: Color,
		kind: int, turns: int) -> void:
	var sides: Array[bool] = []
	for i in TerrainBuilder.SIDES.size():
		var other := TerrainBuilder.side_neighbor(cell, i)
		if kind == TERRAIN_FOUNDATION:
			sides.append(is_void(other) or bridge_cell(other))
		else:
			sides.append(not _wall_set.has(other))
	var top := kind != TERRAIN_FOUNDATION or not _wall_set.has(cell)
	_terrain_builder.add_box(cell, Vector3(cell.x * CELL_SIZE, y, cell.y * CELL_SIZE), size,
		block, tint, top, sides, turns, kind == TERRAIN_WALL)


static func _cell_hash(cell: Vector2i) -> int:
	return absi((cell.x * 73856093) ^ (cell.y * 19349663)) >> 3


static func _group(groups: Dictionary, key: String, cell: Vector2i) -> void:
	if not groups.has(key):
		groups[key] = []
	groups[key].append(cell)


## Bloque del catálogo de una casilla para `part` ("floor", "wall" o
## "foundation"): el de la última zona de block_regions que la contiene, si
## no el del nivel y si no el de DEFAULT_THEME. La roca, si no se indica, es
## la que va bajo el bloque del suelo.
func _block_at(cell: Vector2i, part: String) -> String:
	var found := ""
	for i in range(block_regions.size() - 1, -1, -1):
		var region: Dictionary = block_regions[i]
		if region.has(part) and (region["rect"] as Rect2i).has_point(cell):
			found = region[part]
			break
	if found == "":
		found = block_theme.get(part, "")
	if found == "":
		if part == "foundation":
			return BlockCatalog.under(_block_at(cell, "floor"))
		found = DEFAULT_THEME[part]
	if not BlockCatalog.has(found):
		push_error("Bloque desconocido '%s' en el tema del nivel" % found)
		return DEFAULT_THEME.get(part, "stone")
	return found


## Bloques de roca bajo el suelo y las paredes (niveles con vacío): el
## tablero parece una isla flotando sobre el abismo. Las casillas que dan al
## vacío llevan un bloque algo más claro para que se vea el borde.
func _add_foundations(wall_cells: Array[Vector2i]) -> void:
	## "bloque" -> casillas, por separado las que dan al vacío.
	var inner := {}
	var edge := {}
	var cells: Array[Vector2i] = []
	cells.append_array(wall_cells)
	cells.append_array(_walkable.keys())
	for cell in cells:
		if bridge_cell(cell):
			continue
		var at_edge := false
		for dir: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			if is_void(cell + dir):
				at_edge = true
				break
		_group(edge if at_edge else inner, _block_at(cell, "foundation"), cell)
	var size := Vector3(CELL_SIZE, FOUNDATION_DEPTH, CELL_SIZE)
	var y := -FLOOR_THICKNESS - FOUNDATION_DEPTH * 0.5
	for id: String in inner:
		_add_multimesh(inner[id], id, size, y, FOUNDATION_INNER_TINT, TERRAIN_FOUNDATION)
	for id: String in edge:
		_add_multimesh(edge[id], id, size, y, Color.WHITE, TERRAIN_FOUNDATION)


## La casilla es '=' en el mapa (aunque el puente ya se haya caído).
func bridge_cell(cell: Vector2i) -> bool:
	return cell.y >= 0 and cell.y < layout.size() and cell.x >= 0 and cell.x < layout[cell.y].length() \
		and layout[cell.y][cell.x] == BRIDGE_CHAR


## Agrupa las casillas '=' en puentes rectos (horizontales o verticales).
func _add_bridges(bridge_cells: Dictionary) -> void:
	var pending := bridge_cells.duplicate()
	for z in layout.size():
		for x in layout[z].length():
			var first := Vector2i(x, z)
			if not pending.has(first):
				continue
			var along := Vector2i.RIGHT
			if not bridge_cells.has(first + Vector2i.RIGHT) and bridge_cells.has(first + Vector2i.DOWN):
				along = Vector2i.DOWN
			elif not bridge_cells.has(first + Vector2i.RIGHT):
				# Puente de una casilla: va de un suelo al otro.
				if has_floor(first + Vector2i.UP) and has_floor(first + Vector2i.DOWN):
					along = Vector2i.DOWN
			var run: Array[Vector2i] = []
			var c := first
			while pending.has(c):
				run.append(c)
				pending.erase(c)
				c += along
			var bridge := HangingBridge.new()
			bridge.name = "Bridge%d" % get_child_count()
			bridge.setup(run, along, CELL_SIZE)
			add_child(bridge)
			for cell in run:
				_bridges[cell] = bridge


## Luz que sale del suelo de la casilla (salida y meta).
## Empareja las casillas de teletransporte de cada símbolo y les pone su
## aspecto. Avisa si un símbolo no tiene exactamente dos casillas o si una
## casilla no tiene un muro o el borde al lado.
func _add_teleports(teleport_cells: Dictionary) -> void:
	for symbol: String in teleport_cells:
		var cells: Array = teleport_cells[symbol]
		if cells.size() != 2:
			push_warning("El teletransporte '%s' tiene %d casillas (deben ser 2)" % [symbol, cells.size()])
			continue
		for i in 2:
			var cell: Vector2i = cells[i]
			var by_edge := false
			for dir: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
				by_edge = by_edge or _is_wall(cell + dir) or is_void(cell + dir)
			if not by_edge:
				push_warning("La casilla de teletransporte %s no tiene muro ni borde al lado" % cell)
			var pad := TeleportPad.create(TELEPORT_COLORS[symbol])
			pad.position = Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)
			add_child(pad)
			_teleports[cell] = {"partner": cells[1 - i], "symbol": symbol, "node": pad}


func _add_glow(cell: Vector2i, glow_color: Color, power := 1.0) -> void:
	var glow := TileGlow.create(glow_color, power)
	glow.position = Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)
	add_child(glow)


func _add_box(cell: Vector2i, size: Vector3, y: float, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = Vector3(cell.x * CELL_SIZE, y, cell.y * CELL_SIZE)
	add_child(instance)
	return instance


func _add_key(cell: Vector2i, color: String) -> void:
	var key := KeyVisual.create(ITEM_COLORS[color])
	key.scale = Vector3.ONE * KEY_SCALE
	key.position = Vector3(cell.x * CELL_SIZE, KEY_FLOAT_HEIGHT, cell.y * CELL_SIZE)
	add_child(key)
	_keys[cell] = {"color": color, "node": key}


func _add_power_up(cell: Vector2i, symbol: String) -> void:
	var power_up := PowerUpCatalog.create(symbol)
	var node := power_up.create_pickup_visual()
	node.position = Vector3(cell.x * CELL_SIZE, POWER_UP_FLOAT_HEIGHT, cell.y * CELL_SIZE)
	add_child(node)
	_power_ups[cell] = {"power_up": power_up, "node": node}


## Los barrotes se orientan como las puertas: las lanzas van de muro a muro
## y, al abrirse, se esconden dentro de ellos.
func _add_bars(cell: Vector2i, symbol: String) -> void:
	var bars := Bars.new(symbol == symbol.to_lower())
	bars.position = Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)
	if not (_is_wall(cell + Vector2i.LEFT) and _is_wall(cell + Vector2i.RIGHT)):
		bars.rotation.y = PI * 0.5
	add_child(bars)
	_bars[cell] = {"group": symbol.to_lower(), "node": bars}


## El botón se pega a la cara del muro que da a la casilla libre de al lado
## (nunca a una de vacío: su cara exterior no se puede pulsar).
func _add_button(cell: Vector2i, symbol: String) -> void:
	var facing := Vector2i.ZERO
	for dir: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var n := cell + dir
		if n.y >= 0 and n.y < layout.size() and n.x >= 0 and n.x < layout[n.y].length() \
				and not "#~".contains(layout[n.y][n.x]) and not BUTTON_CHARS.contains(layout[n.y][n.x]) \
				and layout[n.y][n.x] != LASER_CHAR and layout[n.y][n.x] != MORTAR_CHAR:
			facing = dir
			break
	if facing == Vector2i.ZERO:
		push_warning("Botón '%s' en %s sin casilla libre al lado" % [symbol, cell])
		return
	var button := WallButton.new()
	button.position = Vector3((cell.x + facing.x * 0.5) * CELL_SIZE, 0.0, (cell.y + facing.y * 0.5) * CELL_SIZE)
	button.rotation.y = atan2(facing.x, facing.y)
	add_child(button)
	_buttons[cell] = {"symbol": symbol, "node": button, "front": cell + facing, "near": {}}


## Casillas libres a `max_steps` pasos o menos de `origin` (contando origin
## como 1), sin tener en cuenta puertas, barrotes ni muros destructibles.
func _cells_within(origin: Vector2i, max_steps: int) -> Dictionary:
	var steps := {origin: 1}
	var queue: Array[Vector2i] = [origin]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if steps[current] >= max_steps:
			continue
		for dir: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var n := current + dir
			if _walkable.has(n) and not steps.has(n):
				steps[n] = steps[current] + 1
				queue.append(n)
	return steps


## Punto de origen de enemigos del tipo `symbol` en `cell` (ver la leyenda
## del principio y EnemySpawner).
func _add_spawner(cell: Vector2i, symbol: String) -> void:
	var settings: Dictionary = spawner_settings.get(symbol, {}).duplicate()
	settings.merge(spawner_settings.get(cell, {}), true)
	var route := ""
	if PATROL_CHARS.contains(symbol):
		route = patrol_routes.get(symbol, "")
		var check := Patroller.new()
		var problem := check.set_route(cell, route)
		for route_cell in check.route:
			if problem == "" and not _walkable.has(route_cell):
				problem = "pasa por la casilla %s, que no es libre" % route_cell
		check.free()
		if problem != "":
			push_warning("Ruta del patrullero '%s': %s" % [symbol, problem])
			route = ""
	var radius: int = settings.get("radius", EnemySpawner.auto_radius(self, cell))
	_spawners.append(EnemySpawner.new(self, symbol, cell, settings.get("count", 1),
		clampi(radius, 1, 99), route))


## Crea un enemigo del punto de origen `spawner` en `cell` y empieza su
## aparición.
func spawn_enemy(spawner: EnemySpawner, cell: Vector2i) -> Enemy:
	var enemy: Enemy
	if spawner.symbol == CHASER_CHAR:
		enemy = Chaser.new()
	elif spawner.symbol == BLOCKER_CHAR:
		enemy = Blocker.new()
	else:
		var patroller := Patroller.new()
		patroller.set_route(cell, spawner.route)
		enemy = patroller
	enemy.spawner = spawner
	add_child(enemy)
	enemy.setup(self, cell)
	enemy.cube = cube
	enemy.start_appearing()
	_enemies.append(enemy)
	_solid_dirty = true
	return enemy


func _add_breakable(cell: Vector2i, hits: int) -> void:
	var wall := BreakableWall.new(hits)
	wall.position = Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)
	add_child(wall)
	_breakables[cell] = wall


## La puerta se orienta según los muros que la rodean: si los muros están a
## izquierda y derecha, el pasillo va de arriba abajo y la puerta lo cruza en X.
func _add_door(cell: Vector2i, color: String) -> void:
	var across_x := _is_wall(cell + Vector2i.LEFT) and _is_wall(cell + Vector2i.RIGHT)
	var size := Vector3(CELL_SIZE * 0.98, DOOR_HEIGHT, DOOR_THICKNESS) if across_x \
		else Vector3(DOOR_THICKNESS, DOOR_HEIGHT, CELL_SIZE * 0.98)
	var mat := _make_material(ITEM_COLORS[color])
	mat.roughness = 0.5
	var door := _add_box(cell, size, DOOR_HEIGHT * 0.5, mat)
	_doors[cell] = {"color": color, "node": door}


func _is_wall(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= layout.size() or cell.x < 0 or cell.x >= layout[cell.y].length():
		return true
	var symbol := layout[cell.y][cell.x]
	return symbol == "#" or BREAKABLE_CHARS.contains(symbol) or BUTTON_CHARS.contains(symbol) \
		or symbol == LASER_CHAR or symbol == MORTAR_CHAR


func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat
