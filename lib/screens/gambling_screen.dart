import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/gambling/roulette_table.dart';
import '../components/gambling/twenty_seven_table.dart';
import '../components/theme.dart';
import '../game_engine/brawl/brawl.dart';
import '../providers/brawl_provider.dart';

/// The station's gambling den: whichever game the locals play.
class GamblingScreen extends ConsumerWidget {
  const GamblingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brawl = ref.watch(brawlProvider);
    if (brawl == null) return const Scaffold();
    return switch (brawl.gamblingGame) {
      GamblingGame.roulette => const RouletteTable(),
      GamblingGame.al => const TwentySevenTable(),
      final game => _ComingSoon(game: game, station: brawl.stationName),
    };
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.game, required this.station});
  final GamblingGame game;
  final String station;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('$station · ${game.label}')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.casino_outlined, size: 64, color: Palette.muted),
              const SizedBox(height: 16),
              Text(game.label, style: text.headlineSmall),
              const SizedBox(height: 8),
              Text(
                switch (game) {
                  GamblingGame.gor =>
                    'The Gor are still arguing about the rules. Loudly. '
                        'Come back later.',
                  GamblingGame.al => '',
                  GamblingGame.roulette => '',
                },
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(color: Palette.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
