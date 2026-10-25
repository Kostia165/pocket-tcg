extends Node
## Static game data (cards, rarities, packs) and the player-editable settings.

const SETTINGS_PATH := "user://settings.json"
const SETTINGS_VERSION := 2  # bump when default drop chances or prices change meaning

# Rarity index == generation - 1. Price range of a card depends on its rarity, multiplied by
# its pack's price_mult (see price_range()).
const RARITIES := [
	{"name": "Common",      "color": Color("b0b0b0"), "min": 0.10, "max": 0.50},
	{"name": "Uncommon",    "color": Color("66bb6a"), "min": 0.30, "max": 1.00},
	{"name": "Rare",        "color": Color("42a5f5"), "min": 0.80, "max": 2.50},
	{"name": "Super Rare",  "color": Color("26c6da"), "min": 2.00, "max": 6.00},
	{"name": "Epic",        "color": Color("ab47bc"), "min": 5.00, "max": 15.00},
	{"name": "Ultra Rare",  "color": Color("ff7043"), "min": 12.00, "max": 35.00},
	{"name": "Legendary",   "color": Color("ffca28"), "min": 30.00, "max": 80.00},
	{"name": "Mythic",      "color": Color("ec407a"), "min": 70.00, "max": 200.00},
	{"name": "Secret Rare", "color": Color("e040fb"), "min": 150.00, "max": 500.00},
]

# slots: minimum rarity of each card in the pack (0 = any). Card prices scale with the pack cost
# (x1, x10, x100), and the default drop chances make every pack worth about 1.3x its cost.
# demand: share of customers who can afford this pack. max_buy: most packs one customer takes.
const PACKS := [
	{"name": "Wild Grove", "desc": "Grass · Bug · Normal · Poison", "color": Color("2e7d32"),
		"cost": 10, "slots": [0, 0, 0, 0, 2], "demand": 1.0, "max_buy": 3},
	{"name": "Tidal Mystic", "desc": "Water · Ice · Psychic · Ghost · Dark · Fairy · Flying", "color": Color("1565c0"),
		"cost": 100, "slots": [0, 0, 0, 0, 0, 0, 2], "demand": 0.45, "max_buy": 2},
	{"name": "Inferno Strike", "desc": "Fire · Fighting · Dragon · Electric · Rock · Ground · Steel", "color": Color("c62828"),
		"cost": 1000, "slots": [0, 0, 0, 0, 0, 0, 0, 0, 0, 2], "demand": 0.2, "max_buy": 1},
]

# Superpacks hold cards of a single rarity (chosen when buying), from all card types.
const SUPER_RARITIES := [6, 7, 8]  # Legendary, Mythic, Secret Rare
const SUPER_CARDS := 5

# A "God pack" is a rare normal pack where every card is at least this rarity (Legendary).
const GOD_MIN_RARITY := 6

const DEFAULT_SETTINGS := {
	"shelf_price": 500.0,     # price of the second shelf (the first one is free)
	"shelf_growth": 1.5,      # each further shelf costs this many times more
	"max_shelves": 12,
	"shelf_capacity": 10,
	"super_price": [10000.0, 30000.0, 70000.0],  # per SUPER_RARITIES entry
	"god_pack_odds": 100,     # 1 in this many normal packs is a God pack
	# Drop chance in % per pack (rows) and rarity (columns). Rows are rescaled to 100% when used.
	"drop": [
		[57.16, 25.18, 9.94, 4.50, 1.94, 0.80, 0.32, 0.12, 0.04],
		[60.47, 24.54, 8.92, 3.72, 1.48, 0.56, 0.20, 0.07, 0.02],
		[64.46, 23.48, 7.66, 2.87, 1.02, 0.35, 0.11, 0.04, 0.01],
	],
}

var cards: Array = []       # [{id, slug, name, gen, type, pack}]
var by_id: Dictionary = {}  # id -> card
var pools: Array = []       # pools[pack][rarity] -> Array of ids
var rarity_ids: Array = []  # rarity_ids[rarity] -> Array of ids from all packs
var settings: Dictionary = {}


