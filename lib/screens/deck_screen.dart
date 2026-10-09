import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/cards/card_widgets.dart';
import '../components/deck/cargo_hold.dart';
import '../components/deck/colony_grid.dart';
import '../components/deck/ship_stats_bar.dart';
import '../components/deck/triforce.dart';
import '../components/dialogs.dart';
import '../game_engine/combat/catalog.dart';
import '../game_engine/combat/equipment.dart';
import '../game_engine/deck/loadout.dart';
import '../game_engine/run_state.dart';
import '../providers/run_provider.dart';

/// The ship's nine card slots, laid out as a triforce, the cargo bay and
/// hold, and the human colony's grid, docked to the ship.
///
/// Tap a card to pick it up, then tap a slot, hold or colony space to put
/// it there. Whatever was there swaps places with it.
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
    if (run.loadout.whyNotMove(selected, spot) case final why?) {
      return showError(context, why);
    }
    final lost = engine.humansLostWith(
      run,
      run.loadout.copy()..move(selected, spot),
    );
    if (lost > 0 &&
        !await confirmHumansLeave(context, lost, run.humans.count)) {
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
            CargoHold(loadout: run.loadout, tile: (spot) => _tile(run, spot)),
            Center(
              child: ColonyGrid(
                humans: run.humans.count,
                housing: run.stats.housing,
                tile: (spot) => _tile(run, spot),
              ),
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

  Widget _tile(RunState run, CardSpot spot) {
    final id = run.loadout.at(spot);
    return CardTile(
      id: id,
      selected: _selected == spot,
      dimmed: spot is HoldSpot && _inertInHold(id),
      onTap: () => _tap(run, spot),
    );
  }

  bool _inertInHold(String? id) =>
      id != null &&
      switch (equipmentById(id).kind) {
        CardKind.equipment || CardKind.colony => true,
        _ => false,
      };
}
