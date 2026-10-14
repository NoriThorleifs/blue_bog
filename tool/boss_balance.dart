// ignore_for_file: avoid_print
// Boss balance: a brawl's three final bosses against the builds that meet
// them, at full hull with the boss's tractor beam on.
//
//   dart run tool/boss_balance.dart                     # every boss as it is
//   dart run tool/boss_balance.dart satan 7000 8000     # one boss, other base hulls
//
// - Satan comes only for a captain with a full build (every slot Super, or
//   the Hell Clock) who kills his herald, so he fights full builds of each
//   style. Target: they win, not by much.
// - Lady Idun and Shining-head come at fight 27, so they fight late builds
//   of each style (mostly upgraded cards with a super or two, four hull
//   upgrades) and random builds from tool/item_balance.dart at a few
//   budgets, minus any with the rare Hell Clock. Target: a well-built ship
//   of any style wins, though not by much. Shining-head starts holed.
import 'dart:math';

import 'package:blue_bog/game_engine/brawl/brawl_enemies.dart';
import 'package:blue_bog/game_engine/combat/catalog.dart';
import 'package:blue_bog/game_engine/combat/combat.dart';
import 'package:blue_bog/game_engine/deck/loadout.dart';

import 'item_balance.dart' show generate;

typedef Archetype = (List<String?>, List<String>);

/// Late builds of each main style, for fight 27. Slots are three
/// triangles: 0–2, 3–5, 6–8.
final lateBuilds = <String, Archetype>{
  'lasers and shields': (
    [
      'laser_3',
      'laser_2',
      'fire_control_2',
      'shield_3',
      'shield_capacitor_2',
      'shield_2',
      'plating_3',
      'plating_2',
      'fabricator_2',
    ],
    ['feedstock_2'],
  ),
  'missiles and drones': (
    [
      'missiles_3',
      'missiles_2',
      'quick_fuzes_2',
      'fabricator_3',
      'fabricator_2',
      'plating_2',
      'plating_3',
      'shield_2',
      'repair_2',
    ],
    ['missile_crate_3', 'feedstock_3'],
  ),
  'teleport bombs': (
    [
      'teleporter_3',
      'teleporter_2',
      'fire_control_2',
      'jammer_2',
      'shield_3',
      'plating_3',
      'fabricator_2',
      'plating_2',
      'repair_2',
    ],
    ['teleport_charges_3', 'feedstock_2'],
  ),
  'lance and rail': (
    [
      'lance_3',
      'rail_2',
      'ion_2',
      'shield_3',
      'capacitors_2',
      'plating_3',
      'fabricator_2',
      'plating_2',
      'flak_2',
    ],
    ['feedstock_2'],
  ),
  'Hell cards': (
    [
      'brimstone_3',
      'teeth_2',
      'brandy_mist_2',
      'metal_flesh_3',
      'plating_3',
      'shield_2',
      'fabricator_2',
      'teeth_2',
      'repair_2',
    ],
    ['feedstock_2'],
  ),
};

/// Full builds of each style: what it takes to summon Satan.
final fullBuilds = <String, Archetype>{
  'lasers and shields': (
    [
      'laser_3',
      'laser_3',
      'fire_control_3',
      'shield_3',
      'shield_capacitor_3',
      'shield_3',
      'plating_3',
      'fabricator_3',
      'repair_3',
    ],
    ['feedstock_3'],
  ),
  'missiles and drones': (
    [
      'missiles_3',
      'missiles_3',
      'quick_fuzes_3',
      'fabricator_3',
      'fabricator_3',
      'plating_3',
      'plating_3',
      'shield_3',
      'repair_3',
    ],
    ['missile_crate_3', 'feedstock_3'],
  ),
  'teleport bombs': (
    [
      'teleporter_3',
      'teleporter_3',
      'fire_control_3',
      'jammer_3',
      'shield_3',
      'plating_3',
      'fabricator_3',
      'plating_3',
      'repair_3',
    ],
    ['teleport_charges_3', 'feedstock_3'],
  ),
  'lance and rail': (
    [
      'lance_3',
      'rail_3',
      'ion_3',
      'shield_3',
      'capacitors_3',
      'plating_3',
      'fabricator_3',
      'plating_3',
      'flak_3',
    ],
    ['feedstock_3'],
  ),
  'Hell cards': (
    [
      'brimstone_3',
      'teeth_3',
      'brandy_mist_3',
      'metal_flesh_3',
      'plating_3',
      'shield_3',
      'fabricator_3',
      'teeth_3',
      'repair_3',
    ],
    ['feedstock_3'],
  ),
  'with the Hell Clock': (
    [
      'laser_3',
      'lance_3',
      'rail_3',
      'teleporter_3',
      'hell_clock',
      'fabricator_3',
      'shield_3',
      'plating_3',
      'plating_3',
    ],
    ['teleport_charges_3', 'feedstock_3'],
  ),
};

