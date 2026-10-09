import 'dart:collection';
import 'dart:math';

import 'galaxy.dart';
import 'galaxy_attempt.dart';
import 'galaxy_generator.dart';
import 'geometry.dart';

const _sublightOnly = {Sys.neoTerra, Sys.urGor, Sys.elephantHq};

/// Long dead gateways would be drawn right across the map.
const _maxDeadGatewayLength = 1000.0;

/// Gateways and sublight lanes, laid so the map stays readable.
extension GalaxyWiring on GalaxyAttempt {
  Iterable<String> ofAct(int act) =>
      positions.keys.where((id) => acts[id] == act);

  int gatewayCount(String id) => gateways.where((g) => g.touches(id)).length;

  bool linked(String x, String y) =>
      gateways.any((g) => g.touches(x) && g.touches(y));

  /// Adds a gateway if it keeps the map readable.
  bool link(String x, String y, {bool active = true}) {
    if (linked(x, y) || !canDraw(x, y)) return false;
    gateways.add(Gateway(x, y, initiallyActive: active));
    return true;
  }

  bool addLanes() {
    bool lane(String x, String y) {
      if (!canDraw(x, y)) return false;
      final px = at(x).distanceTo(at(y));
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

  bool wireAct1() {
    if (!link(Sys.ghorDum, Sys.bhrunGai) ||
        !link(Sys.bhrunGai, Sys.kepler) ||
        !link(Sys.center, Sys.orcha) ||
        !link(Sys.center, Sys.traeTraeTene, active: false)) {
      return false;
    }

    final network = ofAct(
      1,
    ).where((id) => !_sublightOnly.contains(id)).toList();
    final caps = {
      for (final id in network) id: GalaxyGenerator.maxGatewaysPerStar - 1,
      Sys.center: GalaxyGenerator.maxGatewaysPerStar,
      Sys.kepler: 1,
      Sys.bhrunGai: 2,
      Sys.ghorDum: 2,
    };
    bool open(String id) => gatewayCount(id) < caps[id]!;

    // Ghor-Dum's random gateway goes to the Center or one of its neighbours,
    // so the Gor, the Bhrun and Kepler are never far from the story.
    final via = rng.weighted(
      network.where(
        (p) =>
            p != Sys.ghorDum &&
            !linked(Sys.ghorDum, p) &&
            open(p) &&
            (p == Sys.center || linked(Sys.center, p) || open(Sys.center)),
      ),
      (p) => closeness((Sys.ghorDum, p)),
    );
    if (via == null || !link(Sys.ghorDum, via)) return false;
    if (via != Sys.center && !linked(Sys.center, via)) {
      if (!link(Sys.center, via)) return false;
    }

    if (!connect(network, caps)) return false;
    if (!fillTo(Sys.center, 4, network, caps)) return false;
    extraEdges(network, caps, rng.range(0, 1));
    return gatewayCount(Sys.ghorDum) == 2 &&
        gatewayCount(Sys.center) == 4 &&
        jumps(Sys.center, Sys.ghorDum) <=
            GalaxyGenerator.maxJumpsCenterToGhorDum;
  }

  bool wireAct2() {
    final network = ofAct(2).where((id) => id != Sys.ulaval).toList();
    final caps = {
      for (final id in network) id: GalaxyGenerator.maxGatewaysPerStar - 1,
      Sys.traeTraeTene: GalaxyGenerator.maxGatewaysPerStar,
    };
    if (!connect(network, caps)) return false;
    extraEdges(network, caps, rng.range(1, 3));
    return true;
  }

  bool wireAct3() {
    if (!link(Sys.kyndari, Sys.sol)) return false;
    final network = ofAct(3).where((id) => id != Sys.sol).toList();
    final zirmai = network.where((id) => profiles[id]!.name == 'Zirmai');
    if (zirmai.isNotEmpty) link(Sys.kyndari, zirmai.first);
    final caps = {
      for (final id in network) id: GalaxyGenerator.maxGatewaysPerStar - 1,
    };
    if (!connect(network, caps)) return false;
    extraEdges(network, caps, rng.range(1, 2));
    return true;
  }

  /// Dead gateways left over from the gatecrash. Restoring them is what
  /// moves the story between acts.
  bool wireDeadGateways() {
    const cap = GalaxyGenerator.maxGatewaysPerStar;
    bool open(String id) => gatewayCount(id) < cap;
    final act1 = ofAct(
      1,
    ).where((id) => id.startsWith('a1_') || id == Sys.orcha);
    final act2 = ofAct(2).where((id) => id != Sys.ulaval);
    final act3 = ofAct(3).where((id) => id != Sys.sol);

    for (var i = rng.range(1, 2); i > 0; i--) {
      addDeadBetween(act1.where(open), act2.where(open));
    }
    var bridges = 0;
    for (var i = 2; i > 0; i--) {
      if (addDeadBetween(act2.where(open), act3.where(open))) bridges++;
    }
    return bridges > 0;
  }

  bool addDeadBetween(Iterable<String> from, Iterable<String> to) {
    final pairs = [
      for (final x in from)
        for (final y in to)
          if (!linked(x, y) &&
              at(x).distanceTo(at(y)) <= _maxDeadGatewayLength &&
              canDraw(x, y))
            (x, y),
    ];
    final pick = rng.weighted(pairs, closeness);
    return pick != null && link(pick.$1, pick.$2, active: false);
  }

  /// Joins [ids] into one gateway network, preferring short links.
  bool connect(List<String> ids, Map<String, int> caps) {
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
                gatewayCount(ids[i]) < caps[ids[i]]! &&
                gatewayCount(ids[j]) < caps[ids[j]]! &&
                canDraw(ids[i], ids[j]))
              (ids[i], ids[j]),
      ];
      final pick = rng.weighted(pairs, closeness);
      if (pick == null || !link(pick.$1, pick.$2)) return false;
      parent[root(pick.$1)] = root(pick.$2);
    }
    return true;
  }

  bool fillTo(String id, int degree, List<String> ids, Map<String, int> caps) {
    while (gatewayCount(id) < degree) {
      final options = ids.where(
        (other) =>
            other != id &&
            !linked(id, other) &&
            gatewayCount(other) < caps[other]! &&
            canDraw(id, other),
      );
      final pick = rng.weighted(options, (o) => closeness((id, o)));
      if (pick == null || !link(id, pick)) return false;
    }
    return true;
  }

  /// Adds up to [count] loops so the network isn't a bare tree.
  void extraEdges(List<String> ids, Map<String, int> caps, int count) {
    for (var n = 0; n < count; n++) {
      final pairs = [
        for (var i = 0; i < ids.length; i++)
          for (var j = i + 1; j < ids.length; j++)
            if (!linked(ids[i], ids[j]) &&
                gatewayCount(ids[i]) < caps[ids[i]]! &&
                gatewayCount(ids[j]) < caps[ids[j]]! &&
                canDraw(ids[i], ids[j]))
              (ids[i], ids[j]),
      ];
      final pick = rng.weighted(pairs, closeness);
      if (pick == null) return;
      link(pick.$1, pick.$2);
    }
  }

  int jumps(String from, String to) {
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
  double closeness(PipeSegment pair) {
    final d = at(pair.$1).distanceTo(at(pair.$2));
    return 1 / pow(max(d, 1) / 100, 3);
  }

  // Readability -----------------------------------------------------------

  Iterable<PipeSegment> get pipes => [
    for (final g in gateways) (g.a, g.b),
    for (final l in lanes) (l.a, l.b),
  ];

  /// Whether a new pipe from [x] to [y] keeps the map readable: it crosses
  /// no other pipe, passes no other system too closely, and leaves at least
  /// [GalaxyGenerator.minPipeAngle] to every pipe it shares an end with.
  bool canDraw(String x, String y) {
    final a = at(x);
    final b = at(y);
    for (final (c, d) in pipes) {
      final shared = {c, d}.intersection({x, y});
      if (shared.length == 2) return false;
      if (shared.length == 1) {
        final hub = shared.single;
        final mine = hub == x ? y : x;
        final theirs = hub == c ? d : c;
        if (angleAt(hub, mine, theirs) < GalaxyGenerator.minPipeAngle) {
          return false;
        }
      } else if (segmentsCross(a, b, at(c), at(d))) {
        return false;
      }
    }
    for (final entry in positions.entries) {
      if (entry.key == x || entry.key == y) continue;
      if (distanceToSegment(entry.value, a, b) <
          GalaxyGenerator.minPipeClearance) {
        return false;
      }
    }
    return true;
  }

  double angleAt(String hub, String p, String q) {
    final angle =
        (bearingFrom(at(hub), at(p)) - bearingFrom(at(hub), at(q))).abs() %
        (2 * pi);
    return angle > pi ? 2 * pi - angle : angle;
  }
}
