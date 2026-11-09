class_name StrengthBar
extends Control
## Indicador de fuerza: barra redondeada que se vacía al hacer un dash o un
## pisotón y se llena mientras se recarga (ver RollingCube.strength).
##
## - Recargando: el relleno se ve más apagado.
## - Llena: dorada, late suavemente y da un destello al llenarse.
## - reject(): si se intenta usar sin fuerza, tiembla y se tiñe de rojo un
##   momento.

const FILL_COLOR := Color(1.0, 0.8, 0.3)
const CHARGING_COLOR := Color(0.78, 0.66, 0.45, 0.8)
const BACK_COLOR := Color(0.0, 0.0, 0.0, 0.35)
const BORDER_COLOR := Color(1.0, 1.0, 1.0, 0.55)
const REJECT_COLOR := Color(1.0, 0.28, 0.22)
const BORDER_WIDTH := 3
## Aviso sin fuerza: duración, desplazamiento máximo (px) y frecuencia (rad/s).
const REJECT_TIME := 0.35
const REJECT_SHAKE := 7.0
const REJECT_SHAKE_SPEED := 70.0
## Latido cuando está llena (rad/s) y cuánto se aclara.
const PULSE_SPEED := 4.0
const PULSE_LIGHTEN := 0.15
## Destello al llenarse: cuánto se aclara y lo que tarda en apagarse.
const FULL_FLASH_LIGHTEN := 0.45
const FULL_FLASH_TIME := 0.35

## Fuerza que se muestra, de 0 a 1.
var value := 1.0:
	set(v):
		v = clampf(v, 0.0, 1.0)
		if v >= 1.0 and value < 1.0:
			_full_flash = 1.0
		value = v

var _time := 0.0
var _reject_left := 0.0
var _full_flash := 0.0
var _back_style := StyleBoxFlat.new()
var _fill_style := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back_style.border_color = BORDER_COLOR
	_back_style.set_border_width_all(BORDER_WIDTH)
	_back_style.anti_aliasing = true
	_fill_style.anti_aliasing = true


## Se ha intentado usar la fuerza sin tenerla llena.
func reject() -> void:
	_reject_left = REJECT_TIME


func _process(delta: float) -> void:
	_time += delta
	_reject_left = maxf(_reject_left - delta, 0.0)
	_full_flash = maxf(_full_flash - delta / FULL_FLASH_TIME, 0.0)
	queue_redraw()


func _draw() -> void:
	var reject_amount := _reject_left / REJECT_TIME
	var rect := Rect2(Vector2.ZERO, size)
	rect.position.x += sin(_reject_left * REJECT_SHAKE_SPEED) * REJECT_SHAKE * reject_amount
	var radius := int(size.y * 0.5)
	_back_style.set_corner_radius_all(radius)
	_back_style.bg_color = BACK_COLOR
	_back_style.border_color = BORDER_COLOR.lerp(REJECT_COLOR, reject_amount)
	_back_style.draw(get_canvas_item(), rect)

	var inner := rect.grow(-BORDER_WIDTH - 1)
	var width := inner.size.x * value
	if width < 1.0:
		return
	var color := CHARGING_COLOR
	if value >= 1.0:
		var pulse := (0.5 + 0.5 * sin(_time * PULSE_SPEED)) * PULSE_LIGHTEN
		color = FILL_COLOR.lightened(pulse + _full_flash * FULL_FLASH_LIGHTEN)
	color = color.lerp(REJECT_COLOR, reject_amount)
	_fill_style.bg_color = color
	# Con poca fuerza el redondeo no puede ser mayor que la mitad del ancho.
	_fill_style.set_corner_radius_all(int(minf(inner.size.y, width) * 0.5))
	_fill_style.draw(get_canvas_item(), Rect2(inner.position, Vector2(width, inner.size.y)))
