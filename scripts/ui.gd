class_name UI
## Small helpers for building the menu UI from code.

const BG := Color("1b1d24")
const PANEL := Color("272a34")
const PANEL_LIGHT := Color("343846")
const TEXT_DIM := Color("9aa0ad")
const GOOD := Color("66bb6a")
const BAD := Color("ef5350")
const GOLD := Color("ffd54f")


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 26
	var normal := box(Color("3d4354"), 10)
	var hover := box(Color("4a5166"), 10)
	var pressed := box(Color("2f3442"), 10)
	var disabled := box(Color("2a2d36"), 10)
	for s in [normal, hover, pressed, disabled]:
		s.content_margin_left = 16
		s.content_margin_right = 16
		s.content_margin_top = 10
		s.content_margin_bottom = 10
	for type in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
	t.set_color("font_disabled_color", "Button", Color("6b7080"))
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 12)
	t.set_constant("h_separation", "GridContainer", 10)
	t.set_constant("v_separation", "GridContainer", 10)
	t.set_font_size("font_size", "PopupMenu", 30)
	t.set_constant("v_separation", "PopupMenu", 18)
	return t


static func box(color: Color, radius := 12, border := Color.TRANSPARENT, border_width := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	if border_width > 0:
		s.border_color = border
		s.set_border_width_all(border_width)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


static func panel(color := PANEL, border := Color.TRANSPARENT, border_width := 0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(color, 12, border, border_width))
	return p


## Single-line text. Safe to put in rows.
static func label(text: String, size := 26, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Wrapping text that takes the full width. Put it in a column, not in a row:
## inside a row it gets no width and wraps after every character.
static func para(text: String, size := 26, color := Color.WHITE) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## True while the current touch has moved far enough to count as a swipe, not a tap.
## Updated by Main._input, which sees every event before the controls do.
static var touch_moved := false
static var _touch_start := Vector2.ZERO
const TAP_SLOP := 20.0


static func track_touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_touch_start = event.position
		touch_moved = false
	elif event is InputEventScreenTouch and event.canceled:
		touch_moved = true  # the system took over the gesture; never treat it as a tap
	elif event is InputEventScreenDrag and event.position.distance_to(_touch_start) > TAP_SLOP:
		touch_moved = true


## A button that still lets its parent ScrollContainer scroll when dragged on a touch screen.
## A press that turned into a scroll does not trigger it.
static func button(text: String, on_press: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 64
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.disabled = not enabled
	b.pressed.connect(func():
		if not touch_moved:
			on_press.call())
	return b


static func hbox(children: Array = []) -> HBoxContainer:
	var h := HBoxContainer.new()
	for c in children:
		h.add_child(c)
	return h


static func vbox(children: Array = []) -> VBoxContainer:
	var v := VBoxContainer.new()
	for c in children:
		v.add_child(c)
	return v


static func expand(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func spacer() -> Control:
	return expand(Control.new())


static func sprite(slug: String, px: int, silhouette := false) -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if silhouette:
		t.modulate = Color(0, 0, 0, 0.85)
	Sprites.request(slug, t.set_texture)
	return t


## A pack "box": coloured panel with the pack name and its types. Add more rows to the returned VBox.
static func pack_panel(pack: int, parent: Control) -> VBoxContainer:
	var info: Dictionary = Data.PACKS[pack]
	var p := panel(info.color.darkened(0.6), info.color, 3)
	var col := vbox()
	col.add_child(label(info.name, 32, info.color.lightened(0.5)))
	col.add_child(para(info.desc, 20, TEXT_DIM))
	p.add_child(col)
	parent.add_child(p)
	return col


## "[-] $12.50 [+]  110% of market / sells 40% a day" for a listed card.
## `on_step` gets -1 or +1.
static func listing_price_row(id: int, on_step: Callable) -> HBoxContainer:
	var price: float = Game.listings[id].price
	var ratio: float = price / Game.value(id)
	var chance := Game.card_sell_chance(id)
	var minus := button("-", on_step.bind(-1))
	var plus := button("+", on_step.bind(1))
	minus.custom_minimum_size.x = 64
	plus.custom_minimum_size.x = 64
	var price_label := label(Game.money_text(price), 26, GOLD)
	price_label.custom_minimum_size.x = 130
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var info := vbox([
		label("%d%% of market" % roundi(ratio * 100), 20, TEXT_DIM),
		label("Sells %d%% / day" % roundi(chance * 100), 20, GOOD if chance >= 0.5 else (GOLD if chance >= 0.25 else BAD)),
	])
	info.add_theme_constant_override("separation", 0)
	return hbox([minus, price_label, plus, spacer(), info])


static func trend_text(id: int) -> String:
	var change: float = Game.prices[id] / Game.prev_prices[id] - 1.0
	if absf(change) < 0.005:
		return ""
	return "%+d%%" % roundi(change * 100)


static func trend_color(id: int) -> Color:
	return GOOD if Game.prices[id] >= Game.prev_prices[id] else BAD
