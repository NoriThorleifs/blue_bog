import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/cards/card_widgets.dart';
import '../components/dialogs.dart';
import '../components/theme.dart';
import '../game_engine/combat/catalog.dart';
import '../game_engine/deck/loadout.dart';
import '../game_engine/run_state.dart';
import '../providers/run_provider.dart';

/// A trading hub: 27 offers rolled for this visit, selling your own cards,
/// and the shipyard.
class MarketScreen extends ConsumerWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final run = ref.watch(runProvider);
    final market = run?.market;
    if (run == null || market == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('There is no market here.')),
      );
    }
    final controller = ref.read(runProvider.notifier);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '${run.nameOf(run.location)} '
            '${market.tradingPost ? 'trading post' : 'market'}',
          ),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${run.credits} cr',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Buy'),
              Tab(text: 'Sell'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (market.tradingPost)
                    Text(
                      'A trading post: supplies and commodities only, and '
                      'no shipyard.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Palette.muted),
                    )
                  else
                    _Shipyard(run: run),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Stock changes every visit.',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: Palette.muted),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: run.credits >= market.rerollPrice
                            ? () => _report(context, controller.rerollMarket())
                            : null,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text('Reroll (${market.rerollPrice} cr)'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CardGrid(
                    children: [
                      for (final (i, offer) in market.offers.indexed)
                        CardTile(
                          id: offer.cardId,
                          dimmed: offer.sold,
                          footer: offer.sold ? 'Sold' : '${offer.price} cr',
                          onTap: offer.sold
                              ? null
                              : () => _showOffer(context, ref, i),
                        ),
                    ],
                  ),
                ],
              ),
              _SellTab(run: run),
            ],
          ),
        ),
      ),
    );
  }

  void _showOffer(BuildContext context, WidgetRef ref, int index) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => Consumer(
        builder: (context, ref, _) {
          final run = ref.watch(runProvider)!;
          final offer = run.market!.offers[index];
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: CardDetails(
                id: offer.cardId,
                copies: run.loadout.copiesOf(offer.cardId),
                actions: [
                  FilledButton.icon(
                    onPressed: offer.sold || run.credits < offer.price
                        ? null
                        : () {
                            final error = ref
                                .read(runProvider.notifier)
                                .buy(index);
                            Navigator.pop(sheet);
                            _report(context, error);
                          },
                    icon: const Icon(Icons.shopping_cart_outlined),
                    label: Text('Buy for ${offer.price} cr'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

void _report(BuildContext context, String? error) {
  if (error != null) showError(context, error);
}

class _Shipyard extends ConsumerWidget {
  const _Shipyard({required this.run});
  final RunState run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.read(engineProvider);
    final controller = ref.read(runProvider.notifier);
    final repair = engine.repairCost(run);
    final upgrade = engine.hullUpgradeCost(run);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shipyard', style: Theme.of(context).textTheme.titleMedium),
            Text(
              'Hull ${run.hull}/${run.stats.maxHull}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Palette.muted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: repair != null && run.credits > 0
                      ? () => _report(context, controller.repair())
                      : null,
                  icon: const Icon(Icons.build_outlined, size: 18),
                  label: Text(
                    repair == null
                        ? 'Hull is fine'
                        : run.credits >= repair
                        ? 'Full repair ($repair cr)'
                        : 'Repair what you can (${run.credits} cr)',
                  ),
                ),
                if (upgrade != null)
                  OutlinedButton.icon(
                    onPressed: run.credits >= upgrade
                        ? () => _report(context, controller.upgradeHull())
                        : null,
                    icon: const Icon(Icons.add_moderator_outlined, size: 18),
                    label: Text('+100 max hull ($upgrade cr)'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SellTab extends ConsumerWidget {
  const _SellTab({required this.run});
  final RunState run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.read(engineProvider);
    final spots = <CardSpot>[
      for (var i = 0; i < Loadout.slotCount; i++)
        if (run.loadout.slots[i] != null) SlotSpot(i),
      for (var i = 0; i < run.loadout.hold.length; i++) HoldSpot(i),
    ];
    if (spots.isEmpty) {
      return const Center(child: Text('You have nothing to sell.'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: CardGrid(
        children: [
          for (final spot in spots)
            if (run.market!.buys(equipmentById(run.loadout.at(spot)!)))
              CardTile(
                id: run.loadout.at(spot),
                footer: '${engine.sellValue(run, run.loadout.at(spot)!)} cr',
                onTap: () => _sell(context, ref, spot),
              )
            else
              CardTile(
                id: run.loadout.at(spot),
                dimmed: true,
                footer: 'Not bought here',
              ),
        ],
      ),
    );
  }

  Future<void> _sell(BuildContext context, WidgetRef ref, CardSpot spot) async {
    final engine = ref.read(engineProvider);
    final id = run.loadout.at(spot)!;
    final price = engine.sellValue(run, id);
    final sure = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: CardDetails(
            id: id,
            actions: [
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheet, true),
                icon: const Icon(Icons.sell_outlined),
                label: Text('Sell for $price cr'),
              ),
            ],
          ),
        ),
      ),
    );
    if (sure != true || !context.mounted) return;
    final without = run.loadout.copy()..takeOut(spot);
    final lost = engine.crewLostWith(run, without);
    if (lost > 0 && !await confirmCrewLoss(context, lost, run.humans.count)) {
      return;
    }
    if (!context.mounted) return;
    _report(context, ref.read(runProvider.notifier).sell(spot));
  }
}
