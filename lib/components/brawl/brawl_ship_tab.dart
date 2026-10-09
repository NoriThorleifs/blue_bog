import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game_engine/brawl/brawl.dart';
import '../../game_engine/combat/catalog.dart';
import '../../game_engine/combat/equipment.dart';
import '../../game_engine/deck/loadout.dart';
import '../../providers/brawl_provider.dart';
import '../cards/card_widgets.dart';
import '../deck/triforce.dart';
import '../dialogs.dart';
import '../theme.dart';

/// The triforce and the hold. Tap a card to read it; drag it to move it.
///
/// A card like Hell Brandy has a Use button. Using it highlights every card
/// it can affect, with a pulsing glow, until the captain taps one of them
/// or cancels.
class ShipTab extends ConsumerStatefulWidget {
  const ShipTab({super.key, required this.brawl});
  final BrawlState brawl;

  @override
  ConsumerState<ShipTab> createState() => _ShipTabState();
}

class _ShipTabState extends ConsumerState<ShipTab> {
  /// The card being used, while the captain picks what to use it on.
  CardSpot? _using;

  void _cancel() => setState(() => _using = null);

  /// Every spot the card at [using] could be used on.
  Set<CardSpot> _targets(CardSpot? using) {
    final loadout = widget.brawl.loadout;
    if (using == null) return const {};
    return {
      for (var i = 0; i < Loadout.slotCount; i++)
        if (loadout.canUse(using, SlotSpot(i))) SlotSpot(i),
      for (var i = 0; i < loadout.hold.length; i++)
        if (loadout.canUse(using, HoldSpot(i))) HoldSpot(i),
    };
  }

  void _tap(CardSpot spot) {
    final using = _using;
    if (using == null) return _details(spot);
    if (spot == using) return _cancel();
    if (!_targets(using).contains(spot)) {
      return showError(
        context,
        'That card can\'t take it. Pick a glowing one.',
      );
    }
    _cancel();
    reportError(context, ref.read(brawlProvider.notifier).use(using, spot));
  }

  @override
  Widget build(BuildContext context) {
    final brawl = widget.brawl;
    final text = Theme.of(context).textTheme;
    final capacity = brawl.stats.holdCapacity;
    final gear = brawl.loadout.slotted.where(
      (e) => e.kind == CardKind.equipment,
    );
    final shield = gear.fold(0, (t, e) => t + e.maxShield);
    final drones = gear.fold(0, (t, e) => t + e.maxDrones);
    final using = _using;
    final usingCard = using == null
        ? null
        : equipmentById(brawl.loadout.at(using)!);
    final targets = _targets(using);
    final drop = using == null ? _drop : null;
    return PopScope(
      canPop: using == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (usingCard != null)
            Card(
              color: Color.lerp(Palette.panel, hellishRed, 0.15),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Using ${usingCard.name}: tap a glowing card to tag '
                        'it ${usingCard.grantsTag!.label}.',
                      ),
                    ),
                    TextButton(onPressed: _cancel, child: const Text('Cancel')),
                  ],
                ),
              ),
            )
          else ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (icon, label) in [
                  (
                    Icons.shield_outlined,
                    'Hull ${brawl.hull}/${brawl.stats.maxHull}',
                  ),
                  if (shield > 0) (Icons.blur_circular, 'Shield $shield'),
                  if (drones > 0) (Icons.flight, 'Drones $drones'),
                  (Icons.inventory_2_outlined, 'Hold $capacity'),
                ])
                  Chip(
                    avatar: Icon(icon, size: 16, color: Palette.muted),
                    label: Text(label),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tap a card to read or use it. Drag it to move it.',
              style: text.bodySmall?.copyWith(color: Palette.muted),
            ),
          ],
          const SizedBox(height: 8),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Triforce(
                slots: brawl.loadout.slots,
                selected: using,
                glowing: targets,
                onTap: _tap,
                onDrop: drop,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Cargo hold (${brawl.loadout.hold.length}/$capacity)',
            style: text.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < max(capacity, brawl.loadout.hold.length); i++)
                SizedBox.square(
                  dimension: 76,
                  child: SpotTile(
                    spot: HoldSpot(i),
                    id: brawl.loadout.at(HoldSpot(i)),
                    size: 76,
                    selected: using == HoldSpot(i),
                    glowing: targets.contains(HoldSpot(i)),
                    dimmed: _inertInHold(brawl.loadout.at(HoldSpot(i))),
                    onTap: _tap,
                    onDrop: drop,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  bool _inertInHold(String? id) =>
      id != null && equipmentById(id).kind == CardKind.equipment;

  void _drop(CardSpot from, CardSpot to) =>
      reportError(context, ref.read(brawlProvider.notifier).arrange(from, to));

  void _details(CardSpot spot) {
    final engine = ref.read(brawlEngineProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) {
        final brawl = ref.read(brawlProvider)!;
        final id = brawl.loadout.at(spot)!;
        final card = equipmentById(id);
        final sellable = brawl.docked && brawl.market.buys(card);
        final usable = _targets(spot).isNotEmpty;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: CardDetails(
              id: id,
              copies: brawl.loadout.copiesOf(id),
              median: engine.median(brawl, id),
              actions: [
                if (card.grantsTag != null)
                  FilledButton.icon(
                    onPressed: usable
                        ? () {
                            Navigator.pop(sheet);
                            setState(() => _using = spot);
                          }
                        : null,
                    icon: const Icon(Icons.touch_app_outlined),
                    label: Text(usable ? 'Use' : 'Nothing to use it on'),
                  ),
                if (sellable)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheet);
                      reportError(
                        context,
                        ref.read(brawlProvider.notifier).sell(spot),
                      );
                    },
                    icon: const Icon(Icons.sell_outlined),
                    label: Text('Sell for ${engine.sellValue(brawl, id)} cr'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
