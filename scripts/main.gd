class_name Main
extends Control
## Root of the app: top bar, current tab screen, bottom navigation and popups.

const TABS := [
	["Packs", preload("res://scripts/screens/packs_screen.gd")],
	["Shelves", preload("res://scripts/screens/shelves_screen.gd")],
	["Collection", preload("res://scripts/screens/collection_screen.gd")],
	["Market", preload("res://scripts/screens/market_screen.gd")],
]
const SettingsScreen := preload("res://scripts/screens/settings_screen.gd")
const AchievementsScreen := preload("res://scripts/screens/achievements_screen.gd")

var _money_label: Label
var _day_label: Label
var _holder: Control
var _nav_buttons: Array = []
var _screen: Screen
var _tab := 0
var _overlay: Control
var _back_tab := 0      # tab that "Back" returns to from a non-tab screen
var _toasts: VBoxContainer


func _ready() -> void:
	theme = UI.make_theme()
	get_tree().set_quit_on_go_back(false)

	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	var root := UI.vbox()
	margin.add_child(root)

	# Top bar
	var bar := UI.panel(UI.PANEL)
	_money_label = UI.label("", 32, UI.GOLD)
	_day_label = UI.label("", 22, UI.TEXT_DIM)
	var end_day := UI.button("End Day  >", _end_day)
	bar.add_child(UI.hbox([UI.vbox([_money_label, _day_label]), UI.spacer(), end_day]))
	root.add_child(bar)

	_holder = MarginContainer.new()
	_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_holder)

	# Bottom navigation
	var nav := UI.hbox()
	nav.add_theme_constant_override("separation", 8)
	for i in TABS.size():
		var b := UI.expand(UI.button(TABS[i][0], show_tab.bind(i)))
		b.custom_minimum_size.y = 84
		b.toggle_mode = true
		nav.add_child(b)
		_nav_buttons.append(b)
	root.add_child(nav)

	_toasts = UI.vbox()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toasts.offset_top = 150
	_toasts.offset_left = 24
	_toasts.offset_right = -24
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.z_index = 10
	add_child(_toasts)

	Game.changed.connect(_on_changed)
	Game.achievement_unlocked.connect(_show_achievement_toast)
	show_tab(0)
	_update_bar()


func show_tab(i: int) -> void:
	_open_screen(TABS[i][1], i)


func show_settings() -> void:
	_back_tab = 1
	_open_screen(SettingsScreen, -1)


func show_achievements() -> void:
	_back_tab = 2
	_open_screen(AchievementsScreen, -1)


## Leaves a non-tab screen (settings, achievements).
func go_back() -> void:
	show_tab(_back_tab)


func _open_screen(script: Script, tab: int) -> void:
	_tab = tab
	for j in _nav_buttons.size():
		_nav_buttons[j].set_pressed_no_signal(j == tab)
	if _screen:
		_screen.queue_free()
	_screen = script.new()
	_screen.main = self
	_holder.add_child(_screen)
	_screen.rebuild(false)


func _on_changed() -> void:
	_update_bar()
	if _screen:
		_screen.rebuild()


func _update_bar() -> void:
	_money_label.text = Game.money_text(Game.money)
	_day_label.text = "Day %d  ·  %d / %d cards collected" % [Game.day, Game.owned.size(), Data.cards.size()]


# --- Overlays ----------------------------------------------------------------

## Shows `body` in a centred popup over a dimmed background. Returns the overlay root.
func open_overlay(body: Control, dismiss_on_tap_outside := true) -> Control:
	close_overlay()
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if dismiss_on_tap_outside:
		dim.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and not e.pressed:
				close_overlay())
	_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)
	var p := UI.panel(UI.PANEL, UI.PANEL_LIGHT, 2)
	p.custom_minimum_size.x = minf(680, get_viewport_rect().size.x - 32)
	p.add_child(body)
	center.add_child(p)
	add_child(_overlay)
	return _overlay


