import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/brawl_controller.dart';
import '../../app/theme.dart';
import '../../game/brawl/brawl.dart';
import '../../game/gambling/roulette.dart';
import '../deck/deck_screen.dart' show showError;
import 'twenty_seven_screen.dart';

/// The station's gambling den: whichever game the locals play.
class GamblingScreen extends ConsumerWidget {
  const GamblingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brawl = ref.watch(brawlProvider);
    if (brawl == null) return const Scaffold();
    return switch (brawl.gamblingGame) {
      GamblingGame.roulette => const RouletteScreen(),
      GamblingGame.al => const TwentySevenScreen(),
      final game => _ComingSoon(game: game, station: brawl.stationName),
    };
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.game, required this.station});
  final GamblingGame game;
  final String station;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('$station · ${game.label}')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.casino_outlined, size: 64, color: Palette.muted),
              const SizedBox(height: 16),
              Text(game.label, style: text.headlineSmall),
              const SizedBox(height: 8),
              Text(
                switch (game) {
                  GamblingGame.gor =>
                    'The Gor are still arguing about the rules. Loudly. '
                        'Come back later.',
                  GamblingGame.al => '',
                  GamblingGame.roulette => '',
                },
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(color: Palette.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A roulette table. The engine decides the number the moment the captain
/// spins; the wheel then plays it out, and the ball always lands where the
/// engine said.
class RouletteScreen extends ConsumerStatefulWidget {
  const RouletteScreen({super.key});

  @override
  ConsumerState<RouletteScreen> createState() => _RouletteScreenState();
}

class _RouletteScreenState extends ConsumerState<RouletteScreen>
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
                        painter: _WheelPainter(
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
        color: _pocketColour(n),
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
              colourBet(BetKind.red, _red),
              colourBet(BetKind.black, _black),
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

const _red = Color(0xFFC62828);
const _black = Color(0xFF1C1C22);
const _green = Color(0xFF2E7D32);

Color _pocketColour(int n) => n == 0 ? _green : (isRed(n) ? _red : _black);

/// The angle each pocket takes up on the wheel.
const pocketAngle = 2 * pi / 37;

/// Where the wheel and ball are at time [t] (0 to 1) of a spin.
///
/// Angles are clockwise from the top. The wheel spins clockwise, slowing
/// down. The ball runs the other way around the rim, relative to the wheel,
/// slows, drops toward the pockets, and locks into the result's pocket at
/// [_lock], from then on turning with the wheel. Working the ball's
/// position relative to the wheel backwards from the result is what makes
/// the animation always agree with the engine.
class RouletteMotion {
  const RouletteMotion(this.wheel, this.ball, this.radius);
  final double wheel;
  final double ball;

  /// Ball distance from the centre, as a fraction of the wheel's radius.
  final double radius;

  static const _lock = 0.8;
  static const _wheelTurns = 2.5;
  static const _ballLaps = 4;
  static const _rimRadius = 0.86;
  static const _pocketRadius = 0.69;

  static RouletteMotion at(
    RouletteSpin? spin,
    double wheelFrom,
    double ballFrom,
    double t,
  ) {
    final wheel =
        wheelFrom + _wheelTurns * 2 * pi * Curves.easeOutCubic.transform(t);
    if (spin == null) return RouletteMotion(wheel, wheel, _rimRadius);
    final target = pocketOf(spin.result) * pocketAngle;
    // How far the ball must travel relative to the wheel: backwards, a few
    // laps, ending exactly on the target pocket.
    var travel = (target - ballFrom) % (2 * pi);
    if (travel > 0) travel -= 2 * pi;
    travel -= _ballLaps * 2 * pi;
    final u = (t / _lock).clamp(0.0, 1.0);
    final relative = ballFrom + travel * Curves.easeOutQuad.transform(u);
    // Rolling on the rim, then dropping in with a couple of bounces.
    final drop = Curves.easeIn.transform(((u - 0.55) / 0.45).clamp(0.0, 1.0));
    final bounce = u < 1 ? 0.035 * sin(drop * pi * 3).abs() * (1 - drop) : 0.0;
    final radius = _rimRadius + (_pocketRadius - _rimRadius) * drop + bounce;
    return RouletteMotion(wheel, wheel + relative, radius);
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({
    required this.wheel,
    required this.ball,
    required this.ballRadius,
    required this.highlight,
  });

  final double wheel;
  final double? ball;
  final double ballRadius;
  final int? highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    Offset polar(double angle, double radius) =>
        c + Offset(sin(angle), -cos(angle)) * radius;

    // Bowl and ball track, which don't turn.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0xFF6D4C2F), Color(0xFF3B2716)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(c, r * 0.93, Paint()..color = const Color(0xFF241810));
    canvas.drawCircle(
      c,
      r * 0.93,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.012
        ..color = const Color(0xFFD9B26B),
    );

    // The turning wheel: pockets, numbers, frets, hub.
    final outer = r * 0.79;
    final inner = r * 0.56;
    for (var i = 0; i < wheelOrder.length; i++) {
      final n = wheelOrder[i];
      final start = wheel + (i - 0.5) * pocketAngle - pi / 2;
      final path = Path()
        ..arcTo(
          Rect.fromCircle(center: c, radius: outer),
          start,
          pocketAngle,
          true,
        )
        ..arcTo(
          Rect.fromCircle(center: c, radius: inner),
          start + pocketAngle,
          -pocketAngle,
          false,
        )
        ..close();
      canvas.drawPath(path, Paint()..color = _pocketColour(n));
      if (n == highlight) {
        canvas.drawPath(
          path,
          Paint()..color = Colors.amberAccent.withValues(alpha: 0.45),
        );
      }
      canvas.drawLine(
        polar(wheel + (i - 0.5) * pocketAngle, inner),
        polar(wheel + (i - 0.5) * pocketAngle, outer),
        Paint()
          ..color = const Color(0xFFD9B26B)
          ..strokeWidth = r * 0.008,
      );
      final label = TextPainter(
        text: TextSpan(
          text: '$n',
          style: TextStyle(
            color: Colors.white,
            fontSize: r * 0.065,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final angle = wheel + i * pocketAngle;
      canvas
        ..save()
        ..translate(polar(angle, r * 0.735).dx, polar(angle, r * 0.735).dy)
        ..rotate(angle)
        ..translate(-label.width / 2, -label.height / 2);
      label.paint(canvas, Offset.zero);
      canvas.restore();
    }
    for (final rr in [outer, inner]) {
      canvas.drawCircle(
        c,
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.012
          ..color = const Color(0xFFD9B26B),
      );
    }
    canvas.drawCircle(
      c,
      inner,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0xFF8A6238), Color(0xFF4A321C)],
        ).createShader(Rect.fromCircle(center: c, radius: inner)),
    );
    final spoke = Paint()
      ..color = const Color(0xFFE8C77E)
      ..strokeWidth = r * 0.03
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 4; k++) {
      final a = wheel + k * pi / 2;
      canvas.drawLine(polar(a, r * 0.08), polar(a, r * 0.42), spoke);
      canvas.drawCircle(
        polar(a, r * 0.42),
        r * 0.035,
        Paint()..color = spoke.color,
      );
    }
    canvas.drawCircle(c, r * 0.1, Paint()..color = const Color(0xFFE8C77E));

    // The ball.
    if (ball case final angle?) {
      final at = polar(angle, r * ballRadius);
      canvas.drawCircle(
        at + Offset(r * 0.01, r * 0.012),
        r * 0.035,
        Paint()..color = Colors.black45,
      );
      canvas.drawCircle(
        at,
        r * 0.035,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.4),
            colors: const [Colors.white, Color(0xFFB8B8B8)],
          ).createShader(Rect.fromCircle(center: at, radius: r * 0.035)),
      );
    }
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.wheel != wheel ||
      old.ball != ball ||
      old.ballRadius != ballRadius ||
      old.highlight != highlight;
}