const lateUpgrades = 4;
const fullUpgrades = 6;
const budgets = [1500, 2500, 4000];
const randomBuilds = 150;

CombatResult duel(
  EnemyTemplate boss,
  CombatLoadout you,
  int upgrades, {
  double startHull = 1,
}) {
  final full = Combatant(
    name: boss.name,
    loadout: boss.loadout,
    baseHull: boss.hull,
  );
  return fight(
    Combatant(
      name: 'you',
      loadout: you,
      baseHull: baseHull + upgrades * ShipStats.hullPerUpgrade,
    ),
    Combatant(
      name: boss.name,
      loadout: boss.loadout,
      baseHull: boss.hull,
      hull: (full.maxHull * startHull).round(),
    ),
    tractorBeam: true,
  );
}

String pct(int n, int of) => '${(100 * n / of).round()}%';

/// Each boss: who it fights, with how many hull upgrades, starting at what
/// share of its hull, and whether random builds fight it too.
final bosses = {
  'satan': (SpecialEnemy.satan, fullBuilds, fullUpgrades, 1.0, false),
  'idun': (SpecialEnemy.idunFlagship, lateBuilds, lateUpgrades, 1.0, true),
  'shining-head': (
    SpecialEnemy.uploadedFlagship,
    lateBuilds,
    lateUpgrades,
    SpecialEnemy.uploadedFlagshipHull,
    true,
  ),
};

void main(List<String> args) {
  final only = args.isEmpty ? null : args.first;
  final hullArgs = args.skip(1).map(int.parse).toList();
  final rng = Random(27);
  final random = {
    for (final budget in budgets)
      budget: [
        for (var i = 0; i < randomBuilds * 2; i++) generate(rng, budget),
      ].where((b) => !b.loadout.all.contains('hell_clock')).take(randomBuilds),
  };

  for (final MapEntry(key: id, value: (enemy, builds, upgrades, start, rand))
      in bosses.entries) {
    if (only != null && id != only) continue;
    final base = enemy.template;
    for (final hull in hullArgs.isEmpty ? [base.hull] : hullArgs) {
      final boss = EnemyTemplate(base.name, hull, base.loadout);
      final total = Combatant(
        name: '',
        loadout: boss.loadout,
        baseHull: hull,
      ).maxHull;
      print(
        '${base.name} ($id), base hull $hull ($total in all'
        '${start < 1 ? ', starting at ${(start * 100).round()}%' : ''})',
      );
      var wins = 0;
      for (final MapEntry(key: name, value: (slots, hold)) in builds.entries) {
        final r = duel(
          boss,
          CombatLoadout(slots, hold: hold),
          upgrades,
          startHull: start,
        );
        if (r.outcome == CombatOutcome.win) wins++;
        print(
          '  ${name.padRight(20)} ${r.outcome.name.padRight(5)} in '
          '${r.seconds.round().toString().padLeft(3)} s, hull left '
          '${r.hull.toString().padLeft(4)}, boss left ${r.enemyHull}',
        );
      }
      print('  builds won ${pct(wins, builds.length)}');
      if (!rand) continue;
      for (final MapEntry(key: budget, value: builds) in random.entries) {
        var won = 0, n = 0;
        for (final b in builds) {
          n++;
          final r = duel(
            boss,
            b.loadout.forCombat,
            b.upgrades,
            startHull: start,
          );
          if (r.outcome == CombatOutcome.win) won++;
        }
        print('  random builds, $budget cr: won ${pct(won, n)} of $n');
      }
    }
  }
}
