import 'dart:collection';
import 'dart:math';

import 'captain/species.dart';
import 'combat/catalog.dart';
import 'deck/loadout.dart';
import 'engine/effects.dart';
import 'engine/story_content.dart';
import 'engine/turn.dart';
import 'engine/turn_flow.dart';
import 'faction.dart';
import 'galaxy/galaxy.dart';
import 'galaxy/galaxy_generator.dart';
import 'market.dart';
import 'rng.dart';
import 'run_state.dart';
import 'story/keys.dart';
import 'story/rules.dart';
import 'story/story.dart';

export 'engine/story_content.dart';

/// A way out of the current system.
class Route {
  const Route(this.to, {required this.turns, this.gateway});
  final String to;
  final int turns;
  final Gateway? gateway;
  bool get isSublight => gateway == null;

  int get fuel => isSublight ? sublightFuelCost : gatewayFuelCost;
}

/// Thrown when the UI asks for something the rules don't allow.
class IllegalMove implements Exception {
  IllegalMove(this.message);
  final String message;
  @override
  String toString() => 'IllegalMove: $message';
}

/// Pure game logic. Every action takes a state and returns a new one.
class GameEngine {
  GameEngine(this.content, {GalaxyGenerator? generator})
    : generator = generator ?? GalaxyGenerator(),
      _events = {for (final e in content.events) e.id: e};

  static const baseHellRisk = 0.03;

  /// Act 1 systems that have to be found: the hive world, and the House of
  /// the Elephant's hideout.
  static const hiddenAtStart = {Sys.neoTerra, Sys.elephantHq};
  static const codeGreenBond = 50;

  /// Bond needed for Code Green before the battle of the Bhrun-Gai pipe.
  /// Very few captains are that close to their humans so early.
  static const earlyCodeGreenBond = 60;
  static const codeGreenHumans = 150;

  /// Credits per unit of fuel at a station. Cheap until markets and
  /// missions give the captain a real income.
  static const fuelPrice = 1;

  final StoryContent content;
  final GalaxyGenerator generator;
  final Map<String, GameEvent> _events;

  GameEvent event(String id) =>
      _events[id] ?? (throw ArgumentError('Unknown event $id'));

  RunState newRun(Species species, {required int seed}) {
    final galaxy = generator.generate(seed);
    final loadout = Loadout();
    for (final id in [
      ...species.ship.startingCards,
      ...species.ship.startingColony,
      ...species.ship.startingHold,
    ]) {
      loadout.add(id);
    }
    final stats = ShipStats.of(loadout);
    final s = RunState(
      galaxy: galaxy,
      species: species,
      rngState: GameRng(seed ^ 0x0B10EB06).nextUint32(),
      hull: stats.maxHull,
      fuel: stats.fuelCapacity,
      loadout: loadout,
      credits: species.startingCredits,
      humans: HumanResources(
        count: species.startingHumans,
        loyalty: 50 + 10 * species.humansLikeThem,
        drift: 10 * species.theyLikeHumans,
      ),
      location: species.home,
      flags: {...Flag.history},
      counters: {...Counter.initial},
      revealed: {
        for (final sys in galaxy.systems.values)
          if (sys.act == 1 && !hiddenAtStart.contains(sys.id)) sys.id,
        Sys.traeTraeTene,
      },
      activeGateways: {
        for (final g in galaxy.gateways)
          if (g.initiallyActive) g.key,
      },
      control: initialControl(galaxy),
    );
    final rng = GameRng(s.rngState);
    openMarket(s, rng);
    s.rngState = rng.state;
    s.eventQueue.add(content.openingEvent);
    _advanceQueue(s);
    return s;
  }

  // Queries ---------------------------------------------------------------

  List<Route> routesFrom(RunState s) {
    if (s.inHell) return const [];
    final here = s.location;
    return [
      for (final g in s.galaxy.gatewaysOf(here))
        if (s.isGatewayActive(g)) Route(g.other(here), turns: 1, gateway: g),
      for (final l in s.galaxy.lanesOf(here))
        if (s.revealed.contains(l.other(here)))
          Route(l.other(here), turns: l.turns),
    ];
  }

  bool canAct(RunState s) => !s.isOver && s.pending == null;

  bool canTake(RunState s, Route route) => s.fuel >= route.fuel;

