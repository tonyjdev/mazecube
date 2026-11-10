class_name Encyclopedia
extends Control
## Enciclopedia: un libro de consulta con los elementos del juego, por
## pestañas (enemigos, habilidades, objetos y obstáculos). El contenido está
## en EncyclopediaData y los textos en EncyclopediaTexts.
##
## Se abre desde el menú principal y desde la pausa (encima del mapa). Se
## construye entera desde aquí: arriba las pestañas y el botón de cerrar; en
## medio el libro abierto, con el dibujo de tiza en la página de la izquierda
## (una pizarra con marco de madera) y en la de la derecha, de papel, el
## nombre, la descripción, las curiosidades y en qué nivel aparece por
## primera vez; a los lados, las flechas para pasar de página.
##
## - Las páginas también se pasan deslizando el dedo a izquierda o derecha
##   sobre el libro, o con las flechas del teclado. Al pasar la página, la
##   hoja se desliza hacia un lado y entra la nueva por el otro.
## - Cada pestaña recuerda su página, y al volver a abrir la enciclopedia
##   sigue donde se dejó (mientras no se cierre el juego).
## - Esc cierra la enciclopedia. El botón Atrás de Android lo atiende quien la
##   contiene (Menu o Game): si is_open(), llama a close().
## - Funciona con el juego en pausa (process_mode = ALWAYS).

signal closed

## Tiempos de la apertura y del paso de página, y cuánto se desliza la hoja.
const OPEN_TIME := 0.18
const FLIP_OUT_TIME := 0.1
const FLIP_IN_TIME := 0.16
const FLIP_SHIFT := 70.0
## Deslizamiento mínimo (px) para pasar de página, y cuánto más horizontal
## que vertical tiene que ser.
const SWIPE_MIN := 90.0
const SWIPE_RATIO := 1.5

## Tamaño de los dibujos (ver tools/make_encyclopedia_art.py) y grosor del
## marco de madera de la pizarra.
const IMAGE_SIZE := Vector2i(720, 600)
const FRAME_WIDTH := 9
const DIM_COLOR := Color(0.06, 0.04, 0.03, 0.72)
const COVER_COLOR := Color("#4a3322")
const COVER_EDGE := Color("#6d4c33")
const WOOD_COLOR := Color("#7a5434")
const SLATE_COLOR := Color(0.11, 0.15, 0.13)
const PAPER_COLOR := Color("#f1e4c8")
const LEFT_PAPER_COLOR := Color("#e6d4b2")
const INK_COLOR := Color("#3b2a1b")
const ACCENT_COLOR := Color("#94612c")
const SOFT_INK := Color("#7d6448")

## Pestaña abierta y página de cada pestaña (se conservan entre aperturas).
static var _tab := 0
static var _pages := {}

var _tab_buttons: Array[Button] = []
var _book: Control
var _sheet: Control
var _clip: Control
var _image: TextureRect
var _category: Label
var _name: Label
var _text: RichTextLabel
var _scroll: ScrollContainer
var _footer: Label
var _counter: Label
var _prev: Button
var _next: Button
var _close: Button
var _flip_tween: Tween
var _open_tween: Tween
var _swipe_start := Vector2.INF
var _open := false


func _init() -> void:
	name = "Encyclopedia"
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _ready() -> void:
	# El tema no tiene estilo «desactivado» para los botones de icono: se usa el
	# normal (y se atenúa el botón, ver _show_page).
	for arrow: Button in [_prev, _next]:
		arrow.add_theme_stylebox_override("disabled", arrow.get_theme_stylebox("normal"))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _name != null:
		_refresh_tabs()
		_show_page()


