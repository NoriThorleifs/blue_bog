import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game_engine/brawl/brawl.dart';
import '../../providers/brawl_provider.dart';
import '../dialogs.dart';
import '../theme.dart';
import 'brawl_launch_bar.dart';

/// The event in front of the captain: its choices, then what came of the
/// one they made.
class EventTab extends ConsumerWidget {
  const EventTab({super.key, required this.brawl, required this.onProceed});
  final BrawlState brawl;
  final VoidCallback onProceed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = brawl.currentEvent!;
    final engine = ref.read(brawlEngineProvider);
    final text = Theme.of(context).textTheme;
    final result = brawl.result;
    final plan = brawl.plannedFight;
    final enemy = plan == null ? null : engine.enemyFor(brawl, plan);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (brawl.log.isNotEmpty) ...[
          BrawlLog(brawl.log),
          const SizedBox(height: 16),
        ],
        Text(event.title, style: text.headlineSmall),
        const SizedBox(height: 12),
        Text(event.text, style: text.bodyLarge),
        const SizedBox(height: 20),
        if (result == null)
          for (final (i, choice) in event.choices.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  alignment: Alignment.centerLeft,
                ),
                onPressed: engine.canChoose(brawl, i)
                    ? () => reportError(
                        context,
                        ref.read(brawlProvider.notifier).choose(i),
                      )
                    : null,
                child: Text(choice.label),
              ),
            )
        else ...[
          Text(
            result,
            style: text.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: enemy == null ? null : Palette.hell,
            ),
            onPressed: onProceed,
            icon: Icon(
              enemy != null
                  ? Icons.bolt
                  : brawl.inHell
                  ? Icons.south
                  : Icons.anchor,
            ),
            label: Text(switch (enemy) {
              final e? =>
                'Fight the ${e.name} (${e.hull} hull)'
                    '${plan!.tractorBeam ? ', no escape' : ''}',
              null when brawl.inHell => 'Deeper into Hell',
              null => 'Dock',
            }),
          ),
        ],
      ],
    );
  }
}
