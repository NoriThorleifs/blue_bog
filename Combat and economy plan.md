Plan for the card combat system, the ship loadout rules and the economy around them. Nothing here is built yet. The numbers come from a quick tick-based simulation of the rules below. They are a starting point to tune with a proper balance harness once combat is implemented, not final values.

## The rules being balanced

- **The ship.** Every captain flies the same hull: nine slots in a triforce (three triangles of three) and a minimum of **500 hull**. Species differ only in which cards they start with.
- **Timers.** Every equipped card with an effect has a cooldown that starts counting down when combat begins. When it reaches zero the card fires and the timer restarts.
- **Fight length.** Combat ends when a ship reaches 0 hull. At **60 seconds** both ships disengage and nobody wins.
- **Weapons:**
  - **Lasers** need no ammo but are blocked by shields.
  - **Missiles** pass through shields but need ammo, and each drone stops one missile, however big.
  - **Teleported bombs** pass through shields and drones, but they are expensive, use up materials and charge slowly.
- **Shields.** When a shield generator fires, shields refill to the ship's maximum, which is the sum of all generators plus any capacity cards. Shields absorb laser damage before the hull does.
- **Drones.** A fabricator builds one drone each time it fires, up to a maximum, and each drone uses up material. Each drone intercepts one missile.
- **Synergy.** Some cards affect the other cards in their own small triangle. Others affect every card on the ship, either constantly or when they fire.
- **Cargo.** Hold capacity starts at **0** and only cargo cards raise it. Commodities, mission cargo and ammo are all cards. Without hold space, cargo can be put in a slot, where it does nothing but take up the slot.
- **Humans.** Every species starts with a human accommodation card. Unequipping it means losing the whole human crew. Empty berths fill up over time, faster the better your humans think of you.
- **Shops** exist only at trading hubs. Each one rolls **27** cards every round. Equipment sells for **50%** of its buy value. Commodity prices vary from port to port within a range.
- **Hull upgrades** at ports add maximum hull permanently, at an exponentially rising price.

## Balance principles

1. **Measure everything in DPS and effective hull.**
   - Time to kill (TTK) = effective hull ÷ the damage per second (DPS) that actually gets through.
   - Every card gets a power budget measured in DPS, or hull and damage prevented per second, so different card types can be compared.
2. **One unit of power = one basic card.**
   - An upgraded card is worth 3 units and a super card 9, matching the merge rule.
   - Merging never adds power by itself. It frees slots, and that is where the growth comes from.
3. **The player's edge is hull.**
   - A starter has 500 hull, while early enemies have 200–500.
   - Enemies of a similar stage carry *fewer* damage cards than the player. That way a fair fight costs the player 10–50% of their hull, not all of it.
4. **Target fight lengths:**

   | Fight | Target time |
   | --- | --- |
   | Trash fight | 10–25 s |
   | Real fight | 25–45 s |
   | Hard fight, unprepared | hits the 60 s escape |

   Reaching the escape is a soft loss: no loot, and the mission fails. It is not a game over.
5. **Every defence has a counter, and every weapon type has a reason to exist:**

   | Defence | Beaten by |
   | --- | --- |
   | Shields | missiles, teleports |
   | Drones | lasers, teleports, or many small missiles fired first |
   | Hull stacking | everything, slowly |
6. **Timers stay readable.**
   - Cooldowns come from a small set: 3, 4, 5, 6, 8, 12, 18 and 24 s.
   - Speed buffs can't push a cooldown below 50% of its base, or below 1 s.
   - A full minute is roughly 6–20 activations per card, enough for setups to matter without becoming noise.

## Starting numbers (basic tier)

| Card | Cooldown | Effect | Notes |
| --- | --- | --- | --- |
| Laser | 5 s | 30 damage (6 DPS) | No ammo. Blocked by shields. |
| Missile rack | 6 s | 45 damage (7.5 DPS) | 1 missile per shot. Each drone stops one. |
| Teleport bomb | 24 s | 240 damage (10 DPS, first hit at 24 s) | 1 material per shot. Nothing stops it. Expensive. |
| Shield generator | 6 s | +30 maximum shield, refills to maximum | Absorbs up to 5 laser DPS. |
| Drone fabricator | 8 s | +1 maximum drone, builds 1 drone | 1 material per drone. |
| Hull plating | — | +100 hull | Passive. |
| Cargo pod | — | +3 hold capacity | Passive. Upgraded +9, super +27. |
| Bunk module | — | +3 human berths | Passive. Every starter kit has one. |

