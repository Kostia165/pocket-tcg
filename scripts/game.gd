extends Node
## Player state, economy rules and save/load.

signal changed
signal achievement_unlocked(id: String)

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2
const PRICE_MODEL := 2  # 2: card prices scale with pack cost (saves without it are migrated)
const START_MONEY := 100.0
const DEALER_RATE := 0.6      # dealer pays this share of a card's market value
const OFFER_COUNT := 6
const OFFER_WEIGHTS := [20, 18, 16, 13, 11, 9, 6, 4, 3]  # rarity mix of market offers
const OFFER_PRICE_RANGE := Vector2(0.7, 1.4)              # offer price vs market value
const DEFAULT_MARKUP := 1.3
const LIST_STEP := 0.05       # card listing price changes in 5% of market value
const MONEY_GOALS := [1000, 10000, 100000, 1000000]

var money := 0.0
var day := 1
var inventory: Array = [0, 0, 0]  # unopened packs, by pack type
var super_inventory: Array = [0, 0, 0]  # unopened superpacks, by Data.SUPER_RARITIES index
var shelves: Array = []           # [{pack, count}]; pack is -1 for a shelf never stocked
var retail: Array = [0, 0, 0]     # selling price per pack type
var owned: Dictionary = {}        # card id -> count (includes copies listed for sale)
var listings: Dictionary = {}     # card id -> {count, price}: copies offered to customers
var prices: Dictionary = {}       # card id -> market value
var prev_prices: Dictionary = {}  # card id -> market value yesterday
var offers: Array = []            # [{id, price}]
var stats: Dictionary = {}
var achievements: Dictionary = {}  # achievement id -> day it was unlocked
var last_open_god := false         # whether the last open_pack() was a God pack


func _ready() -> void:
	randomize()
	if not load_game():
		new_game()


# --- Lifecycle ---------------------------------------------------------------

func new_game() -> void:
	money = START_MONEY
	day = 1
	inventory = [0, 0, 0]
	super_inventory = [0, 0, 0]
	shelves = [{"pack": -1, "count": 0}]
	retail = []
	for p in Data.PACKS:
		retail.append(roundi(p.cost * DEFAULT_MARKUP))
	owned = {}
	listings = {}
	prices = {}
	for c in Data.cards:
		prices[c.id] = _random_price(c.id)
	prev_prices = prices.duplicate()
	stats = {"opened": 0, "packs_sold": 0, "cards_sold": 0, "revenue": 0.0, "god_packs": 0}
	achievements = {}
	_make_offers()
	_commit()


func _random_price(id: int) -> float:
	var r := Data.price_range(id)
	return snappedf(randf_range(r.x, r.y), 0.01)


