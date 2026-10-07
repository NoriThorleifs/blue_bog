import 'dart:collection';
import 'dart:math';

import '../rng.dart';
import 'galaxy.dart';
import 'system_catalog.dart';

/// Thrown when no valid galaxy could be generated for a seed. With the
/// current constraints this should never happen; it exists so a bad tweak
/// to the constraints fails loudly instead of looping forever.
class GalaxyGenerationError extends Error {
  GalaxyGenerationError(this.seed);
  final int seed;
  @override
  String toString() => 'No valid galaxy found for seed $seed';
}

/// Builds a random galaxy that always satisfies the lore constraints:
///
/// Act 1: the Center has three working gateways plus a dead one to
/// Træ Træ Tene. Kepler's only gateway goes to Bhrun-Gai, Bhrun-Gai's two go
/// to Kepler and Ghor-Dum, and Ghor-Dum has one more to somewhere random,
/// never more than two jumps from the Center. Neo Terra (sublight from
/// Orcha) and Ur-Gor (sublight from Ghor-Dum) have no gateways.
///
/// Act 2: Træ Træ Tene's network includes Úlamora, with Úlaval at sublight.
///
/// Act 3: Kyndari's network has a working gateway to Sol, which is at
/// sublight from Kepler. Dead gateways link the act 2 and act 3 networks so
/// restoring one can start act 3.
///
/// The Center is not at the galactic core. It sits off toward the edge,
/// 2600 ly from Sol, and the galaxy opens up away from it in later acts.
///
/// For a readable map, pipes (gateways and sublight lanes) never cross,
/// never pass right next to a system, and meet at a system at an angle of
/// at least [minPipeAngle]. A star holds at most four gateways, per
/// `how FTL works.md`.
class GalaxyGenerator {
  static const maxGatewaysPerStar = 4;
  static const maxJumpsCenterToGhorDum = 2;
  static const minPipeAngle = 22.5 * pi / 180;

  /// How close a pipe may pass to a system it doesn't connect to.
  static const minPipeClearance = 50.0;
  static const galacticCore = Point(1486.0, 1400.0);
  static const solPosition = Point(1488.0, 2308.0);
  static const _margin = 130.0;
  static const _minSpacing = 130.0;

  Galaxy generate(int seed) {
    for (var attempt = 0; attempt < 3000; attempt++) {
      final rng = GameRng(seed ^ (attempt * 0x9E3779B9));
      final galaxy = _Attempt(rng, seed).build();
      if (galaxy != null) return galaxy;
    }
    throw GalaxyGenerationError(seed);
  }
}

typedef _Segment = (String, String);

class _Attempt {
  _Attempt(this.rng, this.seed);

  final GameRng rng;
  final int seed;
  final positions = <String, Point<double>>{};
  final profiles = <String, SystemProfile>{};
  final acts = <String, int>{};
  final gateways = <Gateway>[];
  final lanes = <SublightLane>[];
  final _usedNames = <String>{};

  /// Direction from the Center toward open space, where acts 2 and 3 grow.
  late double _frontier;

  Galaxy? build() {
    if (!_placeAct1() || !_placeAct2() || !_placeAct3()) return null;
    if (!_addLanes() || !_wireAct1() || !_wireAct2() || !_wireAct3()) {
      return null;
    }
    if (!_wireDeadGateways()) return null;
    return Galaxy(
      seed: seed,
      systems: [
        for (final id in positions.keys)
          StarSystem(
            id: id,
            name: profiles[id]!.name,
            description: profiles[id]!.description,
            position: positions[id]!,
            act: acts[id]!,
            tags: profiles[id]!.tags,
          ),
      ],
      gateways: gateways,
      lanes: lanes,
    );
  }

  Point<double> _at(String id) => positions[id]!;

  // Placement -------------------------------------------------------------

