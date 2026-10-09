// Opens the combat replay straight onto a sample fight, for working on the
// combat screen without playing to a fight first.
//
//   flutter run -d linux -t tool/combat_preview.dart
//   flutter run -d emulator-5554 -t tool/combat_preview.dart
//   flutter run -d linux -t tool/combat_preview.dart --dart-define=FIGHT=hell
import 'package:blue_bog/functions/sound.dart';
import 'package:blue_bog/components/theme.dart';
import 'package:blue_bog/game_engine/brawl/brawl_enemies.dart';
import 'package:blue_bog/game_engine/combat/catalog.dart'
    show CombatLoadout, EnemyTemplate;
import 'package:blue_bog/game_engine/combat/combat.dart';
import 'package:blue_bog/screens/combat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sample fights, picked with `--dart-define=FIGHT=<name>`.
final _fights = <String, (CombatLoadout, EnemyTemplate)>{
  // Lasers, a lance, ion, missiles and drones against drones and repairs.
  'ark': (
    const CombatLoadout([
      'laser_2',
      'lance_1',
      'fire_control_1',
      'missiles_1',
      'missile_crate_1',
      'ion_1',
      'shield_1',
      'fabricator_1',
      'feedstock_1',
    ]),
    brawlPools[5][2],
  ),
  // Hell's own cards, woken by the Hell Clock, into a jammer and shields.
  'hell': (
    const CombatLoadout([
      'brimstone_1',
      'brimstone_1',
      'teeth_1',
      'teeth_1',
      'brandy_mist_1',
      'hell_clock',
      'metal_flesh_1',
      'teleporter_1',
      'teleport_charges_1',
    ]),
    brawlPools[4].firstWhere((e) => e.name.contains('gate-wright')),
  ),
  // Rail slugs into shields: some glance off, and two ion cannons open
  // the way for the rest. With only one, every slug glances off.
  'rail': (
    CombatLoadout.of(['rail_1', 'rail_1', 'ion_1', 'ion_1', 'plating_1']),
    brawlPools[2].firstWhere((e) => e.name.contains('customs')),
  ),
  // Forty seconds to kill Nobody. This build doesn't make it.
  'nobody': (
    CombatLoadout.of(['laser_1', 'laser_1', 'shield_1', 'missiles_1']),
    SpecialEnemy.nobody.template,
  ),
};

FightRecord _sample() {
  final (loadout, enemy) =
      _fights[const String.fromEnvironment('FIGHT', defaultValue: 'ark')]!;
  final player = Combatant(name: 'you', loadout: loadout);
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
    scrapCredits: 120,
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SoundBoard.instance.init();
  runApp(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appTheme,
        home: CombatScreen(record: _sample()),
      ),
    ),
  );
}
