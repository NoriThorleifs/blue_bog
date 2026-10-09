// ignore_for_file: avoid_print
// Brawl enemy balance: random builds at a budget fit for each stage fight
// every ship in that stage's pool. Ships in one pool should score close to
// the pool's first ship, the one that held the stage alone before.
//
//   dart run tool/enemy_balance.dart [builds]
import 'dart:math';

import 'package:blue_bog/game_engine/brawl/brawl_enemies.dart';
import 'package:blue_bog/game_engine/combat/catalog.dart';
import 'package:blue_bog/game_engine/combat/combat.dart';

import 'item_balance.dart' show Build, generate;

/// A rough guess at what a captain has spent on cards by each stage.
const _stageBudgets = [100, 200, 350, 500, 800, 1200];

/// Late acts and their budgets. Every late fight draws from the last pool.
const _late = {2: 2000, 3: 3500, 4: 5000};

void main(List<String> args) {
  final count = args.isEmpty ? 300 : int.parse(args.first);
  for (final (stage, pool) in brawlPools.indexed) {
    _report('Stage $stage', _stageBudgets[stage], count, pool);
  }
  for (final MapEntry(key: act, value: budget) in _late.entries) {
    _report('Late act $act', budget, count, [
      for (final e in brawlPools.last) e.forAct(act),
    ]);
  }
  // Special ships against the usual enemy at the same fight, across the
  // fights their event can come up.
  const rounds = {
    SpecialEnemy.neoTerranPlatform: [7, 9, 11, 15, 19],
    SpecialEnemy.lastVote: [4, 5],
    SpecialEnemy.gorChampion: [8, 9, 10],
    SpecialEnemy.unmergedFoundry: [11, 14],
    SpecialEnemy.nobody: [7, 8, 9, 11, 15, 19],
  };
  for (final MapEntry(key: s, value: at) in rounds.entries) {
    for (final round in at) {
      _report(
        '${s.name} at fight $round',
        _budgetAt(round),
        count,
        [brawlEnemy(round, 0), s.at(round)],
        // Gor duels have no breaking away.
        tractorBeam: s == SpecialEnemy.gorChampion,
      );
    }
  }
}

/// The stage or late-act budget for fight [round].
int _budgetAt(int round) {
  final act = brawlAct(round);
  if (act > 1) return _late[act] ?? _late.values.last;
  const stages = [0, 1, 2, 2, 3, 3, 4, 4, 5, 5];
  return _stageBudgets[stages[round - 1]];
}

void _report(
  String label,
  int budget,
  int count,
  List<EnemyTemplate> pool, {
  bool tractorBeam = false,
}) {
  final rng = Random(budget);
  final builds = [for (var i = 0; i < count; i++) generate(rng, budget)];
  print('$label, $budget cr builds (player win %, escapes count half):');
  for (final enemy in pool) {
    final score = builds.fold(
      0.0,
      (t, b) => t + _score(b, enemy, tractorBeam: tractorBeam),
    );
    print(
      '  ${enemy.name.padRight(30)} ${enemy.hull.toString().padLeft(5)} hull'
      '  ${(100 * score / count).toStringAsFixed(0).padLeft(3)}%',
    );
  }
}

double _score(Build b, EnemyTemplate enemy, {bool tractorBeam = false}) {
  final r = fight(
    Combatant(name: 'me', loadout: b.loadout.forCombat, baseHull: b.hull),
    Combatant(name: enemy.name, loadout: enemy.loadout, baseHull: enemy.hull),
    tractorBeam: tractorBeam,
  );
  return switch (r.outcome) {
    CombatOutcome.win => 1,
    CombatOutcome.escape => 0.5,
    CombatOutcome.loss => 0,
  };
}
