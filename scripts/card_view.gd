class_name CardView
extends PanelContainer
## A collectible card tile: sprite, name, rarity and price, framed in the rarity colour.

signal tapped(id: int)

const TAP_SLOP := 24.0

var card_id := 0
var _press_pos := Vector2.ZERO
var _pressing := false


static func create(id: int, show_owned := true, img_px := 150) -> CardView:
	var v := CardView.new()
	v.card_id = id
	v._build(show_owned, img_px)
	return v


func _build(show_owned: bool, img_px: int) -> void:
	var c: Dictionary = Data.card(card_id)
	var r: Dictionary = Data.rarity(card_id)
	var have := Game.count(card_id)
	var known := have > 0 or not show_owned
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_stylebox_override("panel", UI.box(UI.PANEL, 14, r.color if known else UI.PANEL_LIGHT, 4))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	var top := UI.hbox([
		UI.label("#%03d" % card_id, 18, UI.TEXT_DIM),
		UI.spacer(),
		UI.label("x%d" % have if show_owned and have > 0 else "", 20, UI.GOLD),
	])
	col.add_child(top)
	col.add_child(UI.sprite(c.slug, img_px, not known))
	var name_label := UI.label(c.name if known else "???", 22)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(name_label)
	var rarity_label := UI.label(r.name, 18, r.color)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(rarity_label)
	var price_label := UI.label(Game.money_text(Game.value(card_id)) if known else "", 20, UI.GOLD)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(price_label)
	for l in col.find_children("*", "Control", true, false):
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE


# Tap detection that tolerates the list being scrolled: only a short, still press counts.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_press_pos = event.global_position
		elif _pressing:
			_pressing = false
			if event.global_position.distance_to(_press_pos) < TAP_SLOP and not UI.touch_moved:
				tapped.emit(card_id)
	elif event is InputEventMouseMotion and _pressing:
		if event.global_position.distance_to(_press_pos) >= TAP_SLOP:
			_pressing = false