func save_game() -> void:
	var data := {
		"version": SAVE_VERSION, "price_model": PRICE_MODEL, "money": money, "day": day, "inventory": inventory,
		"super_inventory": super_inventory, "achievements": achievements,
		"shelves": shelves, "retail": retail, "owned": owned, "listings": listings,
		"prices": prices, "prev_prices": prev_prices, "offers": offers, "stats": stats,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != SAVE_VERSION:
		return false
	money = data.money
	day = int(data.day)
	inventory = data.inventory.map(func(v): return int(v))
	super_inventory = data.get("super_inventory", [0, 0, 0]).map(func(v): return int(v))
	achievements = data.get("achievements", {})
	shelves = data.shelves.map(func(s): return {"pack": int(s.pack), "count": int(s.count)})
	retail = data.retail.map(func(v): return int(v))
	owned = _int_keys(data.owned, true)
	listings = {}
	for k in data.get("listings", {}):
		var l: Dictionary = data.listings[k]
		listings[int(k)] = {"count": int(l.count), "price": float(l.price)}
	prices = _int_keys(data.prices, false)
	prev_prices = _int_keys(data.prev_prices, false)
	offers = data.offers.map(func(o): return {"id": int(o.id), "price": float(o.price)})
	stats = data.stats
	stats.merge({"cards_sold": 0, "god_packs": 0})
	if int(data.get("price_model", 1)) < PRICE_MODEL:
		_scale_old_prices()
	# Fill in anything missing (e.g. cards added to the database after the save was made).
	for c in Data.cards:
		if not prices.has(c.id):
			prices[c.id] = _random_price(c.id)
			prev_prices[c.id] = prices[c.id]
	return true


## Older saves priced every card as if it came from the cheapest pack: apply the pack multiplier.
func _scale_old_prices() -> void:
	for id in prices:
		var m := Data.price_mult(Data.card(id).pack)
		prices[id] = snappedf(prices[id] * m, 0.01)
		prev_prices[id] = snappedf(prev_prices[id] * m, 0.01)
	for id in listings:
		listings[id].price = snappedf(listings[id].price * Data.price_mult(Data.card(id).pack), 0.01)
	for o in offers:
		o.price = snappedf(o.price * Data.price_mult(Data.card(o.id).pack), 0.01)


func _int_keys(d: Dictionary, int_values: bool) -> Dictionary:
	var out := {}
	for k in d:
		out[int(k)] = int(d[k]) if int_values else float(d[k])
	return out


func _commit() -> void:
	_check_achievements()
	save_game()
	changed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


# --- Queries -----------------------------------------------------------------

func value(id: int) -> float:
	return prices[id]


func dealer_price(id: int) -> float:
	return snappedf(prices[id] * DEALER_RATE, 0.01)


func count(id: int) -> int:
	return owned.get(id, 0)


func listed(id: int) -> int:
	return listings[id].count if listings.has(id) else 0


## Copies that are not listed for sale.
func available(id: int) -> int:
	return count(id) - listed(id)


func unique_owned(pack := -1, rarity := -1) -> int:
	var n := 0
	for id in owned:
		var c: Dictionary = Data.card(id)
		if (pack < 0 or c.pack == pack) and (rarity < 0 or c.gen - 1 == rarity):
			n += 1
	return n


func collection_value() -> float:
	var total := 0.0
	for id in owned:
		total += prices[id] * owned[id]
	return total


## Copies beyond the first that are not listed for sale.
func extra_copies(id: int) -> int:
	return mini(available(id), count(id) - 1)


func duplicates_dealer_value() -> float:
	var total := 0.0
	for id in owned:
		total += dealer_price(id) * extra_copies(id)
	return total


func shelf_capacity() -> int:
	return Data.settings.shelf_capacity


func max_shelves() -> int:
	return Data.settings.max_shelves


func on_shelves(pack: int) -> int:
	var n := 0
	for s in shelves:
		if s.pack == pack:
			n += s.count
	return n


## How many more packs of this type fit on the shelves.
func shelf_space(pack: int) -> int:
	var n := 0
	for s in shelves:
		if s.pack == pack or s.count == 0:
			n += maxi(0, shelf_capacity() - s.count)
	return n


func shelf_cost() -> int:
	return roundi(Data.settings.shelf_price * pow(Data.settings.shelf_growth, shelves.size() - 1))


func price_step(pack: int) -> int:
	return maxi(1, Data.PACKS[pack].cost / 10)


## Chance that a customer who wants this pack accepts the price: 100% at or below the
## supplier price, falling to 0% at double the supplier price.
func buy_chance(pack: int) -> float:
	var ratio: float = float(retail[pack]) / Data.PACKS[pack].cost
	return clampf(2.0 - ratio, 0.0, 1.0)


## Daily chance that one listed copy of a card sells: 50% at market value, more when
## cheaper (up to 95%), none at 150% of market value or more.
func card_sell_chance(id: int) -> float:
	if not listings.has(id):
		return 0.0
	var ratio: float = listings[id].price / prices[id]
	return clampf(1.5 - ratio, 0.0, 0.95)


func customer_range() -> Vector2i:
	return Vector2i(1 + 3 * shelves.size(), 3 + 3 * shelves.size())


static func money_text(v: float) -> String:
	return "$%.2f" % v


# --- Pack actions ------------------------------------------------------------

func buy_packs(pack: int, n: int) -> bool:
	var cost: int = Data.PACKS[pack].cost * n
	if money < cost:
		return false
	money -= cost
	inventory[pack] += n
	_unlock("first_pack_%d" % pack)
	_commit()
	return true


func buy_super(i: int, n := 1) -> bool:
	var cost := Data.super_price(i) * n
	if money < cost:
		return false
	money -= cost
	super_inventory[i] += n
	_unlock("first_super")
	_commit()
	return true


## Opens one superpack: every card has the superpack's rarity. Returns [{id, new}].
func open_super(i: int) -> Array:
	if super_inventory[i] <= 0:
		return []
	super_inventory[i] -= 1
	stats.opened += 1
	var result := []
	for k in Data.SUPER_CARDS:
		var id: int = Data.rarity_ids[Data.SUPER_RARITIES[i]].pick_random()
		result.append({"id": id, "new": count(id) == 0})
		owned[id] = count(id) + 1
	_commit()
	return result


## Moves up to `n` packs from inventory to the shelves: same-type shelves first, then
## never-used shelves, then empty shelves of another type.
func stock(pack: int, n := 1 << 30) -> void:
	n = mini(n, inventory[pack])
	for pass_idx in 3:
		for s in shelves:
			if n <= 0:
				break
			var fits: bool = [s.pack == pack, s.pack == -1, s.count == 0][pass_idx]
			if not fits:
				continue
			s.pack = pack
			var moved := clampi(shelf_capacity() - s.count, 0, n)
			s.count += moved
			inventory[pack] -= moved
			n -= moved
	_commit()


func stock_shelf(i: int, pack: int) -> void:
	var s: Dictionary = shelves[i]
	if s.count > 0 and s.pack != pack:
		return
	s.pack = pack
	var moved := clampi(shelf_capacity() - s.count, 0, inventory[pack])
	s.count += moved
	inventory[pack] -= moved
	_commit()


func restock_all() -> void:
	for s in shelves:
		if s.pack >= 0:
			var moved := clampi(shelf_capacity() - s.count, 0, inventory[s.pack])
			s.count += moved
			inventory[s.pack] -= moved
	_commit()


func clear_shelf(i: int) -> void:
	var s: Dictionary = shelves[i]
	if s.pack >= 0:
		inventory[s.pack] += s.count
	s.pack = -1
	s.count = 0
	_commit()


func buy_shelf() -> bool:
	if shelves.size() >= max_shelves() or money < shelf_cost():
		return false
	money -= shelf_cost()
	shelves.append({"pack": -1, "count": 0})
	_commit()
	return true


func change_retail(pack: int, steps: int) -> void:
	var step := price_step(pack)
	retail[pack] = clampi(retail[pack] + steps * step, step, Data.PACKS[pack].cost * 5)
	_commit()


## Opens one pack from the inventory. Returns [{id, new}] in reveal order.
## With a 1 in `god_pack_odds` chance it is a God pack: every card Legendary or better.
func open_pack(pack: int) -> Array:
	if inventory[pack] <= 0:
		return []
	inventory[pack] -= 1
	stats.opened += 1
	last_open_god = randi() % maxi(1, Data.settings.god_pack_odds) == 0
	if last_open_god:
		stats.god_packs += 1
		_unlock("god_pack")
	var result := []
	for slot_min in Data.PACKS[pack].slots:
		var min_r: int = maxi(slot_min, Data.GOD_MIN_RARITY) if last_open_god else slot_min
		var id: int = Data.roll_card(pack, min_r)
		result.append({"id": id, "new": count(id) == 0})
		owned[id] = count(id) + 1
	_commit()
	return result


# --- Card actions ------------------------------------------------------------

func sell_card(id: int, n := 1) -> void:
	n = mini(n, available(id))
	if n <= 0:
		return
	money += dealer_price(id) * n
	_remove_copies(id, n)
	_commit()


func _remove_copies(id: int, n: int) -> void:
	owned[id] -= n
	if owned[id] <= 0:
		owned.erase(id)


func sell_all_duplicates() -> float:
	var earned := 0.0
	for id in owned.keys():
		var extra := extra_copies(id)
		if extra > 0:
			earned += dealer_price(id) * extra
			owned[id] -= extra
	money += earned
	_commit()
	return earned


## Offers `n` more copies to customers (negative takes them back). New listings start at market value.
func list_card(id: int, n: int) -> void:
	var total := clampi(listed(id) + n, 0, count(id))
	if total == 0:
		listings.erase(id)
	elif listings.has(id):
		listings[id].count = total
	else:
		listings[id] = {"count": total, "price": snappedf(prices[id], 0.01)}
	_commit()


func change_list_price(id: int, steps: int) -> void:
	if not listings.has(id):
		return
	var step := maxf(0.01, snappedf(prices[id] * LIST_STEP, 0.01))
	listings[id].price = maxf(0.01, snappedf(listings[id].price + steps * step, 0.01))
	_commit()


func buy_offer(index: int) -> bool:
	var o: Dictionary = offers[index]
	if money < o.price:
		return false
	money -= o.price
	owned[o.id] = count(o.id) + 1
	offers.remove_at(index)
	_commit()
	return true


# --- Achievements ------------------------------------------------------------

## All achievements in display order: [{id, name, desc}].
func achievement_list() -> Array:
	var list := []
	for r in Data.RARITIES.size():
		var rn: String = Data.RARITIES[r].name
		list.append({"id": "first_%d" % r, "name": "First %s" % rn, "desc": "Get your first %s card" % rn})
	for r in Data.RARITIES.size():
		var rn: String = Data.RARITIES[r].name
		list.append({"id": "complete_%d" % r, "name": "%s Master" % rn,
			"desc": "Collect all %d %s cards" % [Data.rarity_ids[r].size(), rn]})
	list.append({"id": "all_cards", "name": "Gotta Catch 'Em All", "desc": "Collect all %d cards" % Data.cards.size()})
	list.append({"id": "first_super", "name": "Super Buyer", "desc": "Buy your first superpack"})
	list.append({"id": "god_pack", "name": "Divine Luck", "desc": "Open a God pack"})
	for p in Data.PACKS.size():
		list.append({"id": "first_pack_%d" % p, "name": "First %s" % Data.PACKS[p].name,
			"desc": "Buy your first %s pack" % Data.PACKS[p].name})
	for m in MONEY_GOALS:
		list.append({"id": "money_%d" % m, "name": "Tycoon $%s" % _thousands(m), "desc": "Have $%s at once" % _thousands(m)})
	return list


## Progress text for an unfinished achievement, or "" if it has no counter.
func achievement_progress(id: String) -> String:
	if id.begins_with("complete_"):
		var r := id.trim_prefix("complete_").to_int()
		return "%d / %d" % [unique_owned(-1, r), Data.rarity_ids[r].size()]
	if id == "all_cards":
		return "%d / %d" % [owned.size(), Data.cards.size()]
	if id.begins_with("money_"):
		return "%s / $%s" % [money_text(money), _thousands(id.trim_prefix("money_").to_int())]
	return ""


func _check_achievements() -> void:
	for r in Data.RARITIES.size():
		var have := unique_owned(-1, r)
		if have > 0:
			_unlock("first_%d" % r)
		if have == Data.rarity_ids[r].size():
			_unlock("complete_%d" % r)
	if owned.size() == Data.cards.size():
		_unlock("all_cards")
	for m in MONEY_GOALS:
		if money >= m:
			_unlock("money_%d" % m)


func _unlock(id: String) -> void:
	if achievements.has(id):
		return
	achievements[id] = day
	achievement_unlocked.emit(id)


static func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


# --- Day cycle ---------------------------------------------------------------

## Simulates customers buying packs and listed cards, moves market prices and starts a new day.
func end_day() -> Dictionary:
	var range_ := customer_range()
	var customers := randi_range(range_.x, range_.y)
	var sold: Array = [0, 0, 0]
	var revenue := 0.0
	var no_stock := 0
	var too_expensive := 0
	for i in customers:
		var stocked := shelves.filter(func(s): return s.count > 0)
		if stocked.is_empty():
			no_stock += 1
			continue
		var s: Dictionary = stocked.pick_random()
		var p: int = s.pack
		var info: Dictionary = Data.PACKS[p]
		if randf() >= info.demand or randf() >= buy_chance(p):
			too_expensive += 1
			continue
		var qty := mini(randi_range(1, info.max_buy), s.count)
		s.count -= qty
		sold[p] += qty
		revenue += retail[p] * qty

	var cards_sold := []  # [{id, price}]
	var card_revenue := 0.0
	for id in listings.keys():
		var chance := card_sell_chance(id)
		var price: float = listings[id].price
		for copy in listings[id].count:
			if randf() < chance:
				cards_sold.append({"id": id, "price": price})
				card_revenue += price
				_remove_copies(id, 1)
				listings[id].count -= 1
		if listings[id].count <= 0:
			listings.erase(id)

	money += revenue + card_revenue
	stats.packs_sold += sold[0] + sold[1] + sold[2]
	stats.cards_sold += cards_sold.size()
	stats.revenue += revenue + card_revenue

	prev_prices = prices.duplicate()
	var top_id := -1
	var top_change := 0.0
	for id in prices:
		var r := Data.price_range(id)
		var v: float = prices[id] * randf_range(0.88, 1.12)
		prices[id] = snappedf(clampf(v, r.x * 0.7, r.y * 1.3), 0.01)
		var change: float = prices[id] / prev_prices[id] - 1.0
		if owned.has(id) and absf(change) > absf(top_change):
			top_change = change
			top_id = id

	day += 1
	_make_offers()
	_commit()
	return {
		"customers": customers, "sold": sold, "revenue": revenue, "no_stock": no_stock,
		"too_expensive": too_expensive, "cards_sold": cards_sold, "card_revenue": card_revenue,
		"top_id": top_id, "top_change": top_change,
	}


func _make_offers() -> void:
	offers = []
	var total := 0
	for w in OFFER_WEIGHTS:
		total += w
	for i in OFFER_COUNT:
		var roll := randi() % total
		var r := 0
		while roll >= OFFER_WEIGHTS[r]:
			roll -= OFFER_WEIGHTS[r]
			r += 1
		var id: int = Data.pools[randi() % Data.PACKS.size()][r].pick_random()
		var factor := randf_range(OFFER_PRICE_RANGE.x, OFFER_PRICE_RANGE.y)
		offers.append({"id": id, "price": snappedf(prices[id] * factor, 0.01)})
