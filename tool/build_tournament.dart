// ignore_for_file: avoid_print
// Build tournament: captains with the same budget buy whatever they like at
// base prices, then every build fights every other build.
//
//   dart run tool/build_tournament.dart            # budgets 200, 500, 1000, 2000
//   dart run tool/build_tournament.dart 300 800    # your own budgets
//
// Every ship has the standard 500 hull before cards. Each archetype buys
// from a shopping list, cycled until the money or the room runs out, with
// merges as in the game. Each archetype also enters with 0 to 3 hull
// upgrades bought first (50, 100, 200, 400 cr), to show what max hull is
// worth. Every pair fights twice, once from each side, at full hull with a
// 60 s limit: a win scores 1, an escape 0.5.
import 'package:blue_bog/game_engine/combat/catalog.dart';
import 'package:blue_bog/game_engine/combat/combat.dart';
import 'package:blue_bog/game_engine/combat/equipment.dart';
import 'package:blue_bog/game_engine/deck/loadout.dart';
import 'package:blue_bog/game_engine/market.dart';

/// What each captain shops for, in order, cycled.
const archetypes = {
  'Lasers': ['laser_1', 'laser_1', 'fire_control_1', 'laser_1'],
  'Missiles': [
    'cargo_pod_1',
    'missiles_1',
    'missile_crate_1',
    'missiles_1',
    'quick_fuzes_1',
    'missiles_1',
    'missile_crate_1',
  ],
  'Missiles+drones': [
    'cargo_pod_1',
    'missiles_1',
    'missile_crate_1',
    'fabricator_1',
    'feedstock_1',
    'missiles_1',
    'fabricator_1',
  ],
  'Lasers+drones': [
    'cargo_pod_1',
    'laser_1',
    'fabricator_1',
    'feedstock_1',
    'laser_1',
    'fabricator_1',
  ],
  'Lasers+shields': ['laser_1', 'shield_1', 'laser_1', 'shield_capacitor_1'],
  'Teleport': ['cargo_pod_1', 'teleporter_1', 'teleport_charges_1', 'laser_1'],
  'Tank': ['plating_1', 'laser_1', 'plating_1', 'shield_1'],
  'Balanced': [
    'cargo_pod_1',
    'laser_1',
    'missiles_1',
    'missile_crate_1',
    'shield_1',
    'fabricator_1',
    'feedstock_1',
  ],
};

class Build {
  Build(this.name, this.upgrades, this.loadout);
  final String name;
  final int upgrades;
  final Loadout loadout;

  String get label => upgrades == 0 ? name : '$name +${upgrades}H';
  int get hull => baseHull + upgrades * ShipStats.hullPerUpgrade;

