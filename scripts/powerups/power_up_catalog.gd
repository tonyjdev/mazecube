class_name PowerUpCatalog
extends RefCounted
## Relación entre los símbolos de los mapas y los tipos de power up.
##
##   s  Velocidad (SpeedPowerUp)

const BY_SYMBOL := {
	"s": preload("res://scripts/powerups/speed_power_up.gd"),
}


static func has_symbol(symbol: String) -> bool:
	return BY_SYMBOL.has(symbol)


## Nueva instancia del power up de ese símbolo. Cada objeto del mapa tiene la
## suya, aunque al cogerlo el cubo agrupa por tipo (PowerUp.id).
static func create(symbol: String) -> PowerUp:
	return BY_SYMBOL[symbol].new()
