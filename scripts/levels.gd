class_name Levels
extends RefCounted
## Lista de niveles, de menor a mayor dificultad.
##
## Leyenda: '#' pared, '.' libre, 'A' inicio, 'B' meta.
## Llaves (minúscula) y su puerta (mayúscula): y/Y amarillo, o/O naranja,
## r/R rojo, u/U azul, g/G verde. Desde el nivel 3 hay parejas llave/puerta
## (1 en los niveles 3-5, 2 en los 6-8 y 3 en los 9-10).
## Power ups (ver PowerUpCatalog): s = velocidad (en los niveles 4, 7 y 9).
## Muros destructibles: '1'..'5' = golpes que aguantan (5 pocas grietas, 1
## muchas). En los niveles 2, 5, 7 y 10 hay que romperlos para pasar; en el 8
## es un atajo (sin romperlo harían falta 26 giros en vez de 14).
## Botones y barrotes (niveles 11-13): barrotes 'c' 'd' 'e' 'f' 'h' (grupo;
## minúscula = empiezan abiertos, mayúscula = cerrados) y botones 'p' 'q' 't'
## 'v' 'w' (muros con botón en la cara que da a su única casilla libre). El
## campo "buttons" indica qué grupos cambia cada botón: {"p": "cd"}. Cada
## botón es imprescindible (sin él, el nivel no tendría solución).
## Enemigos (niveles 14-16): 'x' perseguidor, 'z' obstáculo e 'i' 'j' 'k' 'm'
## 'n' patrulleros; el campo "patrols" da la ruta de cada patrullero como
## tramos rectos desde su casilla: {"i": "R3 D2 L3 U2"} (R derecha, L
## izquierda, U arriba, D abajo; si acaba donde empieza es circular, si no,
## de ida y vuelta). Ver Chaser, Blocker y Patroller.
##
## Los niveles crecen de forma progresiva (en torno a un 15-20% más de
## casillas cada uno) y alternan forma apaisada y vertical. Los pequeños
## caben enteros en pantalla; en los grandes la cámara sigue al cubo.
## "camera_distance" (opcional) fija la distancia de la cámara del nivel; si
## no se indica, se usa la máxima (FollowCamera.MAX_DISTANCE).
## start_heading es el rumbo inicial en casillas (x, z): (1, 0) derecha,
## (-1, 0) izquierda, (0, 1) abajo, (0, -1) arriba.
##
## "turns" es el mínimo de giros necesarios para resolver el nivel con las
## reglas del juego (rebote, giros descartados hacia muros y puertas, sin giro
## en la casilla de salida, una sola llave a la vez), sin contar perseguidores
## ni patrulleros y con el obstáculo como un muro fijo. Se calcula con
## tools/level_solver.py y sirve como medida de dificultad; ejecutar
## "python3 tools/level_solver.py validate" tras modificar los niveles.
##
## Estos niveles sirven para probar las mecánicas; los definitivos se
## diseñarán aparte.