  /// Fuel the captain can buy here right now.
  int fuelForSale(RunState s) {
    if (!canAct(s) || s.inHell || !s.here.tags.contains(Tag.station)) {
      return 0;
    }
    return min(s.stats.fuelCapacity - s.fuel, s.credits ~/ fuelPrice);
  }

  bool canCodeGreen(RunState s) =>
      canAct(s) &&
      s.inHell &&
      !s.has(Flag.codeGreenUsed) &&
      s.humans.bond >=
          (s.has(Flag.gorBhrunWarOver) ? codeGreenBond : earlyCodeGreenBond) &&
      s.humans.count >= codeGreenHumans;

  double hellRisk(RunState s, Gateway g) {
    final risk =
        baseHellRisk +
        s.counter(Counter.pipeInstability) / 100 +
        (content.extraHellRisk?.call(s, g) ?? 0);
    return risk * (1 - s.stats.hellShielding);
  }

  /// The enemy a choice would make you fight, if any, so the player can
  /// decide with their eyes open.
  EnemyTemplate? combatIn(RunState s, Choice choice) {
    for (final o in choice.outcomes) {
      for (final e in o.effects) {
        if (e case Combat(:final enemy, :final strength)) {
          return enemyFor(enemy, strength, s.act);
        }
      }
    }
    return null;
  }

  /// The choices the player can see for the pending event.
  List<Choice> choicesFor(RunState s) {
    final pending = s.pending;
    if (pending == null || pending.result != null) return const [];
    final visible = event(
      pending.eventId,
    ).choices.where((c) => c.condition?.test(s) ?? true).toList();
    return visible.isEmpty
        ? [Choice.simple('Continue', 'Nothing more comes of it.')]
        : visible;
  }

  // Actions ---------------------------------------------------------------

  RunState travel(RunState state, String to) {
    _requireCanAct(state);
    final route =
        routesFrom(state).where((r) => r.to == to).firstOrNull ??
        (throw IllegalMove('No route from ${state.location} to $to'));
    if (!canTake(state, route)) throw IllegalMove('Not enough fuel');
    return _step(state, (t) {
      final s = t.s;
      s.fuel -= route.fuel;
      s.market = null;
      final gateway = route.gateway;
      if (gateway != null) {
        if (t.rng.chance(hellRisk(s, gateway))) {
          t.log(
            LogKind.hell,
            'Something pierced the pipe on the way to '
            '${s.nameOf(to)}. The ship is no longer in our dimension.',
          );
          t.enterHell(HellZone.pipe);
          s.eventQueue.add(content.hellEntryEvent);
          t.endTurn();
          return;
        }
        s
          ..previousLocation = s.location
          ..location = to;
        t.log(LogKind.ship, 'Jumped through the gateway to ${s.nameOf(to)}.');
        t.endTurn();
      } else {
        t.log(
          LogKind.ship,
          'Began a ${route.turns}-turn sublight burn to ${s.nameOf(to)}.',
        );
        for (var i = 0; i < route.turns && !s.isOver; i++) {
          if (i == route.turns - 1) {
            s
              ..previousLocation = s.location
              ..location = to;
          }
          t.endTurn();
        }
        if (!s.isOver) t.trigger(Trigger.sublight, 0.6);
      }
      if (!s.isOver) t.arrive();
    });
  }

  /// Spend a turn where you are.
  RunState hold(RunState state) {
    _requireCanAct(state);
    if (state.inHell) throw IllegalMove('Cannot hold position in Hell');
    return _step(state, (t) {
      // Placeholder until missions exist.
      if (t.s.here.tags.contains(Tag.station)) {
        t.s.credits += 6;
        t.log(LogKind.ship, 'Docked for a turn: odd jobs.');
      }
      t.endTurn();
      if (!t.s.isOver) t.trigger(Trigger.hold, 0.6);
    });
  }

  /// Buys as much fuel as the captain can afford. Doesn't end the turn.
  RunState refuel(RunState state) {
    final amount = fuelForSale(state);
    if (amount <= 0) throw IllegalMove('No fuel for sale');
    return _step(state, (t) {
      t.s
        ..fuel += amount
        ..credits -= amount * fuelPrice;
      t.log(LogKind.ship, 'Bought $amount fuel.');
    });
  }

