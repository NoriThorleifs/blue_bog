# Blue Bog

A Flutter roguelike deck-building auto-battler set in the author's sci-fi universe. The repo root is also an Obsidian vault: the lore notes live in `lore/` (`lore/outline.md` is the master timeline) and the design docs sit at the root. The game was built iteratively with the author, who playtests on an Android phone emulator.

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
- **Arbitrage between two adjacent markets gives infinite money and gets boring fast.** Commodity going rates are fixed per market for the whole run (`commodityPrice` in `lib/game_engine/market.dart`), so one profitable pair can be exploited forever. Supply shocks (below) only make grain and ice swing. Trading needs saturation or price drift, limited demand, risk, or contracts, so that profit means decisions.
- **Being at the right place for a story beat doesn't feel like it matters,** and being one jump away means missing it entirely. Story beats are tied to exact locations (`localEvent` in `lib/game_engine/story/story.dart`). They should reach the captain wherever they are, or be telegraphed with time to get there, and the captain's involvement should visibly change outcomes.

The direction implied: turn the map into a sequence of meaningful choices between fights and trades, make the deck and combat the reason to keep going, make commerce feed the deck (buying cards, ammo, upgrades) rather than being an end in itself, and keep the story as a backdrop that reacts to you.

## Commands

```bash
flutter test                              # unit and widget tests in test/ (~180, ~15 s)
flutter test integration_test -d linux    # end-to-end app tests (or -d emulator-5554)
flutter analyze                           # 3 known infos in the old ternary test
dart run tool/simulate.dart 2000          # headless bot runs: endings, pacing
dart run tool/simulate.dart story 42      # print one run's full log
dart run tool/combat_balance.dart         # combat balance matrix and targets
dart run tool/brawl_sim.dart 300          # brawl mode bots: careful vs Hell divers
dart run tool/build_tournament.dart       # same-budget builds fight each other; hull upgrade value
dart run tool/item_balance.dart           # random 9-card builds; value of every card per 100 cr
dart run tool/enemy_balance.dart          # brawl enemy pools: each ship vs random builds at its stage
dart run tool/boss_balance.dart           # Satan vs realistic fight-27 builds, no Hell Clock (args: other base hulls)
python3 tool/generate_galaxy.py           # regenerate assets/galaxy_ai_generated.jpg
python3 tool/generate_card_icons.py       # regenerate assets/cards/*_ai_generated.png
python3 tool/generate_sounds.py           # regenerate assets/sounds/*_ai_generated.wav (synthesised, numpy + scipy)
python3 tool/generate_mourner_concepts.py # concept_art/mourner_*_ai_generated.png
python3 tool/generate_gate_concepts.py    # concept_art/gate_*_ai_generated.png
flutter run -d emulator-5554              # the author's test device
flutter run -d linux -t tool/combat_preview.dart --dart-define=FIGHT=hell  # combat replay on a sample fight (ark, hell, rail, nobody)
```

`adb` is not on PATH: use `~/Android/Sdk/platform-tools/adb`. Screenshot with `adb -s emulator-5554 exec-out screencap -p > shot.png`. A physical phone is sometimes connected too; target the emulator unless asked.

## Conventions

- Every image or sound Claude generates (concept art, placeholders, icons, sound effects) ends its file name with `_ai_generated`, before the extension: `mourner_1_ai_generated.png`, `laser_ai_generated.wav`. They are proof-of-concept placeholders; the author will hire an artist for real art.
- Idiomatic modern Dart in our own style. `GEMINI.MD` was a leftover from an older tool and has been deleted; don't follow its rules (e.g. arrow functions are fine).
- Verify UI on the Android emulator, phone-sized, not on web or desktop.
- `dart format` after edits. The formatter rewraps lines, so string-match edits against the current file contents.
- Never `pkill -f` with a pattern that also matches your own shell command line: it kills the command itself (exit 144).
- The game engine (`lib/game_engine/`) is pure Dart with no Flutter imports, so tools can run it headlessly. Keep it that way.
- All randomness goes through `GameRng` (seeded, state in `RunState.rngState`). Combat is deterministic.
- Seeds don't need to stay stable between versions. The game is in active development, so a change that makes an old seed play out differently (reordering events, new content, rebalancing) is fine. Determinism within a version is what matters.
- `RunState` is cloned by the engine and never mutated in place by callers. Engine actions take a state and return a new one, and throw `IllegalMove` for things the UI shouldn't offer.

## Code organisation

Only `main.dart` and `routing_table.dart` (the go_router `routerProvider`) sit directly under `lib/`. Everything else goes in one of these folders:

