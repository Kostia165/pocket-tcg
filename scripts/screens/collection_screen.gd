extends Screen
## Binder of all cards with filters and pages.

const PER_PAGE := 24

# Kept as static so filters survive switching tabs.
static var pack_filter := -1
static var rarity_filter := -1
static var owned_only := false
static var page := 0


func build() -> void:
	var have := Game.owned.size()
	var total := Data.cards.size()
	content.add_child(UI.hbox([
		UI.label("Collected %d / %d  (%d%%)" % [have, total, roundi(100.0 * have / total)], 28, UI.GOLD),
	]))
	content.add_child(UI.label("Collection value: %s" % Game.money_text(Game.collection_value()), 22, UI.TEXT_DIM))
	content.add_child(UI.button("Achievements  %d / %d" % [Game.achievements.size(), Game.achievement_list().size()], main.show_achievements))

	var pack_names := ["All packs"]
	for p in Data.PACKS.size():
		pack_names.append("%s (%d/%d)" % [Data.PACKS[p].name, Game.unique_owned(p), Data.pack_count(p)])
	var rarity_names := ["All rarities"]
	for r in Data.RARITIES.size():
		var n := 0
		for p in Data.PACKS.size():
			if pack_filter < 0 or pack_filter == p:
				n += Data.pack_count(p, r)
		rarity_names.append("%s (%d/%d)" % [Data.RARITIES[r].name, Game.unique_owned(pack_filter, r), n])

	var pack_label: String = "All packs" if pack_filter < 0 else Data.PACKS[pack_filter].name
	var rarity_label: String = "All rarities" if rarity_filter < 0 else Data.RARITIES[rarity_filter].name
	content.add_child(UI.hbox([
		UI.expand(UI.button(pack_label + "  v", _choose.bind(pack_names, func(i: int): pack_filter = i - 1))),
		UI.expand(UI.button(rarity_label + "  v", _choose.bind(rarity_names, func(i: int): rarity_filter = i - 1))),
	]))
	content.add_child(UI.button("Only collected: %s" % ("ON" if owned_only else "OFF"), func():
		owned_only = not owned_only
		_reset_page()))

	var ids := []
	for c in Data.cards:
		if pack_filter >= 0 and c.pack != pack_filter:
			continue
		if rarity_filter >= 0 and c.gen - 1 != rarity_filter:
			continue
		if owned_only and Game.count(c.id) == 0:
			continue
		ids.append(c.id)

	var pages := maxi(1, ceili(ids.size() / float(PER_PAGE)))
	page = clampi(page, 0, pages - 1)
	if ids.is_empty():
		content.add_child(UI.label("No cards here yet.", 24, UI.TEXT_DIM))

	var grid := GridContainer.new()
	grid.columns = 3
	for id in ids.slice(page * PER_PAGE, (page + 1) * PER_PAGE):
		var card := CardView.create(id)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.tapped.connect(main.show_card)
		grid.add_child(card)
	content.add_child(grid)

	var page_label := UI.label("Page %d / %d" % [page + 1, pages], 24)
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(UI.hbox([
		UI.expand(UI.button("<  Prev", _go_page.bind(-1), page > 0)),
		UI.expand(page_label),
		UI.expand(UI.button("Next  >", _go_page.bind(1), page < pages - 1)),
	]))


func _go_page(delta: int) -> void:
	page += delta
	rebuild(false)


## Shows the options in a popup; `apply` gets the chosen index.
func _choose(options: Array, apply: Callable) -> void:
	var col := UI.vbox()
	for i in options.size():
		col.add_child(UI.button(options[i], func():
			apply.call(i)
			main.close_overlay()
			_reset_page()))
	main.open_overlay(col)


func _reset_page() -> void:
	page = 0
	rebuild.call_deferred(false)
