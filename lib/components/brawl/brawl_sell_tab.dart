import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game_engine/brawl/brawl.dart';
import '../../game_engine/deck/loadout.dart';
import '../../providers/brawl_provider.dart';
import '../cards/card_widgets.dart';
import '../dialogs.dart';

class SellTab extends ConsumerWidget {
  const SellTab({super.key, required this.brawl});
  final BrawlState brawl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.read(brawlEngineProvider);
    final spots = <CardSpot>[
      for (var i = 0; i < Loadout.slotCount; i++)
        if (brawl.loadout.slots[i] != null) SlotSpot(i),
      for (var i = 0; i < brawl.loadout.hold.length; i++) HoldSpot(i),
    ];
    if (spots.isEmpty) {
      return const Center(child: Text('You have nothing to sell.'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: CardGrid(
        children: [
          for (final spot in spots)
            CardTile(
              id: brawl.loadout.at(spot),
              footer: '${engine.sellValue(brawl, brawl.loadout.at(spot)!)} cr',
              note: 'median ${engine.median(brawl, brawl.loadout.at(spot)!)}',
              onTap: () => _sell(context, ref, spot),
            ),
        ],
      ),
    );
  }

  Future<void> _sell(BuildContext context, WidgetRef ref, CardSpot spot) async {
    final engine = ref.read(brawlEngineProvider);
    final id = brawl.loadout.at(spot)!;
    final sure = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: CardDetails(
            id: id,
            median: engine.median(brawl, id),
            actions: [
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheet, true),
                icon: const Icon(Icons.sell_outlined),
                label: Text('Sell for ${engine.sellValue(brawl, id)} cr'),
              ),
            ],
          ),
        ),
      ),
    );
    if (sure != true || !context.mounted) return;
    reportError(context, ref.read(brawlProvider.notifier).sell(spot));
  }
}
