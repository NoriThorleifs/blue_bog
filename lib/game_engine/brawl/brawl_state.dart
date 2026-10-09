import '../captain/species.dart';
import '../combat/catalog.dart';
import '../combat/combat.dart';
import '../deck/loadout.dart';
import '../gambling/roulette.dart';
import '../gambling/twenty_seven.dart';
import '../market.dart';
import '../run_state.dart';
import 'brawl.dart';
import 'brawl_enemies.dart';
import 'brawl_events.dart';

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

/// The gambling den each station runs, by who mostly lives there.
enum GamblingGame {
  roulette('Roulette'),
  gor('Gor gambling hall'),
  al('27');

  const GamblingGame(this.label);
  final String label;
}

/// The games are run in Galactic Republic stations. Most Republic
/// cultures count in threes, thanks to the Tern; the humans, still on base
/// ten, brought roulette. For now the human stations run roulette and
/// every other station runs 27, the Ál game, until the Gor game exists.
const _humanStations = {'orcha', 'kepler'};
final stationGames = {
  for (final id in brawlStations.keys)
    id: _humanStations.contains(id) ? GamblingGame.roulette : GamblingGame.al,
};

/// Families left out of brawl mode: Hell shielding and fuel tanks do
/// nothing without a map.
const brawlExcludedFamilies = {'barrier', 'tanks'};

final brawlFamilies = [
  for (final f in equipmentFamilies)
    if (!brawlExcludedFamilies.contains(f.id)) f,
];

bool _allowed(String id) =>
    !brawlExcludedFamilies.contains(equipmentById(id).family);

/// The cards a species starts a brawl with: its ship's cards, colony and
/// hold, minus anything left out of brawl mode.
List<String> brawlStartingCards(Species species) => [
  for (final id in [
    ...species.ship.startingCards,
    ...species.ship.startingColony,
    ...species.ship.startingHold,
  ])
    if (_allowed(id)) id,
];

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
    this.lastSpin,
    this.twentySeven,
    this.lost = false,
    this.humans = const HumanResources(count: 0, loyalty: 50, drift: 0),
    this.retired = false,
    Set<String>? flags,
    List<String>? log,
    List<String>? wreckage,
  }) : flags = flags ?? {},
       log = log ?? [],
       wreckage = wreckage ?? [];

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

  /// The most recent roulette spin, for the wheel to play back.
  RouletteSpin? lastSpin;

  /// The game of 27 on the table, in progress or just finished.
  TwentySeven? twentySeven;
  bool lost;

  /// The human colony aboard.
  HumanResources humans;
  Set<String> flags;

  /// What happened since the last decision, for the screen.
  List<String> log;

  /// Cards won or found with no room aboard. The captain can jettison
  /// something to take them, until the ship moves on.
  List<String> wreckage;

  /// Set when a captain who beat Satan retires: the brawl is won and over.
  bool retired;

  /// Satan is coming: the brawl has reached [brawlFinalFight] and he
  /// hasn't been beaten.
  bool get satanDue => round >= brawlFinalFight && !flags.contains(beatSatan);

  /// Satan has just been beaten, and the captain hasn't yet chosen
  /// between retiring and going on.
  bool get awaitingVerdict =>
      flags.contains(beatSatan) && !flags.contains(wentEndless) && !retired;

  /// Past Satan, fighting on for score.
  bool get endless => flags.contains(wentEndless);

  String get stationName => brawlStations[station]!;
  GamblingGame get gamblingGame => stationGames[station]!;

  /// Whether lots of humans live at this station, so more sign on here.
  bool get humansLiveHere => _humanStations.contains(station);
  ShipStats get stats => ShipStats.of(loadout, hullUpgrades: hullUpgrades);
  EnemyTemplate get nextEnemy =>
      satanDue ? SpecialEnemy.satan.template : brawlEnemy(round, seed);
  BrawlEvent? get currentEvent => event == null ? null : brawlEventsById[event];

  /// At a station with nothing pending: free to trade and launch.
  bool get docked =>
      event == null && !inHell && !lost && !retired && !awaitingVerdict;

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
    lastSpin: lastSpin,
    twentySeven: twentySeven,
    lost: lost,
    humans: humans,
    retired: retired,
    flags: {...flags},
    log: [...log],
    wreckage: [...wreckage],
  );
}
