import 'package:flutter/material.dart';

import '../../game_engine/deck/loadout.dart';
import '../theme.dart';

/// Colour of the colony's panel: humans' squares, not the ship's triangles.
const colonyGold = Color(0xFFFFD25A);

/// The human colony: a square grid of its own, docked to the ship but
/// clearly not part of it, the way humans lay out their spaces. Its cards
/// never fight. Each screen builds its own [tile] for a spot.
class ColonyGrid extends StatelessWidget {
  const ColonyGrid({
    super.key,
    required this.humans,
    required this.housing,
    required this.tile,
    this.maxSize = 300,
  });

  final int humans;
  final int housing;
  final Widget Function(CardSpot spot) tile;
  final double maxSize;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const side = Loadout.colonySide;
    const gap = 6.0;
    return Column(
      children: [
        // The tether that docks the colony to the ship.
        Container(
          width: 2,
          height: 24,
          color: colonyGold.withValues(alpha: 0.5),
        ),
        Container(
          constraints: BoxConstraints(maxWidth: maxSize + 24),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: colonyGold.withValues(alpha: 0.5)),
            color: Palette.panel,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Human colony · $humans/$housing humans',
                style: text.titleMedium,
              ),
              Text(
                'Only colony cards work here, and they never fight.',
                style: text.bodySmall?.copyWith(color: Palette.muted),
              ),
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: 1,
                child: Column(
                  children: [
                    for (var row = 0; row < side; row++) ...[
                      if (row > 0) const SizedBox(height: gap),
                      Expanded(
                        child: Row(
                          children: [
                            for (var col = 0; col < side; col++) ...[
                              if (col > 0) const SizedBox(width: gap),
                              Expanded(
                                child: tile(ColonySpot(row * side + col)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
