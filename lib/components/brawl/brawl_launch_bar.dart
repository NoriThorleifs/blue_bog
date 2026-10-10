import 'package:flutter/material.dart';

import '../../game_engine/brawl/brawl.dart';
import '../theme.dart';

/// What happened since the captain last decided anything.
class BrawlLog extends StatelessWidget {
  const BrawlLog(this.lines, {super.key});
  final List<String> lines;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final line in lines)
        Text(
          line,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Palette.muted),
        ),
    ],
  );
}

/// Shows what happened since the captain last decided anything, in a
/// dialog they dismiss, so it doesn't sit over the shop.
Future<void> showBrawlLog(
  BuildContext context,
  String title,
  List<String> lines,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(title),
    content: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(line),
            ),
        ],
      ),
    ),
    actions: [
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('OK'),
      ),
    ],
  ),
);

class LaunchBar extends StatelessWidget {
  const LaunchBar({super.key, required this.brawl, required this.onLaunch});
  final BrawlState brawl;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    final enemy = brawl.nextEnemy;
    return Material(
      color: Palette.panel,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: onLaunch,
                icon: const Icon(Icons.rocket_launch),
                label: Text(
                  'Launch · next up: ${enemy.name}, ${enemy.hull} hull',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
