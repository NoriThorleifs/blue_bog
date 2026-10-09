import 'package:blue_bog/app/sound.dart';
import 'package:blue_bog/game/brawl/brawl_enemies.dart';
import 'package:blue_bog/game/combat/catalog.dart';
import 'package:blue_bog/game/combat/combat.dart';
import 'package:blue_bog/presentation/combat/battle_sounds.dart';
import 'package:flutter_test/flutter_test.dart';

FightRecord _record(List<String> ids, EnemyTemplate enemy) {
  final player = Combatant(name: 'you', loadout: CombatLoadout.of(ids));
  final foe = Combatant(
    name: enemy.name,
    loadout: enemy.loadout,
    baseHull: enemy.hull,
  );
  return FightRecord(
    enemyName: enemy.name,
    player: player.loadout,
    enemy: enemy.loadout,
    playerMaxHull: player.maxHull,
    enemyMaxHull: foe.maxHull,
    playerStartHull: player.hull,
    result: fight(player, foe),
  );
}

void main() {
  test('cues come in order, missiles launching before they land', () {
    final r = _record([
      'missiles_2',
      'missile_crate_2',
      'laser_2',
    ], act1Enemies[0]);
    final cues = battleCues(r);
    for (var i = 1; i < cues.length; i++) {
      expect(cues[i].time, greaterThanOrEqualTo(cues[i - 1].time));
    }
    final launch = cues.firstWhere((c) => c.sfx == Sfx.missileLaunch);
    final hit = cues.firstWhere((c) => c.sfx == Sfx.explosionSmall);
    expect(hit.time - launch.time, closeTo(0.6, 1e-9));
  });

  test('a win ends with the enemy blowing up and a fanfare', () {
    final r = _record(['laser_3', 'laser_3'], act1Enemies[0]);
    expect(r.result.outcome, CombatOutcome.win);
    final ending = battleCues(r).where((c) => c.time >= r.result.seconds);
    expect(
      ending.map((c) => c.sfx),
      containsAll([Sfx.shipExplode, Sfx.victory]),
    );
    expect(ending.firstWhere((c) => c.sfx == Sfx.shipExplode).side, 1);
  });

  test('Nobody boarding plays its own sound, not an explosion', () {
    final r = _record(['shield_1'], SpecialEnemy.nobody.template);
    final sfx = battleCues(r).map((c) => c.sfx);
    expect(sfx, contains(Sfx.boarded));
    expect(sfx, isNot(contains(Sfx.shipExplode)));
  });

  test('Hell cards sound like Hell', () {
    final r = _record([
      'teeth_1',
      'brandy_mist_1',
      'hell_clock',
    ], act1Enemies[1]);
    final sfx = battleCues(r).map((c) => c.sfx).toSet();
    expect(sfx, containsAll([Sfx.teeth, Sfx.brandyMist, Sfx.hellClock]));
    final ours = battleCues(r).where((c) => c.side == 0).map((c) => c.sfx);
    expect(ours, isNot(contains(Sfx.laser)));
    expect(ours, isNot(contains(Sfx.shieldCharge)));
  });
}
