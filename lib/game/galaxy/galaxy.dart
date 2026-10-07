import 'dart:math';

/// Size of `assets/galaxy_ai_generated.jpg` in pixels. All system positions use this
/// coordinate space.
const double mapSize = 2970;

/// Scale from `Map of the galaxy notes.md`.
const double pixelsPerLightYear = 900 / 2600;

/// Ids of the systems whose existence the lore guarantees.
abstract final class Sys {
  static const center = 'center';
  static const orcha = 'orcha';
  static const ghorDum = 'ghor_dum';
  static const bhrunGai = 'bhrun_gai';
  static const kepler = 'kepler';
  static const neoTerra = 'neo_terra';
  static const urGor = 'ur_gor';
  static const traeTraeTene = 'trae_trae_tene';
  static const ulamora = 'ulamora';
  static const ulaval = 'ulaval';
  static const kyndari = 'kyndari';
  static const sol = 'sol';

  /// The House of the Elephant's asteroid port, off a sublight lane.
  static const elephantHq = 'elephant_hq';
}

/// Free-form tags events use to decide where they can happen.
abstract final class Tag {
  static const station = 'station';
  static const homeworld = 'homeworld';
  static const capital = 'capital';
  static const humans = 'humans';
  static const gor = 'gor';
  static const bhrun = 'bhrun';
  static const al = 'al';
  static const tern = 'tern';
  static const unfortunate = 'unfortunate';
  static const consumers = 'consumers';
  static const ruins = 'ruins';
  static const frontier = 'frontier';
  static const neutral = 'neutral';

  /// Has a big market (27 offers of equipment and commodities) and a
  /// shipyard for repairs and hull upgrades.
  static const market = 'market';

  /// Has a small shop that only trades in supplies and commodities.
  static const tradingPost = 'trading post';
}

class StarSystem {
  const StarSystem({
    required this.id,
    required this.name,
    required this.description,
    required this.position,
    required this.act,
    this.tags = const {},
  });

  final String id;
  final String name;
  final String description;
  final Point<double> position;

  /// The act whose gateway network this system belongs to. Sol belongs to
  /// act 3 even though it sits next to Kepler, because that is when it can be
  /// found.
  final int act;
  final Set<String> tags;
}

/// A gateway pair. Gateways are undirected; [key] is order independent.
class Gateway {
  Gateway(String a, String b, {required this.initiallyActive})
    : a = a.compareTo(b) < 0 ? a : b,
      b = a.compareTo(b) < 0 ? b : a;

  final String a;
  final String b;
  final bool initiallyActive;

  String get key => keyOf(a, b);

  bool touches(String id) => a == id || b == id;
  String other(String id) => a == id ? b : a;

  static String keyOf(String x, String y) =>
      x.compareTo(y) < 0 ? '$x|$y' : '$y|$x';
}

/// Fuel burned by a gateway jump.
const gatewayFuelCost = 1;

/// Fuel burned by a sublight burn, however long it takes.
const sublightFuelCost = 2;

/// A route that can only be flown at sublight speed. Takes several turns.
class SublightLane {
  SublightLane(String a, String b, {required this.turns})
    : a = a.compareTo(b) < 0 ? a : b,
      b = a.compareTo(b) < 0 ? b : a;

  final String a;
  final String b;
  final int turns;

  bool touches(String id) => a == id || b == id;
  String other(String id) => a == id ? b : a;
}

/// The immutable layout of one run's galaxy. Everything that changes during
/// play (which gateways work, what has been revealed) lives in the run state.
class Galaxy {
  Galaxy({
    required this.seed,
    required List<StarSystem> systems,
    required this.gateways,
    required this.lanes,
  }) : systems = {for (final s in systems) s.id: s};

  final int seed;
  final Map<String, StarSystem> systems;
  final List<Gateway> gateways;
  final List<SublightLane> lanes;

  StarSystem operator [](String id) =>
      systems[id] ?? (throw ArgumentError('Unknown system $id'));

  Iterable<Gateway> gatewaysOf(String id) =>
      gateways.where((g) => g.touches(id));

  Iterable<SublightLane> lanesOf(String id) =>
      lanes.where((l) => l.touches(id));

  Gateway? gatewayBetween(String x, String y) {
    final key = Gateway.keyOf(x, y);
    for (final g in gateways) {
      if (g.key == key) return g;
    }
    return null;
  }

  SublightLane? laneBetween(String x, String y) {
    for (final l in lanes) {
      if (l.touches(x) && l.touches(y)) return l;
    }
    return null;
  }
}
