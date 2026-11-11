class_name Abilities
extends RefCounted
## Habilidades del cubo que se compran en las tiendas (ver Shop y
## ShopBuilding) y reglas de las monedas con que se pagan.
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
## verdad (ver las monedas más abajo). Al llegar a la primera tienda (nivel
## 10) se tienen unas 140 monedas solo de completar niveles.

const REVERSE := "reverse"
const DASH := "dash"
const STOMP := "stomp"
const IMMUNITY := "immunity"
const RECHARGE := "recharge"
const MAGNET := "magnet"

const CATALOG: Array[Dictionary] = [
	{"id": REVERSE, "prices": [60]},
	{"id": DASH, "prices": [100]},
	# Radio del pisotón en casillas (2 = cuadrado de 5×5).
	{"id": STOMP, "prices": [140, 300], "values": [0, 2, 3]},
	# Segundos de inmunidad.
	{"id": IMMUNITY, "prices": [180, 300, 450], "values": [0.0, 3.0, 4.5, 6.0]},
	# Segundos que tarda la fuerza en volver a llenarse.
	{"id": RECHARGE, "prices": [150, 300], "values": [2.0, 1.5, 1.0],
		"needs": [DASH, STOMP, IMMUNITY]},
	# Casillas alrededor del cubo desde las que atrae las monedas.
	{"id": MAGNET, "prices": [80, 160, 260], "values": [0.0, 1.0, 2.0, 3.0]},
]

## Monedas (ver GameState.coins): las que se recogen del suelo (cada una vale
## COINS_PER_PICKUP; salen de los enemigos destruidos y de los cofres) y la
## recompensa por completar un nivel (ver reward_for_run).
const COINS_PER_PICKUP := 1
const COINS_LEVEL_COMPLETE := 10
const COINS_PER_SPARE_TURN := 1
## Monedas que suelta cada enemigo al destruirlo: obstáculo (dodecaedro),
## patrullero (octaedro) y perseguidor (esfera).
const COINS_BLOCKER := 2
const COINS_PATROLLER := 3
const COINS_CHASER := 5
## Monedas que suelta un cofre al abrirse (al azar, ambos incluidos).
const CHEST_COINS_MIN := 4
const CHEST_COINS_MAX := 7


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


## Recompensa por completar un nivel: COINS_LEVEL_COMPLETE más una moneda por
## cada giro que sobra respecto al reto de giros. Devuelve el total y el
## desglose: { "total", "level", "spare" }.
static func reward_for_run(turns_used: int, star_turns: int) -> Dictionary:
	var spare := maxi(star_turns - turns_used, 0) * COINS_PER_SPARE_TURN
	return {"total": COINS_LEVEL_COMPLETE + spare, "level": COINS_LEVEL_COMPLETE, "spare": spare}


## Monedas que suelta este enemigo al destruirlo.
static func enemy_coins(enemy: Node) -> int:
	if enemy is Blocker:
		return COINS_BLOCKER
	if enemy is Patroller:
		return COINS_PATROLLER
	if enemy is Chaser:
		return COINS_CHASER
	return 0
