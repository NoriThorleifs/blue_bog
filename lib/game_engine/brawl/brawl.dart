import 'dart:math';

import '../captain/species.dart';
import '../colony.dart';
import '../combat/catalog.dart';
import '../combat/combat.dart';
import '../combat/equipment.dart';
import '../deck/loadout.dart';
import '../engine.dart' show IllegalMove;
import '../gambling/roulette.dart';
import '../gambling/twenty_seven.dart';
import '../market.dart';
import '../rng.dart';
import '../run_state.dart';
import 'brawl_enemies.dart';
import 'brawl_events.dart';
import 'brawl_outcomes.dart';
import 'brawl_state.dart';

export 'brawl_enemies.dart';
export 'brawl_state.dart';

/// Brawl mode: a test of the game with nothing but combat and commerce.
///
/// The captain docks at a station, buys, sells and refits, then launches.
/// Something always happens on the way out (see [brawlEvents]), usually
/// followed by a fight. Surviving brings them to another station, picked
/// at random, and the loop repeats until the ship is lost. There is no
/// map, no story and no fuel, but there is a human colony aboard (see
/// [Colony]): it grows, patches the hull and pays dividends at each dock.
///
/// A captain mad enough can dive into Hell through a demon's bite in the
/// pipe. Hell has no stations: every turn there brings a Hell event, the
/// sea eats at the hull, and the demons are tough. The rewards are Hell's
/// own cards, Hell Brandy and, for the polite, the Mourner's gift.

class BrawlEngine {
  const BrawlEngine();

  /// Credits on top of a species' starting money, since there are no odd
  /// jobs or story rewards to fall back on.
  static const startingBonus = 50;

  /// Hull Hell's sea eats every turn.
  static const hellCorrosion = 25;

  BrawlState start(Species species, {required int seed}) {
    final loadout = Loadout();
    for (final id in brawlStartingCards(species)) {
      loadout.add(id);
    }
    final rng = GameRng(seed ^ 0xB4A71);
    final station = rng.pick(brawlStations.keys.toList());
    final market = _roll(station, rng, seed, 1);
    return BrawlState(
      seed: seed,
      species: species,
      rngState: rng.state,
      hull: ShipStats.of(loadout).maxHull,
      loadout: loadout,
      credits: species.startingCredits + startingBonus,
      station: station,
      market: market,
      humans: HumanResources(
        count: species.startingHumans,
        loyalty: 50 + 10 * species.humansLikeThem,
        drift: 10 * species.theyLikeHumans,
      ),
    );
  }

  Market _roll(
    String station,
    GameRng rng,
    int seed,
    int round, {
    int rerolls = 0,
  }) => Market.roll(
    station,
    rng,
    seed,
    rerolls: rerolls,
    stock: brawlFamilies,
    time: round,
  );

  /// The supply shock at the station right now, if any.
  SupplyShock? supply(BrawlState s) => supplyAt(s.station, s.seed, s.round);

  /// What a card usually costs across every brawl station.
  int median(BrawlState s, String id) =>
      medianPrice(equipmentById(id), brawlStations.keys, s.seed);

  int sellValue(BrawlState s, String id) =>
      sellPrice(equipmentById(id), s.station, s.seed, time: s.round);

  /// A demon from [demons], tougher the further along the brawl is and the
  /// longer the ship has been in Hell.
  EnemyTemplate demonFor(BrawlState s, int index) {
    final level = s.round + s.hellTurns;
    return demons[index].forAct(1 + (level - 1) ~/ 5);
  }

  /// The ship [plan] sends against the captain.
  EnemyTemplate enemyFor(BrawlState s, Fight plan) => switch (plan) {
    Fight(:final demon?) => demonFor(s, demon),
    Fight(:final special?) => special.at(s.round),
    _ => brawlEnemy(s.round + plan.roundsAhead, s.seed),
  };

  BrawlState _step(BrawlState state, void Function(BrawlState, GameRng) f) {
    if (state.lost) throw IllegalMove('Your ship is lost');
    final s = state.clone();
    final rng = GameRng(s.rngState);
    f(s, rng);
    s.rngState = rng.state;
    return s;
  }

  void _requireDocked(BrawlState s) {
    if (!s.docked) throw IllegalMove('Not docked');
  }

