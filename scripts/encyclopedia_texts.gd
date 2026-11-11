class_name EncyclopediaTexts
extends RefCounted
## Textos de la enciclopedia en cada idioma (ver EncyclopediaData). Se
## registran junto con los de Translations.
##
## Por cada página: ENC_<ID>_NAME (nombre), ENC_<ID>_DESC (descripción) y
## ENC_<ID>_FACTS (curiosidades, una por línea).

const MESSAGES := {
	"es": {
		"MENU_ENCYCLOPEDIA": "Enciclopedia",
		"ENC_TITLE": "Enciclopedia",
		"ENC_TAB_ENEMIES": "Enemigos",
		"ENC_TAB_ABILITIES": "Habilidades",
		"ENC_TAB_ITEMS": "Objetos",
		"ENC_TAB_OBSTACLES": "Obstáculos",
		"ENC_FACTS": "Curiosidades",
		"ENC_FIRST_LEVEL": "Aparece por primera vez en el nivel %d",
		"ENC_FROM_START": "Desde el primer nivel",
		"ENC_PAGE": "%d / %d",

		"ENC_CHASER_NAME": "Perseguidor",
		"ENC_CHASER_DESC": "Una esfera roja con ojos que deambula por los pasillos sin saber dónde estás. Si te acercas a 4 casillas de recorrido o menos, se queda temblando medio segundo y sale a por ti por el camino más corto, algo más deprisa. Si lo tocas, el cubo explota.",
		"ENC_CHASER_FACTS": "No ve a través de las paredes: cuenta las casillas que tendría que recorrer, no la distancia en línea recta.\nSi te alejas más de 8 casillas, te pierde la pista y vuelve a pasear.\nCuando el cubo muere, se olvida de él durante 3 segundos: así no se queda esperando en la salida.\nAl destruirlo revienta en gotas blandas que se aplastan contra el suelo.",

		"ENC_PATROLLER_NAME": "Patrullero",
		"ENC_PATROLLER_DESC": "Un octaedro morado que flota y recorre siempre la misma ruta: en círculo o de ida y vuelta. No te persigue, pero si te cruzas en su camino, el cubo explota.",
		"ENC_PATROLLER_FACTS": "Nunca se sale de su ruta: si algo le corta el paso, espera a que se libere.\nToda ruta tiene al menos tres salidas, una de ellas lateral, para que siempre puedas esquivarlo.\nSu ritmo es constante: mira cómo se mueve y pasa cuando no esté.",

		"ENC_BLOCKER_NAME": "Obstáculo",
		"ENC_BLOCKER_DESC": "Un dodecaedro verde azulado que no hace daño, pero intenta cortarte el paso. Calcula tu camino más corto hasta la meta y se planta en él. Es sólido como un muro: el cubo rebota contra él.",
		"ENC_BLOCKER_FACTS": "Tiene poca paciencia: nunca bloquea la misma casilla más de 8 segundos seguidos; luego se va a dar una vuelta.\nEs más lento que el cubo, así que puedes dejarlo atrás.\nLos barrotes lo detienen: úsalos para encerrarlo o dejarlo fuera.\nLos demás enemigos tampoco pueden atravesarlo.",

		"ENC_TURN_NAME": "Girar",
		"ENC_TURN_DESC": "El cubo avanza solo, volcando de casilla en casilla. Toca la mitad izquierda o derecha de la pantalla para que gire hacia ese lado al llegar a la siguiente casilla.",
		"ENC_TURN_FACTS": "Puedes pulsar con antelación: el giro espera al siguiente límite entre casillas.\nSi pides un giro hacia una pared, se descarta y el cubo sigue recto.\nEn la casilla de salida no se puede girar.\nCada giro cuenta para la estrella de giros; los rebotes contra las paredes, no.",

		"ENC_REVERSE_NAME": "Media vuelta",
		"ENC_REVERSE_DESC": "Toca los dos lados de la pantalla a la vez y el cubo invertirá su rumbo en la siguiente casilla, como si chocara contra una pared, soltando una nube de humo.",
		"ENC_REVERSE_FACTS": "Cuenta como dos giros para la estrella de giros.\nNo gasta fuerza: puedes usarla siempre que quieras.\nComo un choque contra una pared, hace perder el power up de velocidad.",

		"ENC_DASH_NAME": "Dash",
		"ENC_DASH_DESC": "Desliza el dedo hacia arriba y el cubo se lanzará arrastrándose a la casilla de delante en un instante. Destruye al enemigo que esté allí y rompe de una vez un muro agrietado.",
		"ENC_DASH_FACTS": "Gasta toda la fuerza, que tarda 2 segundos en volver a llenarse.\nDurante el dash el cubo es invulnerable.\nContra una pared, una puerta o unos barrotes no hace nada especial: el cubo rebota.\nSi delante hay vacío, el cubo se cae igual.",

		"ENC_STOMP_NAME": "Pisotón",
		"ENC_STOMP_DESC": "Desliza el dedo hacia abajo y el cubo saltará para caer con fuerza en su casilla. La onda destruye a los enemigos que estén a 2 casillas o menos, diagonales incluidas.",
		"ENC_STOMP_FACTS": "Las paredes no frenan la onda: alcanza una zona de 5 × 5 casillas.\nQuita dos golpes a los muros agrietados de la zona.\nGasta toda la fuerza, igual que el dash, y el cubo es invulnerable mientras salta.",
		"ENC_IMMUNITY_NAME": "Inmunidad",
		"ENC_IMMUNITY_DESC": "Desliza el dedo hacia un lado, a la izquierda o a la derecha, y el cubo se cargará de electricidad durante 3 segundos: ningún enemigo ni arma puede destruirlo. Se activa al momento, sin esperar a la siguiente casilla.",
		"ENC_IMMUNITY_FACTS": "Gasta toda la fuerza, y la fuerza no empieza a recargarse hasta que se acaba.\nMientras dura, el cubo se ve medio disuelto y zumba, y la barra de fuerza se vuelve azul y se vacía con el tiempo que queda.\nProtege de enemigos, pinchos, láseres y bombas, pero no de caer al vacío.\nSi el cubo cae o llega a la meta, se pierde.",

		"ENC_GOLDEN_CUBE_NAME": "Cubito dorado",
		"ENC_GOLDEN_CUBE_DESC": "Cada nivel esconde un cubito dorado que flota, gira y brilla. Cógelo antes de llegar a la meta para ganar una de las tres estrellas del nivel.",
		"ENC_GOLDEN_CUBE_FACTS": "Suele estar en un recoveco apartado del camino más corto.\nIr a por él cuesta unos giros más, pero el límite de la estrella de giros ya cuenta con ello.\nSi reinicias el nivel, vuelve a su sitio.",

		"ENC_KEY_NAME": "Llave",
		"ENC_KEY_DESC": "Al pasar por encima, el cubo coge la llave y la lleva flotando sobre él. Sirve para abrir la puerta de su mismo color.",
		"ENC_KEY_FACTS": "El cubo solo puede llevar una llave: si ya lleva otra, las demás se quedan en el mapa.\nHay cinco colores: amarillo, naranja, rojo, azul y verde.\nSi el cubo muere, conserva la llave que llevaba.",

		"ENC_SPEED_NAME": "Velocidad",
		"ENC_SPEED_DESC": "Un cubito azul translúcido. Cada uno que coges suma un 25 % a la velocidad del cubo, hasta el doble de rápido, y mientras dura deja un rastro de polvo.",
		"ENC_SPEED_FACTS": "No tiene límite de tiempo: chocar contra una pared, el borde del tablero o una puerta no lo quita.\nSolo se pierde al dar media vuelta, y al morir, por supuesto.",

		"ENC_DOOR_NAME": "Puerta",
		"ENC_DOOR_DESC": "Un bloque de color que corta el paso como una pared. Para abrirla, choca de frente contra ella llevando la llave de su mismo color: la puerta y la llave desaparecen.",
		"ENC_DOOR_FACTS": "Los enemigos tampoco pueden atravesar una puerta cerrada.\nLos giros hacia una puerta cerrada se descartan, como hacia una pared.",

		"ENC_BREAKABLE_NAME": "Muro agrietado",
		"ENC_BREAKABLE_DESC": "Un bloque de piedra que se rompe tras varios golpes. Cada choque de frente le quita uno; cuando se rompe, la casilla queda libre.",
		"ENC_BREAKABLE_FACTS": "Aguanta de 1 a 5 golpes: cuantas más grietas tiene, menos le quedan.\nEl dash lo rompe de una vez y el pisotón le quita dos golpes.\nEl golpe que lo rompe también hace rebotar al cubo.",

		"ENC_BARS_NAME": "Barrotes y botones",
		"ENC_BARS_DESC": "Cinco lanzas de metal que cierran un pasillo de muro a muro. Se abren y se cierran al pulsar su botón rojo, chocando contra él de frente.",
		"ENC_BARS_FACTS": "Un botón puede abrir unos barrotes y cerrar otros a la vez.\nLos barrotes cerrados también detienen a los enemigos: sirven para encerrarlos.\nLas lanzas se esconden dentro de los muros al abrirse.",

		"ENC_VOID_NAME": "Vacío",
		"ENC_VOID_DESC": "Donde no hay suelo ni pared está el vacío. El cubo no rebota en el borde: si entra en una casilla de vacío, vuelca, cae girando y explota en el aire.",
		"ENC_VOID_FACTS": "Te caes aunque seas invulnerable.\nLos giros hacia el vacío se aceptan: ¡cuidado con dónde giras!\nLos enemigos nunca se acercan al borde, y las bombas que caen al vacío se pierden.",

		"ENC_BRIDGE_NAME": "Puente colgante",
		"ENC_BRIDGE_DESC": "Una fila de tablas sobre el vacío. Cada tabla se gasta un poco cada vez que el cubo pasa por ella; cuando una cede, se cae el puente entero.",
		"ENC_BRIDGE_FACTS": "Cada tabla aguanta cuatro pasadas.\nCuanto más gastada está, más polvo suelta, y en la última se balancea.\nLos enemigos nunca pisan los puentes, así que no los desgastan.",

		"ENC_TELEPORT_NAME": "Teletransporte",
		"ENC_TELEPORT_DESC": "Un remolino de luz sobre el suelo. Las casillas del mismo color están conectadas: el cubo entra por una y sale por la otra con el mismo rumbo.",
		"ENC_TELEPORT_FACTS": "Los enemigos no pueden usarlos: son una buena forma de escapar.\nDurante el viaje el cubo es invulnerable.\nSalir rodando de la casilla de destino no te devuelve; volver a entrar en ella, sí.",

		"ENC_SPIKES_NAME": "Pinchos",
		"ENC_SPIKES_DESC": "Una placa de metal con cuatro agujeros. Cada pocos segundos salen de golpe cuatro lanzas, se quedan fuera un segundo y vuelven a esconderse. Solo son peligrosas mientras están fuera.",
		"ENC_SPIKES_FACTS": "Salen cada 3 a 8 segundos, al azar.\nJusto antes de salir, la placa tiembla: es el momento de girar o dar media vuelta.\nLos enemigos nunca pisan los pinchos.",

		"ENC_LASER_NAME": "Cañón láser",
		"ENC_LASER_DESC": "Un cañón incrustado en un muro, con un aro de luces rojas. Cada pocos segundos dispara un láser que avanza en línea recta hasta chocar con algo. Si te alcanza, el cubo explota.",
		"ENC_LASER_FACTS": "Antes de disparar, sus luces parpadean y pitan cuatro veces.\nEl láser va el doble de rápido que el cubo.\nLo paran los muros, las puertas, los barrotes cerrados y los enemigos (a ellos no les hace daño).\nPasa por encima del vacío.",

		"ENC_MORTAR_NAME": "Cañón de bombas",
		"ENC_MORTAR_DESC": "Un mortero encima de un muro. Cuando estás a su alcance, te lanza bombas que caen en tu camino. Las casillas a las que llega la explosión se tiñen de rojo: sal de ellas antes de que estalle.",
		"ENC_MORTAR_FACTS": "Gira hacia ti en cualquier dirección y dispara si estás a 10 casillas o menos.\nLa bomba explota de 2 a 3 segundos después de tocar el suelo, y alcanza 2 casillas a la redonda.\nLas bombas son muy pesadas: rebotan poco y el cubo puede empujarlas.\nA los enemigos no les hacen nada.",
	},
	"en": {
		"MENU_ENCYCLOPEDIA": "Encyclopedia",
		"ENC_TITLE": "Encyclopedia",
		"ENC_TAB_ENEMIES": "Enemies",
		"ENC_TAB_ABILITIES": "Abilities",
		"ENC_TAB_ITEMS": "Items",
		"ENC_TAB_OBSTACLES": "Obstacles",
		"ENC_FACTS": "Did you know?",
		"ENC_FIRST_LEVEL": "First appears in level %d",
		"ENC_FROM_START": "From the first level",
		"ENC_PAGE": "%d / %d",

		"ENC_CHASER_NAME": "Chaser",
		"ENC_CHASER_DESC": "A red sphere with eyes that wanders the corridors without knowing where you are. If you get within 4 tiles of walking distance, it trembles for half a second and then comes after you along the shortest path, a little faster. If it touches you, the cube explodes.",
		"ENC_CHASER_FACTS": "It can't see through walls: it counts the tiles it would have to walk, not the straight-line distance.\nIf you get more than 8 tiles away, it loses track of you and goes back to wandering.\nWhen the cube dies, it forgets about it for 3 seconds, so it doesn't camp at the start.\nWhen destroyed, it bursts into soft drops that splat on the floor.",

		"ENC_PATROLLER_NAME": "Patroller",
		"ENC_PATROLLER_DESC": "A floating purple octahedron that always follows the same route, in a loop or back and forth. It won't chase you, but if you cross its path, the cube explodes.",
		"ENC_PATROLLER_FACTS": "It never leaves its route: if something blocks the way, it waits until it's clear.\nEvery route has at least three exits, one of them to the side, so you can always dodge it.\nIts rhythm never changes: watch how it moves and pass when it's away.",

		"ENC_BLOCKER_NAME": "Blocker",
		"ENC_BLOCKER_DESC": "A teal dodecahedron that does no harm but tries to cut you off. It works out your shortest path to the goal and plants itself on it. It's as solid as a wall: the cube bounces off it.",
		"ENC_BLOCKER_FACTS": "It has little patience: it never blocks the same tile for more than 8 seconds in a row, then wanders off.\nIt's slower than the cube, so you can leave it behind.\nBars stop it: use them to lock it in or keep it out.\nOther enemies can't pass through it either.",

		"ENC_TURN_NAME": "Turn",
		"ENC_TURN_DESC": "The cube moves on its own, rolling from tile to tile. Tap the left or right half of the screen to make it turn that way when it reaches the next tile.",
		"ENC_TURN_FACTS": "You can tap ahead of time: the turn waits for the next tile boundary.\nIf you ask for a turn into a wall, it's ignored and the cube keeps going straight.\nYou can't turn on the starting tile.\nEvery turn counts towards the turns star; bouncing off walls doesn't.",

		"ENC_REVERSE_NAME": "Turn around",
		"ENC_REVERSE_DESC": "Tap both sides of the screen at once and the cube will reverse direction at the next tile, as if it had hit a wall, letting out a puff of smoke.",
		"ENC_REVERSE_FACTS": "It counts as two turns for the turns star.\nIt doesn't use strength: you can do it whenever you like.\nLike hitting a wall, it makes you lose the speed power-up.",

		"ENC_DASH_NAME": "Dash",
		"ENC_DASH_DESC": "Swipe up and the cube will lunge to the tile ahead in an instant. It destroys any enemy there and smashes a cracked wall in one go.",
		"ENC_DASH_FACTS": "It uses up all your strength, which takes 2 seconds to refill.\nThe cube is invulnerable while dashing.\nAgainst a wall, a door or bars it does nothing special: the cube bounces.\nIf there's void ahead, the cube still falls.",

		"ENC_STOMP_NAME": "Stomp",
		"ENC_STOMP_DESC": "Swipe down and the cube will jump and slam down on its tile. The shockwave destroys enemies 2 tiles away or closer, diagonals included.",
		"ENC_STOMP_FACTS": "Walls don't stop the shockwave: it covers a 5 × 5 area.\nIt takes two hits off the cracked walls in the area.\nIt uses up all your strength, like the dash, and the cube is invulnerable while jumping.",
		"ENC_IMMUNITY_NAME": "Immunity",
		"ENC_IMMUNITY_DESC": "Swipe sideways, left or right, and the cube will be charged with electricity for 3 seconds: no enemy or weapon can destroy it. It kicks in right away, without waiting for the next tile.",
		"ENC_IMMUNITY_FACTS": "It uses up all your strength, and strength doesn't start refilling until it wears off.\nWhile it lasts, the cube looks half dissolved and buzzes, and the strength bar turns blue and drains with the time left.\nIt protects you from enemies, spikes, lasers and bombs, but not from falling into the void.\nIt is lost if the cube falls or reaches the goal.",

		"ENC_GOLDEN_CUBE_NAME": "Golden cube",
		"ENC_GOLDEN_CUBE_DESC": "Every level hides a golden cube that floats, spins and shines. Grab it before reaching the goal to earn one of the level's three stars.",
		"ENC_GOLDEN_CUBE_FACTS": "It's usually tucked away in a nook off the shortest path.\nGoing for it costs a few extra turns, but the turns star limit already allows for that.\nIf you restart the level, it goes back to its place.",

		"ENC_KEY_NAME": "Key",
		"ENC_KEY_DESC": "When the cube rolls over a key, it picks it up and carries it floating above. It opens the door of the same colour.",
		"ENC_KEY_FACTS": "The cube can only carry one key: if it already has one, the others stay on the map.\nThere are five colours: yellow, orange, red, blue and green.\nIf the cube dies, it keeps the key it was carrying.",

		"ENC_SPEED_NAME": "Speed",
		"ENC_SPEED_DESC": "A translucent blue cube. Each one you pick up adds 25% to the cube's speed, up to twice as fast, and while it lasts the cube leaves a trail of dust.",
		"ENC_SPEED_FACTS": "It has no time limit: hitting a wall, the edge of the board or a door doesn't remove it.\nIt's only lost when you turn around, and when you die, of course.",

		"ENC_DOOR_NAME": "Door",
		"ENC_DOOR_DESC": "A coloured block that blocks the way like a wall. To open it, hit it head-on while carrying the key of the same colour: the door and the key disappear.",
		"ENC_DOOR_FACTS": "Enemies can't pass through a closed door either.\nTurns into a closed door are ignored, just like into a wall.",

		"ENC_BREAKABLE_NAME": "Cracked wall",
		"ENC_BREAKABLE_DESC": "A stone block that breaks after several hits. Each head-on hit takes one off; once it breaks, the tile is free.",
		"ENC_BREAKABLE_FACTS": "It takes 1 to 5 hits: the more cracks it has, the fewer it has left.\nThe dash smashes it in one go and the stomp takes two hits off.\nThe hit that breaks it also makes the cube bounce.",

		"ENC_BARS_NAME": "Bars and buttons",
		"ENC_BARS_DESC": "Five metal spears that close a corridor from wall to wall. They open and close when you press their red button by hitting it head-on.",
		"ENC_BARS_FACTS": "One button can open some bars and close others at the same time.\nClosed bars also stop enemies: use them to trap them.\nThe spears slide into the walls when they open.",

		"ENC_VOID_NAME": "Void",
		"ENC_VOID_DESC": "Where there's no floor and no wall, there's the void. The cube doesn't bounce at the edge: if it rolls into a void tile, it tips over, falls spinning and explodes in mid-air.",
		"ENC_VOID_FACTS": "You fall even when you're invulnerable.\nTurns towards the void are accepted: watch where you turn!\nEnemies never go near the edge, and bombs that fall into the void are lost.",

		"ENC_BRIDGE_NAME": "Hanging bridge",
		"ENC_BRIDGE_DESC": "A row of planks over the void. Each plank wears out a little every time the cube crosses it; when one gives way, the whole bridge falls.",
		"ENC_BRIDGE_FACTS": "Each plank survives four crossings.\nThe more worn it is, the more dust it drops, and on its last one it sways.\nEnemies never step on bridges, so they don't wear them out.",

		"ENC_TELEPORT_NAME": "Teleporter",
		"ENC_TELEPORT_DESC": "A swirl of light on the floor. Tiles of the same colour are linked: the cube goes in through one and comes out of the other with the same heading.",
		"ENC_TELEPORT_FACTS": "Enemies can't use them: they're a good way to escape.\nThe cube is invulnerable during the trip.\nRolling off the destination tile doesn't send you back; rolling onto it again does.",

		"ENC_SPIKES_NAME": "Spikes",
		"ENC_SPIKES_DESC": "A metal plate with four holes. Every few seconds four spears shoot out, stay up for a second and hide again. They're only dangerous while they're out.",
		"ENC_SPIKES_FACTS": "They come out every 3 to 8 seconds, at random.\nJust before they do, the plate trembles: that's your cue to turn or turn around.\nEnemies never step on spikes.",

		"ENC_LASER_NAME": "Laser cannon",
		"ENC_LASER_DESC": "A cannon built into a wall, with a ring of red lights. Every few seconds it fires a laser that travels in a straight line until it hits something. If it hits you, the cube explodes.",
		"ENC_LASER_FACTS": "Before firing, its lights blink and beep four times.\nThe laser is twice as fast as the cube.\nWalls, doors, closed bars and enemies stop it (it doesn't hurt them).\nIt flies over the void.",

		"ENC_MORTAR_NAME": "Bomb cannon",
		"ENC_MORTAR_DESC": "A mortar on top of a wall. When you're in range, it lobs bombs that land in your path. The tiles the blast will reach turn red: get off them before it goes off.",
		"ENC_MORTAR_FACTS": "It turns to face you in any direction and fires if you're within 10 tiles.\nA bomb explodes 2 to 3 seconds after touching the ground, reaching 2 tiles all around.\nBombs are very heavy: they barely bounce and the cube can push them.\nThey don't hurt enemies.",
	},
}