  /// Humans who would leave if [loadout] replaced the current one: every
  /// human without a home in the colony goes. Taking away housing is the
  /// only way a captain can make part of the colony leave.
  int humansLostWith(RunState s, Loadout loadout) {
    final housing = ShipStats.of(
      loadout,
      hullUpgrades: s.counter(Counter.hullUpgrades),
    ).housing;
    return max(0, s.humans.count - housing);
  }

  /// Moves a card between slots, the hold and the colony grid. Doesn't end
  /// the turn.
  ///
  /// Refused if the hold would overflow, or a card would end up where it
  /// doesn't fit. Taking out housing sends away every human left without a
  /// home: check [humansLostWith] first.
  RunState arrange(RunState state, CardSpot from, CardSpot to) {
    if (state.isOver || state.pending != null) {
      throw IllegalMove('Resolve the current event first');
    }
    if (state.loadout.whyNotMove(from, to) case final why?) {
      throw IllegalMove(why);
    }
    final loadout = state.loadout.copy()..move(from, to);
    if (!loadout.holdFits) {
      throw IllegalMove('The hold can\'t fit everything without that pod');
    }
    return _step(state, (t) => _refit(t, loadout));
  }

  /// Puts a new loadout on the ship and applies what follows from it.
  void _refit(EngineTurn t, Loadout loadout) {
    final s = t.s;
    final lost = humansLostWith(s, loadout);
    s.loadout = loadout;
    final stats = s.stats;
    s
      ..hull = min(s.hull, stats.maxHull)
      ..fuel = min(s.fuel, stats.fuelCapacity);
    if (lost > 0) {
      s.humans = s.humans.copyWith(count: s.humans.count - lost);
      if (s.humans.count == 0) s.flags.remove(Flag.hellbornAgentAboard);
      t.log(LogKind.ship, '$lost humans left the colony: no homes for them.');
    }
  }

  // Markets and shipyards ---------------------------------------------------

  /// At any shop: a market or a trading post.
  bool _atMarket(RunState s) => canAct(s) && !s.inHell && s.market != null;

  /// At a shipyard, which only full markets have.
  bool _atShipyard(RunState s) => _atMarket(s) && !s.market!.tradingPost;

  RunState buy(RunState state, int offerIndex) {
    final market = state.market;
    if (!_atMarket(state) || market == null) throw IllegalMove('No market');
    final offer = market.offers[offerIndex];
    if (offer.sold) throw IllegalMove('Already sold');
    if (state.credits < offer.price) throw IllegalMove('Not enough credits');
    final loadout = state.loadout.copy();
    final merges = loadout.add(offer.cardId);
    if (merges == null) throw IllegalMove('No room on the ship');
    return _step(state, (t) {
      t.s
        ..credits -= offer.price
        ..market = market.withOffer(offerIndex, offer.bought);
      _refit(t, loadout);
      final name = equipmentById(offer.cardId).name;
      t.log(LogKind.ship, 'Bought $name for ${offer.price} credits.');
      for (final m in merges) {
        t.log(LogKind.ship, m);
      }
    });
  }

  int sellValue(RunState s, String cardId) =>
      sellPrice(equipmentById(cardId), s.location, s.galaxy.seed, time: s.turn);

  RunState sell(RunState state, CardSpot spot) {
    if (!_atMarket(state)) throw IllegalMove('No market');
    final id = state.loadout.at(spot);
    if (id == null) throw IllegalMove('Nothing there');
    if (!state.market!.buys(equipmentById(id))) {
      throw IllegalMove('Trading posts only buy supplies and commodities');
    }
    final loadout = state.loadout.copy()..takeOut(spot);
    if (!loadout.holdFits) {
      throw IllegalMove('The hold can\'t fit everything without that pod');
    }
    final price = sellValue(state, id);
    return _step(state, (t) {
      t.s.credits += price;
      _refit(t, loadout);
      t.log(LogKind.ship, 'Sold ${equipmentById(id).name} for $price credits.');
    });
  }

  RunState rerollMarket(RunState state) {
    final market = state.market;
    if (!_atMarket(state) || market == null) throw IllegalMove('No market');
    if (state.credits < market.rerollPrice) {
      throw IllegalMove('Not enough credits');
    }
    return _step(state, (t) {
      t.s
        ..credits -= market.rerollPrice
        ..market = Market.roll(
          t.s.location,
          t.rng,
          t.s.galaxy.seed,
          rerolls: market.rerolls + 1,
          tradingPost: market.tradingPost,
          time: t.s.turn,
        );
    });
  }