const LIST: Array[Dictionary] = [
	{
		"name": "Primer giro",
		"turns": 1,
		"start_heading": Vector2i(1, 0),
		"layout": [
			"#########",
			"#A......#",
			"#######.#",
			"#######B#",
			"#########",
		],
	},
	{
		"name": "El muro",
		"turns": 3,
		"start_heading": Vector2i(0, -1),
		"layout": [
			"#######",
			"#.....#",
			"#A###.#",
			"#.#...#",
			"#.###.#",
			"#...#3#",
			"#####.#",
			"#...B.#",
			"#######",
		],
	},
	{
		"name": "La llave",
		"turns": 5,
		"start_heading": Vector2i(1, 0),
		"layout": [
			"###########",
			"#.......#y#",
			"#####.#.#.#",
			"#A....#...#",
			"#########Y#",
			"#........B#",
			"###########",
		],
	},
	{
		"name": "A toda prisa",
		"turns": 7,
		"start_heading": Vector2i(0, 1),
		"layout": [
			"#######",
			"#.#A..#",
			"#.#.#.#",
			"#s..#.#",
			"#.###.#",
			"#...#.#",
			"#.#.#.#",
			"#.#o..#",
			"#O#####",
			"#.....#",
			"#.#####",
			"#...B.#",
			"#######",
		],
	},
	{
		"name": "Escombros",
		"turns": 9,
		"start_heading": Vector2i(0, 1),
		"layout": [
			"#############",
			"#.........#.#",
			"#.###.###.#.#",
			"#.#...#.#r#.#",
			"#.#.###.###.#",
			"#.#.#...R.#.#",
			"#A#.###.#.#.#",
			"#.....4.#..B#",
			"#############",
		],
	},
	{
		"name": "Dos llaves",
		"turns": 10,
		"start_heading": Vector2i(1, 0),
		"layout": [
			"#########",
			"#..A..#.#",
			"#.###.#.#",
			"#.#...#.#",
			"#.#.###.#",
			"#.#.#...#",
			"#.#.#.###",
			"#...#...#",
			"#.#u###.#",
			"#..y#...#",
			"#Y###.#.#",
			"#...#.#.#",
			"###.#.#.#",
			"#...UB#.#",
			"#########",
		],
	},
	{
		"name": "Salas",
		"turns": 12,
		"start_heading": Vector2i(1, 0),
		"layout": [
			"###############",
			"#.......O.#...#",
			"#.#####.#.###.#",
			"#.#.#...#.gG..#",
			"#.#.#...#####2#",
			"#.........#.B.#",
			"###.#...#.#.###",
			"#A....#...#.#o#",
			"#.###.#.#####.#",
			"#.....#...s...#",
			"###############",
		],
	},
	{
		"name": "El atajo",
		"turns": 14,
		"start_heading": Vector2i(-1, 0),
		"layout": [
			"###########",
			"#.U...#..A#",
			"#.###.#.#.#",
			"#...#.....#",
			"###.###.#.#",
			"#...#u#...#",
			"#.###.#.###",
			"#...#...#.#",
			"###.###3#.#",
			"#...#...#.#",
			"#.###.#.#.#",
			"#.....#...#",
			"#.#########",
			"#.....#...#",
			"#####.#.#.#",
			"#BR.....#r#",
			"###########",
		],
	},
	{
		"name": "Galerías",
		"turns": 16,
		"start_heading": Vector2i(0, -1),
		"layout": [
			"#################",
			"#.#..........r#.#",
			"#.#####.#####g#.#",
			"#.......#.....#.#",
			"#.#######.###.#.#",
			"#A.......sss..#.#",
			"#G#####.....###.#",
			"#.....#.....#...#",
			"#####.#######.#.#",
			"#...#R#y....Y.#.#",
			"#.#.#.#####.###.#",
			"#...........#..B#",
			"#################",
		],
	},
	{
		"name": "La gran travesía",
		"turns": 19,
		"start_heading": Vector2i(1, 0),
		"layout": [
			"###############",
			"#.......A.....#",
			"#.#.#######.#.#",
			"#.#...#.gu#.#.#",
			"#.###.#...#.#.#",
			"#.#.......#...#",
			"#.#.###U#.###.#",
			"#.#.#.#G#.....#",
			"#.#.#.#.###.#.#",
			"#...#.#...#...#",
			"#####.###.#####",
			"#o..#...#2#...#",
			"###.#.#.#5#.#.#",
			"#...#.#...#.#.#",
			"#.###.#.#.#B#.#",
			"#.........O.#.#",
			"###############",
		],
	},
	{
		"name": "El botón",
		"turns": 21,
		"start_heading": Vector2i(1, 0),
		"layout": [
			"#################p#",
			"#...#y#.......A.#.#",
			"#.#.#.#.#######.#.#",
			"#.#.#.#.#.......#.#",
			"#.#.#.#.#.###.###.#",
			"#.#.#.......#.#...#",
			"###.#####.#.#s#Y###",
			"#...#.....#.#.#...#",
			"#.###C#####.#.#.#.#",
			"#.....#.#...#.#.#.#",
			"#.#.###.#.###.#.#.#",
			"#.#.....#...#...#.#",
			"#.#.###.###.#.###.#",
			"#..B......#.......#",
			"###################",
		],
		"buttons": {"p": "c"},
	},
	{
		"name": "Barrotes",
		"turns": 22,
		"start_heading": Vector2i(1, 0),
		"layout": [
			"###############",
			"p.......#A....#",
			"#####.#.#.###.#",
			"#.......#...#.#",
			"#.#####.#.#.#.#",
			"#.#...#.....#.#",
			"#.###.###.#.#.#",
			"#...#..d....#.#",
			"###.#.#####.#.#",
			"#...#.#.....#.#",
			"#.###.#.#####.#",
			"#.#...#.....#.#",
			"#.#.###.#.#.#d#",
			"#.....#...#.#.#",
			"#.###.###.#.#.#",
			"#D#.......#...#",
			"#.#############",
			"#.#.....#.....#",
			"#.#.###.#####.#",
			"#...#.#...#...#",
			"#C###.#.###.###",
			"#..B..#..2....q",
			"###############",
		],
		"buttons": {"p": "d", "q": "cd"},
	},
	{
		"name": "La fortaleza",
		"turns": 27,
		"start_heading": Vector2i(0, 1),
		"layout": [
			"#######################",
			"p....A#.E.....D...#...#",
			"#####.#Y###.#.#.#.#.#.#",
			"#.....#.#.#...#.#.#...#",
			"#.#.#.#.#.#####.#.#.#.#",
			"#.#...#...#y#.......#.#",
			"#.#######.#.#.#########",
			"#.......#.#.#.C.#.....#",
			"#.###.###.#.###.#.#####",
			"#.....#...#.#...#.#...#",
			"#.#.#.#.###d#.#.#.###.#",
			"#.#.#...#...#.#.#...#.#",
			"#.#.#.#.#.#.#.#.#.#.#.#",
			"#.#.#...#.#.#.#...#...#",
			"#.#.###.#.#.#.#######.#",
			"#.#..3.s..#.#......B..#",
			"###########q###########",
		],
		"buttons": {"p": "e", "q": "cd"},
	},
	{
		"name": "La patrulla",
		"turns": 12,
		"start_heading": Vector2i(0, 1),
		"layout": [
			"#################",
			"#.....#...#....A#",
			"#.#.#.#.#.#.#.#.#",
			"#.#.#.#.#...#...#",
			"###.#.#.#####.#.#",
			"#i..#.....#...#.#",
			"#.#.#.#####.###.#",
			"#.....#j....#...#",
			"#.#####.###.#.#.#",
			"#...#.........#.#",
			"#.#B#.#.#.#####.#",
			"#...#....k#.....#",
			"#################",
		],
		"patrols": {"i": "D6", "j": "R4 D2 L4 U2", "k": "L4 U2"},
	},
	{
		"name": "Perseguidos",
		"turns": 14,
		"start_heading": Vector2i(1, 0),
		"layout": [
			"###############",
			"#A....#.......#",
			"###.#.#.#.###.#",
			"#.....#.#.#...#",
			"#.#####.#.#.###",
			"#.....#.#.....#",
			"#.###.#.#.###.#",
			"#...#.....#...#",
			"###.#######.#.#",
			"#.#.....#..x#.#",
			"#.#######.#.#.#",
			"#.....#...#...#",
			"#####.#.###.###",
			"#......x#.#.#.#",
			"#.#####.#.#.#.#",
			"#.B.#.....#...#",
			"###.#.#.#.#.#.#",
			"#.............#",
			"###############",
		],
	},
	{
		"name": "El guardián",
		"turns": 5,
		"start_heading": Vector2i(1, 0),
		"layout": [
			"#p#############",
			"#.............#",
			"#.###########.#",
			"#A..c.z.c.....#",
			"###########B###",
			"###############",
		],
		"buttons": {"p": "c"},
	},
]


static func count() -> int:
	return LIST.size()


static func get_level(index: int) -> Dictionary:
	return LIST[clampi(index, 0, LIST.size() - 1)]