- **Upgraded and super cards** keep the same cooldown and have 3× or 9× the effect.
- **Ammo and materials** are commodity cards. One crate holds 9 shots, used up in combat from the hold or a slot, and restocked at shops.
- **Synergy budget:**

  | Synergy | Budget |
  | --- | --- |
  | Triangle card (affects the 2 other cards in its triangle) | ≈ one extra card's worth, e.g. +50% to each neighbour, or −33% cooldown |
  | Ship-wide card (affects the other 8) | ≈ one extra card's worth, e.g. +12% each, or "when this fires, every other card's timer drops by 1 s" |
  | Triangle set bonus (3 cards of the same type in a triangle) | +25% to that triangle |

## Enemies

Act 1 tiers, with 500 hull for the player:

| Enemy | Hull | Cards | Role |
| --- | --- | --- | --- |
| Scout | 200 | laser | trash, ~20 s |
| Raider | 300 | laser, shield | teaches that shields stop lasers |
| Pirate | 350 | laser, missile rack | |
| Gunship | 500 | 2 lasers, shield | mid-act test |
| Elite | 700–800 | 2 missile racks, laser, drones, shield | act 1 gate. Needs upgrades or the right counter. |

**Scaling.** Each act multiplies enemy hull and damage by **×3**: the act 2 scout has ~600 hull. Player power is meant to grow the same way:

| Point in the run | Target power |
| --- | --- |
| Start | ~3 units |
| End of act 1 | ~9 units (a full board of basics, or three upgraded cards) |
| End of act 2 | ~27 units |
| End of act 3 | ~81 units (a board of super cards) |

Hull upgrades and hull cards scale the player's 500 alongside.

## What the simulation showed

- **A fresh starter** beats scouts, raiders and pirates in 18–40 s, keeping 50–95% of its hull. The gunship is a coin flip or an escape, depending on the kit. The elite beats every starter.
- **Plus three basic cards,** everything up to the gunship falls in 10–40 s. Of five kits, only the drone build beats the elite, because drones eat its missiles. That is exactly the counter-play we want.
- **A hull-heavy kit with a single laser** can't break a shielded raider within 60 s. **Every starter kit needs at least two damage cards.**

## Starter kits

Same ship for everyone. Every kit has a bunk module and a cargo pod, 2 damage cards and 1 support card, which leaves 4 slots free.

| Species | Kit | Plays as |
| --- | --- | --- |
| Tern | 2 lasers, shield generator | laser and shield, steady |
| Gor | 2 missile racks + ammo crate, hull plating | burst through shields |
| Bhrun | laser, missile rack + ammo, 2× hull plating (the second takes a free slot) | tank. The cargo pod still counts. |
| Ál | 2 lasers, drone fabricator + materials | anti-missile |
| Unfortunate | laser, teleport bomb + materials, shield generator | slow, unstoppable finisher |

## Economy

- **Equipment prices.**
  - Base value: basic 30, upgraded 90, super 270. Buying three basics costs the same as one upgraded card.
  - Each shop multiplies prices by a random 0.8–1.2 per card.
  - Selling returns 50% of the base value.
- **Shops.** Only trading-hub systems have one, a new tag on the map. Each rolls **27 cards per round**. I'm reading "round" as each turn you arrive or stay there. The mix is roughly 60% basic, 30% upgraded, 10% super, plus commodities.
- **Commodities.**
  - Each has a base price and a per-hub multiplier between 0.6 and 1.6, set per run and drifting a little each turn.
  - They are not halved when sold.
  - Trade missions name a commodity and a destination that pays 2–3× its usual price, which leads to "buy every unit you can carry" runs.
