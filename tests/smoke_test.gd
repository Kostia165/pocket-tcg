extends Node
## Headless smoke test of the game rules and screens.
## Run:  Godot_console.exe --headless --path . res://tests/smoke_test.tscn
## Exits with code 0 when every check passes, 1 otherwise. The player's save and
## settings on this PC are restored afterwards.

var _failures := 0


func _ready() -> void:
	var saved_game: Variant = _read(Game.SAVE_PATH)
	var saved_settings: Variant = _read(Data.SETTINGS_PATH)
	Data.reset_settings()
	Game.new_game()

	_test_data()
	_test_prices()
	_test_packs_and_shelves()
	_test_cards_and_market()
	_test_superpacks_and_god_packs()
	_test_achievements()
	_test_save_load()
	await _test_screens()

	_restore(Game.SAVE_PATH, saved_game)
	_restore(Data.SETTINGS_PATH, saved_settings)
	print("SMOKE TEST: %s" % ("PASSED" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


func check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL: ", what)


func _test_data() -> void:
	check(Data.cards.size() == 1025, "1025 cards loaded")
	for p in Data.PACKS.size():
		for r in Data.RARITIES.size():
			check(not Data.pools[p][r].is_empty(), "pack %d has rarity %d cards" % [p, r])
		var prev := 2.0
		for r in Data.RARITIES.size():
			var c := Data.drop_chance(p, r)
			check(c <= prev, "pack %d drop chance falls with rarity" % p)
			prev = c


func _test_prices() -> void:
	for c in Data.cards:
		var r: Dictionary = Data.rarity(c.id)
		var m := Data.price_mult(c.pack)
		var v := Game.value(c.id)
		check(v >= r.min * m * 0.69 and v <= r.max * m * 1.31, "card %d price scales with its pack" % c.id)
	check(is_equal_approx(Data.price_mult(2), 100.0), "x100 multiplier for the $1000 pack")


func _test_packs_and_shelves() -> void:
	Game.money = 100000
	check(Game.buy_packs(0, 25), "buy packs")
	check(Game.inventory[0] == 25, "packs go to inventory")
	Game.stock(0)
	check(Game.shelves[0].count == Game.shelf_capacity(), "shelf filled to capacity")
	check(Game.buy_shelf(), "buy shelf")
	Game.stock(0)
	check(Game.on_shelves(0) == 2 * Game.shelf_capacity(), "second shelf stocked")
	Data.settings.god_pack_odds = 1000000  # keep this test deterministic
	var pulled := Game.open_pack(0)
	check(pulled.size() == Data.card_count(0), "pack has the right number of cards")
	check(Data.rarity_of(pulled[-1].id) >= Data.PACKS[0].slots[-1], "guaranteed slot respected")
	Game.retail[0] = Data.PACKS[0].cost * 2
	check(is_zero_approx(Game.buy_chance(0)), "nobody buys at double price")
	Game.retail[0] = Data.PACKS[0].cost
	var before := Game.money
	Game.end_day()
	check(Game.money > before, "customers bought packs at supplier price")


func _test_cards_and_market() -> void:
	var id: int = Game.owned.keys()[0]
	Game.owned[id] = 3
	Game.list_card(id, 2)
	check(Game.listed(id) == 2 and Game.available(id) == 1, "listing reserves copies")
	Game.sell_card(id, 5)
	check(Game.count(id) == 2, "dealer only buys copies that are not listed")
	Game.listings[id].price = Game.value(id) * 2
	check(is_zero_approx(Game.card_sell_chance(id)), "overpriced listing never sells")
	Game.list_card(id, -2)
	check(not Game.listings.has(id), "unlisting removes the listing")
	for o in Game.offers:
		var f: float = o.price / Game.value(o.id)
		check(f >= 0.69 and f <= 1.41, "offer price within range")


func _test_superpacks_and_god_packs() -> void:
	check(Game.buy_super(2), "buy secret superpack")
	for c in Game.open_super(2):
		check(Data.rarity_of(c.id) == Data.SUPER_RARITIES[2], "superpack card has chosen rarity")
	Data.settings.god_pack_odds = 1
	Game.inventory[1] = 1
	var pulled := Game.open_pack(1)
	check(Game.last_open_god, "god pack at 1 in 1 odds")
	for c in pulled:
		check(Data.rarity_of(c.id) >= Data.GOD_MIN_RARITY, "god pack card is Legendary+")
	Data.reset_settings()


func _test_achievements() -> void:
	for id in ["first_pack_0", "first_super", "god_pack", "money_10000"]:
		check(Game.achievements.has(id), "achievement %s unlocked" % id)
	check(Game.achievement_list().size() == 28, "28 achievements defined")


func _test_save_load() -> void:
	var money := Game.money
	var cards := Game.owned.size()
	Game.save_game()
	check(Game.load_game(), "save loads")
	check(is_equal_approx(Game.money, money) and Game.owned.size() == cards, "save round-trips")


func _test_screens() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	for t in main.TABS.size():
		main.show_tab(t)
		await get_tree().process_frame
	main.show_settings()
	await get_tree().process_frame
	main.show_achievements()
	await get_tree().process_frame
	main.show_card(Game.owned.keys()[0])
	Game.inventory[0] = 1
	main.show_opening(0)
	await get_tree().process_frame
	check(true, "screens built")
	main.queue_free()


func _read(path: String) -> Variant:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else null


func _restore(path: String, text: Variant) -> void:
	if text == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	else:
		FileAccess.open(path, FileAccess.WRITE).store_string(text)
