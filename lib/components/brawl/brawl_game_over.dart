import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../game_engine/brawl/brawl.dart';
import '../../providers/brawl_provider.dart';

class GameOver extends ConsumerWidget {
  const GameOver({super.key, required this.brawl});
  final BrawlState brawl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Ship lost', style: text.displaySmall),
                const SizedBox(height: 8),
                Text(
                  'You survived ${brawl.fightsWon} '
                  '${brawl.fightsWon == 1 ? 'fight' : 'fights'} and died '
                  'with ${brawl.credits} credits.',
                  textAlign: TextAlign.center,
                  style: text.bodyLarge,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () =>
                      ref.read(brawlProvider.notifier).start(brawl.species),
                  icon: const Icon(Icons.replay),
                  label: Text('Brawl again as ${brawl.species.name}'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    ref.read(brawlProvider.notifier).abandon();
                    context.go('/');
                  },
                  child: const Text('Back to the title'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
