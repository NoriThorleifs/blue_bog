import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../game_engine/run_state.dart';
import '../../game_engine/story/keys.dart';
import '../theme.dart';

/// Top status bar. Shows the ship and crew as the captain sees them, which
/// is to say without the hidden half of HR.
class Hud extends StatelessWidget {
  const Hud({super.key, required this.run, required this.onOpenLog});

  final RunState run;
  final VoidCallback onOpenLog;

  static const _acts = ['I', 'II', 'III'];

  @override
  Widget build(BuildContext context) {
    final stats = run.stats;
    final humans = run.humans;
    final moodColor = switch (humans.loyalty) {
      >= 60 => Palette.codeGreen,
      >= 40 => Colors.white,
      >= 20 => Palette.sublight,
      _ => Palette.hell,
    };
    return Material(
      color: Palette.panel,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 18,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'ACT ${_acts[run.act - 1]} · TURN ${run.turn}',
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(letterSpacing: 2),
                    ),
                    _Item(Icons.toll, '${run.credits}', 'Credits'),
                    _Item(
                      Icons.shield_outlined,
                      '${run.hull}/${stats.maxHull}',
                      'Hull',
                      color: run.hull <= stats.maxHull / 4
                          ? Palette.hell
                          : null,
                    ),
                    _Item(
                      Icons.local_gas_station_outlined,
                      '${run.fuel}/${stats.fuelCapacity}',
                      'Fuel. A gateway jump burns 1, a sublight burn 2. '
                          'Refuel at stations.',
                      color: run.fuel < 2 ? Palette.sublight : null,
                    ),
                    _Item(
                      Icons.groups_outlined,
                      humans.count == 0
                          ? 'No humans'
                          : '${humans.count} humans · ${humans.mood}',
                      'Human resources. Keep them happy enough that they '
                      'don\'t blow up the ship.',
                      color: humans.count == 0 ? Palette.muted : moodColor,
                    ),
                    _Item(
                      Icons.account_balance_outlined,
                      '${run.counter(Counter.influence)}',
                      'Political influence',
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Ship loadout and cards',
                onPressed: () => context.push('/deck'),
                icon: const Icon(Icons.change_history),
              ),
              IconButton(
                tooltip: 'Galactic news and ship\'s log',
                onPressed: onOpenLog,
                icon: const Icon(Icons.feed_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item(this.icon, this.value, this.tooltip, {this.color});
  final IconData icon;
  final String value;
  final String tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color ?? Palette.muted),
        const SizedBox(width: 6),
        Text(value, style: TextStyle(color: color)),
      ],
    ),
  );
}

/// Galactic news and the ship's log, newest first.
class LogDrawer extends StatelessWidget {
  const LogDrawer({super.key, required this.run});
  final RunState run;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final entries = run.log.reversed.toList();
    return Drawer(
      width: min(420, MediaQuery.sizeOf(context).width * 0.9),
      backgroundColor: Palette.space,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('News & log', style: text.titleLarge),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: entries.length,
                separatorBuilder: (_, _) => const Divider(height: 20),
                itemBuilder: (context, i) {
                  final e = entries[i];
                  final color = switch (e.kind) {
                    LogKind.news => Palette.news,
                    LogKind.hell => Palette.hell,
                    LogKind.ship => Palette.muted,
                  };
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Turn ${e.turn} · ${e.title ?? (e.kind == LogKind.news ? 'News' : 'Ship\'s log')}',
                        style: text.labelLarge?.copyWith(color: color),
                      ),
                      if (e.text.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(e.text, style: text.bodyMedium),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
