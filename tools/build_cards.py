"""Builds data/cards.json for Pocket TCG from PokeAPI CSVs.

usage: python -I build_cards.py <csv_dir> <out_json>
"""
import csv, json, sys, collections

csv_dir, out_path = sys.argv[1], sys.argv[2]

def rows(name):
    with open(f"{csv_dir}/{name}.csv", encoding="utf-8") as f:
        return list(csv.DictReader(f))

type_names = {r["id"]: r["identifier"] for r in rows("types")}
names = {r["pokemon_species_id"]: r["name"] for r in rows("pokemon_species_names") if r["local_language_id"] == "9"}
primary = {}
for r in rows("pokemon_types"):
    if r["slot"] == "1":
        primary[r["pokemon_id"]] = type_names[r["type_id"]]

# Primary type -> pack index. Balanced so each pack holds about a third of the cards.
PACKS = {
    0: {"grass", "bug", "normal", "poison"},
    1: {"water", "ice", "psychic", "ghost", "dark", "fairy", "flying"},
    2: {"fire", "fighting", "dragon", "electric", "rock", "ground", "steel"},
}
type_to_pack = {t: p for p, ts in PACKS.items() for t in ts}

cards = []
for s in rows("pokemon_species"):
    sid = s["id"]
    t = primary[sid]
    cards.append({
        "id": int(sid),
        "slug": s["identifier"],
        "name": names[sid],
        "gen": int(s["generation_id"]),
        "type": t,
        "pack": type_to_pack[t],
    })
cards.sort(key=lambda c: c["id"])

with open(out_path, "w", encoding="utf-8") as f:
    json.dump(cards, f, ensure_ascii=False, separators=(",", ":"))

# Report: cards per pack x generation
table = collections.Counter((c["pack"], c["gen"]) for c in cards)
print("pack | " + " ".join(f"g{g:<3}" for g in range(1, 10)) + " total")
for p in range(3):
    counts = [table[(p, g)] for g in range(1, 10)]
    print(f"  {p}  | " + " ".join(f"{n:<4}" for n in counts) + f" {sum(counts)}")
print("cards:", len(cards))
