import 'dart:math';

import 'package:flutter/material.dart';

import '../../functions/sound.dart';
import '../../game_engine/combat/combat.dart';
import '../theme.dart';

/// The fight's clock, how far through the time limit it is, and the
/// playback controls.
class CombatTopBar extends StatelessWidget {
  const CombatTopBar({
    super.key,
    required this.time,
    required this.end,
    required this.done,
    required this.speed,
    required this.onSpeed,
    required this.onSkip,
  });
  final double time;
  final double end;
  final bool done;
  final int speed;
  final ValueChanged<int> onSpeed;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                '${time.toStringAsFixed(1)} s',
                style: text.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                ' / ${combatTimeLimit.round()} s',
                style: text.labelLarge?.copyWith(color: Palette.muted),
              ),
              const Spacer(),
              if (!done) ...[
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('1×')),
                    ButtonSegment(value: 2, label: Text('2×')),
                    ButtonSegment(value: 4, label: Text('4×')),
                  ],
                  selected: {speed},
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  onSelectionChanged: (s) => onSpeed(s.first),
                ),
                IconButton(
                  tooltip: 'Skip to the end',
                  onPressed: onSkip,
                  icon: const Icon(Icons.skip_next),
                ),
              ],
              ValueListenableBuilder(
                valueListenable: SoundBoard.instance.muted,
                builder: (context, muted, _) => IconButton(
                  tooltip: muted ? 'Sound on' : 'Sound off',
                  onPressed: () => SoundBoard.instance.muted.value = !muted,
                  icon: Icon(muted ? Icons.volume_off : Icons.volume_up),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: min(1, time / combatTimeLimit),
              minHeight: 3,
              color: Palette.muted,
              backgroundColor: Colors.white10,
            ),
          ),
        ],
      ),
    );
  }
}
