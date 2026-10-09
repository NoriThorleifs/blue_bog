How the lore in this vault drives the game's map, turns and events. The code lives in `lib/game_engine/`. Story content (beats and events) is in `lib/game_engine/content/` and can be edited without touching the engine.

## Where the game starts in the timeline

Everything in [[lore/outline|outline]] up to "The humans are allowed to set up a temporary residence in Ochra" has already happened when a run starts. These flags are set at turn 1: `gatecrash`, `gor_demilitarised`, `first_contact`, `humans_at_orcha`.

From there the outline plays out as **story beats**, checked at the end of every turn. Each beat has a base chance per turn, hidden modifiers (captain's choices, the humans aboard), and usually a deadline so the story can't stall. Outcomes are random within limits, so the galaxy's story differs between runs.

| Act | Beat | Notes |
| --- | --- | --- |
| 1 | Consumers raid Orcha | Local event if you're docked there: [[lore/Raid at Orcha station|Raid at Orcha station]] |
| 1 | Hive world located | Reveals the hive world (later Neo Terra) at sublight from Orcha |
| 1 | Overseer's offer | Council session at the Center where you can spend influence |
| 1 | Kepler "misunderstanding" | Touchdown. Sets up the Kepler vote in act 2 |
| 1 | War for Neo Terra | Can succeed, stall ratification or bog down. Success grants the planet |
| 1 | Gor–Bhrun war, battle in the pipe | +25% Hell risk on that pipe during the war. Code Green makes the Gor fleet vanish |
| 1 | Consumers invade Bhrun-Gai | The Direction Remover |
| 1→2 | Center–Træ Træ Tene gateway restored | Starts act 2 |
| 2 | Wrong warping | Raises Hell risk in every pipe |
| 2 | Training broadcast → Overseer suspects | A Tern captain with a good bond can be the one who notices ([[lore/The revelation|The revelation]]) |
| 2 | Overseer goes to Neo Terra | Shining-head dies, the Overseer is lost to the Mourner. More gateway restorations follow |
| 2 | Kepler vote | Legal settlement grants a planet; eviction forces Code Red |
| 2→3 | Gateway into Kyndari's network restored | Starts act 3 |
| 3 | The human gateway to Sol | Sol and the Kepler–Sol sublight lane are revealed |
| 3 | The Eldest speaks / demons stir | Unfortunate captains can confess for their people |
| 3 | The code | Fires on visiting Sol, or 12 turns into act 3. Resolves the ending |

## Map rules (enforced by tests)

- The Center: 3 working gateways (one always to Orcha Station) and a dead one to Træ Træ Tene.
- Kepler ↔ Bhrun-Gai only. Bhrun-Gai ↔ Kepler and Ghor-Dum. Ghor-Dum ↔ Bhrun-Gai and one random, but never more than 2 jumps from the Center.
- Sublight only: Neo Terra from Orcha (hidden until the hive is found), Ur-Gor from Ghor-Dum, Úlaval from Úlamora, Sol from Kepler.
- Kyndari ↔ Sol is a working, human-built gateway. Kyndari's network is connected to act 2 only by dead gateways.
- At most 4 gateways per star, from [[lore/how FTL works|how FTL works]].
- Distances from [[lore/Map of the galaxy notes|Map of the galaxy notes]]: Sol–Center 2600 ly, Sol–Kepler 1810 ly, Neo Terra–Træ Træ Tene 127 px, Úlamora–Úlaval 54 px.
- The Center is not at the galactic core. It sits off toward the edge, up and to one side of Sol, and the act 1 network clusters around it. Orcha → Neo Terra → Træ Træ Tene points toward the open galaxy, where act 2 spreads out. Kyndari and act 3 lie beyond Sol on the opposite side.
- Readability: pipes (gateways and sublight lanes) never cross, never pass within 50 px of a system they don't connect, and two pipes at the same system are always at least 22.5° apart. Dead gateways (other than the Center's) are at most 1000 px long.
- Everything else is random per seed: positions, the extra systems (some from the vault, like Pax Morra, Kyberon, Narcillia, Zirmai and Tarsíus, others generated), and the links between them.
- Acts follow the gateway network: act 2 begins when Træ Træ Tene joins the Center's network, act 3 when Kyndari does.

## Human resources

What the player sees: number of humans aboard and a mood word (Devoted / Content / Grumbling / Restless / Mutinous). Below 10 loyalty they mutiny.

