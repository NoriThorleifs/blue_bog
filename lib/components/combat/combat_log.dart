import 'dart:math';

import 'package:flutter/material.dart';

import '../../game_engine/combat/catalog.dart';
import '../../game_engine/combat/combat.dart';
import '../theme.dart';

class CombatLog extends StatelessWidget {
  const CombatLog({super.key, required this.record, required this.time});
  final FightRecord record;
  final double time;

  @override
  Widget build(BuildContext context) {
    final shown = record.result.events
        .where((e) => e.time <= time)
        .toList()
        .reversed
        .take(30)
        .toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: shown.length,
      itemBuilder: (context, i) {
        final e = shown[i];
        final who = e.side == 0 ? 'You' : record.enemyName;
        final slots = e.side == 0 ? record.player.slots : record.enemy.slots;
        final card = equipmentById(slots[e.slot]!).name;
        final line = switch (e.kind) {
          CombatEventKind.laserHit => '$who: $card hits for ${e.value}',
          CombatEventKind.laserAbsorbed => '$who: $card is stopped by shields',
          CombatEventKind.missileHit => '$who: $card hits for ${e.value}',
          CombatEventKind.missileIntercepted =>
            '$who: $card is shot down by a drone',
          CombatEventKind.teleportHit =>
            '$who: $card goes off inside the hull for ${e.value}',
          CombatEventKind.hellfireHit =>
            '$who: $card burns through for ${e.value}, and scorches its own '
                'hull',
          CombatEventKind.shieldsCharged => '$who: shields at ${e.value}',
          CombatEventKind.droneBuilt => '$who: drones out: ${e.value}',
          CombatEventKind.outOfAmmo => '$who: $card is out of ammunition',
          CombatEventKind.ionHit =>
            '$who: $card strips shields${e.value! > 0 ? ' and hits for ${e.value}' : ''}',
          CombatEventKind.flakHit =>
            '$who: $card shoots down ${e.value} '
                '${e.value == 1 ? 'drone' : 'drones'}',
          CombatEventKind.flakShrapnel =>
            e.value == 0
                ? '$who: $card shrapnel is stopped by shields'
                : '$who: $card shrapnel hits for ${e.value}',
          CombatEventKind.repaired => '$who: $card patches ${e.value} hull',
          CombatEventKind.jamsReady => '$who: teleport jams ready: ${e.value}',
          CombatEventKind.teleportJammed =>
            '$who: $card is jammed and goes off harmlessly',
          CombatEventKind.railHit => '$who: $card slams home for ${e.value}',
          CombatEventKind.railDeflected =>
            '$who: $card glances off the shields',
          CombatEventKind.boarded =>
            '$who: $card fires. Nobody is aboard ${e.side == 0 ? record.enemyName : 'your ship'}',
        };
        return Opacity(
          opacity: max(0.35, 1 - i * 0.08),
          child: Text(
            '${e.time.toStringAsFixed(1)}  $line',
            style: TextStyle(
              fontSize: 12,
              color: e.side == 0 ? Palette.gateway : const Color(0xFFFFB3A8),
            ),
          ),
        );
      },
    );
  }
}
