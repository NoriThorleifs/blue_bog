import 'dart:math';

import '../captain/species.dart';
import '../combat/catalog.dart';
import '../combat/combat.dart';
import '../deck/loadout.dart';
import '../engine.dart' show IllegalMove;
import '../market.dart';
import '../rng.dart';
import 'brawl_events.dart';

/// Brawl mode: a test of the game with nothing but combat and commerce.
///
/// The captain docks at a station, buys, sells and refits, then launches.
/// Something always happens on the way out (see [brawlEvents]), usually
/// followed by a fight. Surviving brings them to another station, picked
/// at random, and the loop repeats until the ship is lost. There is no
/// map, no story, no fuel and no humans.
///
/// A captain mad enough can dive into Hell through a demon's bite in the
/// pipe. Hell has no stations: every turn there brings a Hell event, the
/// sea eats at the hull, and the demons are tough. The rewards are Hell's
/// own cards, Hell Brandy and, for the polite, the Mourner's gift.

/// Stations a brawl can dock at. Commodity prices differ between them.
const brawlStations = {
  'orcha': 'Orcha Station',
  'center': 'The Center',
  'ghor_dum': 'Ghor-Dum',
  'bhrun_gai': 'Bhrun-Gai',
  'kepler': 'Kepler',
  'ur_gor': 'Ur-Gor',
  'trae_trae_tene': 'Træ Træ Tene',
  'ulaval': 'Úlaval',
  'kyndari': 'Kyndari',
  'narcillia': 'Narcillia',
  'zirmai': 'Zirmai',
  'kyberon': 'Kyberon',
};

/// Families left out of brawl mode. Humans are out while we test it, so
/// no bunks or hospitals; Hell shielding and fuel tanks do nothing without
/// a map.
const brawlExcludedFamilies = {'bunks', 'hospital', 'barrier', 'tanks'};

final brawlFamilies = [
  for (final f in equipmentFamilies)
    if (!brawlExcludedFamilies.contains(f.id)) f,
];

bool _allowed(String id) =>
    !brawlExcludedFamilies.contains(equipmentById(id).family);

/// Act 1 enemy tiers by fight number, then the dreadnought, scaled up by
/// act every four fights after that.
const _schedule = [0, 1, 2, 2, 3, 3, 4, 4, 5, 5];

/// The enemy waiting at the end of fight [round].
EnemyTemplate brawlEnemy(int round) {
  final i = round - 1;
  if (i < _schedule.length) return act1Enemies[_schedule[i]];
  final act = 2 + (i - _schedule.length) ~/ 4;
  return act1Enemies.last.forAct(act);
}

/// A brawl in progress. Like [RunState], the engine works on a [clone] and
/// never mutates a state it was handed.
class BrawlState {
  BrawlState({
    required this.seed,
    required this.species,
    required this.rngState,
    required this.hull,
    required this.loadout,
    required this.credits,
    required this.station,
    required this.market,
    this.round = 1,
    this.fightsWon = 0,
    this.hullUpgrades = 0,
    this.event,
    this.result,
    this.plannedFight,
    this.inHell = false,
    this.hellTurns = 0,
    this.leavingHell = false,
    this.lastCombat,
    this.lost = false,
    Set<String>? flags,
    List<String>? log,
  }) : flags = flags ?? {},
       log = log ?? [];

  /// Fixes commodity prices at each station for the whole brawl.
  final int seed;
  final Species species;
  int rngState;

  /// How far along the difficulty curve the brawl is, from 1. Usually one
  /// more than the fights so far, until Hell's clocks get involved.
  int round;
  int fightsWon;
  int hull;
  int hullUpgrades;
  Loadout loadout;
  int credits;

  /// Key into [brawlStations]: where the ship is docked, or last docked.
  String station;
  Market market;

  /// The event in front of the captain, if any.
  String? event;

  /// What came of the captain's choice, once they've made it.
  String? result;