What's hidden:
- **Loyalty** (0–100) and **drift** (−100 to 100). Positive drift means the captain is going human; negative means the humans are going native.
- **Bond** = loyalty × min(humans, 18) / 18. It changes event odds and outcome odds through `bondWeight`, gates some outcomes (the Neo Terran border, Hellborn sightings), and unlocks Code Green.
- Every 3 turns with bond ≥ 50: drift ≤ −30 slowly improves the Republic's view of humans (+1 stance). Drift ≥ 30 raises Hellborn awareness.
- Starting loyalty and drift come from how humans and each species feel about each other: Tern +2/+2, Ál +1/+2, Bhrun +1/0, Unfortunate −1/−1, Gor −2/−1.

## The human colony

Replaced the old crew of 3 to 27 humans. Decided with the author. Step 1 is built, in story and brawl mode (brawl mode is meant to grow story features until it becomes the main game); representatives, petitions, the draft and veterans are still to come.

- **The premise.** The Republic has decided that each species elects one captain to retrofit their ship to host a colony of humans, and the player is one of them. These five ships are the only ones carrying both a Republic species and humans. To a captain, it's like letting a colony of small, numerous, friendly, very capable and armed creatures live in the walls of your home: useful for maintenance, but they are everywhere and always watching. That comparison is for us only: never call the humans ants in game text.
- **Scale.** Hundreds to thousands of humans, not a handful.
- **The colony extension.** Its own card spaces, separate from the triforce and never used in combat. On screen it sits detached from the ship and laid out as a square grid, to show how differently humans arrange their spaces. Only human cards fit there: habitats, hospitals, and so on.
- **Card ideas.** Crawlspace crews (the humans in the walls keep the ship running) make sense. Economy cards pay a small dividend whenever the ship docks at a station: a casino, a shop, a two-sided brothel. Rejected: boarding defence, and anything that changes refits.
- **No upkeep.** The captain pays no wages and no colony upkeep. A colony that big makes ends meet on its own, and the Republic subsidised the retrofit.
- **What's built (step 1).** Rules shared by both modes are in `lib/game_engine/colony.dart`.
  - The colony grid is 3×3 (`Loadout.colonySide`). Colony cards (`CardKind.colony`) fit only there or in the hold, and nothing else fits there. Their tier marks are squares, not triangles.
  - Cards: Habitat Block (houses 100, ×3 per tier), Clinic (cuts the colony's losses by 10% per level, up to 75%, and slowly raises loyalty), Crawlspace Crews (patch 10 hull a turn), and three economy cards paying per hundred humans on docking at a station: Corner Shop (1 cr), Card Room (a gamble, 0 to 3 cr) and Two-Sided Brothel (2 cr, pricier).
  - Every species starts with a Habitat Tower (300) from the Republic's retrofit; the Ál also keep their Clinic. Starting populations: Tern 225, Ál and Bhrun 150, Gor and Unfortunate 75.
  - Each turn (story) or dock (brawl): 1% of the colony is born, and at stations adults sign on into free housing, more where humans live and the better the colony likes the captain. Humans patch 1 hull per 12 of them plus crawlspace crews, never past 75%.
  - Story content counts humans ×25 of the old numbers. Code Green needs 150 humans; the hidden bond saturates at 900 humans (a Habitat Arcology's worth), so growing the colony earns its trust.
  - Removing housing asks first, then the homeless humans leave.
- **The draft.** Once the humans begin taking Neo Terra, a universal draft takes some of the colony's population every turn. Population still grows: children are born aboard and adults sign on to the habitat.
- **Veterans.** A few turns into the draft, veterans who served their time on Neo Terra start coming back. Events like `the_helmet` (still a rough draft) belong here: soldiers' helmets are locked on until a commanding officer unlocks them on their return, so they can't defect. The point is the inhumane conditions on Neo Terra.
- **Governance.** The humans pick representatives to speak to the captain. They govern themselves, but the captain has the final say. Petitions are simple and to the point. The colony's internal politics don't matter to gameplay; only three things do: how much they like the captain (loyalty), the cultural shift (drift), and how developed the Hellborn cell is.
- **No expelling.** The captain can't send part of the colony away, except by selling a habitat.
- **The Hellborn cell.** Agents are careful never to out themselves to the captain. The other humans are suspicious of them, because to a human something is plainly off: red eyes instead of brown or blue, an unusually high alcohol tolerance. A Hellborn representative may hint at wrong warping, or suggest leaving the pipe in Hell to save time, but carefully, since they can't explain how they know.

## Hell

- Every gateway jump has a 3% base chance (plus pipe instability and war modifiers, minus ship shielding) of being dragged into Hell inside the pipe.
- Inside the pipe: ~1 hull damage per turn, events offer ways out. Leaving the pipe ("deep" Hell) costs more hull per turn and pays much better.
- Escaping drops you at a random gateway. In act 1 only act-1 systems; later, any system in an act already reached.
- **The headcount** (`hell_headcount`, built): on getting out of Hell, more likely the longer the ship was there, the humans count more of themselves than went in. Hellborn agents teleported aboard. If an agent is already aboard, they wave it off: time passes strangely in Hell, long enough for children to be born and grow up. Otherwise the other humans point out the newcomers' red eyes and their tolerance for brandy. Needs a free berth, so it's rare until the colony replaces berths.
- **Code Green**: in Hell, with bond ≥ 50 (≥ 60 before the battle of the Bhrun-Gai pipe, so early Code Greens are rare) and ≥ 6 humans, once per run, the humans ask for the comms array. The Hellborn tow you out, heal and pay you, and the story shifts by act: act 1 makes the Gor fleet vanish in the pipe, act 2 leaks wrong warping, act 3 stirs the demons at Kyndari.

## Endings

Resolved when the code is broadcast:
- **Code Red**: the humans were evicted from Kepler, or Republic stance ≤ −30.
- **Code Blue**: the humans were granted a planet (ratified Neo Terra deal or legal Kepler), and stance ≥ 15.
- **Code Yellow**: anything else. The text changes if the demons are stirring and if the Hellborn are your allies.

With a random-choice bot over 3000 runs: Yellow 38%, Red 23%, Blue 13%, ship lost 24%, mutiny 1%. Act 2 starts around turn 21, act 3 around turn 34, and runs average about 42 turns. Re-run with `dart run tool/simulate.dart`, or read one run's story with `dart run tool/simulate.dart story 42`.

## Decisions I made that you may want to change

- **Spellings**: notes and prompt disagree. I used *Orcha Station* (note title; the prompt says Ocha, the outline Ochra), *Ghor-Dum* (prompt; species note says Gor-Dhum), *Træ Træ Tene* (map notes; prompt says tre-tre-trene), *Úlaval* (prompt and species note; map notes say Úlavan).
- The Center ↔ Orcha gateway is fixed, because [[lore/Orcha|Orcha]] says the station is the junction on the Center–Gor route.
- The "big bois" homeworld invaded by Consumers is assumed to be Bhrun-Gai.
- Who restores the Træ Træ Tene gateway is not in the outline. I wrote it as a Tern crew pushed through by a council rattled by the humans, with the Unfortunates "consulting" and the Overseer's veto failing.
- Code Green is once per run.
- Playable species' starting homes: Tern and Unfortunates at the Center, Ál at Orcha, Bhrun at Bhrun-Gai, Gor at Ghor-Dum.
- Combat is a placeholder roll (firepower, hull and humans aboard vs. enemy strength) until the deck builder exists. Holding position at a station gives a few credits and repairs as a stand-in for markets and missions.

## Lore settled since the first draft

- **The Havi civil war** was fought between Havi who wanted to live forever by uploading their minds (like Shining-head) and those who kept their bodies (like the Overseer). That's why the Overseer reacts so fast to humans hearing voices on their radios: it has to kill Shining-head before Shining-head can brainwash the humans or teach them the history the Havi want buried. The training-broadcast beat hints at this.
- **Neo Terra's original name** is generated per run. It was a plain Havi agri-world whose gravity (about 1 G) made lifting cargo too expensive and was too heavy for anyone but humans and Consumers to live in comfortably. Story text uses `{sys:neo_terra}` so it shows whatever the planet is called at the time.
- **The Consumers are modified cockroaches** that the Eldest took from Sol. The humans have always known who visited them, because the Unfortunates' mark is in their cave paintings. Only cockroach events reveal it: a hatchling from a smuggled crate of Consumer eggs, or a Consumer nymph stowing away (act 2+). With a strong enough bond the humans explain, which sets `roach_truth`. That doubles the odds of the Eldest's exposure in act 3 and unlocks its strongest version.
- **The Kyndari–Sol gateway is usable.** On every arrival the Solar fleet blocks you. You get in if your humans vouch for you (bond ≥ 50), if you used Code Green, or if you win an almost hopeless fight. Otherwise you're sent back. Entering Sol (`sol_entered`) triggers the final code.
- **Humans at the start of the game** live aboard the Promethius and at Orcha Station, and have built new ships of their own that roam the galaxy. Their industry is growing; what limits them is food and housing. The House of the Elephant is being built in secret. No Republic species lets humans land on its worlds.
- **Kepler and the name Blue Bog.** Kepler is a high-gravity world orbiting a blue sun, with no intelligent life. An observation platform has watched its evolution for over a thousand years. The humans still aren't allowed to touch down there. To the Republic it is one unimportant blue bog kept for research; the humans are fighting for the right to settle the world they travelled so long to reach.

## Territories and borders

`lib/game_engine/galaxy/territory.dart`. Gates take up so much room in Hell that they sit at intervals, so every **gate node** (any system with a gateway, working or dead) claims the space nearest to it, out to a maximum reach. Space beyond every reach belongs to nobody, because the Havi never expanded across the whole galaxy. Systems without gateways (Neo Terra, Ur-Gor, Úlaval) sit inside someone else's territory.

Each node measures distance its own way, and the border styles fall out of that:
- **Colonial**: square distance, which gives ruled straight lines, right angles and diagonals. The Center and Orcha always use it.
- **Radial**: weighted circular distance, which gives arcs drawn around the gate. Kepler and Sol always use it.
- **Contested**: distance plus noise, which gives squiggly lines. Ghor-Dum and Bhrun-Gai always use it. These can leave enclaves and exclaves, which is deliberate.
- Every other node gets a random style per run.

On the map, borders are drawn for discovered systems from act 1. From act 2, territories are filled with the colour of the faction controlling their gate node, with bold borders between factions. Control is run state (`SetControl` effect): a Bhrun surrender hands Bhrun-Gai to the Gor, Kepler goes back to the Republic on eviction, and Neo Terra goes to the humans when claimed.

The galaxy image is generated by `tool/generate_galaxy.py`, a top-down barred spiral in the game's coordinate space. The old fan-made map is still in `assets/` for reference but is no longer bundled.

## Factions

`lib/game_engine/faction.dart`. **Major factions** hold territory and can expand. **Minor factions** hold little or none, but have ships and fight you if you're their enemy. Every human faction follows the captain of the Promethius as the de facto leader of humanity. That's what keeps humans pulling roughly the same way even though not all of them recognise the Havi's authority.

| Faction | Kind | Leader | How it gets territory |
| --- | --- | --- | --- |
| The Galactic Republic | major | the Overseer | All of act 1 at the start. Re-absorbs unaligned act 2 systems one gateway at a time (the *Reunification* beat). |
| The colonist humans | major | the captain of the Promethius | Kepler, and Neo Terra once claimed |
| The Uploaded *(working name)* | major | Shining-head | Forms in act 2+ only if the Republic has soured on the humans (stance < −10) while Shining-head is alive. Takes Neo Terra and Kepler, and grows in act 3. ~4% of runs. |
| The Solar humans | major | the Earth Council | Sol |
| The Hellborn | major | General Grönigen | Only in Code Red: they spawn at Kyndari and spread through gateways, dead ones included |
| The demons | major | nobody | Only in Code Yellow: the gatecrash happens again at 3 random gate pairs and they spread fast |
| The Tern Collective | major | the hivemind | Takes every Tern system when Tern discontent reaches 5. Not hostile; they just stop accepting the Overseer, the weakest of the Havi. ~24% of runs. |
| The House of the Elephant | minor | Lady Idun the Giantess | Elephant Rock, a hidden asteroid port off the Ghor-Dum–Ur-Gor sublight lane |
| The Fuel Rats | minor | the guild | none |
| Human pirates | minor | whoever won the last vote | none |

**Tern discontent** comes from the Overseer being what it always was: the weakest of the Havi, put in charge of a tourist station as a joke job, and only ruling the Republic because it was the last one left after the gatecrash. It goes up when that weakness shows:
- tolerating the Kepler landing: +1
- legalising the settlement: +2
- failing to protect the Bhrun: +1
- losing the veto fight over the Træ Træ Tene gateway: +1

**House of the Elephant.** You find Elephant Rock by flying the Ghor-Dum–Ur-Gor lane (the trumpeting mines show up on short-range radio) or through rumours at stations. On every arrival the minefield stops you. Your humans can talk you in if they like you enough. Forcing your way through makes the House your enemy, and their gunships will hunt you until you pay for the damage. Once welcomed, the port sells repairs, buys Hell salvage and has crew.

**Fuel Rats.** See Fuel below. They also offer repairs when your hull is at 30% or below.

**Human pirates.** They won't kill humans: with humans aboard they demand a toll, talk, or board you with stun weapons. With no humans aboard they open fire.

**The wars.** Code Blue still ends the run at once. Code Red and Code Yellow now start a 9-turn war: the aggressor expands every turn, and arriving in a system it holds means a checkpoint (Hellborn) or a fight (demons). After 9 turns the run ends, and the ending reports how much the aggressor took.

## Shining-head, the Overseer and the Mourner

- **Shining-head** can only be killed by destroying his complex 10 km under Neo Terra's capital. Either the Overseer does it on its trip to Neo Terra, or the captain does: while docked at Neo Terra, once the voice is known about, the colonists ask for your guns. Killing him dissolves the Uploaded back into the colonists.
- **The Overseer** can only be killed by the Mourner. On the Neo Terra trip the human leader delivers it to the Mourner's domain. If the Uploaded hold Neo Terra and Shining-head lives, the Overseer won't fight through human guards. It comes home humiliated, and alive.
- **The Mourner** is a feared run-ender. Deep in Hell from act 2, rarely (about 9% of random runs), the ship gets caught by its black hole. Burning, pleading or demanding just drags you in, and about 83% of encounters end the run. The only reliable way out is asking politely, and the captain only knows that if:
  - a **secret Hellborn agent** is aboard and outs themselves to save their own life. That counts as Code Green whatever your bond. Or
  - the captain has been through it before.
- **The Mourner's gift.** Anyone it lets go gets a unique card "for their trouble", never the same one twice: Event Horizon, The World That Never Falls, A Polite Request, The Backwards Clock, Grief Engine. Placeholder rules text until combat exists. The Deck button lists owned cards.
- **Hellborn agents** are a hidden flag. Anyone who joins can be one: 25% for the starting crew, 30% for each group recruited. The only hint is a crewman whose stories about growing up "on the colony ship" don't add up (red skies, clocks running backwards, a sea that smells of brandy). Losing every human loses the agent too.

## Deck building (base)

`lib/game_engine/deck/`. The power system is ternary.

- **Nine slots** in a triforce: three small triangles of three slots each, making one big triangle. Only slotted cards do anything. A **hold** of 9 keeps spares.
- **Stacking.** One card is one card, two are two cards. Three of the same card, anywhere in slots or hold, **merge** into its upgraded version. Three upgraded copies merge into the **super** version. Super cards don't merge further. A merged card keeps a slot position if one of its copies had one.
- **Tier values.** Each tier is worth exactly three of the tier below (×1, ×3, ×9). Merging doesn't make the ship stronger by itself; it frees two slots.
- **Ship stats** are the species' ship class plus every slotted card: hull, damage by type (kinetic, energy, hellfire), Hell shielding (capped at 90%) and fuel capacity, plus the colony grid's housing, hospital and crawlspace crews (see "The human colony").
- **Card families:**

| Family | Basic → Upgraded → Super | Per basic card |
| --- | --- | --- |
| plating | Bolted Plating → Ablative Plating → Triplex Lattice Hull | +4 hull |
| inhaler | Ammo Inhaler → Railing Battery → Rip and Tear Array | +2 kinetic |
| lance | Lance Emitter → Twin Lances → Tern Choir Lance | +2 energy |
| brimstone | Brandy Burner → Brimstone Projector → Satan's Last Stand | +2 hellfire |
| habitat (colony) | Habitat Block → Habitat Tower → Habitat Arcology | houses 100 |
| hospital (colony) | Clinic → Human Hospital → Hospital Deck | +1 hospital |
| barrier | Barrier Liner → Pipe Hugger → Demon-Proof Hull | +5% Hell shielding |
| tanks | Drop Tank → Fuel Bladder → Fuel Rat Special | +3 fuel |

- **Unique cards** (the Mourner's gifts) have their own stats, never merge, and carry rules text for when combat exists.
- **Getting cards:** every species starts with three slotted (the Bhrun start with two Bolted Platings, one short of a merge). Winning a fight has a 50% chance of salvaging a basic card. The House of the Elephant sells salvage for 30 credits. Markets come later.
- **UI:** the triangle button in the HUD opens the loadout. Tap a card, then tap where it should go; whatever is there swaps.

## Fuel

A gateway jump burns 1 fuel and a sublight burn 2. Stations sell fuel (1 credit a unit for now, until there's a real income). An empty tank grounds you. Stranded away from a station, the **Fuel Rats** always come: pay 45 credits, or put 70 on your tab (up to 140), or, if both are out of reach, let them strip your plating for parts. **A tab comes due 4 turns later.** If you can't pay, they take every credit, siphon your tanks dry and stop answering your calls. Then the only way out is siphoning fuel from a wreck.

Holding position at a station is the only steady income for now: +6 credits and +3 hull a turn.

## Open questions

- The Havi name for the Kepler system, and the human protagonist's name.
- Is the battle at the Bhrun-Gai pipe the humans' first Code Green? The outline implies yes. Right now it only happens through the captain's own Code Green.
- Shining-head's faction is called the Uploaded until a better name comes along.
- The post-code wars last 9 turns (think 9 rounds of combat). Tune pacing once combat exists.
