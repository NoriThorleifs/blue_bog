import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/brawl_controller.dart';
import '../../app/theme.dart';
import '../../game/brawl/brawl.dart';
import '../../game/combat/catalog.dart';
import '../../game/combat/equipment.dart';
import '../../game/deck/loadout.dart';
import '../../game/market.dart';
import '../cards/card_widgets.dart';
import '../deck/deck_screen.dart' show SpotTile, Triforce, showError;

/// Brawl mode's only screen between fights: a station to trade and refit
/// at, the events on the way out, and Hell.
class BrawlScreen extends ConsumerStatefulWidget {
  const BrawlScreen({super.key});

  @override
  ConsumerState<BrawlScreen> createState() => _BrawlScreenState();
}

class _BrawlScreenState extends ConsumerState<BrawlScreen> {
  /// The brawl as it was before a fight. The fight is decided the moment
  /// the captain moves on, so until its replay is closed this screen keeps
  /// showing the moment before rather than giving the result away.
  BrawlState? _frozen;

  Future<void> _proceed() async {
    final before = ref.read(brawlProvider);
    final error = ref.read(brawlProvider.notifier).proceed();
    if (error != null) return _report(context, error);
    final after = ref.read(brawlProvider);
    if (after?.lastCombat == before?.lastCombat) return;
    setState(() => _frozen = before);
    await context.push('/brawl/combat');
    if (mounted) setState(() => _frozen = null);
  }

  @override
  Widget build(BuildContext context) {
    final brawl = _frozen ?? ref.watch(brawlProvider);
    if (brawl == null) return const Scaffold();
    if (brawl.lost) return _GameOver(brawl: brawl);
    final text = Theme.of(context).textTheme;
    final docked = brawl.docked;
    final hull = 'Hull ${brawl.hull}/${brawl.stats.maxHull}';
    return DefaultTabController(
      key: ValueKey(docked),
      length: docked ? 3 : 2,
      child: Scaffold(
        backgroundColor: brawl.inHell
            ? Color.lerp(Palette.space, Palette.hell, 0.12)
            : null,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: brawl.inHell
              ? Color.lerp(Palette.space, Palette.hell, 0.25)
              : null,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                brawl.inHell
                    ? 'Hell'
                    : docked
                    ? brawl.stationName
                    : 'Leaving ${brawl.stationName}',
              ),
              Text(
                brawl.inHell
                    ? 'Turn ${brawl.hellTurns} · $hull · no shipyard'
                    : 'Fight ${brawl.round} · $hull',
                style: text.labelMedium?.copyWith(color: Palette.muted),
              ),
            ],
          ),
          actions: [
            Center(child: Text('${brawl.credits} cr', style: text.titleMedium)),
            PopupMenuButton<void>(
              itemBuilder: (context) => [
                PopupMenuItem(
                  onTap: () {
                    ref.read(brawlProvider.notifier).abandon();
                    context.go('/');
                  },
                  child: const Text('Abandon brawl'),
                ),
              ],
            ),
          ],
          bottom: TabBar(
            tabs: [
              if (docked) ...const [Tab(text: 'Buy'), Tab(text: 'Sell')] else
                Tab(text: brawl.inHell ? 'Hell' : 'Event'),
              const Tab(text: 'Ship'),
            ],
          ),
        ),
        bottomNavigationBar: docked
            ? _LaunchBar(
                brawl: brawl,
                onLaunch: () =>
                    _report(context, ref.read(brawlProvider.notifier).launch()),
              )
            : null,
        body: SafeArea(
          child: TabBarView(
            children: [
              if (docked) ...[
                _BuyTab(brawl: brawl),
                _SellTab(brawl: brawl),
              ] else
                _EventTab(brawl: brawl, onProceed: _proceed),
              _ShipTab(brawl: brawl),
            ],
          ),
        ),
      ),
    );
  }
}

void _report(BuildContext context, String? error) {
  if (error != null) showError(context, error);
}

