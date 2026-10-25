extends Screen
## Game settings: shelf economy, drop chances and clearing progress.


func build() -> void:
	content.add_child(UI.button("<  Back", main.go_back))

	section("Shelves")
	var s: Dictionary = Data.settings
	_stepper("Second shelf price", "$%d" % s.shelf_price, func(d): s.shelf_price = maxf(0.0, s.shelf_price + d * 50.0))
	_stepper("Next shelf price multiplier", "x%.1f" % s.shelf_growth, func(d): s.shelf_growth = maxf(1.0, snappedf(s.shelf_growth + d * 0.1, 0.1)))
	_stepper("Max shelves", str(s.max_shelves), func(d): s.max_shelves = clampi(s.max_shelves + d, 1, 50))
	_stepper("Packs per shelf", str(s.shelf_capacity), func(d): s.shelf_capacity = clampi(s.shelf_capacity + d, 1, 100))
	content.add_child(UI.para("Next shelf now costs $%d." % Game.shelf_cost(), 22, UI.TEXT_DIM))

	section("God pack")
	_stepper("Chance per pack: 1 in", str(s.god_pack_odds),
		func(d): s.god_pack_odds = clampi(s.god_pack_odds + d * (1 if s.god_pack_odds + d <= 10 else 10), 1, 10000))
	content.add_child(UI.para("A God pack is a normal pack where every card is Legendary or better.", 22, UI.TEXT_DIM))

	section("Superpack prices")
	for i in Data.SUPER_RARITIES.size():
		var rarity: Dictionary = Data.RARITIES[Data.SUPER_RARITIES[i]]
		_stepper(Data.super_name(i), "$%d" % Data.super_price(i),
			func(d): s.super_price[i] = maxf(500.0, s.super_price[i] + d * 500.0))

	section("Drop chances")
	content.add_child(UI.para("Chance in % for a normal card slot to be of each rarity. If a pack's values do not add up to 100%, they are scaled to 100% (the real chance is shown on the right). Guaranteed slots use the same chances, limited to the allowed rarities.", 22, UI.TEXT_DIM))
	for p in Data.PACKS.size():
		var col := UI.pack_panel(p, content)
		var drop: Array = s.drop[p]
		var total := 0.0
		for x in drop:
			total += x
		for r in Data.RARITIES.size():
			var rarity: Dictionary = Data.RARITIES[r]
			var row := _stepper_row("G%d %s" % [r + 1, rarity.name], _format(drop[r]), func(d): drop[r] = _step_drop(drop[r], d), rarity.color)
			var pct := UI.label("%.2f%%" % (Data.drop_chance(p, r) * 100.0), 20, UI.TEXT_DIM)
			pct.custom_minimum_size.x = 90
			pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(pct)
			col.add_child(row)
		col.add_child(UI.label("Total: %.2f%%" % total, 22, UI.GOOD if absf(total - 100.0) < 0.05 else UI.GOLD))

	section("Reset")
	content.add_child(UI.button("Reset settings to defaults", func():
		Data.reset_settings()
		rebuild()))
	content.add_child(UI.button("Clear game progress", _confirm_clear))


## A labelled value with - and + buttons. `change` gets -1 or +1 and edits Data.settings.
func _stepper(title: String, value_text: String, change: Callable) -> void:
	content.add_child(_stepper_row(title, value_text, change))


func _stepper_row(title: String, value_text: String, change: Callable, color := Color.WHITE) -> HBoxContainer:
	var l := UI.label(title, 22, color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var value := UI.label(value_text, 24, UI.GOLD)
	value.custom_minimum_size.x = 96
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := UI.hbox([l])
	row.add_theme_constant_override("separation", 6)
	for d in [-1, 1]:
		var b := UI.button("-" if d < 0 else "+", func():
			change.call(d)
			Data.save_settings()
			rebuild())
		b.custom_minimum_size.x = 60
		row.add_child(b)
		if d < 0:
			row.add_child(value)
	return row


## Steps of 1 above 10%, 0.1 above 1%, 0.01 below, so small chances stay adjustable.
func _step_drop(v: float, d: int) -> float:
	var probe := v if d > 0 else v - 0.0001
	var step := 1.0 if probe >= 10.0 else (0.1 if probe >= 1.0 else 0.01)
	return maxf(0.0, snappedf(v + d * step, 0.01))


func _format(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else str(snappedf(v, 0.01))


func _confirm_clear() -> void:
	main.open_overlay(UI.vbox([
		UI.para("Clear all progress? Money, packs, shelves and cards will be lost. Settings are kept.", 28),
		UI.hbox([
			UI.expand(UI.button("Cancel", main.close_overlay)),
			UI.expand(UI.button("Clear", func():
				main.close_overlay()
				Game.new_game()
				main.show_tab(0))),
		]),
	]))
