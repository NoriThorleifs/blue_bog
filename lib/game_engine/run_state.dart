import 'dart:math';

import 'captain/species.dart';
import 'combat/combat.dart';
import 'deck/loadout.dart';
import 'faction.dart';
import 'galaxy/galaxy.dart';
import 'market.dart';
import 'story/keys.dart';

/// The humans aboard the captain's ship.
///
/// The game presents this as a minor morale stat: keep them happy enough that
/// they don't blow up the ship to get at you. Underneath, [bond] quietly
/// changes the odds of events and story beats.
class HumanResources {
  const HumanResources({
    required this.count,
    required this.loyalty,
    required this.drift,
  });

  /// The colony's population.
  final int count;

  /// 0 to 100. How much the humans like their captain.
  final int loyalty;

  /// -100 to 100. Negative means the humans are adopting the captain's
  /// culture; positive means the captain and ship are going human.
  final int drift;

  /// Humans aboard beyond this don't add to [bond].
  static const fullColony = 900;

  /// Hidden. 0 to 100. Loyalty scaled by population, saturating at
  /// [fullColony].
  int get bond => (loyalty * min(count, fullColony) / fullColony).round();

  String get mood => switch (loyalty) {
    >= 80 => 'Devoted',
    >= 60 => 'Content',
    >= 40 => 'Grumbling',
    >= 20 => 'Restless',
    _ => 'Mutinous',
  };

  HumanResources copyWith({int? count, int? loyalty, int? drift}) =>
      HumanResources(
        count: count ?? this.count,
        loyalty: (loyalty ?? this.loyalty).clamp(0, 100),
        drift: (drift ?? this.drift).clamp(-100, 100),
      );
}

/// Where in Hell the ship is. Inside a pipe is survivable. Outside it is
/// extremely dangerous, and that is where the extreme rewards are.
enum HellZone { pipe, deep }

enum Ending {
  codeBlue,
  codeRed,
  codeYellow,
  shipDestroyed,
  mutiny;

  bool get isCode => index <= codeYellow.index;
}

enum LogKind { news, ship, hell }

class LogEntry {
  const LogEntry(this.turn, this.kind, this.text, {this.title});
  final int turn;
  final LogKind kind;
  final String? title;
  final String text;
}

/// Cargo the captain has agreed to carry somewhere.
class Delivery {
  const Delivery(this.cardId, this.to, this.reward);
  final String cardId;

  /// Destination system id.
  final String to;
  final int reward;
}

/// An event waiting for the player. Once a choice is made, [result] holds
/// the outcome text until the player continues.
class PendingEvent {
  const PendingEvent(this.eventId, {this.result});
  final String eventId;
  final String? result;
}

/// Everything about a run in progress.
///
/// Fields are mutable so the engine can work on a [clone] without a huge
/// copyWith. The engine never mutates a state it was handed, so callers can
/// treat each state as an immutable snapshot.
class RunState {
  RunState({
    required this.galaxy,
    required this.species,
    required this.rngState,
    required this.hull,
    required this.fuel,
    required this.loadout,
    required this.credits,
    required this.humans,
    required this.location,
    required this.flags,
    required this.counters,
    required this.revealed,
    required this.activeGateways,
    required this.control,
    this.turn = 1,
    this.act = 1,
    this.actStartedTurn = 1,
    this.previousLocation,
    this.hell,
    this.hellTurns = 0,
    Set<String>? visited,
    Map<String, String>? nameOverrides,
    Map<String, int>? beatsFired,
    Map<String, int>? beatsWaiting,
    Set<String>? seenEvents,

    List<String>? eventQueue,
    this.pending,
    this.market,
    this.lastCombat,
    List<Delivery>? deliveries,
    List<LogEntry>? log,
    this.ending,
  }) : visited = visited ?? {location},
       nameOverrides = nameOverrides ?? {},
       beatsFired = beatsFired ?? {},
       beatsWaiting = beatsWaiting ?? {},
       seenEvents = seenEvents ?? {},