- `lib/game_engine/`: the game engine and its rules, pure Dart (see Conventions). Pieces split off an engine file stay inside this folder, next to the file they came from (`engine.dart` and `engine/`).
- `lib/functions/`: business logic outside the engine. When a file is split, or several screens use the same logic function, the function goes in a file here.
- `lib/components/`: the same for UI: widgets, painters and UI helpers split off a screen or shared by several screens.
- `lib/providers/`: every Riverpod provider, except the router.
- `lib/screens/`: one file per screen.
- `lib/l10n/`: generated localisations.

When a file grows past about 500 lines, split it: functions into `lib/functions/` (or alongside, inside `lib/game_engine/`), widgets and painters into `lib/components/`. Catalog files (written content and data tables: events, beats, the card and enemy catalogs) are exempt from the size limit, but are organised by theme: one file per theme, such as all the Hell events in `hell_events.dart`. A new event goes in the file for its theme, or a new theme file. Private names that move to another file become public with a specific name (`_Log` became `CombatLog`). A split file can `export` its new parts so existing imports keep working, as `engine.dart`, `catalog.dart` and `rules.dart` do.

Tests: `test/unit_tests/` for unit tests, `test/widget_tests/` for widget tests, and `integration_test/` for end-to-end tests only.

Lore: every lore note goes in `lore/`. From a file outside it, link with the path, as in `[[lore/outline|outline]]`.

## Code map

- `lib/game_engine/engine.dart`: the `GameEngine` actions and queries: travel, markets, shipyard, choices. Each action runs on an `EngineTurn` (`engine/turn.dart`); turn flow and story beats are in `engine/turn_flow.dart`, effect application and combat wiring in `engine/effects.dart`, borders, gateways and acts in `engine/world_effects.dart`. `StoryContent` is in `engine/story_content.dart`.
- `lib/game_engine/run_state.dart`: everything about a run in progress, plus `HumanResources` (the hidden bond mechanic).
- `lib/game_engine/story/`: `conditions.dart` and `rules.dart` (conditions and effects as sealed classes), `story.dart` (events, choices, beats), `keys.dart` (flags and counters).
- `lib/functions/sound.dart`: the `SoundBoard` (flutter_soloud): loads every `Sfx` at startup, throttles repeats, mute toggle in the combat top bar. It stays silent rather than failing without an audio device.
- `lib/game_engine/content/`: all written content.
  - `beats.dart`, `faction_beats.dart`: galaxy timeline beats.
  - `events/`: events, one file per theme: the run's own moments (`run_events.dart`), Hell, the crew, events story beats queue, act 1 places, acts 2 and 3, the Consumers, deliveries, holding position, stations, the frontier, species home worlds, the House of the Elephant, the Fuel Rats, pirates, and the wars. `content.dart` combines them.
  - `content.dart`: wiring, endings, code effects.
