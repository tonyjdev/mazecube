class_name Abilities
extends RefCounted
## Habilidades del cubo que se compran en las tiendas (ver Shop y
## ShopBuilding) y reglas de los puntos con que se pagan.
##
## Girar es el movimiento básico y siempre está disponible. El resto empieza
## bloqueado (nivel 0) y cada compra sube un nivel: el primero la
## desbloquea y los siguientes la mejoran. «Recarga» no es una acción sino
## una mejora de la fuerza (la comparten dash, pisotón e inmunidad), así que
## empieza en el nivel 0 con la recarga normal y solo se puede comprar
## teniendo alguna de esas tres.
##
## Cada habilidad del catálogo:
##   id       también la clave de sus textos (SHOP_<ID>_NAME...) y de su dibujo
##            en la enciclopedia (ui/encyclopedia/<id>.png)
##   prices   precio de cada nivel (el primero, el de desbloquearla); su
##            tamaño es el nivel máximo
##   values   valor del efecto en cada nivel, desde el 0 (ver value())
##   needs    habilidades de las que hace falta tener alguna para comprarla
##
## Los precios son provisionales: hay que calibrarlos con lo que se gana de
## verdad (ver los puntos más abajo).

const REVERSE := "reverse"
const DASH := "dash"
const STOMP := "stomp"
const IMMUNITY := "immunity"
const RECHARGE := "recharge"

const CATALOG: Array[Dictionary] = [
	{"id": REVERSE, "prices": [150]},
	{"id": DASH, "prices": [300]},
	# Radio del pisotón en casillas (2 = cuadrado de 5×5).
	{"id": STOMP, "prices": [400, 900], "values": [0, 2, 3]},
	# Segundos de inmunidad.
	{"id": IMMUNITY, "prices": [500, 800, 1200], "values": [0.0, 3.0, 4.5, 6.0]},
	# Segundos que tarda la fuerza en volver a llenarse.
	{"id": RECHARGE, "prices": [400, 800], "values": [2.0, 1.5, 1.0],
		"needs": [DASH, STOMP, IMMUNITY]},
]

## Puntos de una partida (ver points_for_run): cada giro que sobra respecto
## al reto de giros, cada estrella y cada enemigo destruido, según su tipo.
const POINTS_PER_SPARE_TURN := 1
const POINTS_PER_STAR := 50
const POINTS_PATROLLER := 10
const POINTS_BLOCKER := 15
const POINTS_CHASER := 25


static func ids() -> Array[String]:
	var list: Array[String] = []
	for entry in CATALOG:
		list.append(entry["id"])
	return list


static func entry(id: String) -> Dictionary:
	for item in CATALOG:
		if item["id"] == id:
			return item
	return {}


static func max_level(id: String) -> int:
	return entry(id).get("prices", []).size()


## Precio del siguiente nivel de la habilidad (0 si ya está al máximo).
static func price(id: String, current_level: int) -> int:
	var prices: Array = entry(id).get("prices", [])
	return prices[current_level] if current_level < prices.size() else 0


## Valor del efecto de la habilidad en ese nivel (ver "values"); null si no
## tiene.
static func value(id: String, at_level: int) -> Variant:
	var values: Array = entry(id).get("values", [])
	if values.is_empty():
		return null
	return values[clampi(at_level, 0, values.size() - 1)]


## Habilidades de las que hace falta tener alguna para comprar `id` (vacío
## si ninguna).
static func needs(id: String) -> Array:
	return entry(id).get("needs", [])


## Puntos de una partida terminada: giros sobrantes, estrellas y lo que
## valen los enemigos destruidos (`enemy_points`). Devuelve el total y el
## desglose: { "total", "turns", "stars", "enemies" }.
static func points_for_run(turns_used: int, star_turns: int, stars: int, enemy_points: int) -> Dictionary:
	var turns := maxi(star_turns - turns_used, 0) * POINTS_PER_SPARE_TURN
	var star_points := stars * POINTS_PER_STAR
	return {"total": turns + star_points + enemy_points, "turns": turns,
		"stars": star_points, "enemies": enemy_points}


## Puntos por destruir a este enemigo: patrullero (octaedro), obstáculo
## (dodecaedro) o perseguidor (esfera).
static func enemy_points(enemy: Node) -> int:
	if enemy is Patroller:
		return POINTS_PATROLLER
	if enemy is Blocker:
		return POINTS_BLOCKER
	if enemy is Chaser:
		return POINTS_CHASER
	return 0
