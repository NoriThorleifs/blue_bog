import 'package:blue_bog/game_engine/galaxy/galaxy.dart';
import 'package:blue_bog/game_engine/galaxy/galaxy_generator.dart';
import 'package:blue_bog/game_engine/galaxy/territory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases = [
    for (final seed in [1, 2, 3])
      () {
        final galaxy = GalaxyGenerator().generate(seed);
        return (galaxy, buildTerritory(galaxy));
      }(),
  ];

  test('every gate node owns the space around its own gate', () {
    for (final (galaxy, territory) in cases) {
      for (final id in territory.nodes) {
        final p = galaxy[id].position;
        expect(territory.ownerAt(p.x, p.y), id, reason: 'seed ${galaxy.seed}');
      }
    }
  });

  test('only systems with gateways are gate nodes', () {
    for (final (galaxy, territory) in cases) {
      expect(territory.nodes, isNot(contains(Sys.neoTerra)));
      expect(territory.nodes, isNot(contains(Sys.urGor)));
      expect(territory.nodes, containsAll([Sys.center, Sys.kepler, Sys.sol]));
      // Neo Terra lies inside someone else's territory.
      final nt = galaxy[Sys.neoTerra].position;
      expect(territory.ownerAt(nt.x, nt.y), isNotNull);
    }
  });

  test('some of the galaxy belongs to nobody', () {
    for (final (_, territory) in cases) {
      final unclaimed = territory.owners.where((o) => o == 0).length;
      expect(unclaimed / territory.owners.length, greaterThan(0.3));
      expect(territory.ownerAt(5, 5), isNull);
    }
  });

  test('all three border styles appear, and lore borders are fixed', () {
    final styles = {for (final (_, t) in cases) ...t.styles.values};
    expect(styles, BorderStyle.values.toSet());
    for (final (_, t) in cases) {
      expect(t.styles[Sys.center], BorderStyle.colonial);
      expect(t.styles[Sys.ghorDum], BorderStyle.contested);
      expect(t.styles[Sys.kepler], BorderStyle.radial);
    }
  });

  test('is deterministic', () {
    final (galaxy, territory) = cases.first;
    expect(buildTerritory(galaxy).owners, territory.owners);
  });
}