- `lib/game_engine/combat/`: the equipment model (`equipment.dart`), the card catalog and starter loadouts (`catalog.dart`), enemy templates (`enemies.dart`), and the tick-based fight simulator (`combat.dart`).
- `lib/game_engine/deck/loadout.dart`: nine triforce slots (0–2 top, 3–5 bottom left, 6–8 bottom right), the cargo bay slot, the hold, the colony grid, where each kind of card fits (`fits`, `whyNotMove`), merging (three of a card make the next tier: ×1, ×3, ×9), and ship stats.
- `lib/game_engine/brawl/`: brawl mode, the default mode (the title screen's main launch button; story mode is the secondary button). Combat and commerce alone. `brawl.dart` is the engine, `brawl_state.dart` the state and stations, `brawl_outcomes.dart` applies event effects, `brawl_event_model.dart` the event types, `events/` the departure, elite and Hell events by theme, combined in `brawl_events.dart`, `brawl_enemies.dart` the enemy pools by stage (picked by seed, never the same ship twice in a row; after fight 10 the last pool scales by act) and special ships that only events send: the Neo Terran defence platform, and three missable elites, one per stage, each with a once-per-brawl event window and a unique trophy card (`eliteTrophies` in `catalog.dart`): the Last Vote (pirate shakedown, fights 4–5), the Gor champion (duel with a tractor beam, fights 8–10) and the Unmerged foundry (Tern bounty, fights 11–14). Nobody (see `lore/Nobody.md`) can turn up once, any time from fight 9: run for it (100 hull) or kill him before his Boarding Teleporter charges at 40 s, when he boards and the captain is lost (`Board` action). He can't be escaped by the time limit, and his teleporter can never be acquired: unique cards are never salvaged. The human colony is in it (brawl mode is meant to grow story features until it becomes the main game); Hell shielding and fuel tanks are left out.
- `lib/game_engine/market.dart`: markets (27 offers plus a shipyard) and trading posts (9 offers, supplies and commodities only), commodity prices, and supply shocks (`SupplyShock`): each season (3 turns or fights) a station has a 10% chance each of famine (grain) or drought (water ice), paying 2.5–4× its going rate, and of a bumper harvest (grain) or ice glut (water ice), at 0.25–0.45×. The brawl Buy tab shows the shock at this station; there's no news of other stations, since a brawl captain can't choose where to go.
- `lib/game_engine/galaxy/`: the generator (`galaxy_generator.dart`, with one try in `galaxy_attempt.dart`, gateways and lanes in `galaxy_wiring.dart`, enforcing the lore map rules and readable layouts), territories and borders.
- `lib/game_engine/faction.dart`: major and minor factions and starting control.
- `lib/providers/`: `run_provider.dart` (story run), `brawl_provider.dart` (brawl), `territory_provider.dart` (map territories, built in an isolate).
- `lib/screens/`: title, how to play (the user guide, from the title screen and the brawl menu), galaxy map, deck, market, brawl, gambling and combat replay (the combat screen lays the ships side by side on wide windows and stacked on phones).
- `lib/components/`: `map/` (galaxy view, event overlay, HUD, system panel, territory layer), `deck/` (the triforce, the cargo bay and hold, the colony grid, and the stats bar), `cards/` (shared card widgets), `brawl/` (the brawl screen's tabs), `combat/` (`battle_effects.dart` paints shots, shields, drones and numbers from the fight record and the replay clock, with the shot primitives in `shot_painting.dart`), `gambling/` (the roulette and 27 tables), `guide/` (the user guide's sections, illustrated with live cards and layouts, so update them when rules change), `theme.dart`, `dialogs.dart`.
- `lib/functions/`: `battle_sounds.dart` turns the fight record into timed sound cues that play as the clock passes them; `roulette_motion.dart` is the wheel and ball animation; `three_thirds/` writes numbers in ternary words.

## Design docs in the vault

- `Game design - map and story.md`: map rules, story beats, HR, Hell, endings, factions, settled lore, open questions.
- `Combat and economy plan.md`: combat rules and balance numbers, economy, decisions made, build status.

The lore notes in `lore/` (`outline.md`, species, places) are the author's canon. Ask before contradicting them. Spellings in use: Promethius (the colony ship), Orcha Station, Ghor-Dum, Træ Træ Tene, Úlaval, Lady Idun the Giantess (House of the Elephant).

## Systems at a glance

- **Combat.** Every captain flies the same ship: 500 hull and nine slots. Cards fire on cooldown timers.
  - Lasers are blocked by shields.
  - Missiles need ammo and are stopped by drones. Fabricators build 1, 3 or 9 drones per charge by tier, and each drone out repairs 1 hull a second.
  - Teleport bombs need charges and go through everything, except Teleport Jammers, which ready one jam per charge (1, 3, 9 by tier) that stops one bomb. Nothing stops Nobody's boarding.
  - Ion Cannons strip shields; what the shields don't take hits the hull at a third. Flak Batteries shoot down drones (1, 3, 9) and burst on the hull for 10 a round when there are none. Repair Bays patch the ship's own hull. Plasma Lances are lasers that hit 5 harder with every shot (×3 per tier). Rail Cannons fire a 100-damage slug every 9 s that any shield charge at all deflects entirely; Ion Cannons open the way.
  - Shields refill to their combined maximum. Shield generators grow faster than ×3 per tier (30, 105, 360), so lasers fall off late. Shield Capacitors add a little max shield and speed up shield generators in their triangle.
  - Triangle and ship-wide charge boosts stack with no percentage cap; the only floor is one shot a second (`minCooldown`). The author wants fun spam builds (a teleport bomb every second while its charges last).
  - The 60 s limit means escape, with no loot. Story bosses use tractor beams, so there is no escape.
  - Hull damage carries over between fights. Humans patch it toward 75% (`Colony.patched`); shipyards repair fully and sell hull upgrades.
  - Story fights map a strength rating to an enemy template, scaled by act (interim ×2 / ×3).
  - Known issue: teleport bombs are overtuned.
- **Brawl mode.** Station (buy, sell, repair) → departure event → fight → another station, until the ship is lost or the captain wins. At fight 27 (`brawlFinalFight`) Satan comes for the captain wherever they are, Hell included (the `satan` event in `events/finale_events.dart`, an `always` event that pre-empts the rest): a fixed, unscaled ship with a tractor beam, tuned with `tool/boss_balance.dart` so a well-built ship of any style wins without the Hell Clock (it's rare, so never the baseline). Beating him pays The Broken Seal and wins; the captain then retires (victory screen) or keeps going, and every fight past 27 has 1.3× the hull of the last (`endlessGrowth`). Loot with no room aboard goes to the `wreckage` until the ship moves on; any card can be jettisoned from the Ship tab to make room. After a fight (or on leaving Hell) the ship is in transit before docking: `aftermath` events come up 40% of the time (`aftermathChance`), or always when one is due. They tell the colony's story (`events/colony_events.dart`): the war for Neo Terra and its universal draft (fight 5; 3% of the colony leaves at each dock after), veterans and the helmet, simple petitions, the hidden Hellborn cell (`hellbornCell`; the headcount on leaving Hell, the red-eyes warning, the wrong-warp hint that makes the next launch skip its event or drop into Hell), Kepler refused, the Elephant crate, the other elected captains, and a strike below 20 loyalty that stops the hull patching until loyalty is back to 40. A Content (60+) or Devoted (80+) colony gives gifts in transit, at most one every three fights (`events/colony_gift_events.dart`): a copy of a triforce card, a 150-hull double shift, a collection; for Devoted, ammo for a launcher at its tier, a boarding party that starts the next enemy at 80% hull (`boardingParty`), a free hull upgrade. Each stage draws its enemy from a pool of ships that trouble different builds; haulers carry `cargo` that is plundered when they're destroyed. The chewer event lets a captain dive into Hell: no shipyard, 25 hull lost a turn, demons (`demons` in `catalog.dart`), Hell cards and Hell Brandy, and the Hell Clock (one per brawl, from the Mourner or the clock event). Leaving Hell shifts the difficulty curve by Hell's clocks.
- **Gambling.** "LETS GO GAMBLING!" in the brawl shop. Games run in Republic stations (`stationGames` in `brawl.dart`): roulette at the human stations (Orcha, Kepler; humans still count in base ten), 27 everywhere else for now. Roulette: `lib/game_engine/gambling/roulette.dart`, European single zero, stakes 25 or 50 or all in. 27 is the Ál game (`twenty_seven.dart`): take one tile of a triad (one face up, two face down) from a deck of nine 1s, 2s and 3s; bust on one over a multiple of three or past 27; walk away at 9 for 1.5×, reach 27 for 4.5×. The count is shown in ternary words (`lib/functions/three_thirds/`). A Gor game is planned. Randomness goes through `GameRng`; the UI only plays out results.
- **Card tags.** Cards carry tags (`CardTag` in `equipment.dart`, only Hellish so far) that other cards look for. Hell's own families (`hellFamilies`, never sold) are born Hellish. Tags picked up later are written into the card id (`laser_1#hellish`), and merging keeps them. Hell Brandy sells like any commodity or can be used (Ship tab: tap, Use, tap a glowing card) to tag a card Hellish. The Hell Clock (ship-wide charge boost, every card starts half charged, and every other Hellish card fires at the start of a fight) and the three elite trophies are the uniques in brawl mode. Hell's own cards are deliberately stronger for their price than station cards. Hellfire passes shields and drones but burns its user for a quarter.
- **Cards.** Kinds: equipment (works in a slot), supplies (work from the hold too), commodities, mission cargo (can't be sold), and colony cards (work only in the colony grid, never fight). The hold starts at 0; only the cargo pod in the cargo bay, a slot of its own outside the triforce, adds space. Spare pods wait in the hold or a slot until three merge.
- **The human colony.** Hundreds to thousands of humans in a 3×3 colony grid docked to the ship, in story and brawl mode: habitats, clinics, crawlspace crews, and shops, casinos and two-sided brothels that pay dividends on docking. No wages. The colony grows by births and sign-ons; selling housing is the only way to make humans leave. Shared rules in `lib/game_engine/colony.dart`; design and numbers in "The human colony" in `Game design - map and story.md`. Never call the humans ants in game text.
- **HR.** Population, loyalty and drift are visible as a mood word. The hidden bond (saturating at 900 humans) changes event odds and unlocks Code Green.
- **Story.** Three acts driven by the gateway network. Beats come from `outline.md`. Code Blue, Red or Yellow ending, with a 9-turn war for Red and Yellow. Hell and the Mourner are deadly. Hellborn agents are hidden in the crew.
- **Fuel.** A gateway jump costs 1, sublight 2. Being stranded brings the Fuel Rats, whose tab comes due after 4 turns.