  /// Puts a new loadout on the ship, trimming hull to its new maximum.
  void _refit(BrawlState s, Loadout loadout) {
    final lost = humansLostWith(s, loadout);
    s
      ..loadout = loadout
      ..hull = min(s.hull, s.stats.maxHull);
    if (lost > 0) {
      s.humans = s.humans.copyWith(count: s.humans.count - lost);
      s.log.add('$lost humans left the colony: no homes for them.');
    }
  }

  /// Humans who would leave if [loadout] replaced the current one: every
  /// human without a home in the colony.
  int humansLostWith(BrawlState s, Loadout loadout) => max(
    0,
    s.humans.count -
        ShipStats.of(loadout, hullUpgrades: s.hullUpgrades).housing,
  );

  // Trading and refitting ----------------------------------------------------

  BrawlState buy(BrawlState state, int offerIndex) {
    _requireDocked(state);
    final offer = state.market.offers[offerIndex];
    if (offer.sold) throw IllegalMove('Already sold');
    if (state.credits < offer.price) throw IllegalMove('Not enough credits');
    final loadout = state.loadout.copy();
    final merges = loadout.add(offer.cardId);
    if (merges == null) throw IllegalMove('No room on the ship');
    return _step(state, (s, _) {
      s
        ..credits -= offer.price
        ..market = s.market.withOffer(offerIndex, offer.bought);
      s.log = [...merges];
      _refit(s, loadout);
    });
  }

  BrawlState sell(BrawlState state, CardSpot spot) {
    _requireDocked(state);
    final id = state.loadout.at(spot);
    if (id == null) throw IllegalMove('Nothing there');
    if (!state.market.buys(equipmentById(id))) {
      throw IllegalMove('Can\'t sell that');
    }
    final loadout = state.loadout.copy()..takeOut(spot);
    if (!loadout.holdFits) {
      throw IllegalMove('The hold can\'t fit everything without that pod');
    }
    return _step(state, (s, _) {
      s.credits += sellValue(state, id);
      s.log = [];
      _refit(s, loadout);
    });
  }

  /// Moves a card. Allowed anywhere, Hell included: refitting between
  /// fights is the point.
  BrawlState arrange(BrawlState state, CardSpot from, CardSpot to) {
    if (state.loadout.whyNotMove(from, to) case final why?) {
      throw IllegalMove(why);
    }
    final loadout = state.loadout.copy()..move(from, to);
    if (!loadout.holdFits) {
      throw IllegalMove('The hold can\'t fit everything without that pod');
    }
    return _step(state, (s, _) => _refit(s, loadout));
  }

  /// Uses up the card at [from] on the card at [to], like Hell Brandy
  /// tagging a card Hellish.
  BrawlState use(BrawlState state, CardSpot from, CardSpot to) {
    final loadout = state.loadout.copy();
    final item = equipmentById(state.loadout.at(from) ?? '');
    if (!loadout.use(from, to)) throw IllegalMove('That has no effect');
    if (!loadout.holdFits) {
      throw IllegalMove('The hold can\'t fit everything');
    }
    return _step(state, (s, _) {
      _refit(s, loadout);
      final target = equipmentById(loadout.at(to)!);
      s.log = ['${target.name} is now ${item.grantsTag!.label}.'];
    });
  }

  BrawlState reroll(BrawlState state) {
    _requireDocked(state);
    final price = state.market.rerollPrice;
    if (state.credits < price) throw IllegalMove('Not enough credits');
    return _step(state, (s, rng) {
      s
        ..credits -= price
        ..market = _roll(
          s.station,
          rng,
          s.seed,
          s.round,
          rerolls: s.market.rerolls + 1,
        );
    });
  }

  /// Credits to repair the hull fully, or null if it's undamaged or there's
  /// no shipyard to do it.
  int? repairCost(BrawlState s) {
    final missing = s.stats.maxHull - s.hull;
    return missing <= 0 || !s.docked ? null : (missing / hullPerCredit).ceil();
  }

  /// Repairs as much hull as the captain can afford.
  BrawlState repair(BrawlState state) {
    final cost = repairCost(state);
    if (cost == null) throw IllegalMove('Nothing to repair');
    final paid = min(cost, state.credits);
    if (paid <= 0) throw IllegalMove('Not enough credits');
    return _step(state, (s, _) {
      s
        ..credits -= paid
        ..hull = min(s.stats.maxHull, s.hull + paid * hullPerCredit);
    });
  }

  int hullUpgradeCost(BrawlState s) => hullUpgradePrice(s.hullUpgrades);

