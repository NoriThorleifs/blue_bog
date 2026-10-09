// ignore_for_file: avoid_print
// Balance harness for the combat model. See `Combat and economy plan.md`.
//
//   dart run tool/combat_balance.dart
import 'dart:math';

import 'package:blue_bog/game_engine/captain/species.dart';
import 'package:blue_bog/game_engine/combat/catalog.dart';
import 'package:blue_bog/game_engine/combat/combat.dart';
import 'package:blue_bog/game_engine/combat/equipment.dart';

/// Every species' starting ship.
final starterKits = {
  for (final s in Species.values)
    s.name: CombatLoadout.of(s.ship.startingCards, hold: s.ship.startingHold),
};

void main() {
  print('Starter kits against act 1 enemies (result, seconds, hull left)\n');
  _matrix(starterKits);

  print('\nStarter kits plus three random basic cards (average of 200)\n');
  _randomUpgrades();

  print('\nAcceptance targets');
  _acceptance();

  print('\nCards in winning random loadouts against the Gunship');
  _dominance();
}

void _matrix(Map<String, CombatLoadout> kits) {
  print(
    '${''.padRight(12)}${act1Enemies.map((e) => e.name.padLeft(17)).join()}',
  );
  for (final MapEntry(key: name, value: kit) in kits.entries) {
    final row = StringBuffer(name.padRight(12));
    for (final enemy in act1Enemies) {
      final r = _fight(kit, enemy);
      final mark = switch (r.outcome) {
        CombatOutcome.win => 'W',
        CombatOutcome.loss => 'L',
        CombatOutcome.escape => 'esc',
      };
      row.write(
        '${mark.padLeft(5)}${r.seconds.toStringAsFixed(0).padLeft(5)}s'
        '${r.hull.toString().padLeft(5)} ',
      );
    }
    print(row);
  }
}

CombatResult _fight(CombatLoadout kit, EnemyTemplate enemy) => fight(
  Combatant(name: 'me', loadout: kit),
  Combatant(name: enemy.name, loadout: enemy.loadout, baseHull: enemy.hull),
);

/// Basic cards that matter in a fight.
final _basics = [
  for (final f in equipmentFamilies)
    if (f.kind != CardKind.colony &&
        f.hold == 0 &&
        f.fuel == 0 &&
        f.hellShielding == 0)
      f.tiers.first.id,
];

CombatLoadout _plus(CombatLoadout kit, Random rng, int n) {
  final slots = [...kit.slots];
  for (var i = 0; i < n; i++) {
    final free = slots.indexOf(null);
    if (free < 0) break;
    slots[free] = _basics[rng.nextInt(_basics.length)];
  }
  return CombatLoadout(slots, hold: kit.hold);
}

void _randomUpgrades() {
  final rng = Random(1);
  print(
    '${''.padRight(12)}${act1Enemies.map((e) => '${e.name} win%'.padLeft(16)).join()}',
  );
  for (final MapEntry(key: name, value: kit) in starterKits.entries) {
    final row = StringBuffer(name.padRight(12));
    for (final enemy in act1Enemies) {
      var wins = 0;
      for (var i = 0; i < 200; i++) {
        if (_fight(_plus(kit, rng, 3), enemy).outcome == CombatOutcome.win) {
          wins++;
        }
      }
      row.write('${(wins / 2).toStringAsFixed(0)}%'.padLeft(16));
    }
    print(row);
  }
}

void _acceptance() {
  void check(String what, bool ok) => print('  ${ok ? 'PASS' : 'FAIL'}  $what');

  final easy = act1Enemies.take(2);
  check(
    'every starter beats Scout and Raider with over 50% hull left',
    starterKits.values.every(
      (kit) => easy.every((e) {
        final r = _fight(kit, e);
        return r.outcome == CombatOutcome.win && r.hull > baseHull / 2;
      }),
    ),
  );

  // Fair fights: a starter plus three cards against Pirate and Gunship.
  final rng = Random(2);
  var escapes = 0, total = 0;
  final times = <double>[];
  for (final kit in starterKits.values) {
    for (final enemy in act1Enemies.sublist(2, 4)) {
      for (var i = 0; i < 100; i++) {
        final r = _fight(_plus(kit, rng, 3), enemy);
        total++;
        if (r.outcome == CombatOutcome.escape) escapes++;
        times.add(r.seconds);
      }
    }
  }
  times.sort();
  check(
    'at most 10% of fair fights reach the 60 s escape '
    '(${(100 * escapes / total).toStringAsFixed(1)}%)',
    escapes / total <= 0.1,
  );
  check(
    'median fair fight lasts 15–45 s (${times[times.length ~/ 2]} s)',
    times[times.length ~/ 2] >= 15 && times[times.length ~/ 2] <= 45,
  );
  check(
    'a fresh starter never beats the Elite',
    starterKits.values.every(
      (kit) => _fight(kit, act1Enemies.last).outcome != CombatOutcome.win,
    ),
  );
}

void _dominance() {
  final rng = Random(3);
  final inWins = <String, int>{};
  var wins = 0;
  for (var i = 0; i < 3000; i++) {
    final kit = _plus(CombatLoadout.of([]), rng, 6);
    if (_fight(kit, act1Enemies[3]).outcome != CombatOutcome.win) continue;
    wins++;
    for (final id in kit.slots.whereType<String>().toSet()) {
      inWins[id] = (inWins[id] ?? 0) + 1;
    }
  }
  final sorted = inWins.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final e in sorted) {
    final share = e.value / wins;
    print(
      '  ${e.key.padRight(22)} ${(100 * share).toStringAsFixed(0)}%'
      '${share > 0.8 ? '  <- in nearly every win' : ''}',
    );
  }
  print('  ($wins wins out of 3000 random 6-card ships)');
}
