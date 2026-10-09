import 'dart:math';

import 'package:flutter/material.dart';

import '../../game_engine/combat/catalog.dart';
import '../../game_engine/combat/combat.dart';
import '../../game_engine/combat/equipment.dart';
import '../cards/card_widgets.dart';
import '../deck/triforce.dart';
import '../theme.dart';
import 'battle_effects.dart';

/// One ship: its name, hull, shield and drones, and its triforce as large
/// as the space allows.
class ShipPanel extends StatelessWidget {
  const ShipPanel({
    super.key,
    required this.triforceKey,
    required this.maxShield,
    required this.name,
    required this.slots,
    required this.side,
    required this.hull,
    required this.maxHull,
    required this.shield,
    required this.drones,
    required this.time,
    required this.events,
  });

  final GlobalKey triforceKey;
  final int maxShield;
  final String name;
  final List<String?> slots;
  final int side;
  final int hull;
  final int maxHull;
  final int shield;
  final int drones;
  final double time;
  final List<CombatEvent> events;

  /// Hits that land for at least this share of the hull shake the ship.
  static const _heavy = 0.04;

  static const _shieldColour = Color(0xFF7FA8FF);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cooldowns = cooldownSeconds(CombatLoadout(slots));
    final gear = [
      for (final id in slots)
        if (id != null) equipmentById(id),
    ].where((e) => e.kind == CardKind.equipment);
    final maxDrones = gear.fold(0, (t, e) => t + e.maxDrones);
    // A card flashes as its shot leaves, which for missiles is a little
    // before the moment they land.
    final flashing = {
      for (final e in events)
        if (e.side == side)
          if (time - (e.time - launchLead(e.kind)) case final age
              when age >= 0 && age < 0.35)
            e.slot,
    };
    var shake = Offset.zero;
    for (final e in events) {
      final age = time - e.time;
      if (e.side == side || age < 0 || age > 0.3) continue;
      if ((e.value ?? 0) < maxHull * _heavy || !_hurts(e.kind)) continue;
      final fade = 1 - age / 0.3;
      shake = Offset(sin(age * 90) * 7 * fade, cos(age * 70) * 3 * fade);
    }
    final accent = side == 0 ? Palette.gateway : const Color(0xFFFFB3A8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: text.titleMedium?.copyWith(color: accent),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (maxDrones > 0)
                      _Stat(
                        icon: Icons.flight,
                        colour: Palette.codeGreen,
                        label: '$drones / $maxDrones',
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                _Bar(
                  value: hull,
                  max: maxHull,
                  height: 16,
                  colour: hull < maxHull / 4 ? Palette.hell : Palette.codeGreen,
                  label: '$hull / $maxHull hull',
                ),
                if (maxShield > 0) ...[
                  const SizedBox(height: 4),
                  _Bar(
                    value: shield,
                    max: maxShield,
                    height: 14,
                    colour: _shieldColour,
                    label: '$shield / $maxShield shield',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Transform.translate(
              offset: shake,
              child: _FitTriforce(
                triforceKey: triforceKey,
                slots: slots,
                overlay: (slot) => _Charge(
                  id: slots[slot],
                  cooldown: cooldowns[slot],
                  time: time,
                  flash: flashing.contains(slot),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static bool _hurts(CombatEventKind kind) => const {
    CombatEventKind.laserHit,
    CombatEventKind.missileHit,
    CombatEventKind.teleportHit,
    CombatEventKind.hellfireHit,
    CombatEventKind.ionHit,
    CombatEventKind.flakShrapnel,
    CombatEventKind.railHit,
  }.contains(kind);
}

/// A labelled meter, with its numbers written inside it.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.max,
    required this.height,
    required this.colour,
    required this.label,
  });
  final int value;
  final int max;
  final double height;
  final Color colour;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.white12),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: max == 0 ? 0 : (value / max).clamp(0, 1),
            child: ColoredBox(color: colour.withValues(alpha: 0.85)),
          ),
          Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                height: 1,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                shadows: [Shadow(blurRadius: 3)],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.colour, required this.label});
  final IconData icon;
  final Color colour;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: colour),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.labelLarge),
    ],
  );
}

/// The triforce as big as fits in both directions. Its height is a fixed
/// fraction of its width, so a short, wide space would otherwise squash it.
class _FitTriforce extends StatelessWidget {
  const _FitTriforce({
    required this.triforceKey,
    required this.slots,
    required this.overlay,
  });
  final GlobalKey triforceKey;
  final List<String?> slots;
  final Widget Function(int slot) overlay;

  /// Height over width of a [Triforce], tiles included.
  static const _aspect = 0.855 * 0.8660 + 0.145;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final width = min(min(box.maxWidth, box.maxHeight / _aspect), 600.0);
      return Center(
        child: SizedBox(
          key: triforceKey,
          width: width,
          child: Triforce(slots: slots, overlay: overlay),
        ),
      );
    },
  );
}

/// A slot's charge bar, in the card's colour, and a flash when it fires.
class _Charge extends StatelessWidget {
  const _Charge({
    required this.id,
    required this.cooldown,
    required this.time,
    this.flash = false,
  });
  final String? id;
  final double? cooldown;
  final double time;
  final bool flash;

  @override
  Widget build(BuildContext context) {
    final c = cooldown;
    final colour = id == null
        ? Palette.gateway
        : cardColour(equipmentById(id!));
    return Stack(
      children: [
        if (flash)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
        if (c != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              // Along the bottom edge, under the card's name.
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 1.5),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (time % c) / c,
                  minHeight: 3,
                  color: colour,
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
