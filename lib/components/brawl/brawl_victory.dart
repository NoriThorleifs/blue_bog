import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game_engine/brawl/brawl.dart';
import '../../providers/brawl_provider.dart';
import '../dialogs.dart';
import '../theme.dart';

/// Satan is beaten: the brawl is won. The captain retires on top, or fights
/// on for score against ever harder ships.
class Victory extends ConsumerWidget {
  const Victory({super.key, required this.brawl});
  final BrawlState brawl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final controller = ref.read(brawlProvider.notifier);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Satan is beaten', style: text.displaySmall),
                const SizedBox(height: 12),
                Text(
                  'You won the brawl at fight ${brawl.round}, after '
                  '${brawl.fightsWon} fights, with ${brawl.credits} credits '
                  'and ${brawl.humans.count} humans aboard.',
                  textAlign: TextAlign.center,
                  style: text.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'You can retire on top, or fight on for score. Every fight '
                  'from here is harder than the last, and it only ends one '
                  'way.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: Palette.muted),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => reportError(context, controller.retire()),
                  icon: const Icon(Icons.emoji_events_outlined),
                  label: const Text('Retire a winner'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => reportError(context, controller.goEndless()),
                  icon: const Icon(Icons.all_inclusive),
                  label: const Text('Keep going'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
