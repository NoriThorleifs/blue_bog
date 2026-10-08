import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/brawl_controller.dart';
import '../../app/theme.dart';
import '../../game/brawl/brawl.dart';
import '../../game/gambling/twenty_seven.dart';
import '../../three-thirds/ternary_number_translator.dart';
import '../deck/deck_screen.dart' show showError;

const _gold = Color(0xFFFFC84A);
const _bust = Color(0xFFFF5A5F);
const _aqua = Color(0xFF2EC4C6);
const _deep = Color(0xFF061833);
const _foam = Color(0xFFBFF6F2);

/// 27, the Ál counting game, played in a shallow pool. See
/// `lib/game/gambling/twenty_seven.dart` for the rules.
///
/// Everything here is presentation: the engine has already decided what
/// each tile is. Picking a face-down tile flips it over first, so the
/// captain sees what they got before the count moves.
class TwentySevenScreen extends ConsumerStatefulWidget {
  const TwentySevenScreen({super.key});

  @override
  ConsumerState<TwentySevenScreen> createState() => _TwentySevenScreenState();
}

class _TwentySevenScreenState extends ConsumerState<TwentySevenScreen>
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
      backgroundColor: _deep,
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
          Positioned.fill(child: _Pool(water: _water)),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _Glass(
                  child: Text(
                    'Take one tile from each triad and add it to the count. '
                    'Bust on one over a multiple of three, or past 27. On 9 '
                    'you may walk away with 1.5× your stake. Reach 27 for '
                    '4.5×.',
                    style: text.bodySmall?.copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: _shake,
                  builder: (context, child) {
                    final t = _shake.value;
                    return Transform.translate(
                      offset: Offset(sin(t * pi * 7) * 10 * (1 - t), 0),
                      child: child,
                    );
                  },
                  child: _CountPanel(game: game),
                ),
                const SizedBox(height: 12),
                _Glass(
                  padding: 6,
                  child: _Track(count: game?.count ?? 0, water: _water),
                ),
                const SizedBox(height: 20),
                if (game case final g? when g.status == CountStatus.counting)
                  ..._triad(g, text),
                if (game case final g? when g.status == CountStatus.holy)
                  ..._holyChoice(g, controller),
                if (game?.lastTriad case final last?) ...[
                  const SizedBox(height: 20),
                  const _Label('Last triad'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (var i = 0; i < 3; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            child: _Tile(
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
              child: _Bubbles(
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
    const _Label('Take a tile'),
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
                    return _Tile(
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
        backgroundColor: _gold,
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
        foregroundColor: _foam,
        side: const BorderSide(color: _foam),
        backgroundColor: Colors.black26,
      ),
      onPressed: () => _report(controller.keepCounting()),
      icon: const Icon(Icons.trending_up),
      label: Text('Keep counting for 27 (${goalPayout(g.stake)} cr)'),
    ),
  ];

  List<Widget> _betting(BrawlState brawl, BrawlController controller) => [
    const SizedBox(height: 12),
    _Glass(
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
                      : () =>
                            _report(controller.dealTwentySeven(brawl.credits)),
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
              backgroundColor: _aqua,
              foregroundColor: _deep,
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
  ];
}

/// The pool: an aqua and deep-blue gradient that slowly drifts, with
/// caustic light playing over the floor.
class _Pool extends StatelessWidget {
  const _Pool({required this.water});
  final Animation<double> water;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: water,
    builder: (context, _) {
      final a = water.value * 2 * pi;
      final shimmer = 0.5 + 0.5 * sin(a);
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(cos(a) * 0.8, -1),
            end: Alignment(-cos(a) * 0.8, 1),
            colors: [
              _deep,
              Color.lerp(const Color(0xFF0B4F6C), _aqua, shimmer * 0.6)!,
              Color.lerp(_aqua, const Color(0xFF0B3A5C), shimmer)!,
              _deep,
            ],
            stops: const [0, 0.4, 0.7, 1],
          ),
        ),
        child: CustomPaint(painter: _CausticsPainter(water.value)),
      );
    },
  );
}

