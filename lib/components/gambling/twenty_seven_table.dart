import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game_engine/brawl/brawl.dart';
import '../../game_engine/gambling/twenty_seven.dart';
import '../../providers/brawl_provider.dart';
import '../dialogs.dart';
import '../theme.dart';
import 'twenty_seven_colours.dart';
import 'twenty_seven_count.dart';
import 'twenty_seven_pool.dart';
import 'twenty_seven_tile.dart';
import 'twenty_seven_track.dart';

/// 27, the Ál counting game, played in a shallow pool. See
/// `lib/game_engine/gambling/twenty_seven.dart` for the rules.
///
/// Everything here is presentation: the engine has already decided what
/// each tile is. Picking a face-down tile flips it over first, so the
/// captain sees what they got before the count moves.
class TwentySevenTable extends ConsumerStatefulWidget {
  const TwentySevenTable({super.key});

  @override
  ConsumerState<TwentySevenTable> createState() => _TwentySevenTableState();
}

class _TwentySevenTableState extends ConsumerState<TwentySevenTable>
    with TickerProviderStateMixin {
  int _stake = twentySevenStakes.first;

  /// The pool: a slow loop that drives the gradient, caustics and ripples.
  late final _water = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  /// A tile being picked: flipping over if it was face down, lifting if not.
  late final _pick = AnimationController(vsync: this);
  int? _picking;

  late final _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  late final _bubbles = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void dispose() {
    _water.dispose();
    _pick.dispose();
    _shake.dispose();
    _bubbles.dispose();
    super.dispose();
  }

  void _report(String? error) {
    if (error != null) showError(context, error);
  }

  Future<void> _take(int index) async {
    if (_picking != null) return;
    final faceDown = index != 0;
    setState(() => _picking = index);
    _pick.duration = Duration(milliseconds: faceDown ? 900 : 320);
    await _pick.forward(from: 0);
    if (!mounted) return;
    _report(ref.read(brawlProvider.notifier).takeTile(index));
    setState(() => _picking = null);
  }

  /// Plays an effect when a count ends or reaches a holy number.
  void _react(BrawlState? before, BrawlState? after) {
    final was = before?.twentySeven?.status;
    final now = after?.twentySeven?.status;
    if (now == was) return;
    switch (now) {
      case CountStatus.bust:
        _shake.forward(from: 0);
      case CountStatus.won || CountStatus.walked || CountStatus.holy:
        _bubbles.forward(from: 0);
      default:
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<BrawlState?>(brawlProvider, _react);
    final brawl = ref.watch(brawlProvider);
    if (brawl == null) return const Scaffold();
    final controller = ref.read(brawlProvider.notifier);
    final text = Theme.of(context).textTheme;
    final game = brawl.twentySeven;
    final playing = game != null && !game.over;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: SeaColours.deep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('${brawl.stationName} · 27'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, a) =>
                    ScaleTransition(scale: a, child: child),
                child: Text(
                  '${brawl.credits} cr',
                  key: ValueKey(brawl.credits),
                  style: text.titleMedium,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(child: SeaPool(water: _water)),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CountStone(
                    child: Text(
                      'Take one tile from each triad and add it to the count. '
                      'Bust on one over a multiple of three, or past 27. On 9 '
                      'you may walk away with 1.5× your stake. Reach 27 for '
                      '4.5×.',
                      style: text.bodySmall?.copyWith(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AnimatedBuilder(
                    animation: _shake,
                    builder: (context, child) {
                      final t = _shake.value;
                      return Transform.translate(
                        offset: Offset(sin(t * pi * 7) * 10 * (1 - t), 0),
                        child: child,
                      );
                    },
                    child: CountPanel(game: game),
                  ),
                ),
                const SizedBox(height: 12),
                CountTrack(count: game?.count ?? 0, water: _water),
                const SizedBox(height: 20),
                if (game case final g? when g.status == CountStatus.counting)
                  ..._triad(g, text),
                if (game case final g? when g.status == CountStatus.holy)
                  ..._holyChoice(g, controller),
                if (game?.lastTriad case final last?) ...[
                  const SizedBox(height: 20),
                  const CountLabel('Last triad'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (var i = 0; i < 3; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            child: CountTile(
                              value: last[i],
                              water: _water,
                              picked: i == game!.lastPick,
                              small: true,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (!playing) ..._betting(brawl, controller),
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: PoolBubbles(
                animation: _bubbles,
                golden: game?.status == CountStatus.won,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _triad(TwentySeven g, TextTheme text) => [
    const CountLabel('Take a tile'),
    const SizedBox(height: 8),
    // Each new triad drops into the pool, one tile after another.
    Row(
      key: ValueKey('${g.count}/${g.deck.length}'),
      children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 520 + i * 140),
                curve: Interval(i * 0.2, 1, curve: Curves.easeOutBack),
                builder: (context, v, child) => Opacity(
                  opacity: v.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, -36 * (1 - v)),
                    child: Transform.scale(
                      scale: 0.85 + 0.15 * v,
                      child: child,
                    ),
                  ),
                ),
                child: AnimatedBuilder(
                  animation: _pick,
                  builder: (context, _) {
                    final picking = _picking == i;
                    final faceDown = i != 0;
                    final p = picking ? _pick.value : 0.0;
                    // Face down: flip over, then hold a moment. Face up:
                    // lift out of the water.
                    final flip = faceDown
                        ? Curves.easeInOut.transform((p / 0.6).clamp(0.0, 1.0))
                        : 0.0;
                    final lift = faceDown ? 0.0 : Curves.easeOut.transform(p);
                    return CountTile(
                      value: g.triad[i],
                      water: _water,
                      faceDown: faceDown,
                      flip: flip,
                      lift: lift,
                      dimmed: _picking != null && !picking,
                      onTap: _picking == null ? () => _take(i) : null,
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    ),
  ];

  List<Widget> _holyChoice(TwentySeven g, BrawlController controller) => [
    FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: SeaColours.gold,
        foregroundColor: Colors.black,
      ),
      onPressed: () => _report(controller.walkAway()),
      icon: const Icon(Icons.savings_outlined),
      label: Text('Walk away with ${walkPayout(g.stake)} cr'),
    ),
    const SizedBox(height: 8),
    OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: SeaColours.foam,
        side: const BorderSide(color: SeaColours.foam),
        backgroundColor: Colors.black26,
      ),
      onPressed: () => _report(controller.keepCounting()),
      icon: const Icon(Icons.trending_up),
      label: Text('Keep counting for 27 (${goalPayout(g.stake)} cr)'),
    ),
  ];

  List<Widget> _betting(BrawlState brawl, BrawlController controller) => [
    const SizedBox(height: 12),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CountStone(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stake',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final s in twentySevenStakes) ...[
                  ChoiceChip(
                    label: Text('$s cr'),
                    selected: _stake == s,
                    onSelected: s > brawl.credits
                        ? null
                        : (_) => setState(() => _stake = s),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Palette.hell,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: brawl.credits <= 0
                        ? null
                        : () => _report(
                            controller.dealTwentySeven(brawl.credits),
                          ),
                    child: const Text(
                      'Count it all!',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: SeaColours.aqua,
                foregroundColor: SeaColours.deep,
              ),
              onPressed: _stake > brawl.credits
                  ? null
                  : () => _report(controller.dealTwentySeven(_stake)),
              icon: const Icon(Icons.change_history),
              label: Text(
                'Deal: $_stake cr',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    ),
  ];
}