  /// Credits to repair the hull fully here, or null if there's no shipyard.
  int? repairCost(RunState s) {
    if (!_atShipyard(s)) return null;
    final missing = s.stats.maxHull - s.hull;
    return missing <= 0 ? null : (missing / hullPerCredit).ceil();
  }

  /// Repairs as much hull as the captain can afford.
  RunState repair(RunState state) {
    final cost = repairCost(state);
    if (cost == null) throw IllegalMove('Nothing to repair here');
    final paid = min(cost, state.credits);
    if (paid <= 0) throw IllegalMove('Not enough credits');
    return _step(state, (t) {
      t.s
        ..credits -= paid
        ..hull = min(t.s.stats.maxHull, t.s.hull + paid * hullPerCredit);
      t.log(LogKind.ship, 'Paid $paid credits for repairs.');
    });
  }

  /// Price of the next permanent hull upgrade, or null if there's no
  /// shipyard here.
  int? hullUpgradeCost(RunState s) =>
      _atShipyard(s) ? hullUpgradePrice(s.counter(Counter.hullUpgrades)) : null;

  RunState upgradeHull(RunState state) {
    final cost = hullUpgradeCost(state);
    if (cost == null) throw IllegalMove('No shipyard here');
    if (state.credits < cost) throw IllegalMove('Not enough credits');
    return _step(state, (t) {
      t.s.credits -= cost;
      addCounter(t.s, Counter.hullUpgrades, 1);
      t.s.hull += ShipStats.hullPerUpgrade;
      t.log(LogKind.ship, 'Hull upgraded for $cost credits.');
    });
  }

  /// Spend a turn in Hell and see what finds you.
  RunState pressOn(RunState state) {
    _requireCanAct(state);
    if (!state.inHell) throw IllegalMove('Not in Hell');
    return _step(state, (t) {
      t.endTurn();
      if (!t.s.isOver && t.s.inHell) t.trigger(Trigger.hell, 1);
    });
  }

  RunState codeGreen(RunState state) {
    if (!canCodeGreen(state)) throw IllegalMove('Code Green unavailable');
    return _step(state, (t) => t.s.eventQueue.add(content.codeGreenEvent));
  }

  /// Picks the choice at [index] in [choicesFor].
  RunState choose(RunState state, int index) {
    final pending = state.pending;
    final choices = choicesFor(state);
    if (pending == null || index < 0 || index >= choices.length) {
      throw IllegalMove('No such choice');
    }
    final choice = choices[index];
    return _step(state, (t) {
      final s = t.s;
      final outcome =
          t.rng.weighted(
            choice.outcomes.where((o) => o.condition?.test(s) ?? true),
            (o) => eventWeight(s, o.weight, o.bondWeight),
          ) ??
          choice.outcomes.first;
      s.seenEvents.add(pending.eventId);
      final text = StringBuffer(outcome.text);
      t.applyAll(outcome.effects, text);
      s.pending = PendingEvent(
        pending.eventId,
        result: s.format(text.toString().trim()),
      );
    }, advance: false);
  }

  /// Dismisses an event result and moves on to the next queued event.
  RunState acknowledge(RunState state) {
    if (state.pending?.result == null) throw IllegalMove('Nothing to dismiss');
    return _step(state, (t) => t.s.pending = null);
  }

  // Turn flow -------------------------------------------------------------

  RunState _step(
    RunState state,
    void Function(EngineTurn) body, {
    bool advance = true,
  }) {
    final s = state.clone();
    final t = EngineTurn(s, GameRng(s.rngState), content);
    body(t);
    s.rngState = t.rng.state;
    if (advance) _advanceQueue(s);
    return s;
  }

  void _requireCanAct(RunState s) {
    if (!canAct(s)) throw IllegalMove('Resolve the current event first');
  }

  void _advanceQueue(RunState s) {
    if (s.pending != null || s.isOver) return;
    if (s.eventQueue.isNotEmpty) {
      s.pending = PendingEvent(s.eventQueue.removeAt(0));
    }
  }
}
