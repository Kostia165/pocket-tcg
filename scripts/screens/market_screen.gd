extends Screen
## Buy single cards from daily offers, list your cards for customers, or sell them to the dealer.

const PAGE_SIZE := 30

static var shown := PAGE_SIZE


func build() -> void:
	section("Today's offers")
	content.add_child(UI.para("New offers arrive every day. Prices vary: sometimes below market value, sometimes above.", 22, UI.TEXT_DIM))
	if Game.offers.is_empty():
		content.add_child(UI.para("Sold out. Come back tomorrow!", 24, UI.TEXT_DIM))
	for i in Game.offers.size():
		var o: Dictionary = Game.offers[i]
		var diff: float = o.price / Game.value(o.id) - 1.0
		var buy := UI.button("Buy\n%s" % Game.money_text(o.price), Game.buy_offer.bind(i), Game.money >= o.price)
		buy.custom_minimum_size.x = 150
		var row := _row(o.id, buy)
		row.info.add_child(UI.hbox([
			UI.label("Market %s" % Game.money_text(Game.value(o.id)), 20, UI.TEXT_DIM),
			UI.label("%+d%%" % roundi(diff * 100), 20, UI.GOOD if diff < 0 else UI.BAD),
		]))
		content.add_child(row.root)

	section("Your listings")
	content.add_child(UI.para("Cards you offer to customers. Each listed card has a daily chance to sell at your price: higher prices sell less often. List cards from the card popup (tap a card in Collection).", 22, UI.TEXT_DIM))
	if Game.listings.is_empty():
		content.add_child(UI.para("Nothing listed yet.", 24, UI.TEXT_DIM))
	for id in Game.listings:
		var unlist := UI.button("Unlist", Game.list_card.bind(id, -1))
		var row := _row(id, unlist, "x%d listed  ·  market %s" % [Game.listed(id), Game.money_text(Game.value(id))])
		row.body.add_child(UI.listing_price_row(id, func(steps: int): Game.change_list_price(id, steps)))
		content.add_child(row.root)

	section("Sell to dealer")
	content.add_child(UI.para("The dealer buys instantly at %d%% of the market value." % roundi(Game.DEALER_RATE * 100), 22, UI.TEXT_DIM))
	var extras := Game.duplicates_dealer_value()
	content.add_child(UI.button("Sell all duplicates (+%s)" % Game.money_text(extras), Game.sell_all_duplicates, extras > 0))

	var ids: Array = Game.owned.keys().filter(func(id: int): return Game.available(id) > 0)
	ids.sort_custom(func(a: int, b: int): return Game.value(a) > Game.value(b))
	if ids.is_empty():
		content.add_child(UI.para("You have no cards to sell. Open some packs!", 24, UI.TEXT_DIM))
	for id in ids.slice(0, shown):
		var sell := UI.button("Sell\n%s" % Game.money_text(Game.dealer_price(id)), Game.sell_card.bind(id, 1))
		sell.custom_minimum_size.x = 150
		var row := _row(id, sell, "x%d  ·  market %s" % [Game.available(id), Game.money_text(Game.value(id))])
		row.info.add_child(UI.label(UI.trend_text(id), 20, UI.trend_color(id)))
		content.add_child(row.root)
	if ids.size() > shown:
		content.add_child(UI.button("Show more (%d more cards)" % (ids.size() - shown), func():
			shown += PAGE_SIZE
			rebuild()))


## A card row: picture, name, rarity, optional subtitle and an action button.
## Returns {root, info, body}: add lines under the name to `info`, full-width lines to `body`.
func _row(id: int, action: Button, subtitle := "") -> Dictionary:
	var c: Dictionary = Data.card(id)
	var r: Dictionary = Data.rarity(id)
	var root := UI.panel(UI.PANEL, r.color, 2)
	var info := UI.vbox([
		UI.label(c.name, 26),
		UI.label(r.name, 20, r.color),
	])
	if subtitle != "":
		info.add_child(UI.label(subtitle, 20, UI.TEXT_DIM))
	info.add_theme_constant_override("separation", 2)
	var body := UI.vbox([UI.hbox([UI.sprite(c.slug, 96), UI.expand(info), action])])
	root.add_child(body)
	return {"root": root, "info": info, "body": body}
