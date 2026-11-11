class_name Shop
extends Control
## Pantalla de la tienda: se abre al chocar con una tienda del mapa (ver
## ShopBuilding y Game) con el juego en pausa.
##
## Arriba, el título y los puntos que se tienen; en medio, una ficha por
## habilidad (ver Abilities) con su dibujo de la enciclopedia, el nombre, el
## nivel comprado, qué hace, el efecto del siguiente nivel y el botón de
## comprar o mejorar con su precio (desactivado si no llegan los puntos, si
## ya está al máximo o si le falta una habilidad que necesita); abajo, de
## dónde salen los puntos y el botón Salir. Esc o Atrás también la cierran.
## Funciona con el juego en pausa (process_mode = ALWAYS).

signal closed
## Se ha comprado (o mejorado) una habilidad.
signal bought(id: String)

const DIM_COLOR := Color(0.05, 0.04, 0.03, 0.78)
const CARD_COLOR := Color(0.26, 0.2, 0.15, 1.0)
const CARD_OWNED_COLOR := Color(0.24, 0.3, 0.2, 1.0)
const CARD_BORDER := Color(0.45, 0.36, 0.27, 1.0)
const GOLD := Color(0.98, 0.85, 0.3)
const SOFT := Color(0.85, 0.8, 0.72)
const CARD_WIDTH := 212.0
const IMAGE_SIZE := Vector2(184, 130)
const OPEN_TIME := 0.18
const ART_DIR := "res://ui/encyclopedia/"
const ART_OVERRIDES := {Abilities.RECHARGE: "res://ui/shop/recharge.svg"}
## Clave del nombre de cada habilidad (las de la enciclopedia cuando existen).
const NAME_KEYS := {
	Abilities.REVERSE: "ENC_REVERSE_NAME",
	Abilities.DASH: "ENC_DASH_NAME",
	Abilities.STOMP: "ENC_STOMP_NAME",
	Abilities.IMMUNITY: "ENC_IMMUNITY_NAME",
	Abilities.RECHARGE: "SHOP_RECHARGE_NAME",
}

var _points_label: Label
var _panel: PanelContainer
## id -> { "card", "level", "value", "button" }
var _cards := {}
var _close_button: Button
var _tween: Tween
var _open := false


func _init() -> void:
	name = "Shop"
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _points_label != null:
		_refresh()


func open() -> void:
	_open = true
	visible = true
	_refresh()
	if _tween and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2.ONE * 0.94
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "modulate:a", 1.0, OPEN_TIME)
	_tween.tween_property(_panel, "scale", Vector2.ONE, OPEN_TIME * 1.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not OS.has_feature("mobile"):
		_close_button.grab_focus.call_deferred()


func close() -> void:
	if not _open:
		return
	_open = false
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, OPEN_TIME * 0.7)
	_tween.tween_callback(hide)
	closed.emit()


func is_open() -> bool:
	return _open


func _input(event: InputEvent) -> void:
	if _open and event.is_action_pressed("ui_cancel"):
		Sfx.play("click")
		close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	box.add_child(header)
	var icon := TextureRect.new()
	icon.texture = load("res://ui/shop/shop_icon.svg")
	icon.custom_minimum_size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)
	var title := Label.new()
	title.text = "SHOP_TITLE"
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override("font_size", 40)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_points_label = Label.new()
	_points_label.add_theme_font_size_override("font_size", 32)
	_points_label.add_theme_color_override("font_color", GOLD)
	_points_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_points_label)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 12)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(cards)
	for id in Abilities.ids():
		cards.add_child(_build_card(id))

	var hint := Label.new()
	hint.text = "SHOP_HINT"
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.custom_minimum_size = Vector2(Abilities.CATALOG.size() * (CARD_WIDTH + 12.0) - 12.0, 0)
	box.add_child(hint)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	_close_button = Button.new()
	_close_button.text = "SHOP_CLOSE"
	_close_button.custom_minimum_size = Vector2(240, 68)
	_close_button.focus_mode = Control.FOCUS_ALL
	_close_button.pressed.connect(func() -> void:
		Sfx.play("click")
		close())
	buttons.add_child(_close_button)