class _CausticsPainter extends CustomPainter {
  _CausticsPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..blendMode = BlendMode.plus
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    final a = t * 2 * pi;
    for (var k = 0; k < 14; k++) {
      final y0 = size.height * (k + 0.5) / 14;
      final path = Path()..moveTo(0, y0);
      for (var x = 0.0; x <= size.width; x += 12) {
        final y =
            y0 +
            sin(x / 53 + a * 2 + k) * 9 +
            sin(x / 23 - a * 3 + k * 1.7) * 4;
        path.lineTo(x, y);
      }
      paint.color = _foam.withValues(alpha: 0.05 + 0.04 * sin(a + k).abs());
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_CausticsPainter old) => old.t != t;
}

/// The count in ternary words, as the dealer calls it.
class _CountPanel extends StatelessWidget {
  const _CountPanel({required this.game});
  final TwentySeven? game;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final g = game;
    final count = g?.count ?? 0;
    final (colour, verdict) = switch (g?.status) {
      null => (_foam, 'Place your stake'),
      CountStatus.counting => (_aqua, 'Counting… stake ${g!.stake} cr'),
      CountStatus.holy => (_gold, 'Holy 2! Walk away or keep counting?'),
      CountStatus.bust when count > holyGoal => (
        _bust,
        'Past 27. You lose ${g!.stake} cr.',
      ),
      CountStatus.bust => (_bust, 'Bust! You lose ${g!.stake} cr.'),
      CountStatus.walked => (_gold, 'You walk away with ${g!.payout} cr.'),
      CountStatus.won => (_gold, 'TWENTY-SEVEN! You win ${g!.payout} cr!'),
    };
    final glowing = colour != _aqua && colour != _foam;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: colour),
      duration: const Duration(milliseconds: 400),
      builder: (context, c, _) => ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color.lerp(Colors.black, c, 0.12)!.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c!.withValues(alpha: 0.8), width: 1.5),
              boxShadow: [
                if (glowing)
                  BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 24),
              ],
            ),
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.7, end: 1.0).animate(
                        CurvedAnimation(parent: a, curve: Curves.easeOutBack),
                      ),
                      child: child,
                    ),
                  ),
                  child: Column(
                    key: ValueKey(count),
                    children: [
                      Text(
                        intToTernaryString(count),
                        textAlign: TextAlign.center,
                        style: text.headlineSmall?.copyWith(
                          color: c,
                          shadows: [
                            if (glowing) Shadow(color: c, blurRadius: 16),
                          ],
                        ),
                      ),
                      Text('$count', style: text.titleMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  verdict,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A dark frosted-glass panel, so text stays readable over the water.
class _Glass extends StatelessWidget {
  const _Glass({required this.child, this.padding = 12});
  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: const Color(0xFF020B18).withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _foam.withValues(alpha: 0.18)),
        ),
        child: child,
      ),
    ),
  );
}

/// A heading that sits straight on the water.
class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.titleMedium?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      shadows: const [
        Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(0, 1)),
      ],
    ),
  );
}

/// The board, 0 to 27, winding upward: 0 to 13 along the bottom row, then
/// 14 to 27 back along the top. A black Ál tentacle reaches in from the
/// pool and covers every number already passed, its tip on the count.
class _Track extends StatelessWidget {
  const _Track({required this.count, required this.water});
  final int count;
  final Animation<double> water;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final geometry = _Board(box.maxWidth);
      return TweenAnimationBuilder<double>(
        tween: Tween(end: count.toDouble()),
        duration: const Duration(milliseconds: 750),
        curve: Curves.easeInOutCubic,
        builder: (context, reach, _) => AnimatedBuilder(
          animation: water,
          builder: (context, _) => CustomPaint(
            size: Size(box.maxWidth, geometry.height),
            painter: _TrackPainter(geometry, reach, water.value),
          ),
        ),
      );
    },
  );
}

/// Where everything on the board sits, in pixels.
class _Board {
  _Board(this.width) : pitch = width / (_columns + _leftMargin + _rightMargin);

  static const _columns = 14;

  /// Room on the left for the tentacle to come out of the pool, and on
  /// the right for it to curl up between the rows.
  static const _leftMargin = 1.3;
  static const _rightMargin = 0.9;

  /// Length of the curl between the rows, in cells.
  static const turn = 1.6;

  final double width;
  final double pitch;

  double get cell => pitch * 0.86;
  double get height => pitch * 2 + pitch * 0.5;
  double get topY => pitch * 0.5;
  double get bottomY => pitch * 0.5 + pitch * 1.5;
  double get left => pitch * _leftMargin;
  double get right => left + pitch * _columns;

