# Pocket TCG

A 2D Android card-collecting and card-shop game, inspired by TCG Card Shop Simulator. You buy
packs from a supplier, open them or sell them to customers from your shelves, collect all
1025 Pokémon cards, trade single cards on the market and unlock achievements. Everything is
controlled through menus.

Made with **Godot 4.7.2** (GDScript). The APK is not stored in git. Build it as described in
section 2; `tools/deploy.sh` also puts a copy at `pocket-tcg.apk` in the project root.

> Card images are Pokémon sprites from [pokemondb.net](https://pokemondb.net/sprites)
> (© Nintendo / Game Freak). This is fine for a personal project, but the game cannot be
> published on Google Play as is.

---

## 1. Requirements

| Tool | Version | Notes |
|---|---|---|
| Godot Engine | 4.7.2 **Standard** (not .NET) | Use the `_console.exe` build for command-line work. |
| JDK | **17** (e.g. Eclipse Temurin 17) | JDK 21+ breaks the Android build (Gradle cannot read newer class files). |
| Android SDK | via Android Studio | Needs platform-tools (adb) and build-tools. |
| Android export templates | 4.7.2 | Godot: *Editor → Manage Export Templates → Download and Install*. |
| Python 3 + Pillow | optional | Only for the scripts in `tools/`. |

One-time Godot setup (*Editor → Editor Settings → Export → Android*):

- **Java SDK Path**: the JDK 17 folder, e.g. `C:/Program Files/Eclipse Adoptium/jdk-17...`
- **Android SDK Path**: e.g. `D:/ProgramData/Android/Sdk`

Godot creates the debug keystore automatically.

## 2. Running and building

### Run on the PC

Open `project.godot` in Godot and press **F5**. The window is phone-shaped (portrait).

Card images are downloaded over HTTPS. If an antivirus intercepts HTTPS traffic (for example,
Avast's "Web Shield"), images will not load on the PC: Godot does not trust the antivirus
certificate. Phones are not affected.

### Build the APK

**In the editor:** *Project → Export → Android → Export Project*, and turn off "Export With Debug"
only if you have set up a release keystore.

**From the command line** (Git Bash, project root):

```sh
"/d/Program Files/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . \
    --export-debug "Android" build/pocket-tcg.apk
```

The export preset is in `export_presets.cfg` (package `com.pockettcg.game`, arm64 only,
INTERNET permission, Charizard launcher icons). `tests/` and `tools/` are excluded from the APK.

### Install on a phone

1. On the phone, enable *Developer options → USB debugging*, connect the USB cable and accept the
   "Allow USB debugging?" prompt. Tick "Always allow from this computer".
2. Run one of these:

   - **One command:** build, install and launch:

     ```sh
     sh tools/deploy.sh          # override paths with GODOT=... ADB=... if needed
     ```

   - **Install the APK only:**

     ```sh
     adb install -r pocket-tcg.apk
     ```

You can also copy `pocket-tcg.apk` to the phone and open it there. You need to allow installs
from unknown sources.

**Updates keep your progress:** `install -r` replaces the app but keeps its data.

**"device unauthorized" after an export:** Godot's export restarts adb, and the phone takes
a few seconds to authorize it again. `deploy.sh` waits for this.

## 3. Testing

### Automated smoke test

```sh
"/d/Program Files/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/smoke_test.tscn
```

The test prints `SMOKE TEST: PASSED` and exits with code 0 on success. If a check fails, it
prints `FAIL: ...` and exits with code 1.

It checks:

- card data and that drop chances fall as rarity rises;
- buying, shelving and opening packs, and guaranteed slots;
- the customer simulation and price limits;
- card listings and the dealer;
- market offer price range;
- superpacks and God packs;
- achievements and save/load;
- that every screen builds without errors.

Your own save and settings on the PC are backed up and restored around the test.

### Testing on the phone

Useful commands:

```sh
adb exec-out screencap -p > shot.png              # screenshot
adb shell input tap X Y                           # tap (physical pixels)
adb shell input swipe X1 Y1 X2 Y2 400             # swipe / scroll
adb logcat -s godot:*                             # game log (print() output, script errors)
adb shell run-as com.pockettcg.game cat files/save.json        # read the save
adb shell "run-as com.pockettcg.game rm files/save.json"       # reset progress
adb shell "run-as com.pockettcg.game rm files/settings.json"   # reset settings
```

In Git Bash, set `MSYS_NO_PATHCONV=1` before `adb push ... /data/local/tmp/...`. Otherwise Git
Bash rewrites the phone path.

**Don't touch the phone while a script sends input:** your touches and the injected ones mix,
and Android cancels gestures.

To test rare events quickly, use Settings in the game: for example, set *God pack chance* to
1 in 1.

## 4. Project structure

```
project.godot            Engine config: autoloads, portrait 720x1280 viewport, main scene, icon
export_presets.cfg       Android export preset
pocket-tcg.apk           Latest debug build (created by tools/deploy.sh, not in git)
data/cards.json          All 1025 cards: id, slug (sprite name), name, gen, primary type, pack
scenes/main.tscn         Main scene (just the Main script; all UI is built in code)
scripts/
  data.gd                Autoload "Data": rarities, packs, superpacks, settings, card pools
  game.gd                Autoload "Game": player state, economy rules, day cycle,
                         achievements, save/load
  sprites.gd             Autoload "Sprites": downloads and caches card images
  main.gd                Root UI: top bar, tabs, popups (card, pack opening, day report),
                         achievement toasts
  ui.gd                  UI helpers (labels, buttons, panels, theme, touch tracking)
  screen.gd              Base class for tab screens (scroll list rebuilt on every state change)
  card_view.gd           Card tile used in the binder and pack opening
  screens/               packs, shelves, collection, market, settings, achievements
tests/smoke_test.*       Headless automated test
tools/
  build_cards.py         Regenerates data/cards.json from PokeAPI CSVs
  make_icons.py          Builds icon.png and the adaptive launcher icons from a sprite
  deploy.sh              Build + install + launch on the phone
icon*.png                App icon (Charizard) and adaptive icon layers
android/                 Gradle build template (not in git; unused: the preset uses the prebuilt template)
```

## 5. How the code works

### Autoloads

They load in this order: Data, then Sprites, then Game.

- **Data** holds everything that does not change during a game:
  - the 9 rarities with their colours and price ranges;
  - the 3 pack types with cost, slots, customer demand and the most packs one customer buys;
  - the superpack rarities;
  - the card pools: `pools[pack][rarity]` and `rarity_ids[rarity]`.

  It also owns the **settings** (`user://settings.json`) that the player can change in the game.
- **Game** holds the player's state: money, day, inventory, shelves, cards owned, listings, market
  prices, offers, stats and achievements.
  - Every action (`buy_packs`, `open_pack`, `stock`, `sell_card`, `end_day`...) ends with
    `_commit()`, which checks achievements, saves to `user://save.json` and emits `changed`.
  - The UI listens to `changed` and redraws.
- **Sprites** downloads `https://img.pokemondb.net/sprites/home/normal/<slug>.png` the first time a
  card is shown.
  - It downloads at most 4 images at a time, newest request first, and skips requests whose card
    widget is gone.
  - Images are shrunk to 160×160 and cached in `user://sprites/`, so they work offline afterwards.

### UI

- There are no hand-made scenes; screens are built from code with the helpers in `ui.gd`.
- Each tab is a `Screen` (a `ScrollContainer`). It rebuilds its content in `build()` when the game
  state changes and keeps the scroll position.
- **Touch handling.** Two things matter on phones:
  1. `Screen` switches every control to `MOUSE_FILTER_PASS`, so a swipe that starts on a panel or
     button still scrolls the list.
  2. `Main._input` sends every touch to `UI.track_touch`. If the finger moved more than 20 px, or
     Android cancelled the touch, `UI.button` and `CardView` ignore it, so a scroll never presses
     a button.
- The game avoids text input and on-screen keyboards. Godot's Android keyboard let taps fall
  through to the game, so Settings uses − / + steppers.

### Save files

- **`user://save.json`** stores the game. It has a `version` field; a save from an incompatible
  version is ignored and a new game starts. New fields are filled with defaults when an older
  save is loaded.
- **`user://settings.json`** stores the settings, separately from the game. "Clear game progress"
  keeps the settings.

## 6. Game rules and tuning

Most numbers can be changed **in the game** under *Shelves → Settings*. Everything else is a
constant at the top of `data.gd` or `game.gd`.

### Rarity

Rarity is the card's **generation**: Gen 1 is Common, then Uncommon, Rare, Super Rare, Epic,
Ultra Rare, Legendary and Mythic, and Gen 9 is Secret Rare. Each rarity has a base price range,
from $0.10–0.50 for Common up to $150–500 for Secret Rare.

The range is multiplied by the card's **pack multiplier**, which is proportional to the pack
price: ×1 for Wild Grove ($10), ×10 for Tidal Mystic ($100) and ×100 for Inferno Strike
($1000). So a Common Inferno Strike card is worth $10–50. A card's starting market value is
random within its range (`Data.price_range()`).

Market values move by ±12% every day. They stay between 70% of the range's minimum and 130% of its
maximum.

### Packs

Cards are split into 3 packs by the Pokémon's **primary type**. Each pack has about 340 cards
from all 9 generations.

| Pack | Cost | Cards | Guaranteed slots |
|---|---|---|---|
| Wild Grove | $10 | 5 | last card Rare+ |
| Tidal Mystic | $100 | 7 | last card Rare+ |
| Inferno Strike | $1000 | 10 | last card Rare+ |

How cards are rolled:

- A normal slot rolls a rarity using the pack's **drop chances**. You can edit them in Settings,
  and they are rescaled to 100%.
- A guaranteed slot uses the same chances, limited to the allowed rarities.
- The defaults make a pack's average market value about **1.3× its cost**. Because cards in pricier
  packs are worth more, those packs need *lower* odds to stay balanced.
  - Common: 57% (Wild Grove), 60% (Tidal Mystic), 64% (Inferno Strike).
  - Secret Rare: 0.04%, 0.02% and 0.01%.
- Saves made before this rule are migrated: old prices are multiplied once
  (`Game.PRICE_MODEL`). Settings files older than `Data.SETTINGS_VERSION` get the new default
  drop chances and superpack prices.

**God pack:** each normal pack has a 1 in N chance (default 100, set in Settings) that every slot
is Legendary or better.

**Superpacks** ($10,000 / $30,000 / $70,000 by default, set in Settings) contain 5 cards of the
rarity chosen when buying: Legendary, Mythic or Secret Rare. Cards come from all types, so a
superpack can contain ×100 Inferno Strike cards. That is why the prices are high: the average
value is about $9,500, $29,000 and $63,000.

### Shop and customers

- You start with **1 shelf**. Defaults, all set in Settings:
  - the 2nd shelf costs **$500**, and each further shelf costs **1.5×** more;
  - **12** shelves at most;
  - **10** packs per shelf.
- Customers per day: **1 + 3 × shelves** to **3 + 3 × shelves**.
- Each customer picks a random stocked shelf and then decides whether to buy:
  - First, can they afford that pack type? The pack's `demand` is 100% for $10 packs, 45% for $100
    packs and 20% for $1000 packs.
  - Then, do they accept your price? The **buy chance** is `clamp(2 − price / supplier price, 0, 1)`:
    100% at the supplier price or below, 70% at 130%, and 0% at 200%.
  - A buyer takes between 1 and `max_buy` packs.

### Single cards

- **Dealer:** buys instantly at 60% of the market value.
- **Listings:**
  - Listed copies are offered to customers at your price, which you change in 5% steps.
  - Each listed copy sells at the end of the day with chance `clamp(1.5 − price / market value, 0, 0.95)`:
    50% at market value, 95% at about half price, and 0% at 150% or more.
- **Market offers:** 6 random cards per day, priced at 70%–140% of market value.

### Achievements

There are 28. Each is unlocked once and stored with the day it happened.

- First card of each rarity (9)
- Complete each rarity (9)
- Collect all cards
- First superpack
- First God pack
- First pack of each type (3)
- Money goals of $1,000, $10,000, $100,000 and $1,000,000

The list is built in `Game.achievement_list()`, and the checks are in `Game._check_achievements()`
plus a few `_unlock()` calls in the actions.

## 7. Regenerating data and icons

**Card list.** Download the CSVs `pokemon_species`, `pokemon_species_names`, `pokemon_types` and
`types` from `https://raw.githubusercontent.com/PokeAPI/pokeapi/master/data/v2/csv/` into a
folder. Then run:

```sh
python -I tools/build_cards.py <csv_folder> data/cards.json
```

The script prints how many cards each pack gets per generation. The type → pack split is the
`PACKS` table at the top of the script. Pack indices must stay in line with `Data.PACKS`.

**Icons:**

```sh
python -I tools/make_icons.py charizard.png .
```

This writes `icon.png` (512×512) plus `icon_foreground.png` and `icon_background.png` (432×432
adaptive layers).