       eventQueue = eventQueue ?? [],
       log = log ?? [],
       deliveries = deliveries ?? [];

  final Galaxy galaxy;
  final Species species;
  int rngState;

  int hull;
  int fuel;
  Loadout loadout;
  int credits;
  HumanResources humans;

  int turn;
  int act;
  int actStartedTurn;

  /// The current system, or the system whose pipe we fell out of while in
  /// Hell.
  String location;

  /// Where the ship was before its last move. Used by the Retreat effect.
  String? previousLocation;
  HellZone? hell;
  int hellTurns;

  Set<String> flags;
  Map<String, int> counters;

  /// Systems visible on the map.
  Set<String> revealed;
  Set<String> visited;

  /// Keys of working gateways. See [Gateway.key].
  Set<String> activeGateways;

  /// Who controls each system. Drives the faction colours on the map.
  Map<String, Faction> control;

  /// Systems that have been renamed during the run. Neo Terra is the Hive
  /// World until the humans claim it.
  Map<String, String> nameOverrides;

  /// Story beat id to the number of times it has fired.
  Map<String, int> beatsFired;

  /// Story beat id to the turn its condition first held, for beats with a
  /// deadline.
  Map<String, int> beatsWaiting;
  Set<String> seenEvents;

  List<String> eventQueue;
  PendingEvent? pending;

  /// The market here, if there is one, as rolled for this visit.
  Market? market;

  /// The most recent fight, for the combat screen.
  FightRecord? lastCombat;

  /// Cargo the captain has agreed to deliver.
  List<Delivery> deliveries;
  List<LogEntry> log;
  Ending? ending;

  bool get inHell => hell != null;

  /// The ship's class plus every slotted card.
  ShipStats get stats =>
      ShipStats.of(loadout, hullUpgrades: counter(Counter.hullUpgrades));

  /// Every card the captain owns, slotted or in the hold.
  Iterable<String> get cards => loadout.all;
  bool get isOver => ending != null;
  int get turnsInAct => turn - actStartedTurn;
  int counter(String id) => counters[id] ?? 0;
  bool has(String flag) => flags.contains(flag);
  StarSystem get here => galaxy[location];

  String nameOf(String systemId) =>
      nameOverrides[systemId] ?? galaxy[systemId].name;

  /// Fills placeholders in story text: `{sys:<id>}` with a system's current
  /// name, `{counter:<id>}` with a counter's value.
  String format(String text) => text.replaceAllMapped(
    RegExp(r'\{(sys|counter):(\w+)\}'),
    (m) => switch (m[1]) {
      'sys' when galaxy.systems.containsKey(m[2]) => nameOf(m[2]!),
      'counter' => '${counter(m[2]!)}',
      _ => m[0]!,
    },
  );

  bool isGatewayActive(Gateway g) => activeGateways.contains(g.key);

  RunState clone() => RunState(
    galaxy: galaxy,
    species: species,
    rngState: rngState,
    hull: hull,
    fuel: fuel,
    loadout: loadout.copy(),
    credits: credits,
    humans: humans,
    location: location,
    previousLocation: previousLocation,
    flags: {...flags},
    counters: {...counters},
    revealed: {...revealed},
    activeGateways: {...activeGateways},
    control: {...control},
    turn: turn,
    act: act,
    actStartedTurn: actStartedTurn,
    hell: hell,
    hellTurns: hellTurns,
    visited: {...visited},
    nameOverrides: {...nameOverrides},
    beatsFired: {...beatsFired},
    beatsWaiting: {...beatsWaiting},
    seenEvents: {...seenEvents},

    eventQueue: [...eventQueue],
    pending: pending,
    market: market,
    lastCombat: lastCombat,
    deliveries: [...deliveries],
    log: [...log],
    ending: ending,
  );
}
