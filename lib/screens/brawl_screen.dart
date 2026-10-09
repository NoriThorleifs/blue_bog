import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/brawl/brawl_buy_tab.dart';
import '../components/brawl/brawl_event_tab.dart';
import '../components/brawl/brawl_game_over.dart';
import '../components/brawl/brawl_launch_bar.dart';
import '../components/brawl/brawl_sell_tab.dart';
import '../components/brawl/brawl_ship_tab.dart';
import '../components/brawl/brawl_victory.dart';
import '../components/brawl/brawl_wreckage.dart';
import '../components/dialogs.dart';
import '../components/theme.dart';
import '../game_engine/brawl/brawl.dart';
import '../providers/brawl_provider.dart';

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
    if (error != null) return reportError(context, error);
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
    if (brawl.lost || brawl.retired) return GameOver(brawl: brawl);
    if (brawl.awaitingVerdict) return Victory(brawl: brawl);
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
                    : 'Fight ${brawl.round}${brawl.endless ? ' · endless' : ''}'
                          ' · $hull',
                style: text.labelMedium?.copyWith(color: Palette.muted),
              ),
            ],
          ),
          actions: [
            Center(child: Text('${brawl.credits} cr', style: text.titleMedium)),
            PopupMenuButton<void>(
              itemBuilder: (context) => [
                PopupMenuItem(
                  onTap: () => context.push('/guide'),
                  child: const Text('How to play'),
                ),
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
            ? LaunchBar(
                brawl: brawl,
                onLaunch: () => reportError(
                  context,
                  ref.read(brawlProvider.notifier).launch(),
                ),
              )
            : null,
        body: SafeArea(
          child: Column(
            children: [
              if (brawl.wreckage.isNotEmpty) WreckageBar(brawl: brawl),
              Expanded(
                child: TabBarView(
                  children: [
                    if (docked) ...[
                      BuyTab(brawl: brawl),
                      SellTab(brawl: brawl),
                    ] else
                      EventTab(brawl: brawl, onProceed: _proceed),
                    ShipTab(brawl: brawl),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