## Abre la enciclopedia donde se dejó.
func open() -> void:
	if _open:
		return
	_open = true
	visible = true
	_refresh_tabs()
	_show_page()
	_kill(_open_tween)
	modulate.a = 0.0
	_book.pivot_offset = _book.size * 0.5
	_book.scale = Vector2.ONE * 0.94
	_open_tween = create_tween().set_parallel()
	_open_tween.tween_property(self, "modulate:a", 1.0, OPEN_TIME)
	_open_tween.tween_property(_book, "scale", Vector2.ONE, OPEN_TIME * 1.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not OS.has_feature("mobile"):
		_tab_buttons[_tab].grab_focus.call_deferred()


func close() -> void:
	if not _open:
		return
	_open = false
	_kill(_open_tween)
	_open_tween = create_tween()
	_open_tween.tween_property(self, "modulate:a", 0.0, OPEN_TIME * 0.7)
	_open_tween.tween_callback(hide)
	_swipe_start = Vector2.INF
	closed.emit()


## Abierta (o abriéndose). Mientras se funde al cerrarse ya no lo está.
func is_open() -> bool:
	return _open


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_cancel"):
		Sfx.play("click")
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		turn_page(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		turn_page(1)
		get_viewport().set_input_as_handled()
	else:
		_track_swipe(event)


## Deslizar el dedo (o el ratón) a izquierda o derecha sobre el libro pasa
## de página. No se marca como atendido: los botones y el desplazamiento del
## texto siguen funcionando igual.
func _track_swipe(event: InputEvent) -> void:
	var pressed: bool
	var pos: Vector2
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.index != 0:
			return
		pressed = touch.pressed
		pos = touch.position
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		# Los clics que Android genera a partir de los toques ya llegan como toques.
		if mouse.button_index != MOUSE_BUTTON_LEFT or mouse.device == InputEvent.DEVICE_ID_EMULATION:
			return
		pressed = mouse.pressed
		pos = mouse.position
	else:
		return
	if pressed:
		_swipe_start = pos if _book.get_global_rect().has_point(pos) else Vector2.INF
		return
	if _swipe_start == Vector2.INF:
		return
	var moved := pos - _swipe_start
	_swipe_start = Vector2.INF
	if absf(moved.x) >= SWIPE_MIN and absf(moved.x) >= absf(moved.y) * SWIPE_RATIO:
		turn_page(-1 if moved.x > 0.0 else 1)


## Pasa a la página siguiente (1) o anterior (-1) de la pestaña abierta.
func turn_page(direction: int) -> void:
	var count := _page_count()
	var page := _page()
	var target := clampi(page + direction, 0, count - 1)
	if target == page:
		return
	_pages[_tab] = target
	Sfx.play("page", 0.08)
	_flip(direction)


func select_tab(index: int) -> void:
	if index == _tab:
		_refresh_tabs()
		return
	_tab = index
	_refresh_tabs()
	_flip(0)


# --- Contenido ----------------------------------------------------------------

func _page_count() -> int:
	return (EncyclopediaData.TABS[_tab]["pages"] as Array).size()


func _page() -> int:
	return clampi(_pages.get(_tab, 0), 0, _page_count() - 1)


func _refresh_tabs() -> void:
	for i in _tab_buttons.size():
		var button := _tab_buttons[i]
		button.text = tr(EncyclopediaData.TABS[i]["title"])
		button.theme_type_variation = &"PrimaryButton" if i == _tab else &""
		button.button_pressed = i == _tab


func _show_page() -> void:
	var tab: Dictionary = EncyclopediaData.TABS[_tab]
	var index := _page()
	var page: Dictionary = tab["pages"][index]
	_image.texture = load(EncyclopediaData.image_path(page)) as Texture2D
	_category.text = tr(tab["title"]).to_upper()
	_name.text = tr(EncyclopediaData.text_key(page, "NAME"))
	var text := tr(EncyclopediaData.text_key(page, "DESC"))
	var facts := tr(EncyclopediaData.text_key(page, "FACTS")).strip_edges()
	if not facts.is_empty():
		text += "\n[font_size=26][color=#%s]%s[/color][/font_size]\n" % [ACCENT_COLOR.to_html(false), tr("ENC_FACTS")]
		text += "[ul bullet=■]%s[/ul]" % facts
	_text.text = text.strip_edges()
	_scroll.scroll_vertical = 0
	var first := EncyclopediaData.first_level(page)
	if first == 0:
		_footer.text = tr("ENC_FROM_START")
	elif first > 0:
		_footer.text = tr("ENC_FIRST_LEVEL") % (first + 1)
	else:
		_footer.text = ""
	_counter.text = tr("ENC_PAGE") % [index + 1, _page_count()]
	for arrow: Button in [_prev, _next]:
		arrow.disabled = index == (0 if arrow == _prev else _page_count() - 1)
		arrow.modulate.a = 0.3 if arrow.disabled else 1.0


## Cambia la página con la hoja deslizándose: `direction` 1 (siguiente) la
## saca por la izquierda, -1 por la derecha y 0 (cambio de pestaña) solo
## funde.
func _flip(direction: int) -> void:
	_kill(_flip_tween)
	_flip_tween = create_tween()
	_flip_tween.set_parallel()
	_flip_tween.tween_property(_sheet, "position:x", -direction * FLIP_SHIFT, FLIP_OUT_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_flip_tween.tween_property(_sheet, "modulate:a", 0.0, FLIP_OUT_TIME)
	_flip_tween.chain().tween_callback(func() -> void:
		_show_page()
		_sheet.position.x = direction * FLIP_SHIFT)
	_flip_tween.chain().set_parallel()
	_flip_tween.tween_property(_sheet, "position:x", 0.0, FLIP_IN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_flip_tween.tween_property(_sheet, "modulate:a", 1.0, FLIP_IN_TIME)


func _kill(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()


# --- Construcción ---------------------------------------------------------------

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# Cabecera: título, pestañas y cerrar.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	vbox.add_child(header)
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "ENC_TITLE"
	title.add_theme_font_size_override("font_size", 38)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)
	header.add_child(_spacer())
	var group := ButtonGroup.new()
	for i in EncyclopediaData.TABS.size():
		var tab := Button.new()
		tab.toggle_mode = true
		tab.button_group = group
		tab.custom_minimum_size = Vector2(0, 62)
		tab.add_theme_font_size_override("font_size", 24)
		tab.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		tab.pressed.connect(func() -> void:
			Sfx.play("click")
			select_tab(i))
		header.add_child(tab)
		_tab_buttons.append(tab)
	header.add_child(_spacer())
	_close = _icon_button("res://ui/enc_close.svg", 66)
	_close.pressed.connect(func() -> void:
		Sfx.play("click")
		close())
	header.add_child(_close)

	# Cuerpo: flecha, libro, flecha.
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	vbox.add_child(body)
	_prev = _icon_button("res://ui/enc_prev.svg", 72)
	_prev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_prev.pressed.connect(turn_page.bind(-1))
	body.add_child(_prev)

	var book := PanelContainer.new()
	book.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	book.add_theme_stylebox_override("panel", _box(COVER_COLOR, 14, 14, COVER_EDGE, 3, Color("#1a1410"), 9))
	body.add_child(book)
	_book = book
	_clip = Control.new()
	_clip.clip_contents = true
	book.add_child(_clip)
	_sheet = HBoxContainer.new()
	_sheet.add_theme_constant_override("separation", 0)
	_clip.add_child(_sheet)
	_clip.resized.connect(func() -> void: _sheet.size = _clip.size)

	# Página izquierda: la pizarra con su marco, pegada en el papel.
	var left := PanelContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.9
	var left_box := _box(LEFT_PAPER_COLOR, 8, 16)
	left.add_theme_stylebox_override("panel", left_box)
	_sheet.add_child(left)
	var aspect := AspectRatioContainer.new()
	aspect.ratio = float(IMAGE_SIZE.x) / IMAGE_SIZE.y
	left.add_child(aspect)
	var frame := PanelContainer.new()
	var frame_box := _box(SLATE_COLOR, 6, FRAME_WIDTH, Color.TRANSPARENT, 0, Color(0.2, 0.13, 0.08, 0.5), 5)
	frame_box.set_border_width_all(FRAME_WIDTH)
	frame_box.border_color = WOOD_COLOR
	frame.add_theme_stylebox_override("panel", frame_box)
	aspect.add_child(frame)
	_image = TextureRect.new()
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image.custom_minimum_size = Vector2(200, 160)
	frame.add_child(_image)

	var spine := ColorRect.new()
	spine.color = Color("#2a1c13")
	spine.custom_minimum_size = Vector2(8, 0)
	_sheet.add_child(spine)

	# Página derecha: papel con el texto.
	var paper := PanelContainer.new()
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var paper_box := _box(PAPER_COLOR, 8, 0)
	paper_box.content_margin_left = 30
	paper_box.content_margin_right = 26
	paper_box.content_margin_top = 18
	paper_box.content_margin_bottom = 14
	paper.add_theme_stylebox_override("panel", paper_box)
	_sheet.add_child(paper)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 4)
	paper.add_child(page)
	_category = _ink_label(20, ACCENT_COLOR)
	page.add_child(_category)
	_name = _ink_label(42, INK_COLOR)
	page.add_child(_name)
	var rule := ColorRect.new()
	rule.color = Color(ACCENT_COLOR, 0.55)
	rule.custom_minimum_size = Vector2(0, 3)
	page.add_child(rule)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	page.add_child(gap)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(_scroll)
	# Barra de desplazamiento clara, a juego con el papel.
	var bar := _scroll.get_v_scroll_bar()
	var track := _box(Color(ACCENT_COLOR, 0.14), 4, 0)
	track.content_margin_left = 4
	track.content_margin_right = 4
	bar.add_theme_stylebox_override("scroll", track)
	var grab := _box(Color(ACCENT_COLOR, 0.55), 4, 0)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(state, grab)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.mouse_filter = Control.MOUSE_FILTER_PASS
	_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_text.add_theme_color_override("default_color", INK_COLOR)
	_text.add_theme_font_size_override("normal_font_size", 23)
	_text.add_theme_constant_override("line_separation", 4)
	_text.add_theme_constant_override("paragraph_separation", 8)
	_scroll.add_child(_text)
	var footer := HBoxContainer.new()
	page.add_child(footer)
	_footer = _ink_label(19, SOFT_INK)
	_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_footer)
	_counter = _ink_label(19, SOFT_INK)
	footer.add_child(_counter)

	_next = _icon_button("res://ui/enc_next.svg", 72)
	_next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_next.pressed.connect(turn_page.bind(1))
	body.add_child(_next)


func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer


func _icon_button(icon: String, side: float) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"IconButton"
	button.icon = load(icon)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.expand_icon = true
	button.custom_minimum_size = Vector2(side, side)
	return button


func _ink_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 0)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _box(color: Color, radius: int, margin: int, edge := Color.TRANSPARENT, edge_top := 0,
		shadow := Color.TRANSPARENT, shadow_y := 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(margin)
	if edge_top > 0:
		box.border_width_top = edge_top
		box.border_color = edge
		box.border_blend = false
	if shadow_y > 0:
		box.shadow_color = shadow
		box.shadow_size = 1
		box.shadow_offset = Vector2(0, shadow_y)
	return box
