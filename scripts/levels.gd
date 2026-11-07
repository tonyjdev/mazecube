class_name Levels
extends RefCounted
## Lista de niveles, de menor a mayor dificultad.
##
## Leyenda: '#' pared, '.' libre, 'A' inicio, 'B' meta.
## Llaves (minúscula) y su puerta (mayúscula): y/Y amarillo, o/O naranja,
## r/R rojo, u/U azul, g/G verde. Desde el nivel 3 hay parejas llave/puerta
## (1 en los niveles 3-5, 2 en los 6-8 y 3 en los 9-10).
## Power ups (ver PowerUpCatalog): s = velocidad (en los niveles 4, 7 y 9).
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
			"#####",
			"#A..#",
			"###.#",
			"###.#",
			"###.#",
			"###B#",
			"#####",
		],
	},
	{
		"name": "Ida y vuelta",
		"turns": 2,
		"start_heading": Vector2i(1, 0),
		"layout": [
			"#######",
			"#A....#",
			"#####.#",
			"#####.#",
			"#####.#",
			"#####.#",
			"#B....#",
			"#######",
		],
	},
	{
		"name": "Bifurcación",
		"turns": 5,
		"start_heading": Vector2i(0, 1),
		"layout": [
			"#######",
			"#A....#",
			"#.###.#",
			"#.#.y.#",
			"#.#.###",
			"#...#.#",
			"###Y#.#",
			"#B....#",
			"#######",
		],
	},
	{
		"name": "Serpiente",
		"turns": 7,
		"start_heading": Vector2i(0, 1),
		"layout": [
			"#######",
			"#A.s.o#",
			"#.###.#",
			"#...#.#",
			"###.#.#",
			"#...#.#",
			"#.#####",
			"#..O.B#",
			"#######",
		],
	},
	{
		"name": "Pasillos",
		"turns": 8,
		"start_heading": Vector2i(1, 0),
		"layout": [
			"#########",
			"#....A..#",
			"#.###.###",
			"#r#...#.#",
			"###.#.#.#",
			"#...#.#.#",
			"#.#.###.#",
			"#.#.#...#",
			"#.###.###",
			"#..R..B.#",
			"#########",
		],
	},
	{
		"name": "La plaza",
		"turns": 9,
		"start_heading": Vector2i(1, 0),
		"layout": [
			"#########",
			"#....A.y#",
			"#.#.#####",
			"#Y#..U..#",
			"#.#####.#",
			"#u..#...#",
			"####....#",
			"#.#.....#",
			"#B#.....#",
			"#...#...#",
			"#########",
		],
	},
	{
		"name": "Encrucijada",
		"turns": 12,
		"start_heading": Vector2i(1, 0),
		"layout": [
			"#########",
			"#.#...A.#",
			"#.#...g##",
			"#.......#",
			"####o...#",
			"#...#...#",
			"#.#.#G###",
			"#..s..#.#",
			"#O#####.#",
			"#...#.B.#",
			"#.#.#.###",
			"#.#.....#",
			"#########",
		],
	},
	{
		"name": "Rodeo",
		"turns": 13,
		"start_heading": Vector2i(0, 1),
		"layout": [
			"###########",
			"#......R.A#",
			"#####.###.#",
			"#.....#.r.#",
			"#.###.#####",
			"#.........#",
			"#.##u...###",
			"#.......#.#",
			"#.#######.#",
			"#...#...B.#",
			"###.#.#.#.#",
			"#...U...#.#",
			"###########",
		],
	},
	{
		"name": "Laberinto",
		"turns": 15,
		"start_heading": Vector2i(1, 0),
		"layout": [
			"###########",
			"#A....#...#",
			"#.y.###.#.#",
			"#...#...#.#",
			"#.###.###.#",
			"#..Ysss...#",
			"#.#####.#.#",
			"#.#.....#.#",
			"###.#.#####",
			"#...#.#...#",
			"#...r##.#.#",
			"#.....#B#G#",
			"#.....###.#",
			"#...#g.R..#",
			"###########",
		],
	},
	{
		"name": "El gran recorrido",
		"turns": 19,
		"start_heading": Vector2i(1, 0),
		"layout": [
			"###########",
			"#.#.....A.#",
			"#.#.o...#.#",
			"#..g....#.#",
			"#...###.#.#",
			"#...G.#...#",
			"#####.#####",
			"#.#...#...#",
			"#.#.###.#.#",
			"#..u#...#.#",
			"#.#####.#.#",
			"#O#..U..#B#",
			"#.#.###.#.#",
			"#...#.....#",
			"###########",
		],
	},
]


static func count() -> int:
	return LIST.size()


static func get_level(index: int) -> Dictionary:
	return LIST[clampi(index, 0, LIST.size() - 1)]
