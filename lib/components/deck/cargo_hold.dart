import 'dart:math';

import 'package:flutter/material.dart';

import '../../game_engine/deck/loadout.dart';
import '../theme.dart';

/// The cargo bay's own slot, outside the triforce, and the hold its pod
/// opens up. Each screen builds its own [tile] for a spot, so it can be
/// tapped or dragged however that screen works.
class CargoHold extends StatelessWidget {
  const CargoHold({
    super.key,
    required this.loadout,
    required this.tile,
    this.size = 76,
  });

  final Loadout loadout;
  final Widget Function(CardSpot spot) tile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final capacity = loadout.holdCapacity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cargo hold (${loadout.hold.length}/$capacity)',
          style: text.titleMedium,
        ),
        Text(
          capacity == 0
              ? 'No hold until a cargo pod goes in the cargo bay.'
              : 'Supplies and commodities belong in the hold. Equipment '
                    'there does nothing. Three of a card anywhere merge.',
          style: text.bodySmall?.copyWith(color: Palette.muted),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                SizedBox.square(
                  dimension: size,
                  child: tile(const CargoSpot()),
                ),
                const SizedBox(height: 2),
                Text(
                  'Cargo bay',
                  style: text.labelSmall?.copyWith(color: Palette.muted),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < max(capacity, loadout.hold.length); i++)
                    SizedBox.square(dimension: size, child: tile(HoldSpot(i))),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
