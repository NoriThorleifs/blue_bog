import 'dart:collection';
import 'dart:math';

import 'captain/species.dart';
import 'combat/catalog.dart';
import 'combat/combat.dart';
import 'combat/equipment.dart';
import 'deck/loadout.dart';
import 'faction.dart';
import 'galaxy/galaxy.dart';
import 'galaxy/galaxy_generator.dart';
import 'market.dart';
import 'rng.dart';
import 'run_state.dart';
import 'story/keys.dart';
import 'story/rules.dart';
import 'story/story.dart';

/// Everything the engine needs from the writers.
class StoryContent {
  const StoryContent({
    required this.events,
    required this.beats,
    required this.openingEvent,
    required this.hellEntryEvent,
    required this.codeGreenEvent,
    required this.mutinyEvent,
    required this.actHeadlines,
    required this.endingFor,
    this.codeEffects = const {},
    this.extraHellRisk,
  });

  final List<GameEvent> events;
  final List<StoryBeat> beats;

  /// Event ids the engine queues itself.
  final String openingEvent;
  final String hellEntryEvent;
  final String codeGreenEvent;
  final String mutinyEvent;

  /// News headline and text when an act begins, keyed by act number.
  final Map<int, (String, String)> actHeadlines;

  /// Picks Code Blue, Red or Yellow from the state of the galaxy.
  final Ending Function(RunState) endingFor;

  /// What happens when a code is sent. A code listed here doesn't end the
  /// run straight away: its effects start whatever comes next (a war, say),
  /// and story beats end the run later. Unlisted codes end the run at once.
  final Map<Ending, List<Effect>> codeEffects;

