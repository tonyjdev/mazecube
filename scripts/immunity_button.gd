class_name ImmunityButton
extends Button
## Botón de la inmunidad (arriba en el centro de la partida; ver
## RollingCube.request_immunity).
##
## - Con la fuerza llena se ve normal; si no, apagado (se puede pulsar igual:
##   el cubo lo descarta y avisa).
## - Mientras dura la inmunidad, el icono se tiñe de azul eléctrico y late, y
##   un anillo alrededor se va vaciando con el tiempo que queda.

const READY_ALPHA := 1.0
const NOT_READY_ALPHA := 0.45
const ACTIVE_COLOR := Color(0.55, 0.9, 1.0)
const RING_COLOR := Color(0.45, 0.85, 1.0, 0.95)
const RING_BACK_COLOR := Color(0.0, 0.0, 0.0, 0.3)
const RING_WIDTH := 6.0
## Latido del icono durante la inmunidad (rad/s).
const PULSE_SPEED := 14.0

## Fuerza del cubo (0-1): con menos de 1 se ve apagado.
var strength := 1.0
## Fracción de inmunidad que queda (0 = sin inmunidad).
var immunity := 0.0

var _time := 0.0


func _ready() -> void:
	# Responde al apoyar el dedo, sin esperar a levantarlo.
	action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS


func _process(delta: float) -> void:
	_time += delta
	if immunity > 0.0:
		modulate.a = READY_ALPHA
		var pulse := 0.5 + 0.5 * sin(_time * PULSE_SPEED)
		self_modulate = Color.WHITE.lerp(ACTIVE_COLOR, 0.6 + 0.4 * pulse)
	else:
		modulate.a = READY_ALPHA if strength >= 1.0 else NOT_READY_ALPHA
		self_modulate = Color.WHITE
	queue_redraw()


func _draw() -> void:
	if immunity <= 0.0:
		return
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 + RING_WIDTH * 0.5 + 2.0
	draw_arc(center, radius, 0.0, TAU, 48, RING_BACK_COLOR, RING_WIDTH, true)
	draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * immunity, 48, RING_COLOR, RING_WIDTH, true)