  String get cards {
    final counts = <String, int>{};
    for (final id in loadout.all) {
      final name = equipmentById(id).name;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    return [
      for (final e in counts.entries)
        e.value == 1 ? e.key : '${e.value}× ${e.key}',
    ].join(', ');
  }
}

/// Buys hull upgrades first, then cycles the shopping list until nothing
/// more can be bought. Cargo pods are only bought when the hold is full,
/// and equipment only when it fits in a slot (or merges into one).
Build? shop(String name, List<String> list, int budget, int upgrades) {
  var credits = budget;
  for (var i = 0; i < upgrades; i++) {
    credits -= hullUpgradePrice(i);
  }
  if (credits < 0) return null;
  final loadout = Loadout();
  final full = <String>{};
  var bought = true;
  while (bought) {
    bought = false;
    for (final id in list) {
      final card = equipmentById(id);
      final price = card.price;
      if (full.contains(id) || price > credits) continue;
      // Only buy a cargo pod when the hold is full.
      if (card.hold > 0 && loadout.hold.length < loadout.holdCapacity) {
        continue;
      }
      final trial = loadout.copy();
      // Never buy equipment that would sit uselessly in the hold.
      if (trial.add(id) == null ||
          trial.hold.any((c) => equipmentById(c).kind == CardKind.equipment)) {
        full.add(id);
        continue;
      }
      loadout
        ..slots.setAll(0, trial.slots)
        ..hold.replaceRange(0, loadout.hold.length, trial.hold);
      credits -= price;
      bought = true;
    }
  }
  arrange(loadout);
  return Build(name, upgrades, loadout);
}

/// Puts each triangle booster in a small triangle with the weapons it
/// helps, the way a player would, then fills the rest.
void arrange(Loadout l) {
  final cards = l.slots.whereType<String>().toList();
  bool isBooster(String id) =>
      equipmentById(id).boost?.scope == BoostScope.triangle;
  bool helps(String booster, String weapon) {
    final b = equipmentById(booster).boost!;
    final w = equipmentById(weapon);
    return w.action != null &&
        (b.only == null || w.action.runtimeType == b.only);
  }

  final boosters = cards.where(isBooster).toList();
  final rest = cards.where((c) => !isBooster(c)).toList();
  final slots = List<String?>.filled(Loadout.slotCount, null);
  for (var t = 0; t < 3 && boosters.isNotEmpty; t++) {
    final b = boosters.removeAt(0);
    slots[t * 3] = b;
    for (var k = 1; k < 3; k++) {
      final i = rest.indexWhere((w) => helps(b, w));
      if (i >= 0) slots[t * 3 + k] = rest.removeAt(i);
    }
  }
  final leftovers = [...boosters, ...rest];
  for (var i = 0; i < slots.length && leftovers.isNotEmpty; i++) {
    slots[i] ??= leftovers.removeAt(0);
  }
  l.slots.setAll(0, slots);
}

/// Points for [a] against [b]: one fight from each side.
double score(Build a, Build b) {
  var points = 0.0;
  for (final aFirst in [true, false]) {
    final ca = Combatant(
      name: a.label,
      loadout: a.loadout.forCombat,
      baseHull: a.hull,
    );
    final cb = Combatant(
      name: b.label,
      loadout: b.loadout.forCombat,
      baseHull: b.hull,
    );
    final r = aFirst ? fight(ca, cb) : fight(cb, ca);
    final mine = switch (r.outcome) {
      CombatOutcome.win => aFirst ? 1.0 : 0.0,
      CombatOutcome.loss => aFirst ? 0.0 : 1.0,
      CombatOutcome.escape => 0.5,
    };
    points += mine;
  }
  return points / 2;
}

String pct(double x) => '${(x * 100).round()}%'.padLeft(5);

void main(List<String> args) {
  final budgets = args.isEmpty
      ? [200, 500, 1000, 2000]
      : [for (final a in args) int.parse(a)];
  final byUpgrades = <int, Map<int, List<double>>>{};
  final archetypeTotals = <String, Map<int, double>>{};

  for (final budget in budgets) {
    final builds = [
      for (final MapEntry(key: name, value: list) in archetypes.entries)
        for (var u = 0; u <= 3; u++) ?shop(name, list, budget, u),
    ];
    final points = {for (final b in builds) b: 0.0};
    final vs = <(String, String), double>{};
    for (var i = 0; i < builds.length; i++) {
      for (var j = i + 1; j < builds.length; j++) {
        final s = score(builds[i], builds[j]);
        points[builds[i]] = points[builds[i]]! + s;
        points[builds[j]] = points[builds[j]]! + 1 - s;
        if (builds[i].upgrades == 0 && builds[j].upgrades == 0) {
          vs[(builds[i].name, builds[j].name)] = s;
          vs[(builds[j].name, builds[i].name)] = 1 - s;
        }
      }
    }
    final games = builds.length - 1;
    final ranked = builds.toList()
      ..sort((a, b) => points[b]!.compareTo(points[a]!));

    print(
      '\n=== Budget $budget cr: ${builds.length} builds, '
      'each plays the other $games twice ===\n',
    );
    for (final b in ranked) {
      print('${pct(points[b]! / games)}  ${b.label.padRight(22)} ${b.cards}');
    }

    // Head to head, no hull upgrades.
    final names = archetypes.keys.toList();
    print('\nHead to head, row vs column, no hull upgrades:\n');
    print(
      ''.padRight(17) +
          [
            for (final n in names)
              n.substring(0, n.length.clamp(0, 6)).padLeft(7),
          ].join(),
    );
    for (final a in names) {
      final row = StringBuffer(a.padRight(17));
      for (final b in names) {
        row.write(a == b ? '      -' : pct(vs[(a, b)] ?? 0.5).padLeft(7));
      }
      print(row);
    }

    for (final b in builds) {
      byUpgrades
          .putIfAbsent(b.upgrades, () => {})
          .putIfAbsent(budget, () => [])
          .add(points[b]! / games);
      if (b.upgrades == 0) {
        archetypeTotals.putIfAbsent(b.name, () => {})[budget] =
            points[b]! / games;
      }
    }
  }

  print(
    '\n=== Is max hull worth it? Average score by hull upgrades bought ===\n',
  );
  print('${''.padRight(12)}${budgets.map((b) => '$b cr'.padLeft(9)).join()}');
  for (var u = 0; u <= 3; u++) {
    final row = StringBuffer(
      (u == 0 ? 'none' : '+$u (${[50, 150, 350][u - 1]} cr)').padRight(12),
    );
    for (final budget in budgets) {
      final scores = byUpgrades[u]?[budget];
      row.write(
        scores == null || scores.isEmpty
            ? '        -'
            : pct(scores.reduce((a, b) => a + b) / scores.length).padLeft(9),
      );
    }
    print(row);
  }

  print('\n=== Archetypes across budgets (no hull upgrades) ===\n');
  print('${''.padRight(17)}${budgets.map((b) => '$b cr'.padLeft(9)).join()}');
  for (final MapEntry(key: name, value: scores) in archetypeTotals.entries) {
    print(
      name.padRight(17) +
          [for (final b in budgets) pct(scores[b] ?? 0).padLeft(9)].join(),
    );
  }
}