  bool _placeAct1() {
    const sol = GalaxyGenerator.solPosition;
    _put(Sys.sol, sol, 3);

    // The Center is 2600 ly from Sol, off to one side of the galaxy.
    final left = rng.chance(0.5);
    final tilt = _degrees(rng.rangeDouble(15, 40));
    final center = _polar(
      sol,
      2600 * pixelsPerLightYear,
      left ? pi + tilt : -tilt,
    );
    if (!_free(center)) return false;
    _put(Sys.center, center, 1);
    _frontier = _bearingFrom(center, GalaxyGenerator.galacticCore);

    // Kepler is 1810 ly from Sol, roughly on the way to the Center.
    final toCenter = _bearingFrom(sol, center);
    final kepler = _polar(
      sol,
      1810 * pixelsPerLightYear,
      toCenter + _degrees(rng.rangeDouble(-35, 35)),
    );
    if (!_free(kepler)) return false;
    _put(Sys.kepler, kepler, 1);

    final towardOrcha =
        _frontier +
        _degrees(rng.rangeDouble(25, 70)) * (rng.chance(0.5) ? 1 : -1);
    return _placeNear(
          Sys.bhrunGai,
          Sys.kepler,
          1,
          170,
          380,
          maxFromCenter: 650,
        ) &&
        _placeNear(
          Sys.ghorDum,
          Sys.bhrunGai,
          1,
          170,
          380,
          maxFromCenter: 650,
        ) &&
        _placeNear(Sys.urGor, Sys.ghorDum, 1, 110, 170, spacing: 100) &&
        _placeElephantRock() &&
        _placeToward(Sys.orcha, Sys.center, 1, 220, 400, towardOrcha, 15) &&
        _nameAgriWorld() &&
        _placeToward(
          Sys.neoTerra,
          Sys.orcha,
          1,
          120,
          160,
          _frontier,
          35,
          spacing: 100,
        ) &&
        _placeFillers(1, rng.range(3, 5), Sys.center, 170, 560);
  }

  bool _placeAct2() {
    // Neo Terra to Træ Træ Tene is 127 px in the map notes.
    return _placeToward(
          Sys.traeTraeTene,
          Sys.neoTerra,
          2,
          127,
          127,
          _frontier,
          40,
          spacing: 110,
        ) &&
        _placeNear(
          Sys.ulamora,
          Sys.traeTraeTene,
          2,
          170,
          450,
          minFromCenter: 550,
        ) &&
        // Úlamora to Úlaval is 54.1 px in the map notes.
        _placeNear(Sys.ulaval, Sys.ulamora, 2, 54, 54, spacing: 40) &&
        _placeFillers(
          2,
          rng.range(6, 8),
          Sys.traeTraeTene,
          150,
          750,
          minFromCenter: 550,
        );
  }

  bool _placeAct3() {
    // Kyndari lies on the far side of Sol from the Center, so the human
    // gateway between them runs through empty space.
    final sol = GalaxyGenerator.solPosition;
    final away = _bearingFrom(_at(Sys.center), sol);
    for (var i = 0; i < 200; i++) {
      final p = _polar(
        sol,
        rng.rangeDouble(450, 850),
        away + _degrees(rng.rangeDouble(-75, 15)) * _turnSign(),
      );
      if (p.distanceTo(_at(Sys.center)) >= 1000 && _free(p)) {
        _put(Sys.kyndari, p, 3);
        return _placeFillers(
          3,
          rng.range(4, 6),
          Sys.kyndari,
          150,
          550,
          minFromCenter: 900,
        );
      }
    }
    return false;
  }

  /// Bends act 3 up and away from the galaxy's bottom edge.
  double _turnSign() =>
      _at(Sys.center).x < GalaxyGenerator.solPosition.x ? 1 : -1;

  /// The House of the Elephant hides off the Ghor-Dum–Ur-Gor sublight lane,
  /// in the middle of nowhere but close to the traffic.
  bool _placeElephantRock() {
    final a = _at(Sys.ghorDum);
    final b = _at(Sys.urGor);
    final mid = Point((a.x + b.x) / 2, (a.y + b.y) / 2);
    final along = _bearingFrom(a, b);
    for (var i = 0; i < 40; i++) {
      final side = rng.chance(0.5) ? pi / 2 : -pi / 2;
      final p = _polar(
        mid,
        rng.rangeDouble(110, 160),
        along + side + _degrees(rng.rangeDouble(-20, 20)),
      );
      if (_free(p, spacing: 95)) {
        _put(Sys.elephantHq, p, 1);
        return true;
      }
    }
    return false;
  }

