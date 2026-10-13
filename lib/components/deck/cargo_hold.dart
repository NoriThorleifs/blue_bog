import 'dart:math';

import 'package:flutter/material.dart';

import '../../game_engine/deck/loadout.dart';
import '../theme.dart';

/// The cargo bay's own slot, outside the triforce, and below it the hold
/// its pod opens up, as a grid across the full width. Each screen builds
/// its own [tile] for a spot, so it can be tapped or dragged however that
/// screen works.
class CargoHold extends StatelessWidget {
  const CargoHold({
    super.key,
    required this.loadout,
    required this.tile,
    this.maxTile = 76,
  });

  final Loadout loadout;
  final Widget Function(CardSpot spot) tile;

  /// The largest a hold space gets. Narrower screens get smaller spaces
  /// rather than fewer than [minColumns] to a row, so a big hold doesn't
  /// scroll forever.
  final double maxTile;

  static const minColumns = 5;
  static const gap = 6.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: Palette.muted);
    final capacity = loadout.holdCapacity;
    final spaces = max(capacity, loadout.hold.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox.square(dimension: maxTile, child: tile(const CargoSpot())),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cargo bay', style: text.titleMedium),
                  Text(
                    'Only a cargo pod goes here, and only the pod here opens '
                    'the hold.',
                    style: muted,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Cargo hold (${loadout.hold.length}/$capacity)',
          style: text.titleMedium,
        ),
        Text(
          capacity == 0
              ? 'No hold until a cargo pod goes in the cargo bay.'
              : 'Supplies and commodities belong in the hold. Equipment '
                    'there does nothing. Three of a card anywhere merge.',
          style: muted,
        ),
        if (spaces > 0) ...[
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, box) {
              final columns = max(
                minColumns,
                ((box.maxWidth + gap) / (maxTile + gap)).floor(),
              );
              final size = min(
                maxTile,
                (box.maxWidth - gap * (columns - 1)) / columns,
              );
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var i = 0; i < spaces; i++)
                    SizedBox.square(dimension: size, child: tile(HoldSpot(i))),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}