/// What happened since the captain last decided anything.
class _Log extends StatelessWidget {
  const _Log(this.lines);
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

class _LaunchBar extends StatelessWidget {
  const _LaunchBar({required this.brawl, required this.onLaunch});
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
              if (brawl.log.isNotEmpty) ...[
                _Log(brawl.log),
                const SizedBox(height: 8),
              ],
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

/// The event in front of the captain: its choices, then what came of the
/// one they made.
class _EventTab extends ConsumerWidget {
  const _EventTab({required this.brawl, required this.onProceed});
  final BrawlState brawl;
  final VoidCallback onProceed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = brawl.currentEvent!;
    final engine = ref.read(brawlEngineProvider);
    final text = Theme.of(context).textTheme;
    final result = brawl.result;
    final plan = brawl.plannedFight;
    final enemy = plan == null ? null : engine.enemyFor(brawl, plan);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (brawl.log.isNotEmpty) ...[
          _Log(brawl.log),
          const SizedBox(height: 16),
        ],
        Text(event.title, style: text.headlineSmall),
        const SizedBox(height: 12),
        Text(event.text, style: text.bodyLarge),
        const SizedBox(height: 20),
        if (result == null)
          for (final (i, choice) in event.choices.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  alignment: Alignment.centerLeft,
                ),
                onPressed: engine.canChoose(brawl, i)
                    ? () => _report(
                        context,
                        ref.read(brawlProvider.notifier).choose(i),
                      )
                    : null,
                child: Text(choice.label),
              ),
            )
        else ...[
          Text(
            result,
            style: text.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: enemy == null ? null : Palette.hell,
            ),
            onPressed: onProceed,
            icon: Icon(
              enemy != null
                  ? Icons.bolt
                  : brawl.inHell
                  ? Icons.south
                  : Icons.anchor,
            ),
            label: Text(switch (enemy) {
              final e? =>
                'Fight the ${e.name} (${e.hull} hull)'
                    '${plan!.tractorBeam ? ', no escape' : ''}',
              null when brawl.inHell => 'Deeper into Hell',
              null => 'Dock',
            }),
          ),
        ],
      ],
    );
  }
}

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

class _BuyTab extends ConsumerWidget {
  const _BuyTab({required this.brawl});
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
                  ? () => _report(context, controller.repair())
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
                  ? () => _report(context, controller.upgradeHull())
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
                  ? () => _report(context, controller.reroll())
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

class _SellTab extends ConsumerWidget {
  const _SellTab({required this.brawl});
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
    _report(context, ref.read(brawlProvider.notifier).sell(spot));
  }
}

/// The triforce and the hold. Tap a card to read it; drag it to move it.
///
/// A card like Hell Brandy has a Use button. Using it highlights every card
/// it can affect, with a pulsing glow, until the captain taps one of them
/// or cancels.
class _ShipTab extends ConsumerStatefulWidget {
  const _ShipTab({required this.brawl});
  final BrawlState brawl;

  @override
  ConsumerState<_ShipTab> createState() => _ShipTabState();
}

class _ShipTabState extends ConsumerState<_ShipTab> {
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
    _report(context, ref.read(brawlProvider.notifier).use(using, spot));
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
      _report(context, ref.read(brawlProvider.notifier).arrange(from, to));

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
                      _report(
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

class _GameOver extends ConsumerWidget {
  const _GameOver({required this.brawl});
  final BrawlState brawl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Ship lost', style: text.displaySmall),
                const SizedBox(height: 8),
                Text(
                  'You survived ${brawl.fightsWon} '
                  '${brawl.fightsWon == 1 ? 'fight' : 'fights'} and died '
                  'with ${brawl.credits} credits.',
                  textAlign: TextAlign.center,
                  style: text.bodyLarge,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () =>
                      ref.read(brawlProvider.notifier).start(brawl.species),
                  icon: const Icon(Icons.replay),
                  label: Text('Brawl again as ${brawl.species.name}'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    ref.read(brawlProvider.notifier).abandon();
                    context.go('/');
                  },
                  child: const Text('Back to the title'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
