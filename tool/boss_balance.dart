// ignore_for_file: avoid_print
// Boss balance: Satan, the end of a brawl, against the builds a captain can
// realistically have at fight 27. No Hell Clock: it's rare even in a long
// brawl, so it can't be the baseline.
//
//   dart run tool/boss_balance.dart              # Satan as he is
//   dart run tool/boss_balance.dart 2000 2500    # other base hulls
//
// Two sets of builds fight him, at full hull with his tractor beam on:
//
// - Archetypes: hand-built late builds of each main style, mostly upgraded
//   cards with a super or two, and four hull upgrades.
// - Random builds from tool/item_balance.dart at a few budgets, minus any
//   that happened to buy the Hell Clock.
import 'dart:math';

import 'package:blue_bog/game_engine/brawl/brawl_enemies.dart';
import 'package:blue_bog/game_engine/combat/catalog.dart';
import 'package:blue_bog/game_engine/combat/combat.dart';
import 'package:blue_bog/game_engine/deck/loadout.dart';

import 'item_balance.dart' show generate;

/// Late builds of each main style. Slots are three triangles: 0–2, 3–5,
/// 6–8.
final archetypes = <String, (List<String?>, List<String>)>{
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

const archetypeUpgrades = 4;
const budgets = [1500, 2500, 4000];
const randomBuilds = 150;

CombatResult duel(EnemyTemplate boss, CombatLoadout you, int upgrades) => fight(
  Combatant(
    name: 'you',
    loadout: you,
    baseHull: baseHull + upgrades * ShipStats.hullPerUpgrade,
  ),
  Combatant(name: boss.name, loadout: boss.loadout, baseHull: boss.hull),
  tractorBeam: true,
);

String pct(int n, int of) => '${(100 * n / of).round()}%';

void main(List<String> args) {
  final satan = SpecialEnemy.satan.template;
  final hulls = args.isEmpty ? [satan.hull] : args.map(int.parse).toList();
  final rng = Random(27);
  final random = {
    for (final budget in budgets)
      budget: [
        for (var i = 0; i < randomBuilds * 2; i++) generate(rng, budget),
      ].where((b) => !b.loadout.all.contains('hell_clock')).take(randomBuilds),
  };

  for (final hull in hulls) {
    final boss = EnemyTemplate('Satan', hull, satan.loadout);
    final total =
        hull +
        satan.loadout.slots
            .whereType<String>()
            .map(equipmentById)
            .fold(0, (t, e) => t + e.hull);
    print('Satan, base hull $hull ($total in all)');
    var wins = 0;
    for (final MapEntry(key: name, value: (slots, hold))
        in archetypes.entries) {
      final r = duel(boss, CombatLoadout(slots, hold: hold), archetypeUpgrades);
      if (r.outcome == CombatOutcome.win) wins++;
      print(
        '  ${name.padRight(20)} ${r.outcome.name.padRight(5)} in '
        '${r.seconds.round().toString().padLeft(2)} s, hull left ${r.hull}',
      );
    }
    print('  archetypes won ${pct(wins, archetypes.length)}');
    for (final MapEntry(key: budget, value: builds) in random.entries) {
      var won = 0, n = 0;
      for (final b in builds) {
        n++;
        if (duel(boss, b.loadout.forCombat, b.upgrades).outcome ==
            CombatOutcome.win) {
          won++;
        }
      }
      print('  random builds, $budget cr: won ${pct(won, n)} of $n');
    }
  }
}
