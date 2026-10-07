import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/run_controller.dart';
import '../app/theme.dart';
import '../game/content/content.dart';
import '../game/run_state.dart';

/// Modal card for the pending event, its result, or the end of the run.
class EventOverlay extends ConsumerWidget {
  const EventOverlay({super.key, required this.run});
  final RunState run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ending = run.ending;
    final pending = run.pending;
    final Widget card;
    if (ending != null) {
      card = _EndingCard(run: run, ending: ending);
    } else if (pending != null) {
      card = _EventCard(run: run, pending: pending);
    } else {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(padding: const EdgeInsets.all(16), child: card),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventCard extends ConsumerWidget {
  const _EventCard({required this.run, required this.pending});
  final RunState run;
  final PendingEvent pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final engine = ref.read(engineProvider);
    final controller = ref.read(runProvider.notifier);
    final event = engine.event(pending.eventId);
    final result = pending.result;
    final accent = run.inHell ? Palette.hell : Palette.gateway;

    return Card(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accent.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              event.title,
              style: text.headlineSmall?.copyWith(color: accent),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  result == null
                      ? run.format(event.text)
                      : (result.isEmpty ? 'So be it.' : result),
                  style: text.bodyLarge?.copyWith(height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (result != null)
              FilledButton(
                onPressed: controller.acknowledge,
                child: const Text('Continue'),
              )
            else
              for (final (i, choice) in engine.choicesFor(run).indexed)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton(
                    onPressed: () => controller.choose(i),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(choice.label),
                        if (choice.hint != null)
                          Text(
                            choice.hint!,
                            style: text.labelSmall?.copyWith(
                              color: Palette.muted,
                            ),
                          ),
                        if (engine.combatIn(run, choice) case final enemy?)
                          Text(
                            'Combat: ${enemy.name}, a '
                            '${enemy.hull}-hull ship',
                            style: text.labelSmall?.copyWith(
                              color: Palette.hell,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _EndingCard extends ConsumerWidget {
  const _EndingCard({required this.run, required this.ending});
  final RunState run;
  final Ending ending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final (title, body) = endingText(ending, run);
    final color = switch (ending) {
      Ending.codeBlue => Palette.gateway,
      Ending.codeRed => Palette.hell,
      Ending.codeYellow => Palette.sublight,
      _ => Palette.muted,
    };
    final pendingResult = run.pending?.result;
    return Card(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title.toUpperCase(),
              textAlign: TextAlign.center,
              style: text.displaySmall?.copyWith(color: color),
            ),
            const SizedBox(height: 16),
            if (pendingResult != null && pendingResult.isNotEmpty) ...[
              Text(pendingResult, style: text.bodyMedium),
              const SizedBox(height: 12),
            ],
            Text(body, style: text.bodyLarge?.copyWith(height: 1.5)),
            const SizedBox(height: 16),
            Text(
              '${run.species.name} captain · turn ${run.turn} · act ${run.act} · '
              '${run.humans.count} humans aboard · seed ${run.galaxy.seed}',
              textAlign: TextAlign.center,
              style: text.labelMedium?.copyWith(color: Palette.muted),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                ref.read(runProvider.notifier).abandon();
                context.go('/');
              },
              child: const Text('New run'),
            ),
          ],
        ),
      ),
    );
  }
}