  BrawlState upgradeHull(BrawlState state) {
    _requireDocked(state);
    final cost = hullUpgradeCost(state);
    if (state.credits < cost) throw IllegalMove('Not enough credits');
    return _step(state, (s, _) {
      s
        ..credits -= cost
        ..hullUpgrades += 1
        ..hull += ShipStats.hullPerUpgrade;
    });
  }

  // Gambling -------------------------------------------------------------------

  /// One spin of the roulette wheel. Only at a station that runs roulette.
  /// The stake is one of [rouletteStakes], or every credit the captain has.
  BrawlState spinRoulette(BrawlState state, RouletteBet bet) {
    _requireDocked(state);
    if (state.gamblingGame != GamblingGame.roulette) {
      throw IllegalMove('No roulette here');
    }
    final allIn = bet.stake == state.credits && bet.stake > 0;
    if (!rouletteStakes.contains(bet.stake) && !allIn) {
      throw IllegalMove('The table doesn\'t take that bet');
    }
    if (state.credits < bet.stake) throw IllegalMove('Not enough credits');
    return _step(state, (s, rng) {
      final spin = RouletteSpin(
        bet,
        wheelOrder[rng.nextInt(wheelOrder.length)],
      );
      s
        ..credits += spin.net
        ..lastSpin = spin
        ..log = [];
    });
  }

  void _requireGame(BrawlState s, GamblingGame game) {
    _requireDocked(s);
    if (s.gamblingGame != game) throw IllegalMove('Not played here');
  }

  /// Deals a game of 27. The stake is one of [twentySevenStakes], or every
  /// credit the captain has, and is paid up front.
  BrawlState dealTwentySeven(BrawlState state, int stake) {
    _requireGame(state, GamblingGame.al);
    if (state.twentySeven case final g? when !g.over) {
      throw IllegalMove('Finish the count first');
    }
    final allIn = stake == state.credits && stake > 0;
    if (!twentySevenStakes.contains(stake) && !allIn) {
      throw IllegalMove('The table doesn\'t take that bet');
    }
    if (state.credits < stake) throw IllegalMove('Not enough credits');
    return _step(state, (s, rng) {
      s
        ..credits -= stake
        ..twentySeven = TwentySeven.deal(stake, rng)
        ..log = [];
    });
  }

  BrawlState takeTile(BrawlState state, int index) =>
      _count(state, CountStatus.counting, (g, rng) => g.take(index, rng));

  BrawlState keepCounting(BrawlState state) =>
      _count(state, CountStatus.holy, (g, rng) => g.keepCounting(rng));

  BrawlState walkAway(BrawlState state) =>
      _count(state, CountStatus.holy, (g, _) => g.walk());

  BrawlState _count(
    BrawlState state,
    CountStatus need,
    TwentySeven Function(TwentySeven, GameRng) move,
  ) {
    _requireGame(state, GamblingGame.al);
    final game = state.twentySeven;
    if (game == null || game.status != need) throw IllegalMove('Not now');
    return _step(state, (s, rng) {
      final next = move(game, rng);
      s
        ..twentySeven = next
        ..credits += next.payout;
    });
  }

  // Events and fights --------------------------------------------------------

  /// Leaves the station. Something always happens on the way out; the
  /// scheduled fight follows unless the captain's choice changes that.
  BrawlState launch(BrawlState state) {
    _requireDocked(state);
    return _step(state, (s, rng) {
      // Leaving mid-count forfeits the stake on the table, and the wreckage
      // stays behind.
      s
        ..plannedFight = const Fight()
        ..twentySeven = null
        ..wreckage = []
        ..log = [];
      _pickEvent(s, rng);
    });
  }

  /// Whether the captain can make choice [index] of the current event.
  bool canChoose(BrawlState s, int index) {
    final event = s.currentEvent;
    if (event == null || s.result != null) return false;
    return event.choices[index].available?.call(s) ?? true;
  }

  BrawlState choose(BrawlState state, int index) {
    if (!canChoose(state, index) || state.awaitingVerdict) {
      throw IllegalMove('Not now');
    }
    return _step(state, (s, rng) {
      final choice = s.currentEvent!.choices[index];
      final outcome = rng.weighted(choice.outcomes, (o) => o.weight)!;
      final lines = <String>[];
      for (final effect in outcome.effects) {
        applyBrawlEffect(s, rng, effect, lines);
      }
      s.result = [
        if (outcome.text.isNotEmpty) outcome.text,
        if (lines.isNotEmpty) lines.join(' '),
      ].join('\n\n');
    });
  }