  bool _placeFillers(
    int act,
    int count,
    String anchorId,
    double minRadius,
    double maxRadius, {
    double minFromCenter = 0,
  }) {
    final lore = rng.shuffled(loreFillers[act] ?? const <SystemProfile>[]);
    for (var i = 0; i < count; i++) {
      final id = 'a${act}_$i';
      final profile = i < lore.length ? lore[i] : _proceduralProfile();
      profiles[id] = profile;
      _usedNames.add(profile.name);
      if (!_placeNear(
        id,
        anchorId,
        act,
        minRadius,
        maxRadius,
        minFromCenter: minFromCenter,
      )) {
        return false;
      }
    }
    return true;
  }

  /// Neo Terra's original Havi name is different in every run.
  bool _nameAgriWorld() {
    String name;
    do {
      name = '${rng.pick(fillerNamePrefixes)}${rng.pick(fillerNameSuffixes)}';
    } while (_usedNames.contains(name));
    _usedNames.add(name);
    final lore = fixedSystems[Sys.neoTerra]!;
    profiles[Sys.neoTerra] = SystemProfile(name, lore.description, lore.tags);
    return true;
  }

  SystemProfile _proceduralProfile() {
    final template = rng.pick(fillerProfiles);
    String name;
    do {
      name = rng.chance(0.25)
          ? 'Survey ${List.generate(4, (_) => rng.nextInt(3)).join('-')}'
          : '${rng.pick(fillerNamePrefixes)}${rng.pick(fillerNameSuffixes)}';
    } while (_usedNames.contains(name));
    // Stations may have a shop: a quarter a full market, half a trading
    // post that only deals in supplies and commodities.
    final shop = rng.nextDouble();
    final tags = {
      ...template.tags,
      if (template.tags.contains(Tag.station))
        if (shop < 0.25) Tag.market else if (shop < 0.75) Tag.tradingPost,
    };
    return SystemProfile(name, template.description, tags);
  }

  bool _placeNear(
    String id,
    String anchorId,
    int act,
    double minRadius,
    double maxRadius, {
    double spacing = GalaxyGenerator._minSpacing,
    double minFromCenter = 0,
    double maxFromCenter = double.infinity,
  }) {
    for (var i = 0; i < 200; i++) {
      final p = _polar(
        _at(anchorId),
        rng.rangeDouble(minRadius, maxRadius),
        rng.rangeDouble(0, 2 * pi),
      );
      final fromCenter = p.distanceTo(_at(Sys.center));
      if (fromCenter >= minFromCenter &&
          fromCenter <= maxFromCenter &&
          _free(p, spacing: spacing)) {
        _put(id, p, act);
        return true;
      }
    }
    return false;
  }

  /// Places [id] between [minRadius] and [maxRadius] from [anchorId], within
  /// [spreadDegrees] of [bearing].
  bool _placeToward(
    String id,
    String anchorId,
    int act,
    double minRadius,
    double maxRadius,
    double bearing,
    double spreadDegrees, {
    double spacing = GalaxyGenerator._minSpacing,
  }) {
    for (var i = 0; i < 100; i++) {
      final angle =
          bearing + _degrees(rng.rangeDouble(-spreadDegrees, spreadDegrees));
      final p = _polar(
        _at(anchorId),
        rng.rangeDouble(minRadius, maxRadius),
        angle,
      );
      if (_free(p, spacing: spacing)) {
        _put(id, p, act);
        return true;
      }
    }
    return false;
  }

  void _put(String id, Point<double> p, int act) {
    positions[id] = p;
    acts[id] = act;
    profiles.putIfAbsent(id, () => fixedSystems[id]!);
  }

  bool _free(Point<double> p, {double spacing = GalaxyGenerator._minSpacing}) {
    const lo = GalaxyGenerator._margin;
    const hi = mapSize - GalaxyGenerator._margin;
    if (p.x < lo || p.x > hi || p.y < lo || p.y > hi) return false;
    if (positions.values.any((q) => q.distanceTo(p) < spacing)) return false;
    // Keep clear of sublight lanes whose ends are already placed, so the
    // lanes can still be drawn once everything is in place.
    for (final (x, y) in _plannedLanes) {
      final a = positions[x];
      final b = positions[y];
      if (a != null &&
          b != null &&
          _distanceToSegment(p, a, b) < GalaxyGenerator.minPipeClearance + 10) {
        return false;
      }
    }
    return true;
  }