func _build_card(id: String) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.add_theme_stylebox_override("panel", _card_style(CARD_COLOR))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var art := TextureRect.new()
	art.texture = load(ART_OVERRIDES.get(id, ART_DIR + id + ".png"))
	art.custom_minimum_size = IMAGE_SIZE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(art)
	var name_label := Label.new()
	name_label.text = NAME_KEYS[id]
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	var level := Label.new()
	level.add_theme_font_size_override("font_size", 18)
	level.add_theme_color_override("font_color", GOLD)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(level)
	var desc := Label.new()
	desc.text = "SHOP_%s_DESC" % id.to_upper()
	desc.add_theme_font_size_override("font_size", 17)
	desc.add_theme_color_override("font_color", SOFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.custom_minimum_size = Vector2(CARD_WIDTH - 20.0, 72)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(desc)
	var value := Label.new()
	value.add_theme_font_size_override("font_size", 18)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value)
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 58)
	button.add_theme_font_size_override("font_size", 22)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(_buy.bind(id))
	box.add_child(button)
	_cards[id] = {"card": card, "level": level, "value": value, "button": button}
	return card


func _card_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = CARD_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	return style


func _buy(id: String) -> void:
	if not GameState.buy_ability(id):
		Sfx.play("reject")
		return
	Sfx.play("powerup")
	GameState.vibrate(GameState.VIBRATION_BUTTON)
	_refresh()
	var card: Control = _cards[id]["card"]
	card.pivot_offset = card.size * 0.5
	var tween := card.create_tween()
	tween.tween_property(card, "scale", Vector2.ONE * 1.06, 0.1).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	bought.emit(id)


func _refresh() -> void:
	_points_label.text = tr("SHOP_POINTS") % GameState.points()
	for id: String in _cards:
		var parts: Dictionary = _cards[id]
		var current := GameState.ability_level(id)
		var top := Abilities.max_level(id)
		var maxed := current >= top
		var level_label: Label = parts["level"]
		level_label.text = tr("SHOP_LOCKED") if current == 0 and id != Abilities.RECHARGE \
			else tr("SHOP_LEVEL") % [current, top]
		var value_label: Label = parts["value"]
		var shown := current if maxed else current + 1
		var effect := _effect_text(id, shown)
		value_label.text = "" if effect == "" else (tr("SHOP_NOW") if maxed else tr("SHOP_NEXT")) % effect
		var button: Button = parts["button"]
		var owned := current > 0
		(parts["card"] as PanelContainer).add_theme_stylebox_override("panel",
			_card_style(CARD_OWNED_COLOR if owned else CARD_COLOR))
		if maxed:
			button.text = tr("SHOP_MAXED")
			button.disabled = true
			button.theme_type_variation = &""
		elif not GameState.meets_ability_needs(id):
			button.text = tr("SHOP_NEEDS")
			button.add_theme_font_size_override("font_size", 15)
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.disabled = true
			button.theme_type_variation = &""
			continue
		else:
			var price := Abilities.price(id, current)
			button.text = (tr("SHOP_UPGRADE") if owned else tr("SHOP_BUY")) % price
			button.disabled = not GameState.can_buy_ability(id)
			button.theme_type_variation = &"" if button.disabled else &"PrimaryButton"
		button.add_theme_font_size_override("font_size", 22)
		button.autowrap_mode = TextServer.AUTOWRAP_OFF


## Texto del efecto de la habilidad en ese nivel (vacío si no tiene valores).
func _effect_text(id: String, at_level: int) -> String:
	match id:
		Abilities.STOMP:
			var side: int = Abilities.value(id, at_level) * 2 + 1
			return tr("SHOP_STOMP_VALUE") % [side, side]
		Abilities.IMMUNITY:
			return tr("SHOP_IMMUNITY_VALUE") % _number(Abilities.value(id, at_level))
		Abilities.RECHARGE:
			return tr("SHOP_RECHARGE_VALUE") % _number(Abilities.value(id, at_level))
	return ""


## Número con decimales solo si hacen falta, con coma en español.
func _number(value: float) -> String:
	var text := str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
	return text.replace(".", ",") if TranslationServer.get_locale().begins_with("es") else text
