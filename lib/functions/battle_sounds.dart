import '../components/combat/battle_effects.dart' show launchLead;
import '../game_engine/combat/catalog.dart';
import '../game_engine/combat/combat.dart';
import 'sound.dart';

/// One sound at one moment of a fight. [side] is the ship it comes from,
/// for panning, or null for the whole screen.
typedef Cue = ({double time, Sfx sfx, double volume, int? side});

/// Every sound a fight makes, in order, timed to match [BattleEffects]:
/// launches when a shot leaves, impacts when it lands.
List<Cue> battleCues(FightRecord record) {
  final cues = <Cue>[];
  void cue(double time, Sfx sfx, int? side, [double volume = 1]) =>
      cues.add((time: time, sfx: sfx, volume: volume, side: side));

  for (final e in record.result.events) {
    final launch = e.time - launchLead(e.kind);
    final target = 1 - e.side;
    final slots = e.side == 0 ? record.player.slots : record.enemy.slots;
    final family = switch (slots[e.slot]) {
      final id? => equipmentById(id).family,
      null => null,
    };
    // Beams by what fired them: lasers zap, lances hum, Hell's teeth bite.
    final beam = switch (family) {
      'lance' => Sfx.lance,
      'teeth' => Sfx.teeth,
      _ => Sfx.laser,
    };
    switch (e.kind) {
      case CombatEventKind.laserHit:
        cue(e.time, beam, e.side, 0.7);
      case CombatEventKind.laserAbsorbed:
        cue(e.time, beam, e.side, 0.6);
        cue(e.time, Sfx.shieldBlock, target, 0.6);
      case CombatEventKind.missileHit:
        cue(launch, Sfx.missileLaunch, e.side, 0.6);
        cue(e.time, Sfx.explosionSmall, target, 0.8);
      case CombatEventKind.missileIntercepted:
        cue(launch, Sfx.missileLaunch, e.side, 0.6);
        cue(e.time, Sfx.explosionSmall, target, 0.45);
      case CombatEventKind.teleportHit:
        // The sound rises for a moment before its pop.
        cue(e.time - 0.15, Sfx.teleport, target);
      case CombatEventKind.teleportJammed:
        cue(e.time - 0.15, Sfx.jammed, target);
      case CombatEventKind.hellfireHit:
        cue(launch, Sfx.hellfire, e.side, 0.8);
        cue(e.time, Sfx.explosionSmall, target, 0.6);
      case CombatEventKind.ionHit:
        cue(e.time, Sfx.ion, e.side, 0.7);
      case CombatEventKind.flakHit || CombatEventKind.flakShrapnel:
        cue(e.time, Sfx.flak, target, 0.7);
      case CombatEventKind.shieldsCharged:
        family == 'brandy_mist'
            ? cue(e.time, Sfx.brandyMist, e.side, 0.6)
            : cue(e.time, Sfx.shieldCharge, e.side, 0.4);
      case CombatEventKind.droneBuilt:
        cue(e.time, Sfx.droneBuilt, e.side, 0.5);
      case CombatEventKind.repaired:
        cue(e.time, Sfx.repair, e.side, 0.6);
      case CombatEventKind.outOfAmmo:
        cue(e.time, Sfx.outOfAmmo, e.side, 0.6);
      case CombatEventKind.railHit:
        cue(e.time, Sfx.rail, e.side, 0.85);
        cue(e.time, Sfx.explosionSmall, target, 0.9);
      case CombatEventKind.railDeflected:
        cue(e.time, Sfx.rail, e.side, 0.85);
        cue(e.time + 0.03, Sfx.railGlance, target, 0.8);
      case CombatEventKind.boarded:
        cue(e.time, Sfx.boarded, null);
      case CombatEventKind.jamsReady:
        break;
    }
  }

  // The Hell Clock ticks backwards as the fight begins.
  for (final (side, loadout) in [record.player, record.enemy].indexed) {
    if (loadout.slots.contains(hellClock.id)) cue(0, Sfx.hellClock, side, 0.7);
  }

  final result = record.result;
  final boarded =
      result.events.isNotEmpty &&
      result.events.last.kind == CombatEventKind.boarded;
  if (!boarded) {
    switch (result.outcome) {
      case CombatOutcome.win:
        cue(result.seconds, Sfx.shipExplode, 1);
        cue(result.seconds + 0.5, Sfx.victory, null, 0.8);
      case CombatOutcome.loss:
        cue(result.seconds, Sfx.shipExplode, 0);
        cue(result.seconds + 0.5, Sfx.defeat, null, 0.8);
      case CombatOutcome.escape:
        break;
    }
  }
  cues.sort((a, b) => a.time.compareTo(b.time));
  return cues;
}