  static const _plannedLanes = [
    (Sys.orcha, Sys.neoTerra),
    (Sys.ghorDum, Sys.urGor),
    (Sys.elephantHq, Sys.urGor),
    (Sys.elephantHq, Sys.ghorDum),
    (Sys.ulamora, Sys.ulaval),
    (Sys.kepler, Sys.sol),
  ];

  // Wiring ----------------------------------------------------------------

  Iterable<String> _ofAct(int act) =>
      positions.keys.where((id) => acts[id] == act);

  int _degree(String id) => gateways.where((g) => g.touches(id)).length;

  bool _linked(String x, String y) =>
      gateways.any((g) => g.touches(x) && g.touches(y));

  /// Adds a gateway if it keeps the map readable.
  bool _link(String x, String y, {bool active = true}) {
    if (_linked(x, y) || !_canDraw(x, y)) return false;
    gateways.add(Gateway(x, y, initiallyActive: active));
    return true;
  }

  bool _addLanes() {
    bool lane(String x, String y) {
      if (!_canDraw(x, y)) return false;
      final px = _at(x).distanceTo(_at(y));
      lanes.add(SublightLane(x, y, turns: (1 + (px / 150).ceil()).clamp(2, 6)));
      return true;
    }

    return lane(Sys.orcha, Sys.neoTerra) &&
        lane(Sys.ghorDum, Sys.urGor) &&
        (lane(Sys.elephantHq, Sys.urGor) ||
            lane(Sys.elephantHq, Sys.ghorDum)) &&
        lane(Sys.ulamora, Sys.ulaval) &&
        lane(Sys.kepler, Sys.sol);
  }

  bool _wireAct1() {
    if (!_link(Sys.ghorDum, Sys.bhrunGai) ||
        !_link(Sys.bhrunGai, Sys.kepler) ||
        !_link(Sys.center, Sys.orcha) ||
        !_link(Sys.center, Sys.traeTraeTene, active: false)) {
      return false;
    }

    final network = _ofAct(
      1,
    ).where((id) => !_sublightOnly.contains(id)).toList();
    final caps = {
      for (final id in network) id: GalaxyGenerator.maxGatewaysPerStar - 1,
      Sys.center: GalaxyGenerator.maxGatewaysPerStar,
      Sys.kepler: 1,
      Sys.bhrunGai: 2,
      Sys.ghorDum: 2,
    };
    bool open(String id) => _degree(id) < caps[id]!;

    // Ghor-Dum's random gateway goes to the Center or one of its neighbours,
    // so the Gor, the Bhrun and Kepler are never far from the story.
    final via = rng.weighted(
      network.where(
        (p) =>
            p != Sys.ghorDum &&
            !_linked(Sys.ghorDum, p) &&
            open(p) &&
            (p == Sys.center || _linked(Sys.center, p) || open(Sys.center)),
      ),
      (p) => _closeness((Sys.ghorDum, p)),
    );
    if (via == null || !_link(Sys.ghorDum, via)) return false;
    if (via != Sys.center && !_linked(Sys.center, via)) {
      if (!_link(Sys.center, via)) return false;
    }

    if (!_connect(network, caps)) return false;
    if (!_fillTo(Sys.center, 4, network, caps)) return false;
    _extraEdges(network, caps, rng.range(0, 1));
    return _degree(Sys.ghorDum) == 2 &&
        _degree(Sys.center) == 4 &&
        _jumps(Sys.center, Sys.ghorDum) <=
            GalaxyGenerator.maxJumpsCenterToGhorDum;
  }

  bool _wireAct2() {
    final network = _ofAct(2).where((id) => id != Sys.ulaval).toList();
    final caps = {
      for (final id in network) id: GalaxyGenerator.maxGatewaysPerStar - 1,
      Sys.traeTraeTene: GalaxyGenerator.maxGatewaysPerStar,
    };
    if (!_connect(network, caps)) return false;
    _extraEdges(network, caps, rng.range(1, 3));
    return true;
  }

