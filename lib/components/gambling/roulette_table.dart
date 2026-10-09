import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../functions/roulette_motion.dart';
import '../../game_engine/gambling/roulette.dart';
import '../../providers/brawl_provider.dart';
import '../dialogs.dart';
import '../theme.dart';
import 'roulette_wheel.dart';

/// A roulette table. The engine decides the number the moment the captain
/// spins; the wheel then plays it out, and the ball always lands where the
/// engine said.
class RouletteTable extends ConsumerStatefulWidget {
  const RouletteTable({super.key});

  @override
  ConsumerState<RouletteTable> createState() => _RouletteTableState();
}

class _RouletteTableState extends ConsumerState<RouletteTable>
    with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 7000),
  )..addStatusListener(_onStatus);

  BetKind _kind = BetKind.red;
  int _number = 17;
  int _stake = rouletteStakes.first;

  /// Credits as shown: held at the pre-spin amount until the ball lands.
  int? _heldCredits;

  /// The spin being played, and the wheel and ball where it started.
  RouletteSpin? _shown;
  double _wheelFrom = 0;
  double _ballFrom = 0;

  bool get _spinning => _spin.isAnimating;

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() => _heldCredits = null);
    }
  }

  RouletteBet _bet(int stake) =>
      RouletteBet(_kind, stake, number: _kind == BetKind.number ? _number : 0);

  /// The all-in button's words: "Put it all on red!", "Put it all on 8!".
  String get _allInLabel =>
      'Put it all on ${switch (_kind) {
        BetKind.number when _number == 0 => 'zero',
        BetKind.number => '$_number',
        final colour => colour.label.toLowerCase(),
      }}!';

  void _go({bool allIn = false}) {
    final before = ref.read(brawlProvider)!;
    final bet = _bet(allIn ? before.credits : _stake);
    final error = ref.read(brawlProvider.notifier).spinRoulette(bet);
    if (error != null) return showError(context, error);
    final now = RouletteMotion.at(_shown, _wheelFrom, _ballFrom, _spin.value);
    setState(() {
      _heldCredits = before.credits;
      _wheelFrom = now.wheel;
      _ballFrom = now.ball - now.wheel;
      _shown = ref.read(brawlProvider)!.lastSpin;
    });
    _spin.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final brawl = ref.watch(brawlProvider);
    if (brawl == null) return const Scaffold();
    final text = Theme.of(context).textTheme;
    final credits = _heldCredits ?? brawl.credits;
    final spin = _shown;
    final landed = spin != null && !_spinning;
    return Scaffold(
      appBar: AppBar(
        title: Text('${brawl.stationName} · Roulette'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('$credits cr', style: text.titleMedium),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: AnimatedBuilder(
                    animation: _spin,
                    builder: (context, _) {
                      final m = RouletteMotion.at(
                        spin,
                        _wheelFrom,
                        _ballFrom,
                        _spin.value,
                      );
                      return CustomPaint(
                        painter: RouletteWheelPainter(
                          wheel: m.wheel,
                          ball: spin == null ? null : m.ball,
                          ballRadius: m.radius,
                          highlight: landed ? spin.result : null,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 72,
              child: Center(
                child: landed
                    ? _Result(spin: spin)
                    : Text(
                        _spinning ? 'No more bets…' : 'Place your bet',
                        style: text.titleMedium?.copyWith(color: Palette.muted),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            _BetPicker(
              kind: _kind,
              number: _number,
              enabled: !_spinning,
              onKind: (k) => setState(() => _kind = k),
              onNumber: (n) => setState(() {
                _kind = BetKind.number;
                _number = n;
              }),
            ),
            const SizedBox(height: 16),
            Text('Stake', style: text.titleSmall),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final s in rouletteStakes) ...[
                  ChoiceChip(
                    label: Text('$s cr'),
                    selected: _stake == s,
                    onSelected: _spinning || s > credits
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
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: _spinning || credits <= 0
                        ? null
                        : () => _go(allIn: true),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _allInLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: _spinning || _stake > credits ? null : () => _go(),
              icon: const Icon(Icons.casino),
              label: Text(
                'Spin: $_stake cr on ${_bet(_stake).label} '
                '(pays ${_kind.odds} to 1)',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.spin});
  final RouletteSpin spin;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final n = spin.result;
    final colour = n == 0 ? 'Green' : (isRed(n) ? 'Red' : 'Black');
    final won = spin.payout > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$n $colour', style: text.headlineSmall),
        Text(
          won ? 'You win ${spin.net} cr!' : 'You lose ${spin.bet.stake} cr.',
          style: text.titleMedium?.copyWith(
            color: won ? Palette.codeGreen : Palette.hell,
          ),
        ),
      ],
    );
  }
}

/// Red, black, zero, or one number from a table laid out like the felt.
class _BetPicker extends StatelessWidget {
  const _BetPicker({
    required this.kind,
    required this.number,
    required this.enabled,
    required this.onKind,
    required this.onNumber,
  });

  final BetKind kind;
  final int number;
  final bool enabled;
  final ValueChanged<BetKind> onKind;
  final ValueChanged<int> onNumber;

  @override
  Widget build(BuildContext context) {
    bool picked(int n) => kind == BetKind.number && number == n;
    Widget cell(int n, {double? height}) => Padding(
      padding: const EdgeInsets.all(1.5),
      child: Material(
        color: pocketColour(n),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(
            color: picked(n) ? Colors.amberAccent : Colors.white24,
            width: picked(n) ? 2.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: enabled ? () => onNumber(n) : null,
          child: SizedBox(
            height: height ?? 34,
            child: Center(
              child: Text(
                '$n',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Widget colourBet(BetKind k, Color colour) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: Material(
          color: colour,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(
              color: kind == k ? Colors.amberAccent : Colors.white24,
              width: kind == k ? 2.5 : 1,
            ),
          ),
          child: InkWell(
            onTap: enabled ? () => onKind(k) : null,
            child: SizedBox(
              height: 40,
              child: Center(
                child: Text(
                  '${k.label} · pays 1 to 1',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 34, child: cell(0, height: 3 * 34 + 6)),
              Expanded(
                child: Column(
                  children: [
                    for (final row in [3, 2, 1])
                      Row(
                        children: [
                          for (var col = 0; col < 12; col++)
                            Expanded(child: cell(col * 3 + row)),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              colourBet(BetKind.red, rouletteRed),
              colourBet(BetKind.black, rouletteBlack),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a number (0 for zero) to bet on it: pays 35 to 1.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Palette.muted),
          ),
        ],
      ),
    );
  }
}
