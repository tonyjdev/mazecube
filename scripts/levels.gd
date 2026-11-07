class_name Levels
extends RefCounted
## Lista de niveles, de menor a mayor dificultad.
##
## Leyenda: '#' pared, '.' libre, 'A' inicio, 'B' meta.
## start_heading es el rumbo inicial en casillas (x, z): (1, 0) derecha,
## (-1, 0) izquierda, (0, 1) abajo, (0, -1) arriba.
##
## "turns" es el mínimo de giros necesarios para resolver el nivel con las
## reglas del juego (rebote al chocar, giros descartados si hay muro y sin
## giro posible en la casilla de salida). Se calculó con un resolvedor por
## búsqueda en anchura y sirve como medida de dificultad.

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
		"turns": 3,
		"start_heading": Vector2i(0, 1),
		"layout": [
			"#######",
			"#A....#",
			"#.###.#",
			"#.#...#",
			"#.#.###",
			"#...#.#",
			"###.#.#",
			"#B....#",
			"#######",
		],
	},
	{
		"name": "Serpiente",
		"turns": 5,
		"start_heading": Vector2i(0, 1),
		"layout": [
			"#######",
			"#A....#",
			"#.###.#",
			"#...#.#",
			"###.#.#",
			"#...#.#",
			"#.#####",
			"#....B#",
			"#######",
		],
	},
	{
		"name": "Pasillos",
		"turns": 6,
		"start_heading": Vector2i(1, 0),
		"layout": [
			"#########",
			"#....A..#",
			"#.###.###",
			"#.#...#.#",
			"###.#.#.#",
			"#...#.#.#",
			"#.#.###.#",
			"#.#.#...#",
			"#.###.###",
			"#.....B.#",
			"#########",
		],
	},
	{
		"name": "La plaza",
		"turns": 7,
		"start_heading": Vector2i(1, 0),
		"layout": [
			"#########",
			"#....A..#",
			"#.#.#####",
			"#.#.....#",
			"#.#####.#",
			"#...#...#",
			"####....#",
			"#.#.....#",
			"#B#.....#",
			"#...#...#",
			"#########",
		],
	},
	{
		"name": "Encrucijada",
		"turns": 8,
		"start_heading": Vector2i(1, 0),
		"layout": [
			"#########",
			"#.#...A.#",
			"#.#....##",
			"#.......#",
			"####....#",
			"#...#...#",
			"#.#.#.###",
			"#.....#.#",
			"#.#####.#",
			"#...#.B.#",
			"#.#.#.###",
			"#.#.....#",
			"#########",
		],
	},
	{
		"name": "Rodeo",
		"turns": 9,
		"start_heading": Vector2i(0, 1),
		"layout": [
			"###########",
			"#........A#",
			"#####.###.#",
			"#.....#...#",
			"#.###.#####",
			"#.........#",
			"#.##....###",
			"#.......#.#",
			"#.#######.#",
			"#...#...B.#",
			"###.#.#.#.#",
			"#.......#.#",
			"###########",
		],
	},
	{
		"name": "Laberinto",
		"turns": 11,
		"start_heading": Vector2i(1, 0),
		"layout": [
			"###########",
			"#A....#...#",
			"#...###.#.#",
			"#...#...#.#",
			"#.###.###.#",
			"#.........#",
			"#.#####.#.#",
			"#.#.....#.#",
			"###.#.#####",
			"#...#.#...#",
			"#....##.#.#",
			"#.....#B#.#",
			"#.....###.#",
			"#...#.....#",
			"###########",
		],
	},
	{
		"name": "El gran recorrido",
		"turns": 13,
		"start_heading": Vector2i(1, 0),
		"layout": [
			"###########",
			"#.#.....A.#",
			"#.#.....#.#",
			"#.......#.#",
			"#...###.#.#",
			"#.....#...#",
			"#####.#####",
			"#.#...#...#",
			"#.#.###.#.#",
			"#...#...#.#",
			"#.#####.#.#",
			"#.#.....#B#",
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
