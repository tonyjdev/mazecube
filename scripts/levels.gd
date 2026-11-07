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
##
## Los niveles crecen de forma progresiva (en torno a un 15-20% más de
## casillas cada uno) y alternan forma apaisada y vertical. Con la distancia
## máxima de la cámara solo el nivel 2 (7×9) cabe entero en pantalla; en el
## resto la cámara sigue al cubo.
## "camera_distance" (opcional) fija la distancia de la cámara del nivel; si
## no se indica, se usa la máxima (FollowCamera.MAX_DISTANCE).
## start_heading es el rumbo inicial en casillas (x, z): (1, 0) derecha,
## (-1, 0) izquierda, (0, 1) abajo, (0, -1) arriba.
##
## "turns" es el mínimo de giros necesarios para resolver el nivel con las
## reglas del juego (rebote, giros descartados hacia muros y puertas, sin giro
## en la casilla de salida, una sola llave a la vez). Se calcula con
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
]


static func count() -> int:
	return LIST.size()


static func get_level(index: int) -> Dictionary:
	return LIST[clampi(index, 0, LIST.size() - 1)]