func _ready() -> void:
	load_settings()
	var text := FileAccess.get_file_as_string("res://data/cards.json")
	cards = JSON.parse_string(text)
	pools = []
	rarity_ids = []
	for r in RARITIES.size():
		rarity_ids.append([])
	for p in PACKS.size():
		var by_rarity: Array = []
		for r in RARITIES.size():
			by_rarity.append([])
		pools.append(by_rarity)
	for c in cards:
		c.id = int(c.id)
		c.gen = int(c.gen)
		c.pack = int(c.pack)
		by_id[c.id] = c
		pools[c.pack][rarity_of(c.id)].append(c.id)
		rarity_ids[rarity_of(c.id)].append(c.id)


# --- Settings ----------------------------------------------------------------

func load_settings() -> void:
	settings = DEFAULT_SETTINGS.duplicate(true)
	var data = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH)) if FileAccess.file_exists(SETTINGS_PATH) else null
	if typeof(data) != TYPE_DICTIONARY:
		return
	if int(data.get("version", 1)) < SETTINGS_VERSION:
		# Old drop chances and superpack prices don't fit the current card prices.
		data.erase("drop")
		data.erase("super_price")
	for key in settings:
		# JSON numbers always load as floats, so accept a float where an int is expected.
		if data.has(key) and (typeof(data[key]) == typeof(settings[key]) or (data[key] is float and settings[key] is int)):
			settings[key] = data[key]
	settings.max_shelves = int(settings.max_shelves)
	settings.shelf_capacity = int(settings.shelf_capacity)
	settings.god_pack_odds = int(settings.god_pack_odds)


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings.merged({"version": SETTINGS_VERSION})))


func reset_settings() -> void:
	settings = DEFAULT_SETTINGS.duplicate(true)
	save_settings()


# --- Cards and packs ---------------------------------------------------------

func card(id: int) -> Dictionary:
	return by_id[id]


func rarity_of(id: int) -> int:
	return by_id[id].gen - 1


func rarity(id: int) -> Dictionary:
	return RARITIES[rarity_of(id)]


## Card prices scale with the pack price: x1 for the cheapest pack, x10 for a 10x pricier one.
func price_mult(pack: int) -> float:
	return float(PACKS[pack].cost) / PACKS[0].cost


## Market value range (min, max) of a card: its rarity's range times its pack's multiplier.
func price_range(id: int) -> Vector2:
	var r: Dictionary = rarity(id)
	return Vector2(r.min, r.max) * price_mult(by_id[id].pack)


func card_count(pack: int) -> int:
	return PACKS[pack].slots.size()


## Chance (0..1) for one unrestricted card slot of `pack` to be of rarity `r`.
func drop_chance(pack: int, r: int) -> float:
	var w: Array = settings.drop[pack]
	var total := 0.0
	for x in w:
		total += x
	return w[r] / total if total > 0.0 else 0.0


func roll_rarity(pack: int, min_rarity := 0) -> int:
	var w: Array = settings.drop[pack]
	var total := 0.0
	for r in range(min_rarity, w.size()):
		total += w[r]
	if total <= 0.0:
		return min_rarity
	var roll := randf() * total
	for r in range(min_rarity, w.size()):
		roll -= w[r]
		if roll <= 0.0:
			return r
	return w.size() - 1


func roll_card(pack: int, min_rarity := 0) -> int:
	return pools[pack][roll_rarity(pack, min_rarity)].pick_random()


## e.g. "3x Ultra Rare+, 4x Mythic+"
func guarantee_text(pack: int) -> String:
	var counts := {}
	for m in PACKS[pack].slots:
		if m > 0:
			counts[m] = counts.get(m, 0) + 1
	var parts := []
	for m in counts:
		parts.append("%dx %s+" % [counts[m], RARITIES[m].name])
	return ", ".join(parts)


func super_price(i: int) -> int:
	return roundi(settings.super_price[i])


func super_name(i: int) -> String:
	return "%s Superpack" % RARITIES[SUPER_RARITIES[i]].name


func pack_count(pack: int, rarity_idx := -1) -> int:
	if rarity_idx >= 0:
		return pools[pack][rarity_idx].size()
	var n := 0
	for ids in pools[pack]:
		n += ids.size()
	return n
