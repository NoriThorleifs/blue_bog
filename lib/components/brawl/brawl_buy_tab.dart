import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../game_engine/brawl/brawl.dart';
import '../../game_engine/combat/catalog.dart';
import '../../game_engine/market.dart';
import '../../providers/brawl_provider.dart';
import '../cards/card_widgets.dart';
import '../dialogs.dart';
import '../theme.dart';

/// A famine, drought or glut at this station, while it lasts.
class _SupplyShock extends ConsumerWidget {
  const _SupplyShock({required this.brawl});
  final BrawlState brawl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shock = ref.read(brawlEngineProvider).supply(brawl);
    if (shock == null) return const SizedBox.shrink();
    final name = equipmentById(shock.goodId).name;
    final good = name.toLowerCase();
    final until = (brawl.round ~/ supplySeason + 1) * supplySeason;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: Color.lerp(
          Palette.panel,
          shock.shortage ? Palette.sublight : Palette.codeGreen,
          0.2,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            shock.shortage
                ? '${shock.label} at ${brawl.stationName}. They pay several '
                      'times the going rate for $good until fight $until.'
                : '${shock.label} at ${brawl.stationName}. $name goes for a '
                      'fraction of the going rate until fight $until: cheap '
                      'to buy, next to worthless to sell.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}

class BuyTab extends ConsumerWidget {
  const BuyTab({super.key, required this.brawl});
  final BrawlState brawl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.read(brawlEngineProvider);
    final controller = ref.read(brawlProvider.notifier);
    final market = brawl.market;
    final repair = engine.repairCost(brawl);
    final upgrade = engine.hullUpgradeCost(brawl);
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: Palette.muted);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: repair != null && brawl.credits > 0
                  ? () => reportError(context, controller.repair())
                  : null,
              icon: const Icon(Icons.build_outlined, size: 18),
              label: Text(
                repair == null
                    ? 'Hull is fine'
                    : brawl.credits >= repair
                    ? 'Full repair ($repair cr)'
                    : 'Repair what you can (${brawl.credits} cr)',
              ),
            ),
            OutlinedButton.icon(
              onPressed: brawl.credits >= upgrade
                  ? () => reportError(context, controller.upgradeHull())
                  : null,
              icon: const Icon(Icons.add_moderator_outlined, size: 18),
              label: Text('+100 max hull ($upgrade cr)'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          onPressed: () => context.push('/brawl/gambling'),
          icon: const Icon(Icons.casino),
          label: Text('LETS GO GAMBLING! · ${brawl.gamblingGame.label}'),
        ),
        const SizedBox(height: 12),
        _SupplyShock(brawl: brawl),
        Row(
          children: [
            Expanded(
              child: Text(
                'Price, then the galactic median. Your next stop is '
                'a surprise.',
                style: muted,
              ),
            ),
            OutlinedButton.icon(
              onPressed: brawl.credits >= market.rerollPrice
                  ? () => reportError(context, controller.reroll())
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
                note: 'median ${engine.median(brawl, offer.cardId)}',
                onTap: offer.sold ? null : () => _showOffer(context, ref, i),
              ),
          ],
        ),
      ],
    );
  }

  void _showOffer(BuildContext context, WidgetRef ref, int index) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => Consumer(
        builder: (context, ref, _) {
          final brawl = ref.watch(brawlProvider)!;
          final offer = brawl.market.offers[index];
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: CardDetails(
                id: offer.cardId,
                copies: brawl.loadout.copiesOf(offer.cardId),
                median: ref
                    .read(brawlEngineProvider)
                    .median(brawl, offer.cardId),
                actions: [
                  FilledButton.icon(
                    onPressed: offer.sold || brawl.credits < offer.price
                        ? null
                        : () {
                            final error = ref
                                .read(brawlProvider.notifier)
                                .buy(index);
                            Navigator.pop(sheet);
                            reportError(context, error);
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
