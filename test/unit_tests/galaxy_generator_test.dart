import 'dart:math';

import 'package:blue_bog/game_engine/galaxy/galaxy.dart';
import 'package:blue_bog/game_engine/galaxy/galaxy_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final generator = GalaxyGenerator();
  final galaxies = [
    for (var seed = 0; seed < 400; seed++) generator.generate(seed),
  ];

  Set<String> activeNeighbours(Galaxy g, String id) => {
    for (final gate in g.gatewaysOf(id))
      if (gate.initiallyActive) gate.other(id),
  };

  Set<String> allNeighbours(Galaxy g, String id) => {
    for (final gate in g.gatewaysOf(id)) gate.other(id),
  };

  test('same seed gives the same galaxy', () {
    final a = generator.generate(1234);
    final b = generator.generate(1234);
    expect(a.systems.keys, b.systems.keys);
    expect(a.gateways.map((g) => g.key), b.gateways.map((g) => g.key));
    for (final id in a.systems.keys) {
      expect(a[id].position, b[id].position);
      expect(a[id].name, b[id].name);
    }
  });

  test('different seeds give different layouts', () {
    final layouts = galaxies.take(20).map((g) => g[Sys.orcha].position);
    expect(layouts.toSet().length, greaterThan(15));
  });

  test(
    'the Center has three working gateways and a dead one to Træ Træ Tene',
    () {
      for (final g in galaxies) {
        expect(activeNeighbours(g, Sys.center), hasLength(3));
        expect(activeNeighbours(g, Sys.center), contains(Sys.orcha));
        final dead = g.gatewaysOf(Sys.center).where((x) => !x.initiallyActive);
        expect(dead.map((x) => x.other(Sys.center)), [Sys.traeTraeTene]);
      }
    },
  );

  test('Kepler, Bhrun-Gai and Ghor-Dum have their fixed gateways', () {
    for (final g in galaxies) {
      expect(allNeighbours(g, Sys.kepler), {Sys.bhrunGai});
      expect(allNeighbours(g, Sys.bhrunGai), {Sys.kepler, Sys.ghorDum});
      final ghor = allNeighbours(g, Sys.ghorDum);
      expect(ghor, hasLength(2));
      expect(ghor, contains(Sys.bhrunGai));
      expect(g.gatewaysOf(Sys.ghorDum).every((x) => x.initiallyActive), isTrue);
    }
  });

  test('sublight-only systems have lanes and no gateways', () {
    for (final g in galaxies) {
      for (final (system, neighbour) in [
        (Sys.neoTerra, Sys.orcha),
        (Sys.urGor, Sys.ghorDum),
        (Sys.ulaval, Sys.ulamora),
      ]) {
        expect(g.gatewaysOf(system), isEmpty, reason: system);
        expect(g.laneBetween(system, neighbour), isNotNull, reason: system);
      }
      expect(g.laneBetween(Sys.kepler, Sys.sol), isNotNull);
    }
  });

  test('Sol has exactly one gateway, a working one to Kyndari', () {
    for (final g in galaxies) {
      expect(activeNeighbours(g, Sys.sol), {Sys.kyndari});
      expect(allNeighbours(g, Sys.sol), {Sys.kyndari});
    }
  });

  test('each act network is connected through working gateways', () {
    for (final g in galaxies) {
      for (final (act, root) in [
        (1, Sys.center),
        (2, Sys.traeTraeTene),
        (3, Sys.kyndari),
      ]) {
        final members = g.systems.values
            .where((s) => s.act == act && g.gatewaysOf(s.id).isNotEmpty)
            .map((s) => s.id)
            .toSet();
        final seen = {root};
        final frontier = [root];
        while (frontier.isNotEmpty) {
          for (final n in activeNeighbours(g, frontier.removeLast())) {
            if (members.contains(n) && seen.add(n)) frontier.add(n);
          }
        }
        expect(seen, members, reason: 'act $act, seed ${g.seed}');
      }
      expect(g[Sys.ulamora].act, 2);
    }
  });

  test('a dead gateway always links act 2 to act 3', () {
    for (final g in galaxies) {
      final bridges = g.gateways.where(
        (x) =>
            !x.initiallyActive && {g[x.a].act, g[x.b].act}.containsAll({2, 3}),
      );
      expect(bridges, isNotEmpty, reason: 'seed ${g.seed}');
      for (final x in g.gateways.where((x) => !x.initiallyActive)) {
        if (x.touches(Sys.center)) continue;
        expect(
          g[x.a].position.distanceTo(g[x.b].position),
          lessThanOrEqualTo(1000),
        );
      }
    }
  });

  test('no star has more than four gateways', () {
    for (final g in galaxies) {
      for (final id in g.systems.keys) {
        expect(
          g.gatewaysOf(id).length,
          lessThanOrEqualTo(GalaxyGenerator.maxGatewaysPerStar),
        );
      }
    }
  });

  test('lore distances from the map notes hold', () {
    for (final g in galaxies) {
      double d(String a, String b) => g[a].position.distanceTo(g[b].position);
      expect(d(Sys.kepler, Sys.sol), closeTo(626.5, 1));
      expect(d(Sys.neoTerra, Sys.traeTraeTene), closeTo(127, 1));
      expect(d(Sys.ulamora, Sys.ulaval), closeTo(54, 1));
    }
  });

  test('systems stay on the map and do not overlap', () {
    for (final g in galaxies) {
      final systems = g.systems.values.toList();
      for (final s in systems) {
        expect(s.position.x, inInclusiveRange(0, mapSize));
        expect(s.position.y, inInclusiveRange(0, mapSize));
      }
      for (var i = 0; i < systems.length; i++) {
        for (var j = i + 1; j < systems.length; j++) {
          expect(
            systems[i].position.distanceTo(systems[j].position),
            greaterThan(39),
          );
        }
      }
      expect(
        g.systems.values.map((s) => s.name).toSet(),
        hasLength(g.systems.length),
      );
    }
  });

  test('Ghor-Dum is at most two jumps from the Center', () {
    for (final g in galaxies) {
      final dist = {Sys.center: 0};
      final queue = [Sys.center];
      while (queue.isNotEmpty) {
        final id = queue.removeAt(0);
        for (final n in activeNeighbours(g, id)) {
          if (!dist.containsKey(n)) {
            dist[n] = dist[id]! + 1;
            queue.add(n);
          }
        }
      }
      expect(dist[Sys.ghorDum], lessThanOrEqualTo(2), reason: 'seed ${g.seed}');
    }
  });

  test('the Center sits off to the side, 2600 ly from Sol', () {
    for (final g in galaxies) {
      final center = g[Sys.center].position;
      expect(center.distanceTo(g[Sys.sol].position), closeTo(900, 1));
      expect(center.distanceTo(GalaxyGenerator.galacticCore), greaterThan(600));
    }
  });

  group('readable layout', () {
    List<(Point<double>, Point<double>, String, String)> pipes(Galaxy g) => [
      for (final x in g.gateways) (g[x.a].position, g[x.b].position, x.a, x.b),
      for (final l in g.lanes) (g[l.a].position, g[l.b].position, l.a, l.b),
    ];

    double cross(Point<double> o, Point<double> a, Point<double> b) =>
        (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);

    test('no two pipes cross', () {
      for (final g in galaxies) {
        final all = pipes(g);
        for (var i = 0; i < all.length; i++) {
          for (var j = i + 1; j < all.length; j++) {
            final (a, b, a1, a2) = all[i];
            final (c, d, b1, b2) = all[j];
            if ({a1, a2}.intersection({b1, b2}).isNotEmpty) continue;
            final crosses =
                (cross(c, d, a) > 0) != (cross(c, d, b) > 0) &&
                (cross(a, b, c) > 0) != (cross(a, b, d) > 0);
            expect(
              crosses,
              isFalse,
              reason: 'seed ${g.seed}: $a1-$a2 crosses $b1-$b2',
            );
          }
        }
      }
    });

    test('pipes meeting at a system are at least 22.5 degrees apart', () {
      for (final g in galaxies) {
        for (final id in g.systems.keys) {
          final here = g[id].position;
          final bearings = [
            for (final (a, b, x, y) in pipes(g))
              if (x == id || y == id)
                () {
                  final there = x == id ? b : a;
                  return atan2(there.y - here.y, there.x - here.x);
                }(),
          ];
          for (var i = 0; i < bearings.length; i++) {
            for (var j = i + 1; j < bearings.length; j++) {
              var angle = (bearings[i] - bearings[j]).abs() % (2 * pi);
              if (angle > pi) angle = 2 * pi - angle;
              expect(
                angle * 180 / pi,
                greaterThanOrEqualTo(22.5 - 1e-9),
                reason: 'seed ${g.seed} at $id',
              );
            }
          }
        }
      }
    });

    test('pipes do not run through other systems', () {
      for (final g in galaxies) {
        for (final (a, b, x, y) in pipes(g)) {
          for (final s in g.systems.values) {
            if (s.id == x || s.id == y) continue;
            final ab = b - a;
            final t =
                (((s.position.x - a.x) * ab.x + (s.position.y - a.y) * ab.y) /
                        (ab.x * ab.x + ab.y * ab.y))
                    .clamp(0.0, 1.0);
            final nearest = Point(a.x + ab.x * t, a.y + ab.y * t);
            expect(
              s.position.distanceTo(nearest),
              greaterThanOrEqualTo(GalaxyGenerator.minPipeClearance),
              reason: 'seed ${g.seed}: $x-$y passes ${s.id}',
            );
          }
        }
      }
    });
  });

  test('Elephant Rock hides off the Ghor-Dum to Ur-Gor sublight lane', () {
    for (final g in galaxies) {
      expect(g.gatewaysOf(Sys.elephantHq), isEmpty);
      final lane = g.lanesOf(Sys.elephantHq).single;
      expect([Sys.ghorDum, Sys.urGor], contains(lane.other(Sys.elephantHq)));
    }
  });

  test('every seed produces a galaxy', () {
    for (var seed = 400; seed < 2400; seed++) {
      expect(() => generator.generate(seed), returnsNormally, reason: '$seed');
    }
  });
}