  bool _wireAct3() {
    if (!_link(Sys.kyndari, Sys.sol)) return false;
    final network = _ofAct(3).where((id) => id != Sys.sol).toList();
    final zirmai = network.where((id) => profiles[id]!.name == 'Zirmai');
    if (zirmai.isNotEmpty) _link(Sys.kyndari, zirmai.first);
    final caps = {
      for (final id in network) id: GalaxyGenerator.maxGatewaysPerStar - 1,
    };
    if (!_connect(network, caps)) return false;
    _extraEdges(network, caps, rng.range(1, 2));
    return true;
  }

  /// Dead gateways left over from the gatecrash. Restoring them is what
  /// moves the story between acts.
  bool _wireDeadGateways() {
    const cap = GalaxyGenerator.maxGatewaysPerStar;
    bool open(String id) => _degree(id) < cap;
    final act1 = _ofAct(
      1,
    ).where((id) => id.startsWith('a1_') || id == Sys.orcha);
    final act2 = _ofAct(2).where((id) => id != Sys.ulaval);
    final act3 = _ofAct(3).where((id) => id != Sys.sol);

    for (var i = rng.range(1, 2); i > 0; i--) {
      _addDeadBetween(act1.where(open), act2.where(open));
    }
    var bridges = 0;
    for (var i = 2; i > 0; i--) {
      if (_addDeadBetween(act2.where(open), act3.where(open))) bridges++;
    }
    return bridges > 0;
  }

  bool _addDeadBetween(Iterable<String> from, Iterable<String> to) {
    final pairs = [
      for (final x in from)
        for (final y in to)
          if (!_linked(x, y) &&
              _at(x).distanceTo(_at(y)) <= _maxDeadGatewayLength &&
              _canDraw(x, y))
            (x, y),
    ];
    final pick = rng.weighted(pairs, _closeness);
    return pick != null && _link(pick.$1, pick.$2, active: false);
  }

  static const _sublightOnly = {Sys.neoTerra, Sys.urGor, Sys.elephantHq};

  /// Long dead gateways would be drawn right across the map.
  static const _maxDeadGatewayLength = 1000.0;

  /// Joins [ids] into one gateway network, preferring short links.
  bool _connect(List<String> ids, Map<String, int> caps) {
    final parent = {for (final id in ids) id: id};
    String root(String id) {
      while (parent[id] != id) {
        id = parent[id]!;
      }
      return id;
    }

    for (final g in gateways) {
      if (parent.containsKey(g.a) && parent.containsKey(g.b)) {
        parent[root(g.a)] = root(g.b);
      }
    }
    while (ids.map(root).toSet().length > 1) {
      final pairs = [
        for (var i = 0; i < ids.length; i++)
          for (var j = i + 1; j < ids.length; j++)
            if (root(ids[i]) != root(ids[j]) &&
                _degree(ids[i]) < caps[ids[i]]! &&
                _degree(ids[j]) < caps[ids[j]]! &&
                _canDraw(ids[i], ids[j]))
              (ids[i], ids[j]),
      ];
      final pick = rng.weighted(pairs, _closeness);
      if (pick == null || !_link(pick.$1, pick.$2)) return false;
      parent[root(pick.$1)] = root(pick.$2);
    }
    return true;
  }

  bool _fillTo(String id, int degree, List<String> ids, Map<String, int> caps) {
    while (_degree(id) < degree) {
      final options = ids.where(
        (other) =>
            other != id &&
            !_linked(id, other) &&
            _degree(other) < caps[other]! &&
            _canDraw(id, other),
      );
      final pick = rng.weighted(options, (o) => _closeness((id, o)));
      if (pick == null || !_link(id, pick)) return false;
    }
    return true;
  }

