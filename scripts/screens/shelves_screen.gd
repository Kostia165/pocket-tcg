extends Screen
## Shop shelves: what is on sale, selling prices and buying more shelves.


func build() -> void:
	section("Selling prices")
	content.add_child(UI.para("Customers come at the end of each day. The higher your price compared to the supplier price, the less often they buy. At double the supplier price nobody buys.", 22, UI.TEXT_DIM))
	for p in Data.PACKS.size():
		var info: Dictionary = Data.PACKS[p]
		var box := UI.panel(UI.PANEL, info.color, 2)
		var col := UI.vbox()
		box.add_child(col)
		var chance := Game.buy_chance(p)
		col.add_child(UI.hbox([
			UI.label(info.name, 26, info.color.lightened(0.4)), UI.spacer(),
			UI.label("Supplier $%d" % info.cost, 22, UI.TEXT_DIM),
		]))
		var price_label := UI.label("$%d" % Game.retail[p], 30, UI.GOLD)
		price_label.custom_minimum_size.x = 120
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var minus := UI.button("-", Game.change_retail.bind(p, -1))
		var plus := UI.button("+", Game.change_retail.bind(p, 1))
		minus.custom_minimum_size.x = 72
		plus.custom_minimum_size.x = 72
		col.add_child(UI.hbox([
			minus, price_label, plus, UI.spacer(),
			UI.vbox([
				UI.label("%d%% of supplier" % roundi(100.0 * Game.retail[p] / info.cost), 20, UI.TEXT_DIM),
				UI.label("Buy chance %d%%" % roundi(chance * 100), 22, _chance_color(chance)),
			]),
		]))
		content.add_child(box)

	var r := Game.customer_range()
	section("Shelves  %d / %d" % [Game.shelves.size(), Game.max_shelves()])
	content.add_child(UI.para("Each shelf holds %d packs. More shelves bring more customers: now %d-%d per day." % [Game.shelf_capacity(), r.x, r.y], 22, UI.TEXT_DIM))
	content.add_child(UI.button("Restock all shelves from inventory", Game.restock_all))
	for i in Game.shelves.size():
		content.add_child(_shelf_row(i))
	if Game.shelves.size() < Game.max_shelves():
		var cost := Game.shelf_cost()
		content.add_child(UI.button("Buy new shelf for $%d" % cost, Game.buy_shelf, Game.money >= cost))
	else:
		content.add_child(UI.para("Your shop is full: all shelves bought.", 22, UI.TEXT_DIM))

	section("Stats")
	var stats := UI.panel()
	stats.add_child(UI.vbox([
		UI.label("Packs opened: %d (God packs: %d)" % [Game.stats.opened, Game.stats.god_packs], 24),
		UI.label("Packs sold to customers: %d" % Game.stats.packs_sold, 24),
		UI.label("Cards sold to customers: %d" % Game.stats.cards_sold, 24),
		UI.label("Shop revenue: %s" % Game.money_text(Game.stats.revenue), 24),
		UI.label("Collection market value: %s" % Game.money_text(Game.collection_value()), 24),
	]))
	content.add_child(stats)
	content.add_child(UI.button("Settings", main.show_settings))


func _shelf_row(i: int) -> Control:
	var s: Dictionary = Game.shelves[i]
	var box := UI.panel(UI.PANEL_LIGHT if s.pack < 0 else Data.PACKS[s.pack].color.darkened(0.6))
	var col := UI.vbox()
	box.add_child(col)
	if s.pack < 0:
		col.add_child(UI.label("Shelf %d  ·  empty" % (i + 1), 26, UI.TEXT_DIM))
		var row := UI.hbox()
		for p in Data.PACKS.size():
			var b := UI.button("$%d (%d)" % [Data.PACKS[p].cost, Game.inventory[p]], Game.stock_shelf.bind(i, p), Game.inventory[p] > 0)
			row.add_child(UI.expand(b))
		col.add_child(UI.label("Stock with (in inventory):", 20, UI.TEXT_DIM))
		col.add_child(row)
	else:
		var info: Dictionary = Data.PACKS[s.pack]
		col.add_child(UI.hbox([
			UI.label("Shelf %d  ·  %s" % [i + 1, info.name], 26, info.color.lightened(0.5)), UI.spacer(),
			UI.label("%d / %d" % [s.count, Game.shelf_capacity()], 26, UI.GOLD if s.count > 0 else UI.BAD),
		]))
		col.add_child(UI.hbox([
			UI.expand(UI.button("Refill (%d in inventory)" % Game.inventory[s.pack], Game.stock_shelf.bind(i, s.pack),
				Game.inventory[s.pack] > 0 and s.count < Game.shelf_capacity())),
			UI.button("Clear", Game.clear_shelf.bind(i)),
		]))
	return box


func _chance_color(chance: float) -> Color:
	if chance >= 0.7:
		return UI.GOOD
	if chance >= 0.4:
		return UI.GOLD
	return UI.BAD