func close_overlay() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null


func _input(event: InputEvent) -> void:
	UI.track_touch(event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _overlay:
			close_overlay()
		elif _tab == -1:
			go_back()
		elif _tab != 0:
			show_tab(0)
		else:
			get_tree().quit()


## Card details with sell buttons.
func show_card(id: int) -> void:
	var c: Dictionary = Data.card(id)
	var r: Dictionary = Data.rarity(id)
	var have := Game.count(id)
	var known := have > 0
	var col := UI.vbox()
	col.add_child(UI.sprite(c.slug, 240, not known))
	var title := UI.para(c.name if known else "??? (not collected yet)", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := UI.para("#%03d  ·  Gen %d  ·  %s  ·  %s pack" % [id, c.gen, c.type.capitalize(), Data.PACKS[c.pack].name], 22, UI.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var rl := UI.label(r.name, 30, r.color)
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(rl)
	col.add_child(UI.hbox([
		UI.label("Market value", 24, UI.TEXT_DIM), UI.spacer(),
		UI.label(UI.trend_text(id), 22, UI.trend_color(id)),
		UI.label(Game.money_text(Game.value(id)), 28, UI.GOLD),
	]))
	col.add_child(UI.hbox([
		UI.label("Dealer pays", 24, UI.TEXT_DIM), UI.spacer(),
		UI.label(Game.money_text(Game.dealer_price(id)), 28),
	]))
	col.add_child(UI.hbox([UI.label("You own", 24, UI.TEXT_DIM), UI.spacer(), UI.label("x%d" % have, 28)]))
	col.add_child(UI.hbox([
		UI.expand(UI.button("Dealer: sell 1", _in_popup.bind(id, Game.sell_card.bind(id, 1)), Game.available(id) > 0)),
		UI.expand(UI.button("Dealer: sell extras", _in_popup.bind(id, Game.sell_card.bind(id, Game.extra_copies(id))), Game.extra_copies(id) > 0)),
	]))

	if known:
		col.add_child(UI.label("Sell to customers", 26, UI.GOLD))
		var n := Game.listed(id)
		if n > 0:
			col.add_child(UI.listing_price_row(id, func(steps: int): _in_popup(id, Game.change_list_price.bind(id, steps))))
		col.add_child(UI.hbox([
			UI.expand(UI.button("List 1 for sale" if n == 0 else "List 1 more (%d listed)" % n,
				_in_popup.bind(id, Game.list_card.bind(id, 1)), Game.available(id) > 0)),
			UI.expand(UI.button("Unlist 1", _in_popup.bind(id, Game.list_card.bind(id, -1)), n > 0)),
		]))
	col.add_child(UI.button("Close", close_overlay))
	open_overlay(col)


## Runs a game action from the card popup and redraws the popup.
func _in_popup(id: int, action: Callable) -> void:
	action.call()
	show_card(id)


## Animated pack opening.
func show_opening(pack: int) -> void:
	var pulled := Game.open_pack(pack)
	if pulled.is_empty():
		return
	var info: Dictionary = Data.PACKS[pack]
	if Game.last_open_god:
		_show_pulls("GOD PACK!  " + info.name, UI.GOLD, pulled, show_opening.bind(pack), Game.inventory[pack])
	else:
		_show_pulls(info.name, info.color.lightened(0.4), pulled, show_opening.bind(pack), Game.inventory[pack])


func show_super_opening(i: int) -> void:
	var pulled := Game.open_super(i)
	if pulled.is_empty():
		return
	var color: Color = Data.RARITIES[Data.SUPER_RARITIES[i]].color
	_show_pulls(Data.super_name(i), color, pulled, show_super_opening.bind(i), Game.super_inventory[i])


## Pack opening popup: reveals the pulled cards one by one.
func _show_pulls(title_text: String, color: Color, pulled: Array, open_another: Callable, left: int) -> void:
	var col := UI.vbox()
	var title := UI.label(title_text, 34, color)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 3 if pulled.size() <= 6 else 4
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(grid)
	var total := 0.0
	for i in pulled.size():
		var id: int = pulled[i].id
		total += Game.value(id)
		var cell := UI.vbox()
		cell.add_theme_constant_override("separation", 2)
		var tag := UI.label("NEW!" if pulled[i].new else " ", 20, UI.GOLD)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(tag)
		var card := CardView.create(id, false, 130 if grid.columns == 3 else 96)
		card.custom_minimum_size.x = 196 if grid.columns == 3 else 146
		cell.add_child(card)
		cell.modulate.a = 0.0
		grid.add_child(cell)
		var tw := create_tween()
		tw.tween_interval(0.35 * i + 0.2)
		tw.tween_property(cell, "modulate:a", 1.0, 0.3)
	col.add_child(UI.label("Pulled value: %s" % Game.money_text(total), 26, UI.GOLD))
	col.add_child(UI.hbox([
		UI.expand(UI.button("Open another (%d)" % left, open_another, left > 0)),
		UI.expand(UI.button("Done", close_overlay)),
	]))
	open_overlay(col, false)


func _show_achievement_toast(id: String) -> void:
	var a: Dictionary = {}
	for x in Game.achievement_list():
		if x.id == id:
			a = x
	var toast := UI.panel(Color("3a3220"), UI.GOLD, 3)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text := UI.vbox([UI.label("Achievement unlocked!", 20, UI.GOLD), UI.label(a.name, 28), UI.para(a.desc, 20, UI.TEXT_DIM)])
	text.add_theme_constant_override("separation", 0)
	toast.add_child(text)
	_toasts.add_child(toast)
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(toast, "modulate:a", 0.0, 0.6)
	tw.tween_callback(toast.queue_free)


func _end_day() -> void:
	var report := Game.end_day()
	var col := UI.vbox()
	col.add_child(UI.label("Day %d report" % (Game.day - 1), 36, UI.GOLD))
	col.add_child(UI.para("Customers: %d" % report.customers, 24))
	if report.too_expensive > 0:
		col.add_child(UI.para("%d looked but did not buy (price too high or pack too expensive for them)" % report.too_expensive, 22, UI.TEXT_DIM))
	if report.no_stock > 0:
		col.add_child(UI.para("%d left because the shelves were empty" % report.no_stock, 22, UI.BAD))
	for p in Data.PACKS.size():
		if report.sold[p] > 0:
			col.add_child(UI.label("Sold %d x %s" % [report.sold[p], Data.PACKS[p].name], 24, Data.PACKS[p].color.lightened(0.4)))
	var shown_sales: Array = report.cards_sold.slice(0, 6)
	for sale in shown_sales:
		col.add_child(UI.label("Sold card %s for %s" % [Data.card(sale.id).name, Game.money_text(sale.price)], 22, Data.rarity(sale.id).color))
	if report.cards_sold.size() > shown_sales.size():
		col.add_child(UI.label("...and %d more cards" % (report.cards_sold.size() - shown_sales.size()), 22, UI.TEXT_DIM))
	col.add_child(UI.label("Revenue: %s" % Game.money_text(report.revenue + report.card_revenue), 30, UI.GOOD))
	if Game.shelves.all(func(s): return s.count == 0):
		col.add_child(UI.para("Your shelves are empty! Buy packs in the Packs tab and put them on the shelves.", 22, UI.BAD))
	if report.top_id >= 0:
		var c: Dictionary = Data.card(report.top_id)
		col.add_child(UI.para("Biggest price move in your collection: %s %+d%%" % [c.name, roundi(report.top_change * 100)], 22, UI.TEXT_DIM))
	col.add_child(UI.para("The market has new offers.", 22, UI.TEXT_DIM))
	col.add_child(UI.button("Start day %d" % Game.day, close_overlay))
	open_overlay(col)
