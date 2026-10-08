# Blue Bog

A Flutter roguelike deck-building auto-battler set in the author's sci-fi universe. The repo root is also an Obsidian vault of lore notes (`outline.md` is the master timeline). The game was built iteratively with the author, who playtests on an Android phone emulator.

## Design priorities (set by the author after playtesting)

Highest first. When features compete, the higher one wins.

1. **Deck building.** The triforce loadout, card synergy, merging and auto-battle combat. This is the core of the game.
2. **Commerce.** Buying low and selling high, markets, trading posts, cargo.
3. **Story and random events.** Flavour and stakes around the core loop, not the main attraction.
4. **Space exploration.** Lowest priority. The map is a way to choose where the next trade or fight happens, not a goal in itself.

### Playtest findings to fix next

The game tries to be four things at once (exploration, deck builder, commerce, visual novel) and does none of them well. Specifically:

- **Visiting every node is pointless.** Exploration has no payoff.
- **Repeating "Odd jobs" at one station is boring,** and it's still a viable strategy. Passive income must not be a way to play.
- **Arbitrage between two adjacent markets gives infinite money and gets boring fast.** Commodity prices are fixed per market for the whole run (`commodityPrice` in `lib/game/market.dart`), so one profitable pair can be exploited forever. Trading needs saturation or price drift, limited demand, risk, or contracts, so that profit means decisions.
- **Being at the right place for a story beat doesn't feel like it matters,** and being one jump away means missing it entirely. Story beats are tied to exact locations (`localEvent` in `lib/game/story/story.dart`). They should reach the captain wherever they are, or be telegraphed with time to get there, and the captain's involvement should visibly change outcomes.

The direction implied: turn the map into a sequence of meaningful choices between fights and trades, make the deck and combat the reason to keep going, make commerce feed the deck (buying cards, ammo, upgrades) rather than being an end in itself, and keep the story as a backdrop that reacts to you.

## Commands

```bash
flutter test                              # all tests (~110, ~15 s)
flutter analyze                           # 3 known infos in the old ternary test
dart run tool/simulate.dart 2000          # headless bot runs: endings, pacing
dart run tool/simulate.dart story 42      # print one run's full log
dart run tool/combat_balance.dart         # combat balance matrix and targets
dart run tool/brawl_sim.dart 300          # brawl mode bots: careful vs Hell divers
dart run tool/build_tournament.dart       # same-budget builds fight each other; hull upgrade value
dart run tool/item_balance.dart           # random 9-card builds; value of every card per 100 cr
python3 tool/generate_galaxy.py           # regenerate assets/galaxy_ai_generated.jpg
python3 tool/generate_card_icons.py       # regenerate assets/cards/*_ai_generated.png
python3 tool/generate_mourner_concepts.py # concept_art/mourner_*_ai_generated.png
python3 tool/generate_gate_concepts.py    # concept_art/gate_*_ai_generated.png
flutter run -d emulator-5554              # the author's test device
```

`adb` is not on PATH: use `~/Android/Sdk/platform-tools/adb`. Screenshot with `adb -s emulator-5554 exec-out screencap -p > shot.png`. A physical phone is sometimes connected too; target the emulator unless asked.

## Conventions

- Every image Claude generates (concept art, placeholders, icons) ends its file name with `_ai_generated`, before the extension: `mourner_1_ai_generated.png`. They are proof-of-concept placeholders; the author will hire an artist for real art.
- Idiomatic modern Dart in our own style. `GEMINI.MD` was a leftover from an older tool and has been deleted; don't follow its rules (e.g. arrow functions are fine).
- Verify UI on the Android emulator, phone-sized, not on web or desktop.
- `dart format` after edits. The formatter rewraps lines, so string-match edits against the current file contents.
- Never `pkill -f` with a pattern that also matches your own shell command line: it kills the command itself (exit 144).
- The game domain (`lib/game/`) is pure Dart with no Flutter imports, so tools can run it headlessly. Keep it that way.
- All randomness goes through `GameRng` (seeded, state in `RunState.rngState`). Combat is deterministic.
- `RunState` is cloned by the engine and never mutated in place by callers. Engine actions take a state and return a new one, and throw `IllegalMove` for things the UI shouldn't offer.

## Code map

- `lib/game/engine.dart`: turn flow, travel, Hell, story beats, effect application, markets, shipyard, combat wiring.
- `lib/game/run_state.dart`: everything about a run in progress, plus `HumanResources` (the hidden bond mechanic).
- `lib/game/story/`: `rules.dart` (conditions and effects as sealed classes), `story.dart` (events, choices, beats), `keys.dart` (flags and counters).
- `lib/game/content/`: all written content.
  - `beats.dart`, `faction_beats.dart`: galaxy timeline beats.
  - `events_*.dart`: events.
  - `content.dart`: wiring, endings, code effects.
