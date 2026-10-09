import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/cards/card_widgets.dart';
import '../components/deck/ship_stats_bar.dart';
import '../components/deck/triforce.dart';
import '../components/dialogs.dart';
import '../components/theme.dart';
import '../game_engine/combat/catalog.dart';
import '../game_engine/combat/equipment.dart';
import '../game_engine/deck/loadout.dart';
import '../game_engine/run_state.dart';
import '../providers/run_provider.dart';

/// The ship's nine card slots, laid out as a triforce, plus the hold.
///
/// Tap a card to pick it up, then tap a slot or hold space to put it there.
/// Whatever was there swaps places with it.
class DeckScreen extends ConsumerStatefulWidget {
  const DeckScreen({super.key});

  @override
  ConsumerState<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends ConsumerState<DeckScreen> {
  CardSpot? _selected;

  Future<void> _tap(RunState run, CardSpot spot) async {
    final selected = _selected;
    if (selected == null) {
      if (run.loadout.at(spot) != null) setState(() => _selected = spot);
      return;
    }
    if (selected == spot) {
      setState(() => _selected = null);
      return;
    }
    setState(() => _selected = null);
    final engine = ref.read(engineProvider);
    final lost = engine.crewLostWith(
      run,
      run.loadout.copy()..move(selected, spot),
    );
    if (lost > 0 && !await confirmCrewLoss(context, lost, run.humans.count)) {
      return;
    }
    final error = ref.read(runProvider.notifier).arrange(selected, spot);
    if (error != null && mounted) showError(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final run = ref.watch(runProvider);
    if (run == null) return const Scaffold();
    final selectedId = _selected == null ? null : run.loadout.at(_selected!);
    final text = Theme.of(context).textTheme;
    final capacity = run.stats.holdCapacity;
    final holdSpaces = max(capacity, run.loadout.hold.length);

    return Scaffold(
      appBar: AppBar(title: const Text('Ship loadout')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ShipStatsBar(run: run),
            const SizedBox(height: 16),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Triforce(
                  slots: run.loadout.slots,
                  selected: _selected,
                  onTap: (spot) => _tap(run, spot),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Cargo hold (${run.loadout.hold.length}/$capacity)',
              style: text.titleMedium,
            ),
            Text(
              capacity == 0
                  ? 'No hold without a cargo pod. Cargo can sit in a slot '
                        'instead, doing nothing.'
                  : 'Supplies and commodities belong here. Equipment in the '
                        'hold does nothing. Three of a card anywhere merge.',
              style: text.bodySmall?.copyWith(color: Palette.muted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < holdSpaces; i++)
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: CardTile(
                      id: run.loadout.at(HoldSpot(i)),
                      selected: _selected == HoldSpot(i),
                      dimmed: _inertInHold(run.loadout.at(HoldSpot(i))),
                      onTap: () => _tap(run, HoldSpot(i)),
                    ),
                  ),
              ],
            ),
            if (selectedId != null) ...[
              const SizedBox(height: 16),
              CardDetails(
                id: selectedId,
                copies: run.loadout.copiesOf(selectedId),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _inertInHold(String? id) =>
      id != null && equipmentById(id).kind == CardKind.equipment;
}