  /// Moves on once the captain has read what came of their choice: fights
  /// whatever is waiting, then docks or, in Hell, faces the next turn.
  BrawlState proceed(BrawlState state) {
    if (state.result == null) throw IllegalMove('Choose first');
    return _step(state, (s, rng) {
      final fight = s.plannedFight;
      s
        ..event = null
        ..result = null
        ..plannedFight = null
        ..wreckage = []
        ..log = [];
      if (s.lost) return;
      if (fight != null) {
        _fight(s, rng, fight);
        if (s.lost) return;
      }
      // Satan beaten: nothing moves until the captain retires or goes on.
      if (s.awaitingVerdict) return;
      if (s.inHell) {
        _hellTurn(s, rng);
      } else {
        _dock(s, rng);
      }
    });
  }

  void _pickEvent(BrawlState s, GameRng rng) {
    final event =
        brawlEvents
            .where((e) => e.always && (e.condition?.call(s) ?? true))
            .firstOrNull ??
        rng.weighted(
          brawlEvents.where(
            (e) =>
                !e.always &&
                e.hell == s.inHell &&
                (e.condition?.call(s) ?? true),
          ),
          (e) => e.weight?.call(s) ?? 1,
        )!;
    s
      ..event = event.id
      ..result = null;
  }

  void _hellTurn(BrawlState s, GameRng rng) {
    s
      ..hellTurns += 1
      ..hull -= hellCorrosion;
    if (s.hull <= 0) {
      s
        ..hull = 0
        ..lost = true
        ..log.add('Hell\'s sea ate through the last of the hull.');
      return;
    }
    s.log.add('The sea eats $hellCorrosion hull. There is no shipyard here.');
    _pickEvent(s, rng);
  }

  void _dock(BrawlState s, GameRng rng) {
    if (s.leavingHell) {
      // Hell's clocks run anywhere from ten times fast to three times
      // backwards, so the galaxy may be older or younger than you left it.
      final shift = rng.range(-3, 2);
      s
        ..leavingHell = false
        ..round = max(1, s.round + shift)
        ..log.add(switch (shift) {
          < 0 =>
            'The clocks ran backwards in Hell. The galaxy is '
                '${-shift} ${-shift == 1 ? 'fight' : 'fights'} younger than '
                'you left it.',
          0 => 'The clocks agree, for once.',
          _ =>
            'The clocks raced in Hell. The galaxy is $shift '
                '${shift == 1 ? 'fight' : 'fights'} older than you left it.',
        });
    } else {
      s.round += 1;
    }
    s.station = rng.pick([
      for (final id in brawlStations.keys)
        if (id != s.station) id,
    ]);
    s.market = _roll(s.station, rng, s.seed, s.round);
    s.log.add('Docked at ${s.stationName}.');
    _tendColony(s, rng);
    if (supply(s) case final shock?) {
      final good = equipmentById(shock.goodId).name.toLowerCase();
      s.log.add(
        shock.shortage
            ? '${shock.label} here. ${s.stationName} will pay a fortune for '
                  '$good.'
            : '${shock.label} here. ${s.stationName} is practically giving '
                  '$good away.',
      );
    }
  }

  /// Jettisons the card at [spot] into space, for nothing. Allowed anywhere:
  /// it's how the captain makes room for something better.
  BrawlState jettison(BrawlState state, CardSpot spot) {
    final id = state.loadout.at(spot);
    if (id == null) throw IllegalMove('Nothing there');
    final loadout = state.loadout.copy()..takeOut(spot);
    if (!loadout.holdFits) {
      throw IllegalMove('The hold can\'t fit everything without that pod');
    }
    return _step(state, (s, _) {
      s.log = ['Jettisoned ${equipmentById(id).name}.'];
      _refit(s, loadout);
    });
  }

  /// Takes the card at [index] in the wreckage aboard, if there's room.
  BrawlState salvage(BrawlState state, int index) {
    if (index < 0 || index >= state.wreckage.length) {
      throw IllegalMove('Nothing there');
    }
    final id = state.wreckage[index];
    final loadout = state.loadout.copy();
    final merges = loadout.add(id);
    if (merges == null) {
      throw IllegalMove('No room. Jettison something first.');
    }
    return _step(state, (s, _) {
      s
        ..wreckage.removeAt(index)
        ..log = [
          'Took ${equipmentById(id).name} from the wreckage.',
          ...merges,
        ];
      _refit(s, loadout);
    });
  }

  /// Ends a brawl the captain has won, after beating Satan.
  BrawlState retire(BrawlState state) {
    if (!state.awaitingVerdict) throw IllegalMove('Not now');
    return _step(state, (s, _) => s.retired = true);
  }