- **Hull upgrades.** +100 maximum hull per purchase at any port with a shipyard. The price doubles each time: 50, 100, 200, 400, 800, and so on.
- **Repairs.** If hull damage carries over between fights, repairs cost about 1 credit per 5 hull.
- **Income targets.**
  - A typical act 1 turn should net enough for one basic card every 2–3 turns.
  - Trade runs and missions should be clearly better than odd jobs.
- **Humans.**
  - Each empty berth has a chance to fill each turn:
    - 5% + 25% × (loyalty ÷ 100) in human-populated systems.
    - A third of that anywhere else.
  - Removing the last accommodation card asks for confirmation, then every human leaves.

## How it gets built

Status: steps 1, 2, 4 (markets and shipyards), 6 (combat screen) and 7 (rescaling) are built and in the game.
- **Combat:** story fights are real fights against enemy templates chosen by the event's strength rating. Each choice that leads to a fight shows the enemy first.
  - **Win:** you scrap the enemy for credits, with a 25% chance to salvage each of its cards.
  - **Escape:** no loot, and the enemy remembers you.
  - **Loss:** the ship is destroyed.
- **Interim act scaling:** enemies get 2× hull in act 2, and 3× hull plus one tier of better equipment in act 3. This stays until missions and trading give the player the income the ×3-per-act plan assumes.
- **Shops come in two sizes:**
  - **Markets:** 27 offers of equipment and commodities, plus a shipyard for repairs and hull upgrades. Orcha Station, the Center and Elephant Rock always have one, and so do about a quarter of the other stations.
  - **Trading posts:** 9 offers. They only buy and sell supplies (ammunition and materials) and commodities, and have no shipyard. About half of the other stations have one.

First balance findings:
- **Teleport bombs are too strong** at 240 damage. They're in 65% of winning random loadouts, and the Unfortunate starter plus any three cards always beats the Gunship.
- **12% of fair fights reach the 60 s escape** (target 10%). Shielded Gunships stall laser-only builds.

1. **Combat model in pure Dart.**
   - Deterministic ticks of 0.1 s, cards as data (cooldown, effect, target rules).
   - It replaces today's dice-roll `Combat` effect with real fights against enemy templates.
2. **Balance harness** like `tool/simulate.dart`.
   - Runs thousands of fights between starter kits, enemy tiers and random loadouts built from the shop.
   - Reports TTK, hull lost, the share of fights reaching 60 s, and win rates by archetype.
   - **Acceptance targets:**
     - Every starter beats scouts and raiders with over 50% hull left.
     - No more than 10% of fair fights reach the 60 s escape.
     - No single basic card is in more than 30% of winning random loadouts.
3. **Loadout rules.** Triangle and ship-wide synergy, the hold starting at 0, cargo in slots, the accommodation rule, and berths filling over time.
4. **Shops and trading hubs.** The 27-card roll, sell at 50%, per-hub commodity prices, and hull upgrades.
5. **Missions.** Cargo delivery, trade runs, and bounties that start fights.
6. **Combat screen.** Card timers filling up, shield and drone counters, missiles and intercepts, the 60 s clock.
7. **Rescaling.** Story events that change hull (today's ±2 to ±15 on a ~30 scale) move to the 500 scale, or turn into repair bills.

## Decisions made

- **Hull damage carries over between fights.**
  - Humans patch the ship between turns, but never completely: each turn out of combat, every human repairs 2 hull, up to 75% of maximum hull.
  - Full repairs need a berth at a port with a shipyard, at about 1 credit per 5 hull.
- **Players can't set timers directly.** Equipment changes them instead:
  - triangle cards that make weapons charge a percentage faster
  - ship-wide capacitors
  - quick-arm fuzes that make smaller missiles arm faster, so they fire first and soak up drones
- **Escaping at 60 seconds:** no loot, and the hostile faction remembers you.
- **Winning lets you scrap the enemy ship:** credits, plus a chance to salvage each of its cards.
- **Boss fights** that matter to the story have a **tractor beam**. There's no 60-second limit, so you win or you die.
- **A shop rolls its 27 cards on every visit.** A small fee rerolls it: 5 credits, plus 5 more for each reroll in the same visit.