- `lib/game/combat/`: the equipment model (`equipment.dart`), the card catalog, enemy templates and starter loadouts (`catalog.dart`), and the tick-based fight simulator (`combat.dart`).
- `lib/game/deck/loadout.dart`: nine triforce slots (0–2 top, 3–5 bottom left, 6–8 bottom right), the hold, merging (three of a card make the next tier: ×1, ×3, ×9), and ship stats.
- `lib/game/brawl/`: brawl mode, the default mode (the title screen's main launch button; story mode is the secondary button). Combat and commerce alone. `brawl.dart` is the engine and state, `brawl_events.dart` the departure and Hell events. Humans, bunks, hospitals, Hell shielding and fuel tanks are left out of it.
- `lib/game/market.dart`: markets (27 offers plus a shipyard) and trading posts (9 offers, supplies and commodities only), commodity prices.
- `lib/game/galaxy/`: the generator (enforces the lore map rules and readable layouts), territories and borders.
- `lib/game/faction.dart`: major and minor factions and starting control.
- `lib/presentation/`: screens. Galaxy map, event overlay, HUD, loadout triforce (`deck/`), market (`market/`), combat replay (`combat/`), shared card widgets (`cards/`).

## Design docs in the vault

- `Game design - map and story.md`: map rules, story beats, HR, Hell, endings, factions, settled lore, open questions.
- `Combat and economy plan.md`: combat rules and balance numbers, economy, decisions made, build status.

The lore notes (`outline.md`, species, places) are the author's canon. Ask before contradicting them. Spellings in use: Promethius (the colony ship), Orcha Station, Ghor-Dum, Træ Træ Tene, Úlaval, Lady Idun the Giantess (House of the Elephant).

## Systems at a glance

- **Combat.** Every captain flies the same ship: 500 hull and nine slots. Cards fire on cooldown timers.
  - Lasers are blocked by shields.
  - Missiles need ammo and are stopped by drones. Fabricators build 1, 3 or 9 drones per charge by tier, and each drone out repairs 1 hull a second.
  - Teleport bombs need charges and go through everything.
  - Shields refill to their combined maximum. Shield generators grow faster than ×3 per tier (30, 105, 360), so lasers fall off late. Shield Capacitors add a little max shield and speed up shield generators in their triangle.
  - Triangle and ship-wide charge boosts, capped at 50%.
  - The 60 s limit means escape, with no loot. Story bosses use tractor beams, so there is no escape.
  - Hull damage carries over between fights. Humans patch it to 75%; shipyards repair fully and sell hull upgrades.
  - Story fights map a strength rating to an enemy template, scaled by act (interim ×2 / ×3).
  - Known issue: teleport bombs are overtuned.
- **Brawl mode.** Station (buy, sell, repair) → departure event → fight → another station, until the ship is lost. The chewer event lets a captain dive into Hell: no shipyard, 25 hull lost a turn, demons (`demons` in `catalog.dart`), Hell cards and Hell Brandy, and the Hell Clock (one per brawl, from the Mourner or the clock event). Leaving Hell shifts the difficulty curve by Hell's clocks.
- **Gambling.** "LETS GO GAMBLING!" in the brawl shop. Games run in Republic stations (`stationGames` in `brawl.dart`): roulette at the human stations (Orcha, Kepler; humans still count in base ten), 27 everywhere else for now. Roulette: `lib/game/gambling/roulette.dart`, European single zero, stakes 25 or 50 or all in. 27 is the Ál game (`twenty_seven.dart`): take one tile of a triad (one face up, two face down) from a deck of nine 1s, 2s and 3s; bust on one over a multiple of three or past 27; walk away at 9 for 1.5×, reach 27 for 4.5×. The count is shown in ternary words (`lib/three-thirds/`). A Gor game is planned. Randomness goes through `GameRng`; the UI only plays out results.
- **Card tags.** Cards carry tags (`CardTag` in `equipment.dart`, only Hellish so far) that other cards look for. Hell's own families (`hellFamilies`, never sold) are born Hellish. Tags picked up later are written into the card id (`laser_1#hellish`), and merging keeps them. Hell Brandy sells like any commodity or can be used (Ship tab: tap, Use, tap a glowing card) to tag a card Hellish. The Hell Clock (ship-wide charge boost, every card starts half charged, and every other Hellish card fires at the start of a fight) is the only unique in brawl mode. Hell's own cards are deliberately stronger for their price than station cards. Hellfire passes shields and drones but burns its user for a quarter.
- **Cards.** Kinds: equipment (works in a slot), supplies (work from the hold too), commodities, and mission cargo (can't be sold). The hold starts at 0 and only cargo pods add space. Removing accommodation sends humans away.
- **HR.** Human count, loyalty and drift are visible as a mood word. The hidden bond changes event odds and unlocks Code Green.
- **Story.** Three acts driven by the gateway network. Beats come from `outline.md`. Code Blue, Red or Yellow ending, with a 9-turn war for Red and Yellow. Hell and the Mourner are deadly. Hellborn agents are hidden in the crew.
- **Fuel.** A gateway jump costs 1, sublight 2. Being stranded brings the Fuel Rats, whose tab comes due after 4 turns.