  /// Fights on past Satan, for score. Every fight from here on is harder
  /// than the last.
  BrawlState goEndless(BrawlState state) {
    if (!state.awaitingVerdict) throw IllegalMove('Not now');
    return _step(state, (s, rng) {
      s.flags.add(wentEndless);
      if (s.inHell) {
        _hellTurn(s, rng);
      } else {
        _dock(s, rng);
      }
    });
  }

  /// At each dock the humans patch the hull, the colony grows, and its
  /// businesses pay out. See [Colony].
  void _tendColony(BrawlState s, GameRng rng) {
    final before = s.hull;
    s.hull = Colony.patched(s.hull, s.humans.count, s.stats);
    if (s.hull > before) {
      s.log.add('Your humans patched ${s.hull - before} hull.');
    }
    final (:born, :joined) = Colony.growth(
      humans: s.humans.count,
      housing: s.stats.housing,
      loyalty: s.humans.loyalty,
      station: true,
      humanStation: s.humansLiveHere,
      rng: rng,
    );
    s.humans = s.humans.copyWith(count: s.humans.count + born + joined);
    if (joined > 0) s.log.add('$joined humans moved into the colony.');
    final paid = Colony.dividends(s.loadout, s.humans.count, rng);
    if (paid > 0) {
      s.credits += paid;
      s.log.add('The colony\'s businesses paid $paid credits.');
    }
  }

  /// Fights [plan]. Winning pays scrap and maybe salvage; breaking away at
  /// the time limit pays nothing. Losing ends the brawl.
  void _fight(BrawlState s, GameRng rng, Fight plan) {
    final demon = plan.demon != null;
    final enemy = enemyFor(s, plan);
    final player = Combatant(
      name: 'you',
      loadout: s.loadout.forCombat,
      baseHull: baseHull + s.hullUpgrades * ShipStats.hullPerUpgrade,
      hull: s.hull,
    );
    final foe = Combatant(
      name: enemy.name,
      loadout: enemy.loadout,
      baseHull: enemy.hull,
    );
    final result = fight(player, foe, tractorBeam: plan.tractorBeam);
    s.hull = result.hull;
    final salvage = <String>[];
    var scrap = 0;
    switch (result.outcome) {
      case CombatOutcome.win:
        s.fightsWon += 1;
        scrap = (foe.maxHull ~/ (demon ? 6 : 10) * plan.scrap).round();
        s.credits += scrap + plan.winCredits;
        s.log.add(
          'Destroyed the ${enemy.name} and scrapped it for $scrap cr'
          '${plan.winCredits > 0 ? ', plus ${plan.winCredits} cr for the job' : ''}.',
        );
        for (final id in enemy.loadout.slots.whereType<String>()) {
          if (equipmentById(id).tier == Tier.unique) continue;
          if (!rng.chance(demon ? 0.35 : 0.25)) continue;
          final merges = s.loadout.add(id);
          if (merges == null) {
            s.wreckage.add(id);
            continue;
          }
          salvage.add(id);
          s.log
            ..add('Salvaged ${equipmentById(id).name}.')
            ..addAll(merges);
        }
        for (final id in plan.winCards) {
          gainCard(s, id, s.log, force: true);
        }
        for (final id in enemy.cargo) {
          if (s.loadout.add(id) == null) {
            s.wreckage.add(id);
            continue;
          }
          s.log.add('Plundered ${equipmentById(id).name}.');
        }
        if (plan.special == SpecialEnemy.satan) {
          s.flags.add(beatSatan);
          s.log.add(
            'Satan\'s ship comes apart around him. He crawls back into Hell, '
            'beaten. Nobody in the Republic will ever believe you.',
          );
        }
        if (s.wreckage.isNotEmpty) s.log.add(wreckageNote(s.wreckage));
      case CombatOutcome.escape:
        s.log.add('Broke away from the ${enemy.name}. No scrap.');
      case CombatOutcome.loss:
        s.lost = true;
        s.log.add('The ${enemy.name} destroyed your ship.');
    }
    s.lastCombat = FightRecord(
      enemyName: enemy.name,
      player: player.loadout,
      enemy: enemy.loadout,
      playerMaxHull: player.maxHull,
      enemyMaxHull: foe.maxHull,
      playerStartHull: player.hull,
      result: result,
      salvage: salvage,
      scrapCredits: scrap,
    );
  }
}