  /// The fight that follows the current event.
  Fight? plannedFight;
  bool inHell;
  int hellTurns;

  /// Set when an event lets the ship out of Hell, until it docks.
  bool leavingHell;
  FightRecord? lastCombat;
  bool lost;
  Set<String> flags;

  /// What happened since the last decision, for the screen.
  List<String> log;

  String get stationName => brawlStations[station]!;
  ShipStats get stats => ShipStats.of(loadout, hullUpgrades: hullUpgrades);
  EnemyTemplate get nextEnemy => brawlEnemy(round);
  BrawlEvent? get currentEvent => event == null ? null : brawlEventsById[event];

  /// At a station with nothing pending: free to trade and launch.
  bool get docked => event == null && !inHell && !lost;

  BrawlState clone() => BrawlState(
    seed: seed,
    species: species,
    rngState: rngState,
    hull: hull,
    loadout: loadout.copy(),
    credits: credits,
    station: station,
    market: market,
    round: round,
    fightsWon: fightsWon,
    hullUpgrades: hullUpgrades,
    event: event,
    result: result,
    plannedFight: plannedFight,
    inHell: inHell,
    hellTurns: hellTurns,
    leavingHell: leavingHell,
    lastCombat: lastCombat,
    lost: lost,
    flags: {...flags},
    log: [...log],
  );
}

class BrawlEngine {
  const BrawlEngine();

  /// Credits on top of a species' starting money, since there are no odd
  /// jobs or story rewards to fall back on.
  static const startingBonus = 50;

  /// Hull Hell's sea eats every turn.
  static const hellCorrosion = 25;

  BrawlState start(Species species, {required int seed}) {
    final loadout = Loadout();
    for (final id in [
      ...species.ship.startingCards,
      ...species.ship.startingHold,
    ]) {
      if (_allowed(id)) loadout.add(id);
    }
    final rng = GameRng(seed ^ 0xB4A71);
    final station = rng.pick(brawlStations.keys.toList());
    final market = _roll(station, rng, seed);
    return BrawlState(
      seed: seed,
      species: species,
      rngState: rng.state,
      hull: ShipStats.of(loadout).maxHull,
      loadout: loadout,
      credits: species.startingCredits + startingBonus,
      station: station,
      market: market,
    );
  }

  Market _roll(String station, GameRng rng, int seed, {int rerolls = 0}) =>
      Market.roll(station, rng, seed, rerolls: rerolls, stock: brawlFamilies);

  /// What a card usually costs across every brawl station.
  int median(BrawlState s, String id) =>
      medianPrice(equipmentById(id), brawlStations.keys, s.seed);

  int sellValue(BrawlState s, String id) =>
      sellPrice(equipmentById(id), s.station, s.seed);

