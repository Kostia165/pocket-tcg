extends Screen
## Supplier and inventory: buy packs, then open them or put them on the shelves.


func build() -> void:
	section("Packs")
	content.add_child(UI.para("Buy packs from the supplier. Bought packs go to your inventory, where you can open them or put them on your shelves for customers.", 22, UI.TEXT_DIM))
	for p in Data.PACKS.size():
		var info: Dictionary = Data.PACKS[p]
		var cost: int = info.cost
		var col := UI.pack_panel(p, content)
		col.add_child(UI.hbox([
			UI.label("$%d" % cost, 34, UI.GOLD),
			UI.label("%d cards per pack" % Data.card_count(p), 22),
			UI.spacer(),
			UI.label("Collected %d / %d" % [Game.unique_owned(p), Data.pack_count(p)], 22, UI.TEXT_DIM),
		]))
		var buy_row := UI.hbox()
		for n in [1, 5, 10]:
			buy_row.add_child(UI.expand(UI.button("Buy %d" % n, Game.buy_packs.bind(p, n), Game.money >= cost * n)))
		col.add_child(buy_row)

		var have: int = Game.inventory[p]
		col.add_child(UI.hbox([
			UI.label("In inventory: %d" % have, 26, UI.GOLD if have > 0 else Color.WHITE),
			UI.spacer(),
			UI.label("On shelves: %d" % Game.on_shelves(p), 22, UI.TEXT_DIM),
		]))
		var space := Game.shelf_space(p)
		col.add_child(UI.hbox([
			UI.expand(UI.button("Open", main.show_opening.bind(p), have > 0)),
			UI.expand(UI.button("Shelf +1", Game.stock.bind(p, 1), have > 0 and space > 0)),
			UI.expand(UI.button("Shelf all", Game.stock.bind(p), have > 0 and space > 0)),
		]))

	content.add_child(UI.para("Lucky! About 1 in %d packs is a God pack: every card is Legendary or better." % Data.settings.god_pack_odds, 22, UI.GOLD))

	section("Superpacks")
	content.add_child(UI.para("Very expensive packs of %d cards that are all of one rarity, from every card type. Choose the rarity when buying." % Data.SUPER_CARDS, 22, UI.TEXT_DIM))
	for i in Data.SUPER_RARITIES.size():
		var r: int = Data.SUPER_RARITIES[i]
		var rarity: Dictionary = Data.RARITIES[r]
		var price := Data.super_price(i)
		var have: int = Game.super_inventory[i]
		var box := UI.panel(rarity.color.darkened(0.75), rarity.color, 3)
		var col := UI.vbox()
		box.add_child(col)
		col.add_child(UI.hbox([
			UI.label(Data.super_name(i), 28, rarity.color),
			UI.spacer(),
			UI.label("$%d" % price, 30, UI.GOLD),
		]))
		col.add_child(UI.hbox([
			UI.label("Collected %d / %d" % [Game.unique_owned(-1, r), Data.rarity_ids[r].size()], 22, UI.TEXT_DIM),
			UI.spacer(),
			UI.label("In inventory: %d" % have, 22, UI.GOLD if have > 0 else Color.WHITE),
		]))
		col.add_child(UI.hbox([
			UI.expand(UI.button("Buy 1", Game.buy_super.bind(i, 1), Game.money >= price)),
			UI.expand(UI.button("Open", main.show_super_opening.bind(i), have > 0)),
		]))
		content.add_child(box)

	section("Drop rates per card")
	content.add_child(UI.para("Rarity depends on the generation. The table shows the chance for a normal card slot. Cards are worth more in pricier packs: x10 in the $100 pack and x100 in the $1000 pack.", 22, UI.TEXT_DIM))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_child(UI.expand(UI.label("Rarity", 20, UI.TEXT_DIM)))
	for p in Data.PACKS.size():
		grid.add_child(UI.label("$%d" % Data.PACKS[p].cost, 20, Data.PACKS[p].color.lightened(0.4)))
	for r in Data.RARITIES.size():
		var info: Dictionary = Data.RARITIES[r]
		grid.add_child(UI.expand(UI.label("G%d  %s" % [r + 1, info.name], 20, info.color)))
		for p in Data.PACKS.size():
			grid.add_child(UI.label(_percent(Data.drop_chance(p, r)), 20))
	content.add_child(grid)
	for p in Data.PACKS.size():
		var info: Dictionary = Data.PACKS[p]
		var normal := 0
		for m in info.slots:
			if m == 0:
				normal += 1
		content.add_child(UI.para("$%d %s: %d normal cards + %s" % [info.cost, info.name, normal, Data.guarantee_text(p)], 20, info.color.lightened(0.4)))


func _percent(v: float) -> String:
	return "%.1f%%" % (v * 100.0) if v >= 0.001 else "<0.1%"