  /// Centre of the cell for number [n].
  Offset centre(int n) => n < _columns
      ? Offset(left + (n + 0.5) * pitch, bottomY)
      : Offset(left + (2 * _columns - n - 0.5) * pitch, topY);

  /// Distance along the tentacle's route, in cells, where the cell for
  /// [count] starts. Fractions slide smoothly round the curl.
  double routeAt(double count) {
    if (count <= _columns - 1) return count;
    if (count >= _columns) return count + turn;
    return _columns - 1 + (count - (_columns - 1)) * (1 + turn);
  }

  /// A point on the route: out of the pool on the left, along the bottom,
  /// round the curl on the right, and back along the top.
  Offset at(double u) {
    if (u <= _columns) return Offset(left + u * pitch, bottomY);
    if (u <= _columns + turn) {
      final a = (u - _columns) / turn * pi;
      final r = (bottomY - topY) / 2;
      return Offset(
        right + sin(a) * r * 0.75,
        (topY + bottomY) / 2 + cos(a) * r,
      );
    }
    return Offset(right - (u - _columns - turn) * pitch, topY);
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter(this.board, this.reach, this.wave);
  final _Board board;
  final double reach;
  final double wave;

  @override
  void paint(Canvas canvas, Size size) {
    for (var n = 0; n <= holyGoal; n++) {
      _cell(canvas, n);
    }
    _tentacle(canvas);
  }

  void _cell(Canvas canvas, int n) {
    final colour = n == holyStop || n == holyGoal
        ? _gold
        : busts(n)
        ? _bust
        : _foam;
    final rect = Rect.fromCenter(
      center: board.centre(n),
      width: board.cell,
      height: board.cell,
    );
    final r = RRect.fromRectAndRadius(rect, Radius.circular(board.cell * 0.2));
    canvas
      ..drawRRect(r, Paint()..color = const Color(0xFF041426))
      ..drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = colour.withValues(alpha: 0.75),
      );
    final label = TextPainter(
      text: TextSpan(
        text: '$n',
        style: TextStyle(
          fontSize: board.cell * 0.42,
          fontWeight: FontWeight.w700,
          color: colour == _foam ? Colors.white : colour,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(
      canvas,
      rect.center - Offset(label.width / 2, label.height / 2),
    );
  }

  /// A smooth, glossy black tentacle. No suckers: Ál tentacles don't have
  /// them.
  void _tentacle(Canvas canvas) {
    final tip = board.routeAt(reach);
    const start = -1.3;
    final length = tip - start;
    final step = 0.06;
    final phase = wave * 2 * pi * 6;
    final thick = board.cell * 1.08;
    final spine = <Offset>[];
    final widths = <double>[];
    for (var u = start; u <= tip + 1e-9; u += step) {
      final along = (u - start) / max(length, 0.001);
      // Thick where it leaves the pool, tapering to a rounded tip.
      final taper = (1 - pow(along, 2.2) * 0.45).toDouble();
      final point = (tip - u) < 0.7 ? sqrt(max(0, (tip - u) / 0.7)) : 1.0;
      widths.add(thick * taper * point);
      spine.add(board.at(u));
    }
    if (spine.length < 2) return;
    // Wriggle: a travelling wave, stronger toward the tip.
    final left = <Offset>[];
    final right = <Offset>[];
    final mid = <Offset>[];
    for (var i = 0; i < spine.length; i++) {
      final a = spine[max(0, i - 1)];
      final b = spine[min(spine.length - 1, i + 1)];
      final d = b - a;
      final len = d.distance == 0 ? 1.0 : d.distance;
      final normal = Offset(-d.dy / len, d.dx / len);
      final along = i / (spine.length - 1);
      final sway =
          sin(i * step * 1.6 - phase) * board.cell * 0.12 * (0.2 + along);
      final c = spine[i] + normal * sway;
      mid.add(c);
      left.add(c + normal * widths[i] / 2);
      right.add(c - normal * widths[i] / 2);
    }
    final body = Path()..addPolygon([...left, ...right.reversed], true);
    canvas
      ..drawPath(
        body.shift(Offset(board.cell * 0.12, board.cell * 0.22)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.55)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, board.cell * 0.2),
      )
      ..drawPath(
        body,
        Paint()
          ..shader = LinearGradient(
            colors: const [Color(0xFF020306), Color(0xFF10141C)],
          ).createShader(body.getBounds()),
      );
    // A wet sheen along its back.
    final sheen = Path();
    for (var i = 0; i < mid.length; i++) {
      final p = Offset.lerp(mid[i], left[i], 0.55)!;
      i == 0 ? sheen.moveTo(p.dx, p.dy) : sheen.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      sheen,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = board.cell * 0.09
        ..color = const Color(0xFF7FA6B8).withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, board.cell * 0.05),
    );
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.reach != reach || old.wave != wave || old.board.width != board.width;
}

/// A triangular tile standing in shallow water. [flip] turns it over
/// (0 to 1); [lift] raises it out of the water.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.value,
    required this.water,
    this.faceDown = false,
    this.flip = 0,
    this.lift = 0,
    this.picked = false,
    this.dimmed = false,
    this.small = false,
    this.onTap,
  });

  final int value;
  final Animation<double> water;
  final bool faceDown;
  final double flip;
  final double lift;
  final bool picked;
  final bool dimmed;
  final bool small;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final angle = flip * pi;
    // Past halfway through the flip, the front is the side facing us.
    final showFront = !faceDown || angle > pi / 2;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: dimmed ? 0.45 : 1,
        child: AspectRatio(
          aspectRatio: 1.1,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0018)
              ..translateByDouble(0, -14 * lift, 0, 1)
              ..rotateY(angle)
              ..scaleByDouble(angle > pi / 2 ? -1 : 1, 1, 1, 1),
            child: AnimatedBuilder(
              animation: water,
              builder: (context, _) => CustomPaint(
                painter: _TilePainter(
                  value: value,
                  faceUp: showFront,
                  picked: picked,
                  ripple: water.value,
                  lift: lift + sin(flip * pi) * 0.6,
                  label: !small,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TilePainter extends CustomPainter {
  _TilePainter({
    required this.value,
    required this.faceUp,
    required this.picked,
    required this.ripple,
    required this.lift,
    required this.label,
  });

  final int value;
  final bool faceUp;
  final bool picked;
  final double ripple;
  final double lift;
  final bool label;

  Path _tri(Size s, Offset shift, {double grow = 0}) {
    final c = Offset(s.width / 2, s.height * 0.6) + shift;
    Offset p(double x, double y) => Offset(
      c.dx + (x - s.width / 2) * (1 + grow),
      c.dy + (y - s.height * 0.6) * (1 + grow),
    );
    return Path()..addPolygon([
      p(s.width / 2, s.height * 0.06),
      p(s.width * 0.05, s.height * 0.86),
      p(s.width * 0.95, s.height * 0.86),
    ], true);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final thick = h * 0.1;
    // The water is a little shallower than the tile is thick, so the top
    // face stays dry and a sliver of the side shows above the surface.
    final waterline = thick * 0.28;
    final colour = switch (value) {
      1 => const Color(0xFF5E7CE2),
      2 => const Color(0xFF9B6BD6),
      _ => const Color(0xFF2FB39F),
    };
    final face = faceUp
        ? Color.lerp(_deep, colour, 0.55)!
        : const Color(0xFF0E4D55);
    final side = Color.lerp(face, Colors.black, 0.45)!;

    // Ripples spreading out from where the tile meets the water.
    for (var k = 0; k < 3; k++) {
      final r = (ripple * 4 + k / 3) % 1;
      canvas.drawPath(
        _tri(size, Offset(0, thick), grow: 0.05 + r * 0.28),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _foam.withValues(alpha: (1 - r) * 0.28),
      );
    }

    // Shadow on the pool floor, softer and further away when lifted.
    canvas.drawPath(
      _tri(size, Offset(thick * 1.3, thick * (2.4 + lift * 2.5))),
      Paint()
        ..color = const Color(0xFF010B16).withValues(alpha: 0.8 - lift * 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 + lift * 10),
    );

    // The tile's thickness, mostly under water.
    canvas.drawPath(_tri(size, Offset(0, thick)), Paint()..color = side);
    final submerged = Path.combine(
      PathOperation.difference,
      _tri(size, Offset(0, thick)),
      _tri(size, Offset(0, waterline * (1 + lift * 3))),
    );
    canvas.drawPath(
      submerged,
      Paint()..color = _aqua.withValues(alpha: 0.45 * (1 - lift)),
    );
    // The waterline: a bright meniscus where the surface meets the sides.
    canvas
      ..save()
      ..clipPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(Offset.zero & size),
          _tri(size, Offset.zero),
        ),
      )
      ..drawPath(
        _tri(size, Offset(0, waterline)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _foam.withValues(
            alpha: (0.55 + 0.25 * sin(ripple * 2 * pi * 5)) * (1 - lift),
          ),
      )
      ..restore();

    // The dry top face.
    final top = _tri(size, Offset.zero);
    canvas.drawPath(
      top,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(face, Colors.white, 0.18)!, face],
        ).createShader(Offset.zero & size),
    );
    if (faceUp) {
      final c = Offset(size.width / 2, h * 0.5);
      final r = size.width * 0.06;
      final spots = switch (value) {
        1 => [c],
        2 => [
          c + Offset(-size.width * 0.1, 0),
          c + Offset(size.width * 0.1, 0),
        ],
        _ => [
          c + Offset(0, -h * 0.11),
          c + Offset(-size.width * 0.11, h * 0.05),
          c + Offset(size.width * 0.11, h * 0.05),
        ],
      };
      for (final s in spots) {
        canvas
          ..drawCircle(
            s + const Offset(1, 1.5),
            r,
            Paint()..color = Colors.black38,
          )
          ..drawCircle(s, r, Paint()..color = Colors.white);
      }
      if (label) {
        final name = TextPainter(
          text: TextSpan(
            text: intToTernaryString(value),
            style: TextStyle(
              color: Colors.white,
              fontSize: h * 0.13,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        name.paint(canvas, Offset(size.width / 2 - name.width / 2, h * 0.64));
      }
    } else {
      // The Ál back: rolling waves, and a question.
      canvas
        ..save()
        ..clipPath(top);
      final wave = Paint()
        ..color = _aqua.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.02;
      for (var row = 0; row < 6; row++) {
        final y = h * (0.3 + row * 0.1);
        final path = Path()..moveTo(0, y);
        for (var x = 0.0; x <= size.width; x += size.width / 24) {
          path.lineTo(
            x,
            y +
                sin(x / size.width * 4 * pi + row + ripple * 2 * pi) *
                    h *
                    0.022,
          );
        }
        canvas.drawPath(path, wave);
      }
      canvas.restore();
      final q = TextPainter(
        text: TextSpan(
          text: '?',
          style: TextStyle(
            color: Colors.white70,
            fontSize: h * 0.28,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      q.paint(canvas, Offset(size.width / 2 - q.width / 2, h * 0.38));
    }
    canvas.drawPath(
      top,
      Paint()
        ..color = picked ? _gold : Color.lerp(face, Colors.white, 0.35)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = picked ? 4 : 1.5,
    );
  }

  @override
  bool shouldRepaint(_TilePainter old) =>
      old.value != value ||
      old.faceUp != faceUp ||
      old.picked != picked ||
      old.ripple != ripple ||
      old.lift != lift;
}

/// Bubbles rising through the pool: a few for Holy 2, a golden flood for 27.
class _Bubbles extends StatelessWidget {
  const _Bubbles({required this.animation, required this.golden});
  final Animation<double> animation;
  final bool golden;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (context, _) => animation.isAnimating
        ? CustomPaint(painter: _BubblePainter(animation.value, golden))
        : const SizedBox.shrink(),
  );
}

class _BubblePainter extends CustomPainter {
  _BubblePainter(this.t, this.golden);
  final double t;
  final bool golden;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(27);
    final count = golden ? 90 : 36;
    for (var i = 0; i < count; i++) {
      final x0 = rng.nextDouble() * size.width;
      final speed = 0.6 + rng.nextDouble() * 0.8;
      final r = 3 + rng.nextDouble() * (golden ? 12 : 8);
      final delay = rng.nextDouble() * 0.3;
      final p = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (p <= 0) continue;
      final y = size.height * (1.05 - p * speed * 1.1);
      final x = x0 + sin(p * 8 + i) * 14;
      final fade = (1 - p).clamp(0.0, 1.0);
      final colour = golden && i.isEven ? _gold : _foam;
      canvas
        ..drawCircle(
          Offset(x, y),
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = colour.withValues(alpha: 0.8 * fade),
        )
        ..drawCircle(
          Offset(x - r * 0.35, y - r * 0.35),
          r * 0.25,
          Paint()..color = Colors.white.withValues(alpha: 0.7 * fade),
        );
    }
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.t != t || old.golden != golden;
}