  /// A demon from [demons], tougher the further along the brawl is and the
  /// longer the ship has been in Hell.
  EnemyTemplate demonFor(BrawlState s, int index) {
    final level = s.round + s.hellTurns;
    return demons[index].forAct(1 + (level - 1) ~/ 5);
  }

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
    s
      ..loadout = loadout
      ..hull = min(s.hull, s.stats.maxHull);
  }

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
      _refit(s, loadout);
      s.log = merges;
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
      _refit(s, loadout);
      s.log = [];
    });
  }

  /// Moves a card. Allowed anywhere, Hell included: refitting between
  /// fights is the point.
  BrawlState arrange(BrawlState state, CardSpot from, CardSpot to) {
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
        ..market = _roll(s.station, rng, s.seed, rerolls: s.market.rerolls + 1);
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

  // Events and fights --------------------------------------------------------

  /// Leaves the station. Something always happens on the way out; the
  /// scheduled fight follows unless the captain's choice changes that.
  BrawlState launch(BrawlState state) {
    _requireDocked(state);
    return _step(state, (s, rng) {
      s
        ..plannedFight = const Fight()
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
    if (!canChoose(state, index)) throw IllegalMove('Not now');
    return _step(state, (s, rng) {
      final choice = s.currentEvent!.choices[index];
      final outcome = rng.weighted(choice.outcomes, (o) => o.weight)!;
      final lines = <String>[];
      for (final effect in outcome.effects) {
        _apply(s, rng, effect, lines);
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
        ..log = [];
      if (s.lost) return;
      if (fight != null) {
        _fight(s, rng, fight);
        if (s.lost) return;
      }
      if (s.inHell) {
        _hellTurn(s, rng);
      } else {
        _dock(s, rng);
      }
    });
  }

  void _pickEvent(BrawlState s, GameRng rng) {
    final event = rng.weighted(
      brawlEvents.where(
        (e) => e.hell == s.inHell && (e.condition?.call(s) ?? true),
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
    s.market = _roll(s.station, rng, s.seed);
    s.log.add('Docked at ${s.stationName}.');
  }

  void _apply(
    BrawlState s,
    GameRng rng,
    BrawlEffect effect,
    List<String> lines,
  ) {
    switch (effect) {
      case GainCredits(:final amount):
        s.credits = max(0, s.credits + amount);
      case HullChange(:final amount, :final lethal):
        s.hull = min(s.stats.maxHull, s.hull + amount);
        if (s.hull <= 0) {
          if (lethal) {
            s
              ..hull = 0
              ..lost = true;
            lines.add('Your ship breaks apart.');
          } else {
            s.hull = 1;
          }
        }
      case GainCards(:final ids, :final force):
        for (final id in ids) {
          _gain(s, id, lines, force: force);
        }
      case GainRandom(:final pool, :final count):
        for (var i = 0; i < count; i++) {
          _gain(s, rng.pick(pool), lines);
        }
      case LoseCargo():
        if (s.loadout.hold.isNotEmpty) {
          final i = rng.nextInt(s.loadout.hold.length);
          final id = s.loadout.hold.removeAt(i);
          lines.add('Lost ${equipmentById(id).name}.');
        }
      case Fight():
        s.plannedFight = effect;
      case NoFight():
        s.plannedFight = null;
      case EnterHell():
        s
          ..inHell = true
          ..hellTurns = 0
          ..plannedFight = null;
      case LeaveHell():
        s
          ..inHell = false
          ..leavingHell = true;
      case SetFlag(:final flag):
        s.flags.add(flag);
    }
  }

  void _gain(
    BrawlState s,
    String id,
    List<String> lines, {
    bool force = false,
  }) {
    final name = equipmentById(id).name;
    final merges = s.loadout.add(id);
    if (merges != null) {
      lines
        ..add('Gained $name.')
        ..addAll(merges);
      return;
    }
    if (!force) {
      lines.add('No room for $name, so you leave it behind.');
      return;
    }
    // No refusing this one: it takes the place of the cheapest card aboard.
    final cheapest = s.loadout.all.reduce(
      (a, b) => equipmentById(a).price <= equipmentById(b).price ? a : b,
    );
    s.loadout.remove(cheapest);
    lines.add(
      'There was no room, so ${equipmentById(cheapest).name} is gone and '
      '$name is in its place.',
    );
    s.loadout.add(id);
  }

  /// Fights [plan]. Winning pays scrap and maybe salvage; breaking away at
  /// the time limit pays nothing. Losing ends the brawl.
  void _fight(BrawlState s, GameRng rng, Fight plan) {
    final demon = plan.demon != null;
    final enemy = demon
        ? demonFor(s, plan.demon!)
        : brawlEnemy(s.round + plan.roundsAhead);
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
          if (!rng.chance(demon ? 0.35 : 0.25)) continue;
          final merges = s.loadout.add(id);
          if (merges == null) continue;
          salvage.add(id);
          s.log
            ..add('Salvaged ${equipmentById(id).name}.')
            ..addAll(merges);
        }
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