  /// Adds up to [count] loops so the network isn't a bare tree.
  void _extraEdges(List<String> ids, Map<String, int> caps, int count) {
    for (var n = 0; n < count; n++) {
      final pairs = [
        for (var i = 0; i < ids.length; i++)
          for (var j = i + 1; j < ids.length; j++)
            if (!_linked(ids[i], ids[j]) &&
                _degree(ids[i]) < caps[ids[i]]! &&
                _degree(ids[j]) < caps[ids[j]]! &&
                _canDraw(ids[i], ids[j]))
              (ids[i], ids[j]),
      ];
      final pick = rng.weighted(pairs, _closeness);
      if (pick == null) return;
      _link(pick.$1, pick.$2);
    }
  }

  int _jumps(String from, String to) {
    final dist = {from: 0};
    final queue = Queue.of([from]);
    while (queue.isNotEmpty) {
      final id = queue.removeFirst();
      if (id == to) return dist[id]!;
      for (final g in gateways) {
        if (g.initiallyActive &&
            g.touches(id) &&
            !dist.containsKey(g.other(id))) {
          dist[g.other(id)] = dist[id]! + 1;
          queue.add(g.other(id));
        }
      }
    }
    return 1 << 30;
  }

  /// Weight that strongly favours nearby pairs.
  double _closeness(_Segment pair) {
    final d = _at(pair.$1).distanceTo(_at(pair.$2));
    return 1 / pow(max(d, 1) / 100, 3);
  }

  // Readability -----------------------------------------------------------

  Iterable<_Segment> get _pipes => [
    for (final g in gateways) (g.a, g.b),
    for (final l in lanes) (l.a, l.b),
  ];

  /// Whether a new pipe from [x] to [y] keeps the map readable: it crosses
  /// no other pipe, passes no other system too closely, and leaves at least
  /// [GalaxyGenerator.minPipeAngle] to every pipe it shares an end with.
  bool _canDraw(String x, String y) {
    final a = _at(x);
    final b = _at(y);
    for (final (c, d) in _pipes) {
      final shared = {c, d}.intersection({x, y});
      if (shared.length == 2) return false;
      if (shared.length == 1) {
        final hub = shared.single;
        final mine = hub == x ? y : x;
        final theirs = hub == c ? d : c;
        if (_angleAt(hub, mine, theirs) < GalaxyGenerator.minPipeAngle) {
          return false;
        }
      } else if (_segmentsCross(a, b, _at(c), _at(d))) {
        return false;
      }
    }
    for (final entry in positions.entries) {
      if (entry.key == x || entry.key == y) continue;
      if (_distanceToSegment(entry.value, a, b) <
          GalaxyGenerator.minPipeClearance) {
        return false;
      }
    }
    return true;
  }

  double _angleAt(String hub, String p, String q) {
    final angle =
        (_bearingFrom(_at(hub), _at(p)) - _bearingFrom(_at(hub), _at(q)))
            .abs() %
        (2 * pi);
    return angle > pi ? 2 * pi - angle : angle;
  }

  // Geometry --------------------------------------------------------------

  static Point<double> _polar(Point<double> from, double r, double angle) =>
      Point(from.x + r * cos(angle), from.y + r * sin(angle));

  static double _bearingFrom(Point<double> from, Point<double> to) =>
      atan2(to.y - from.y, to.x - from.x);

  static double _degrees(double deg) => deg * pi / 180;

  static double _cross(Point<double> o, Point<double> a, Point<double> b) =>
      (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);

  static bool _segmentsCross(
    Point<double> a,
    Point<double> b,
    Point<double> c,
    Point<double> d,
  ) {
    final d1 = _cross(c, d, a);
    final d2 = _cross(c, d, b);
    final d3 = _cross(a, b, c);
    final d4 = _cross(a, b, d);
    return ((d1 > 0) != (d2 > 0)) && ((d3 > 0) != (d4 > 0));
  }

  static double _distanceToSegment(
    Point<double> p,
    Point<double> a,
    Point<double> b,
  ) {
    final ab = b - a;
    final lengthSquared = ab.x * ab.x + ab.y * ab.y;
    final t = lengthSquared == 0
        ? 0.0
        : (((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) / lengthSquared).clamp(
            0.0,
            1.0,
          );
    return p.distanceTo(Point(a.x + ab.x * t, a.y + ab.y * t));
  }
}
