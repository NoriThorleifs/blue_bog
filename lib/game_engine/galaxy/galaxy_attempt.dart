import 'dart:math';

import '../rng.dart';
import 'galaxy.dart';
import 'galaxy_generator.dart';
import 'galaxy_wiring.dart';
import 'geometry.dart';
import 'system_catalog.dart';

typedef PipeSegment = (String, String);

/// One try at building a galaxy. [build] returns null if the try painted
/// itself into a corner, and [GalaxyGenerator] starts another.
class GalaxyAttempt {
  GalaxyAttempt(this.rng, this.seed);

  final GameRng rng;
  final int seed;
  final positions = <String, Point<double>>{};
  final profiles = <String, SystemProfile>{};
  final acts = <String, int>{};
  final gateways = <Gateway>[];
  final lanes = <SublightLane>[];
  final usedNames = <String>{};

  /// Direction from the Center toward open space, where acts 2 and 3 grow.
  late double frontier;

  Galaxy? build() {
    if (!placeAct1() || !placeAct2() || !placeAct3()) return null;
    if (!addLanes() || !wireAct1() || !wireAct2() || !wireAct3()) {
      return null;
    }
    if (!wireDeadGateways()) return null;
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

  Point<double> at(String id) => positions[id]!;

  // Placement -------------------------------------------------------------

  bool placeAct1() {
    const sol = GalaxyGenerator.solPosition;
    put(Sys.sol, sol, 3);

    // The Center is 2600 ly from Sol, off to one side of the galaxy.
    final left = rng.chance(0.5);
    final tilt = degrees(rng.rangeDouble(15, 40));
    final center = polar(
      sol,
      2600 * pixelsPerLightYear,
      left ? pi + tilt : -tilt,
    );
    if (!free(center)) return false;
    put(Sys.center, center, 1);
    frontier = bearingFrom(center, GalaxyGenerator.galacticCore);

    // Kepler is 1810 ly from Sol, roughly on the way to the Center.
    final toCenter = bearingFrom(sol, center);
    final kepler = polar(
      sol,
      1810 * pixelsPerLightYear,
      toCenter + degrees(rng.rangeDouble(-35, 35)),
    );
    if (!free(kepler)) return false;
    put(Sys.kepler, kepler, 1);

    final towardOrcha =
        frontier +
        degrees(rng.rangeDouble(25, 70)) * (rng.chance(0.5) ? 1 : -1);
    return placeNear(
          Sys.bhrunGai,
          Sys.kepler,
          1,
          170,
          380,
          maxFromCenter: 650,
        ) &&
        placeNear(Sys.ghorDum, Sys.bhrunGai, 1, 170, 380, maxFromCenter: 650) &&
        placeNear(Sys.urGor, Sys.ghorDum, 1, 110, 170, spacing: 100) &&
        placeElephantRock() &&
        placeToward(Sys.orcha, Sys.center, 1, 220, 400, towardOrcha, 15) &&
        nameAgriWorld() &&
        placeToward(
          Sys.neoTerra,
          Sys.orcha,
          1,
          120,
          160,
          frontier,
          35,
          spacing: 100,
        ) &&
        placeFillers(1, rng.range(3, 5), Sys.center, 170, 560);
  }

  bool placeAct2() {
    // Neo Terra to Træ Træ Tene is 127 px in the map notes.
    return placeToward(
          Sys.traeTraeTene,
          Sys.neoTerra,
          2,
          127,
          127,
          frontier,
          40,
          spacing: 110,
        ) &&
        placeNear(
          Sys.ulamora,
          Sys.traeTraeTene,
          2,
          170,
          450,
          minFromCenter: 550,
        ) &&
        // Úlamora to Úlaval is 54.1 px in the map notes.
        placeNear(Sys.ulaval, Sys.ulamora, 2, 54, 54, spacing: 40) &&
        placeFillers(
          2,
          rng.range(6, 8),
          Sys.traeTraeTene,
          150,
          750,
          minFromCenter: 550,
        );
  }

  bool placeAct3() {
    // Kyndari lies on the far side of Sol from the Center, so the human
    // gateway between them runs through empty space.
    final sol = GalaxyGenerator.solPosition;
    final away = bearingFrom(at(Sys.center), sol);
    for (var i = 0; i < 200; i++) {
      final p = polar(
        sol,
        rng.rangeDouble(450, 850),
        away + degrees(rng.rangeDouble(-75, 15)) * turnSign(),
      );
      if (p.distanceTo(at(Sys.center)) >= 1000 && free(p)) {
        put(Sys.kyndari, p, 3);
        return placeFillers(
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
  double turnSign() =>
      at(Sys.center).x < GalaxyGenerator.solPosition.x ? 1 : -1;

  /// The House of the Elephant hides off the Ghor-Dum–Ur-Gor sublight lane,
  /// in the middle of nowhere but close to the traffic.
  bool placeElephantRock() {
    final a = at(Sys.ghorDum);
    final b = at(Sys.urGor);
    final mid = Point((a.x + b.x) / 2, (a.y + b.y) / 2);
    final along = bearingFrom(a, b);
    for (var i = 0; i < 40; i++) {
      final side = rng.chance(0.5) ? pi / 2 : -pi / 2;
      final p = polar(
        mid,
        rng.rangeDouble(110, 160),
        along + side + degrees(rng.rangeDouble(-20, 20)),
      );
      if (free(p, spacing: 95)) {
        put(Sys.elephantHq, p, 1);
        return true;
      }
    }
    return false;
  }

  bool placeFillers(
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
      final profile = i < lore.length ? lore[i] : proceduralProfile();
      profiles[id] = profile;
      usedNames.add(profile.name);
      if (!placeNear(
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
  bool nameAgriWorld() {
    String name;
    do {
      name = '${rng.pick(fillerNamePrefixes)}${rng.pick(fillerNameSuffixes)}';
    } while (usedNames.contains(name));
    usedNames.add(name);
    final lore = fixedSystems[Sys.neoTerra]!;
    profiles[Sys.neoTerra] = SystemProfile(name, lore.description, lore.tags);
    return true;
  }

  SystemProfile proceduralProfile() {
    final template = rng.pick(fillerProfiles);
    String name;
    do {
      name = rng.chance(0.25)
          ? 'Survey ${List.generate(4, (_) => rng.nextInt(3)).join('-')}'
          : '${rng.pick(fillerNamePrefixes)}${rng.pick(fillerNameSuffixes)}';
    } while (usedNames.contains(name));
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

  bool placeNear(
    String id,
    String anchorId,
    int act,
    double minRadius,
    double maxRadius, {
    double spacing = GalaxyGenerator.minSpacing,
    double minFromCenter = 0,
    double maxFromCenter = double.infinity,
  }) {
    for (var i = 0; i < 200; i++) {
      final p = polar(
        at(anchorId),
        rng.rangeDouble(minRadius, maxRadius),
        rng.rangeDouble(0, 2 * pi),
      );
      final fromCenter = p.distanceTo(at(Sys.center));
      if (fromCenter >= minFromCenter &&
          fromCenter <= maxFromCenter &&
          free(p, spacing: spacing)) {
        put(id, p, act);
        return true;
      }
    }
    return false;
  }

  /// Places [id] between [minRadius] and [maxRadius] from [anchorId], within
  /// [spreadDegrees] of [bearing].
  bool placeToward(
    String id,
    String anchorId,
    int act,
    double minRadius,
    double maxRadius,
    double bearing,
    double spreadDegrees, {
    double spacing = GalaxyGenerator.minSpacing,
  }) {
    for (var i = 0; i < 100; i++) {
      final angle =
          bearing + degrees(rng.rangeDouble(-spreadDegrees, spreadDegrees));
      final p = polar(
        at(anchorId),
        rng.rangeDouble(minRadius, maxRadius),
        angle,
      );
      if (free(p, spacing: spacing)) {
        put(id, p, act);
        return true;
      }
    }
    return false;
  }

  void put(String id, Point<double> p, int act) {
    positions[id] = p;
    acts[id] = act;
    profiles.putIfAbsent(id, () => fixedSystems[id]!);
  }

  bool free(Point<double> p, {double spacing = GalaxyGenerator.minSpacing}) {
    const lo = GalaxyGenerator.margin;
    const hi = mapSize - GalaxyGenerator.margin;
    if (p.x < lo || p.x > hi || p.y < lo || p.y > hi) return false;
    if (positions.values.any((q) => q.distanceTo(p) < spacing)) return false;
    // Keep clear of sublight lanes whose ends are already placed, so the
    // lanes can still be drawn once everything is in place.
    for (final (x, y) in plannedLanes) {
      final a = positions[x];
      final b = positions[y];
      if (a != null &&
          b != null &&
          distanceToSegment(p, a, b) < GalaxyGenerator.minPipeClearance + 10) {
        return false;
      }
    }
    return true;
  }

  static const plannedLanes = [
    (Sys.orcha, Sys.neoTerra),
    (Sys.ghorDum, Sys.urGor),
    (Sys.elephantHq, Sys.urGor),
    (Sys.elephantHq, Sys.ghorDum),
    (Sys.ulamora, Sys.ulaval),
    (Sys.kepler, Sys.sol),
  ];
}
