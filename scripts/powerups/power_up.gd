class_name PowerUp
extends RefCounted
## Base de los power ups.
##
## Cada tipo de power up hereda de esta clase y define sus reglas con las
## propiedades de abajo y, si lo necesita, sobrescribiendo los métodos
## virtuales. El cubo (RollingCube) gestiona de forma genérica los power ups
## activos: acumulaciones, duración y fin del efecto al rebotar.
##
## Para añadir un tipo nuevo:
##   1. Crear un script que herede de PowerUp (ver speed_power_up.gd).
##   2. Registrar su símbolo de mapa en PowerUpCatalog.
##   3. Añadir el símbolo a POWERUP_CHARS en tools/level_solver.py.

## Identificador único del tipo (clave en los power ups activos del cubo).
var id := ""
## Nombre para mostrar al jugador.
var display_name := ""
## Si es acumulable, coger otro igual mientras está activo suma una
## acumulación (hasta max_stacks). Si no, solo reinicia su duración.
var stackable := false
var max_stacks := 1
## Duración del efecto en segundos. 0 = ilimitada (dura hasta que otra regla
## lo termine, por ejemplo un rebote).
var duration := 0.0
## El efecto termina al rebotar contra una pared o el borde del tablero.
var ends_on_wall_bounce := false
## El efecto termina al rebotar contra una puerta.
var ends_on_door_bounce := false
## El efecto termina al dar media vuelta.
var ends_on_reverse := false
## Giro del objeto mientras está en el mapa (eje y velocidad en rad/s).
var pickup_spin_axis := Vector3.UP
var pickup_spin_speed := 1.0


## Modelo 3D del objeto que se coge en el mapa.
func create_pickup_visual() -> Node3D:
	return Node3D.new()


## Multiplicador de velocidad del cubo con `stacks` acumulaciones.
## Si hay varios power ups activos, sus multiplicadores se multiplican.
func speed_multiplier(_stacks: int) -> float:
	return 1.0


## Texto que se muestra al coger el power up.
func describe(_stacks: int) -> String:
	return display_name


## El efecto empieza (el cubo lo coge sin tenerlo activo).
func on_activated(_cube: Node3D, _stacks: int) -> void:
	pass


## Cambia el número de acumulaciones de un efecto ya activo.
func on_stacks_changed(_cube: Node3D, _stacks: int) -> void:
	pass


## Cada fotograma mientras el efecto está activo.
func on_process(_cube: Node3D, _stacks: int, _delta: float) -> void:
	pass


## El efecto termina. `immediate` es true al reiniciar el nivel: hay que
## quitar los efectos visuales sin esperar a que se desvanezcan.
func on_deactivated(_cube: Node3D, _immediate: bool) -> void:
	pass