  /// Additional chance of falling into Hell on a specific gateway jump.
  final double Function(RunState, Gateway)? extraHellRisk;
}

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
  static const codeGreenHumans = 6;

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
    _openMarket(s, rng);
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
          _enterHell(t, HellZone.pipe);
          s.eventQueue.add(content.hellEntryEvent);
          _endTurn(t);
          return;
        }
        s
          ..previousLocation = s.location
          ..location = to;
        t.log(LogKind.ship, 'Jumped through the gateway to ${s.nameOf(to)}.');
        _endTurn(t);
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
          _endTurn(t);
        }
        if (!s.isOver) _trigger(t, Trigger.sublight, 0.6);
      }
      if (!s.isOver) _arrive(t);
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
      _endTurn(t);
      if (!t.s.isOver) _trigger(t, Trigger.hold, 0.6);
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
  /// human without a berth goes.
  int crewLostWith(RunState s, Loadout loadout) {
    final berths = ShipStats.of(
      loadout,
      hullUpgrades: s.counter(Counter.hullUpgrades),
    ).berths;
    return max(0, s.humans.count - berths);
  }

  /// Moves a card between slots and the hold. Doesn't end the turn.
  ///
  /// Refused if the hold would overflow. Taking out accommodation sends
  /// home every human left without a berth: check [crewLostWith] first.
  RunState arrange(RunState state, CardSpot from, CardSpot to) {
    if (state.isOver || state.pending != null) {
      throw IllegalMove('Resolve the current event first');
    }
    final loadout = state.loadout.copy()..move(from, to);
    if (!loadout.holdFits) {
      throw IllegalMove('The hold can\'t fit everything without that pod');
    }
    return _step(state, (t) => _refit(t, loadout));
  }

  /// Puts a new loadout on the ship and applies what follows from it.
  void _refit(_Turn t, Loadout loadout) {
    final s = t.s;
    final lost = crewLostWith(s, loadout);
    s.loadout = loadout;
    final stats = s.stats;
    s
      ..hull = min(s.hull, stats.maxHull)
      ..fuel = min(s.fuel, stats.fuelCapacity);
    if (lost > 0) {
      s.humans = s.humans.copyWith(count: s.humans.count - lost);
      if (s.humans.count == 0) s.flags.remove(Flag.hellbornAgentAboard);
      t.log(LogKind.ship, '$lost humans left the ship: no berths for them.');
    }
  }

  // Markets and shipyards ---------------------------------------------------

  /// At any shop: a market or a trading post.
  bool _atMarket(RunState s) => canAct(s) && !s.inHell && s.market != null;

  /// At a shipyard, which only full markets have.
  bool _atShipyard(RunState s) => _atMarket(s) && !s.market!.tradingPost;

  /// Rolls a fresh shop for this visit, if there's one here.
  void _openMarket(RunState s, GameRng rng) {
    final tags = s.here.tags;
    s.market = tags.contains(Tag.market) || tags.contains(Tag.tradingPost)
        ? Market.roll(
            s.location,
            rng,
            s.galaxy.seed,
            tradingPost: !tags.contains(Tag.market),
          )
        : null;
  }

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
      sellPrice(equipmentById(cardId), s.location, s.galaxy.seed);

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
      _addCounter(t.s, Counter.hullUpgrades, 1);
      t.s.hull += ShipStats.hullPerUpgrade;
      t.log(LogKind.ship, 'Hull upgraded for $cost credits.');
    });
  }

  /// Spend a turn in Hell and see what finds you.
  RunState pressOn(RunState state) {
    _requireCanAct(state);
    if (!state.inHell) throw IllegalMove('Not in Hell');
    return _step(state, (t) {
      _endTurn(t);
      if (!t.s.isOver && t.s.inHell) _trigger(t, Trigger.hell, 1);
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
            (o) => _weight(s, o.weight, o.bondWeight),
          ) ??
          choice.outcomes.first;
      s.seenEvents.add(pending.eventId);
      final text = StringBuffer(outcome.text);
      _applyAll(t, outcome.effects, text);
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
    void Function(_Turn) body, {
    bool advance = true,
  }) {
    final s = state.clone();
    final t = _Turn(s, GameRng(s.rngState));
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

  void _arrive(_Turn t) {
    final s = t.s;
    final firstVisit = s.visited.add(s.location);
    _openMarket(s, t.rng);
    s.revealed.add(s.location);
    for (final g in s.galaxy.gatewaysOf(s.location)) {
      if (s.isGatewayActive(g)) s.revealed.add(g.other(s.location));
    }
    _trigger(t, Trigger.arrival, firstVisit ? 0.8 : 0.55);
  }

  /// Queues an `always` event for [trigger] if one applies. Otherwise, with
  /// probability [chance], a random one.
  void _trigger(_Turn t, Trigger trigger, double chance) {
    final s = t.s;
    bool eligible(GameEvent e) =>
        e.triggers.contains(trigger) &&
        !(e.once && s.seenEvents.contains(e.id)) &&
        (e.condition?.test(s) ?? true);
    final guard = _events.values.where((e) => e.always && eligible(e));
    if (guard.isNotEmpty) {
      s.eventQueue.add(guard.first.id);
      return;
    }
    if (s.eventQueue.isNotEmpty || !t.rng.chance(chance)) return;
    final pick = t.rng.weighted(
      _events.values.where(
        (e) =>
            !e.always &&
            e.triggers.contains(trigger) &&
            !(e.once && s.seenEvents.contains(e.id)) &&
            (e.condition?.test(s) ?? true),
      ),
      (e) => _weight(s, e.weight, e.bondWeight),
    );
    if (pick != null) s.eventQueue.add(pick.id);
  }

  double _weight(RunState s, double weight, double bondWeight) =>
      max(0, weight * (1 + bondWeight * s.humans.bond / 100));

  void _endTurn(_Turn t) {
    final s = t.s;
    s.turn++;
    _payCrew(t);
    _quietHumanInfluence(s);
    if (s.inHell) {
      s.hellTurns++;
      final base = s.hell == HellZone.deep ? 45 : 15;
      final damage = (base * (1 - s.stats.hellShielding)).ceil();
      _apply(t, Hull(-damage), StringBuffer());
    }
    _patchAndCrew(t);
    _runBeats(t);
    if (s.humans.count > 0 &&
        s.humans.loyalty < 10 &&
        s.pending?.eventId != content.mutinyEvent &&
        !s.eventQueue.contains(content.mutinyEvent)) {
      s.eventQueue.insert(0, content.mutinyEvent);
    }
  }

  /// Between turns the humans patch the ship, though never past 75% of its
  /// hull, and empty berths slowly fill: faster where humans live, and the
  /// better the humans aboard think of you.
  void _patchAndCrew(_Turn t) {
    final s = t.s;
    final stats = s.stats;
    final patchTo = (stats.maxHull * 0.75).floor();
    if (s.hull < patchTo && s.humans.count > 0) {
      s.hull = min(patchTo, s.hull + 2 * s.humans.count);
    }
    if (s.inHell) return;
    final free = stats.berths - s.humans.count;
    if (free <= 0) return;
    final odds =
        (0.05 + 0.25 * s.humans.loyalty / 100) *
        (s.here.tags.contains(Tag.humans) ? 1 : 0.33);
    var joined = 0;
    for (var i = 0; i < free; i++) {
      if (t.rng.chance(odds)) joined++;
    }
    if (joined > 0) {
      _apply(t, Humans(joined), StringBuffer());
      _apply(t, const MaybeAgent(0.15), StringBuffer());
      t.log(
        LogKind.ship,
        joined == 1 ? 'A human signed on.' : '$joined humans signed on.',
      );
    }
  }

  void _payCrew(_Turn t) {
    final s = t.s;
    final wages = 1 + s.humans.count ~/ 3;
    if (s.credits >= wages) {
      s.credits -= wages;
    } else {
      s.credits = 0;
      s.humans = s.humans.copyWith(loyalty: s.humans.loyalty - 5);
      t.log(LogKind.ship, 'Could not make payroll. The humans noticed.');
    }
  }

  /// The hidden part of HR: a well-bonded crew changes the galaxy a little
  /// every few turns, in a direction set by whose culture is winning aboard.
  void _quietHumanInfluence(RunState s) {
    if (s.turn % 3 != 0) return;
    // A hospital aboard is noticed.
    final care = min(s.stats.hospital, 5);
    if (care > 0 && s.humans.count > 0) {
      s.humans = s.humans.copyWith(loyalty: s.humans.loyalty + care);
    }
    if (s.humans.bond < 50) return;
    if (s.humans.drift <= -30) _addCounter(s, Counter.republicStance, 1);
    if (s.humans.drift >= 30) _addCounter(s, Counter.hellbornAwareness, 1);
  }

  void _runBeats(_Turn t) {
    final s = t.s;
    for (final beat in content.beats) {
      if (s.isOver) return;
      final fired = s.beatsFired[beat.id] ?? 0;
      if (fired > 0 && !beat.repeatable) continue;
      if (!beat.condition.test(s)) {
        s.beatsWaiting.remove(beat.id);
        continue;
      }
      final waited = s.turn - s.beatsWaiting.putIfAbsent(beat.id, () => s.turn);
      if (waited < beat.delay) continue;
      final overdue = beat.deadline != null && waited >= beat.deadline!;
      final chance = beat.modifiers.fold(
        beat.chance,
        (p, m) => m.$1.test(s) ? p * m.$2 : p,
      );
      if (overdue || t.rng.chance(chance)) _fireBeat(t, beat);
    }
  }

  void _fireBeat(_Turn t, StoryBeat beat) {
    final s = t.s;
    s.beatsFired[beat.id] = (s.beatsFired[beat.id] ?? 0) + 1;
    s.beatsWaiting.remove(beat.id);
    final outcome = t.rng.weighted(
      beat.outcomes.where((o) => o.condition?.test(s) ?? true),
      (o) => _weight(s, o.weight, o.bondWeight),
    );
    t.log(LogKind.news, s.format(outcome?.text ?? ''), title: beat.headline);
    _applyAll(t, [...beat.effects, ...?outcome?.effects], StringBuffer());
    final local = beat.localEvent;
    if (local != null && local.$1.test(s)) s.eventQueue.add(local.$2);
  }

  // Effects ---------------------------------------------------------------

  void _applyAll(_Turn t, List<Effect> effects, StringBuffer text) {
    for (final e in effects) {
      if (t.s.isOver) return;
      _apply(t, e, text);
    }
  }

  void _apply(_Turn t, Effect effect, StringBuffer text) {
    final s = t.s;
    switch (effect) {
      case Fuel(:final amount):
        s.fuel = (s.fuel + amount).clamp(0, s.stats.fuelCapacity);
      case SettleDebt(:final counter):
        final debt = s.counter(counter);
        if (s.credits >= debt) {
          s.credits -= debt;
          s.counters[counter] = 0;
        }
      case Credits(:final amount):
        s.credits = max(0, s.credits + amount);
      case Hull(:final amount):
        s.hull = min(s.stats.maxHull, s.hull + amount);
        if (s.hull <= 0) {
          s.hull = 0;
          s.ending = Ending.shipDestroyed;
        }
      case Humans(:final amount):
        // A hospital saves one human per level from every loss.
        final change = amount < 0 && amount > -99
            ? min(0, amount + s.stats.hospital)
            : amount;
        s.humans = s.humans.copyWith(
          count: (s.humans.count + change).clamp(0, s.stats.berths),
        );
        if (s.humans.count == 0) s.flags.remove(Flag.hellbornAgentAboard);
      case Loyalty(:final amount):
        s.humans = s.humans.copyWith(loyalty: s.humans.loyalty + amount);
      case Drift(:final amount):
        s.humans = s.humans.copyWith(drift: s.humans.drift + amount);
      case SetFlag(:final flag):
        s.flags.add(flag);
      case ClearFlag(:final flag):
        s.flags.remove(flag);
      case AddCounter(:final counter, :final amount):
        _addCounter(s, counter, amount);
      case Reveal(:final systemId):
        s.revealed.add(systemId);
      case Rename(:final systemId, :final name):
        s.nameOverrides[systemId] = name;
      case RestoreGateway(:final a, :final b):
        final g =
            s.galaxy.gatewayBetween(a, b) ??
            (throw ArgumentError('No gateway between $a and $b'));
        _restore(t, g);
      case RestoreDeadGateway(:final towardAct, :final here):
        _restoreDeadGateway(t, towardAct, here: here);
      case EnterHell(:final zone):
        _enterHell(t, zone);
      case EscapeHell():
        _escapeHell(t, text);
      case SetControl(:final systemId, :final faction):
        s.control[systemId] = faction;
      case Retreat():
        final back = s.previousLocation;
        if (back != null && !s.inHell) {
          s
            ..previousLocation = s.location
            ..location = back;
          t.log(LogKind.ship, 'Turned back to ${s.nameOf(back)}.');
        }
      case QueueEvent(:final eventId):
        s.eventQueue.add(eventId);
      case Note(text: final note):
        t.log(LogKind.ship, note);
      case Combat():
        _combat(t, effect, text);
      case ResolveEnding():
        final code = content.endingFor(s);
        final next = content.codeEffects[code];
        if (next == null) {
          s.ending = code;
        } else {
          _applyAll(t, next, text);
        }
      case Expand():
        _expand(t, effect);
      case Breach(:final faction, :final pairs):
        _breach(t, faction, pairs);
      case Transfer(:final from, :final to):
        for (final id in s.control.keys) {
          if (s.control[id] == from) s.control[id] = to;
        }
      case MaybeAgent(:final chance):
        if (s.humans.count > 0 && t.rng.chance(chance)) {
          s.flags.add(Flag.hellbornAgentAboard);
        }
      case StartDelivery():
        _startDelivery(t, effect, text);
      case CompleteDeliveries(:final paid):
        for (final d in s.deliveries.where((d) => d.to == s.location)) {
          if (!s.loadout.remove(d.cardId) || !paid) continue;
          s.credits += d.reward;
          text.write('\n\nDelivered. Paid ${d.reward} credits.');
          t.log(LogKind.ship, 'Delivered cargo for ${d.reward} credits.');
        }
        s.deliveries.removeWhere((d) => d.to == s.location);
      case SellCommodity(:final markup):
        final goods = [
          for (final id in s.cards)
            if (equipmentById(id).kind == CardKind.commodity) id,
        ];
        if (goods.isEmpty) break;
        int value(String id) =>
            commodityPrice(equipmentById(id), s.location, s.galaxy.seed);
        goods.sort((a, b) => value(b).compareTo(value(a)));
        final price = (value(goods.first) * markup).round();
        s.loadout.remove(goods.first);
        s.credits += price;
        text.write(
          '\n\nSold ${equipmentById(goods.first).name} for $price credits.',
        );
      case GrantCard(:final pool):
        _grantCard(t, pool, text);
      case ClaimTagged(:final tag, :final faction):
        for (final sys in s.galaxy.systems.values) {
          if (sys.tags.contains(tag)) s.control[sys.id] = faction;
        }
      case EndRun(:final ending):
        s.ending = ending;
    }
  }

  void _addCounter(RunState s, String counter, int amount) {
    final value = s.counter(counter) + amount;
    // Only the Republic's stance can go negative.
    s.counters[counter] = counter == Counter.republicStance
        ? value.clamp(-100, 100)
        : max(0, value);
  }

  void _enterHell(_Turn t, HellZone zone) {
    if (!t.s.inHell) {
      t.s.hellTurns = 0;
      _addCounter(t.s, Counter.hellbornAwareness, 1);
    }
    t.s.hell = zone;
  }

  void _escapeHell(_Turn t, StringBuffer text) {
    final s = t.s;
    if (!s.inHell) return;
    // In act 1 Hell only lets you out into the act 1 network.
    final exits = s.galaxy.systems.values
        .where(
          (sys) =>
              sys.act <= s.act &&
              s.galaxy.gatewaysOf(sys.id).any(s.isGatewayActive),
        )
        .toList();
    final exit = t.rng.pick(exits);
    s.flags.remove(Flag.mournerPull);
    s
      ..hell = null
      ..location = exit.id
      ..visited.add(exit.id)
      ..revealed.add(exit.id);
    text.write(
      '\n\nThe ship tumbles out of a gateway at ${s.nameOf(exit.id)}.',
    );
    t.log(
      LogKind.ship,
      'Escaped Hell at ${s.nameOf(exit.id)} '
      'after ${s.hellTurns} turns.',
    );
  }

  /// A real fight against an enemy built from the event's strength rating
  /// and the act. Winning scraps the enemy. At the time limit both ships get
  /// away: no loot, and the event's "lose" effects apply (without their old
  /// hull damage, since the fight already did that). Losing ends the run.
  void _combat(_Turn t, Combat c, StringBuffer text) {
    final s = t.s;
    final enemy = enemyFor(c.enemy, c.strength, s.act);
    final upgrades = s.counter(Counter.hullUpgrades);
    final player = Combatant(
      name: 'you',
      loadout: s.loadout.forCombat,
      baseHull: baseHull + upgrades * ShipStats.hullPerUpgrade,
      hull: s.hull,
    );
    final foe = Combatant(
      name: enemy.name,
      loadout: enemy.loadout,
      baseHull: enemy.hull,
    );
    final result = fight(player, foe, tractorBeam: c.tractorBeam);
    s.hull = result.hull;

    final salvage = <String>[];
    var scrap = 0;
    switch (result.outcome) {
      case CombatOutcome.win:
        scrap = foe.maxHull ~/ 10;
        for (final id in enemy.loadout.slots.whereType<String>()) {
          if (t.rng.chance(0.25)) salvage.add(id);
        }
        text.write(
          '\n\nYou destroyed ${enemy.name} in ${result.seconds.round()} s '
          'and scrapped it for $scrap credits',
        );
        s.credits += scrap;
        final kept = <String>[];
        for (final id in salvage) {
          final merges = s.loadout.add(id);
          if (merges == null) continue;
          kept.add(equipmentById(id).name);
          for (final m in merges) {
            text.write(' $m');
          }
        }
        text.write(kept.isEmpty ? '.' : ', plus ${kept.join(', ')}.');
        _applyAll(t, c.win, text);
      case CombatOutcome.escape:
        text.write(
          '\n\nAfter a minute neither ship could finish the other, and you '
          'broke away. No salvage, and ${enemy.name} will remember you.',
        );
        _applyAll(t, [
          for (final e in c.lose)
            if (e is! Hull) e,
        ], text);
      case CombatOutcome.loss:
        text.write('\n\n${enemy.name} destroyed your ship.');
        s.ending = Ending.shipDestroyed;
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

  void _startDelivery(_Turn t, StartDelivery d, StringBuffer text) {
    final s = t.s;
    // Known stations within two working jumps.
    final reach = <String, int>{s.location: 0};
    final queue = Queue.of([s.location]);
    while (queue.isNotEmpty) {
      final id = queue.removeFirst();
      if (reach[id]! >= 2) continue;
      for (final g in s.galaxy.gatewaysOf(id)) {
        final next = g.other(id);
        if (s.isGatewayActive(g) && !reach.containsKey(next)) {
          reach[next] = reach[id]! + 1;
          queue.add(next);
        }
      }
    }
    final options = [
      for (final id in reach.keys)
        if (id != s.location &&
            s.revealed.contains(id) &&
            s.galaxy[id].tags.contains(Tag.station))
          id,
    ];
    final favoured = d.prefer != null && (d.preferWhen?.test(s) ?? true);
    final to = t.rng.weighted(
      options,
      (id) => favoured && id == d.prefer ? 12.0 : 1.0,
    );
    if (to == null) {
      text.write('\n\nThere\'s nowhere nearby to take it, so you pass.');
      return;
    }
    if (s.loadout.add(d.cardId) == null) {
      text.write('\n\nThere\'s no room aboard for it, so you pass.');
      return;
    }
    s.deliveries.add(Delivery(d.cardId, to, d.reward));
    text.write(
      '\n\nDeliver the ${equipmentById(d.cardId).name} to '
      '${s.nameOf(to)} for ${d.reward} credits.',
    );
    t.log(LogKind.ship, 'Took on cargo for ${s.nameOf(to)}.');
  }

  void _grantCard(_Turn t, String pool, StringBuffer text) {
    final s = t.s;
    final options = switch (pool) {
      'salvage' => basicEquipment,
      'commodity' => commodities,
      'supplies' => [
        for (final e in basicEquipment)
          if (e.kind == CardKind.supplies) e,
      ],
      _ when equipmentCatalog.containsKey(pool) => [equipmentById(pool)],
      'mourner' => [
        for (final c in mournerCards)
          if (!s.cards.contains(c.id)) c,
      ],
      _ => throw ArgumentError('Unknown card pool $pool'),
    };
    if (options.isEmpty) return;
    final card = t.rng.pick(options);
    final merges = s.loadout.add(card.id);
    if (merges == null) {
      text.write('\n\nFound ${card.name}, but there was no room for it.');
      return;
    }
    text.write('\n\nNew card: ${card.name}.');
    t.log(LogKind.ship, 'Got the card ${card.name}.');
    for (final m in merges) {
      text.write(' $m');
      t.log(LogKind.ship, m);
    }
  }

  void _expand(_Turn t, Expand e) {
    final s = t.s;
    final before = Map.of(s.control);
    final taken = <String>{};
    for (final g in s.galaxy.gateways) {
      if (!e.throughDeadGateways && !s.isGatewayActive(g)) continue;
      for (final (from, to) in [(g.a, g.b), (g.b, g.a)]) {
        if (before[from] != e.faction || before[to] == e.faction) continue;
        if (e.only != null && before[to] != e.only) continue;
        if (taken.contains(to) || !t.rng.chance(e.chance)) continue;
        taken.add(to);
        s.control[to] = e.faction;
      }
    }
    if (taken.isNotEmpty) {
      t.log(
        LogKind.news,
        '${taken.map(s.nameOf).join(', ')} ${e.verb} ${e.faction.label}.',
        title: 'Borders shift',
      );
    }
  }

  void _breach(_Turn t, Faction faction, int pairs) {
    final s = t.s;
    final gates = t.rng.shuffled(s.galaxy.gateways).take(pairs);
    for (final g in gates) {
      s.activeGateways.add(g.key);
      s.control[g.a] = faction;
      s.control[g.b] = faction;
      s.revealed.addAll([g.a, g.b]);
    }
    t.log(
      LogKind.news,
      'The barrier gave way in the gateways between '
      '${gates.map((g) => '${s.nameOf(g.a)} and ${s.nameOf(g.b)}').join('; ')}.',
      title: 'Gatecrash',
    );
  }

  void _restore(_Turn t, Gateway g) {
    final s = t.s;
    if (!s.activeGateways.add(g.key)) return;
    s.revealed.addAll([g.a, g.b]);
    t.log(
      LogKind.news,
      'The gateway between ${s.nameOf(g.a)} and ${s.nameOf(g.b)} is open '
      'for the first time since the gatecrash.',
      title: 'Gateway restored',
    );
    _checkActs(t);
  }

  void _restoreDeadGateway(_Turn t, int? towardAct, {required bool here}) {
    final s = t.s;
    final network = _network(s);
    final candidates = s.galaxy.gateways.where((g) {
      final inA = network.contains(g.a);
      final inB = network.contains(g.b);
      if (s.isGatewayActive(g) || (!inA && !inB)) return false;
      if (here) return g.touches(s.location);
      final farAct = max(s.galaxy[g.a].act, s.galaxy[g.b].act);
      return towardAct == null ? farAct <= s.act : farAct == towardAct;
    });
    final pick = candidates.isEmpty ? null : t.rng.pick(candidates.toList());
    if (pick != null) _restore(t, pick);
  }

  /// Systems reachable from the Center through working gateways.
  Set<String> _network(RunState s) {
    final seen = {Sys.center};
    final queue = Queue.of([Sys.center]);
    while (queue.isNotEmpty) {
      final id = queue.removeFirst();
      for (final g in s.galaxy.gatewaysOf(id)) {
        if (s.isGatewayActive(g) && seen.add(g.other(id))) {
          queue.add(g.other(id));
        }
      }
    }
    return seen;
  }

  /// Acts follow the gateway network: act 2 when Træ Træ Tene joins it,
  /// act 3 when Kyndari does.
  void _checkActs(_Turn t) {
    final network = _network(t.s);
    if (t.s.act < 2 && network.contains(Sys.traeTraeTene)) _startAct(t, 2);
    if (t.s.act < 3 && network.contains(Sys.kyndari)) _startAct(t, 3);
  }

  void _startAct(_Turn t, int act) {
    final s = t.s;
    s
      ..act = act
      ..actStartedTurn = s.turn;
    for (final sys in s.galaxy.systems.values) {
      if (sys.act == act) s.revealed.add(sys.id);
    }
    if (act == 3) s.flags.add(Flag.kyndariRevealed);
    final (title, text) = content.actHeadlines[act] ?? ('Act $act', '');
    t.log(LogKind.news, text, title: title);
  }
}

/// Working state for one engine action.
class _Turn {
  _Turn(this.s, this.rng);
  final RunState s;
  final GameRng rng;

  void log(LogKind kind, String text, {String? title}) =>
      s.log.add(LogEntry(s.turn, kind, text, title: title));
}
