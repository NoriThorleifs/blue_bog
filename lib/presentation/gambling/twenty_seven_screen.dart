import 'dart:math';
import 'dart:ui' show FragmentProgram, FragmentShader;

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
const _stone = Color(0xFF1A2733);
const _floorShadow = Color(0xFF010B16);

/// The pool shader, loaded once and shared by every visit to the table.
final Future<FragmentProgram> _poolProgram = FragmentProgram.fromAsset(
  'shaders/pool.frag',
);

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
          Positioned.fill(
            child: RepaintBoundary(child: _Pool(water: _water)),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _Stone(
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
                    child: _CountPanel(game: game),
                  ),
                ),
                const SizedBox(height: 12),
                _Track(count: game?.count ?? 0, water: _water),
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
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _Stone(
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
    ),
  ];
}

/// The pool: an aqua and deep-blue gradient that slowly drifts, with
/// caustic light playing over the floor. Drawn by `shaders/pool.frag`; until
/// the shader has loaded, the water is still.
class _Pool extends StatefulWidget {
  const _Pool({required this.water});
  final Animation<double> water;

  @override
  State<_Pool> createState() => _PoolState();
}

class _PoolState extends State<_Pool> {
  FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _poolProgram.then((program) {
      if (mounted) setState(() => _shader = program.fragmentShader());
    }, onError: (Object error) => debugPrint('Pool shader failed: $error'));
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => switch (_shader) {
    final shader? => CustomPaint(
      painter: _PoolPainter(shader, widget.water),
      child: const SizedBox.expand(),
    ),
    null => const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_deep, Color(0xFF0B4F6C), _deep],
        ),
      ),
    ),
  };
}

class _PoolPainter extends CustomPainter {
  _PoolPainter(this.shader, this.water) : super(repaint: water);
  final FragmentShader shader;
  final Animation<double> water;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, water.value);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_PoolPainter old) =>
      old.shader != shader || old.water != water;
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
      builder: (context, c, _) => _Stone(
        padding: 16,
        tint: c,
        glow: glowing ? c : null,
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
                      color: c!,
                      shadows: [if (glowing) Shadow(color: c, blurRadius: 16)],
                    ),
                  ),
                  Text('$count', style: text.titleMedium),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(verdict, textAlign: TextAlign.center, style: text.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// A slab of stone standing in the pool, like the tiles: a dry top face, a
/// sliver of its side above the waterline and a shadow on the floor.
/// Opaque, so text stays readable over the water, and painted once: nothing
/// on it moves with the water.
class _Stone extends StatelessWidget {
  const _Stone({required this.child, this.padding = 12, this.tint, this.glow});
  final Widget child;
  final double padding;

  /// Colours the face and edge, for the count's verdicts.
  final Color? tint;

  /// A halo round the slab, for the verdicts worth shouting about.
  final Color? glow;

  /// How much of the slab's side shows below its face.
  static const thick = 7.0;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _StonePainter(tint: tint, glow: glow),
    child: Padding(
      padding: EdgeInsets.fromLTRB(padding, padding, padding, padding + thick),
      child: child,
    ),
  );
}

class _StonePainter extends CustomPainter {
  _StonePainter({this.tint, this.glow});
  final Color? tint;
  final Color? glow;

  @override
  void paint(Canvas canvas, Size size) {
    const thick = _Stone.thick;
    const waterline = thick * 0.35;
    final face = tint == null ? _stone : Color.lerp(_stone, tint, 0.12)!;
    final side = Color.lerp(face, Colors.black, 0.45)!;
    final slab = RRect.fromRectAndRadius(
      Offset.zero & Size(size.width, size.height - thick),
      const Radius.circular(16),
    );
    RRect sunk(double dy) => slab.shift(Offset(0, dy));

    // Flat layers stand in for blurs throughout: the water under them
    // moves, so a blur would be worked out again every frame.
    // Fine steps of a pixel or so, from a wide faint rim in to a dark core,
    // read as a soft edge.
    final shadow = slab.shift(const Offset(thick * 0.8, thick * 1.6));
    for (var i = 0; i < 6; i++) {
      canvas.drawRRect(
        shadow.inflate(6.0 - i * 1.6),
        Paint()..color = _floorShadow.withValues(alpha: 0.09),
      );
    }
    if (glow case final g?) {
      for (final grow in [12.0, 8.0, 4.0]) {
        canvas.drawRRect(
          slab.inflate(grow),
          Paint()..color = g.withValues(alpha: 0.09),
        );
      }
    }
    // The side: under water up to the waterline, dry above it, with a
    // bright meniscus where the surface meets it.
    canvas
      ..drawRRect(sunk(thick), Paint()..color = side)
      ..drawRRect(sunk(thick), Paint()..color = _aqua.withValues(alpha: 0.35))
      ..drawRRect(sunk(waterline), Paint()..color = side)
      ..drawRRect(
        sunk(waterline),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _foam.withValues(alpha: 0.5),
      )
      ..drawRRect(
        slab,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(face, Colors.white, 0.12)!, face],
          ).createShader(slab.outerRect),
      )
      ..drawRRect(
        slab.deflate(0.75),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color =
              tint?.withValues(alpha: 0.8) ??
              Color.lerp(face, Colors.white, 0.3)!,
      );
  }

  @override
  bool shouldRepaint(_StonePainter old) => old.tint != tint || old.glow != glow;
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
      // The numbers never move, so they get their own layer and are
      // painted once; only the tentacle repaints with the water.
      return SizedBox(
        width: box.maxWidth,
        height: geometry.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(painter: _CellsPainter(geometry)),
            ),
            RepaintBoundary(
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: count.toDouble()),
                duration: const Duration(milliseconds: 750),
                curve: Curves.easeInOutCubic,
                builder: (context, reach, _) => CustomPaint(
                  painter: _TentaclePainter(geometry, reach, water),
                ),
              ),
            ),
          ],
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

/// The numbered cells, 0 to 27.
class _CellsPainter extends CustomPainter {
  _CellsPainter(this.board);
  final _Board board;

  @override
  void paint(Canvas canvas, Size size) {
    for (var n = 0; n <= holyGoal; n++) {
      _cell(canvas, n);
    }
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
    label
      ..paint(canvas, rect.center - Offset(label.width / 2, label.height / 2))
      ..dispose();
  }

  @override
  bool shouldRepaint(_CellsPainter old) => old.board.width != board.width;
}

/// A smooth, glossy black tentacle. No suckers: Ál tentacles don't have
/// them.
class _TentaclePainter extends CustomPainter {
  _TentaclePainter(this.board, this.reach, this.water) : super(repaint: water);
  final _Board board;
  final double reach;
  final Animation<double> water;

  @override
  void paint(Canvas canvas, Size size) {
    final tip = board.routeAt(reach);
    const start = -1.3;
    final length = tip - start;
    final step = 0.06;
    final phase = water.value * 2 * pi * 6;
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
    // Two flat shadows, a near dark one and a far faint one, instead of a
    // blur that would be worked out again every frame.
    for (final (dx, dy, alpha) in [(0.2, 0.32, 0.2), (0.1, 0.18, 0.35)]) {
      canvas.drawPath(
        body.shift(Offset(board.cell * dx, board.cell * dy)),
        Paint()..color = Colors.black.withValues(alpha: alpha),
      );
    }
    canvas.drawPath(
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
        ..strokeWidth = board.cell * 0.08
        ..color = const Color(0xFF7FA6B8).withValues(alpha: 0.3),
    );
  }

  @override
  bool shouldRepaint(_TentaclePainter old) =>
      old.reach != reach ||
      old.water != water ||
      old.board.width != board.width;
}

/// A triangular tile standing in shallow water. [flip] turns it over
/// (0 to 1); [lift] raises it out of the water.
///
/// The tile is painted in three layers: ripples spreading under it and the
/// water's surface over it move every frame, while the tile itself only
/// changes when it's picked or flipped, so it has a layer of its own and
/// is painted once.
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
    final rise = lift + sin(flip * pi) * 0.6;
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
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _RipplePainter(water),
                foregroundPainter: _SurfacePainter(
                  water: water,
                  faceUp: showFront,
                  lift: rise,
                ),
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _TilePainter(
                      value: value,
                      faceUp: showFront,
                      picked: picked,
                      lift: rise,
                      label: !small,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tile's triangle at one size, and the paths every frame reuses.
class _TileShape {
  _TileShape(this.size) : thick = size.height * 0.1;
  final Size size;
  final double thick;

  /// The water is a little shallower than the tile is thick, so the top
  /// face stays dry and a sliver of the side shows above the surface.
  double get waterline => thick * 0.28;

  late final top = tri(Offset.zero);

  /// Everything but the top face.
  late final aroundTop = Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & size)
    ..addPath(top, Offset.zero);

  Path tri(Offset shift, {double grow = 0}) {
    final s = size;
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

  /// The triangle at [shift] with every edge pushed out by [d] pixels (in
  /// with a negative [d]): scaled about its incentre, the one point as far
  /// from all three edges.
  Path outset(Offset shift, double d) {
    final s = size;
    final a = Offset(s.width / 2, s.height * 0.06);
    final b = Offset(s.width * 0.05, s.height * 0.86);
    final c = Offset(s.width * 0.95, s.height * 0.86);
    final (la, lb, lc) = ((b - c).distance, (c - a).distance, (a - b).distance);
    final perimeter = la + lb + lc;
    final centre = (a * la + b * lb + c * lc) / perimeter;
    final area =
        ((b.dx - a.dx) * (c.dy - a.dy) - (c.dx - a.dx) * (b.dy - a.dy)).abs() /
        2;
    final k = (area / (perimeter / 2) + d) / (area / (perimeter / 2));
    Offset p(Offset v) => centre + (v - centre) * k + shift;
    return Path()..addPolygon([p(a), p(b), p(c)], true);
  }

  /// The colour of the top face.
  static Color face(int value, {required bool faceUp}) => faceUp
      ? Color.lerp(_deep, switch (value) {
          1 => const Color(0xFF5E7CE2),
          2 => const Color(0xFF9B6BD6),
          _ => const Color(0xFF2FB39F),
        }, 0.55)!
      : const Color(0xFF0E4D55);

  static Color outline(Color face) => Color.lerp(face, Colors.white, 0.35)!;
}

/// Keeps the [_TileShape] for the last size painted. The water painters
/// live as long as their tile, so the shape is worked out once.
mixin _ShapeCache on CustomPainter {
  _TileShape? _shape;
  _TileShape shapeFor(Size size) =>
      _shape?.size == size ? _shape! : _shape = _TileShape(size);
}

/// Ripples spreading out from where the tile meets the water.
class _RipplePainter extends CustomPainter with _ShapeCache {
  _RipplePainter(this.water) : super(repaint: water);
  final Animation<double> water;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = shapeFor(size);
    for (var k = 0; k < 3; k++) {
      final r = (water.value * 4 + k / 3) % 1;
      canvas.drawPath(
        shape.tri(Offset(0, shape.thick), grow: 0.05 + r * 0.28),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _foam.withValues(alpha: (1 - r) * 0.28),
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.water != water;
}

/// The moving water over the tile: the bright meniscus where the surface
/// meets its sides and, face down, the Ál back's rolling waves.
class _SurfacePainter extends CustomPainter with _ShapeCache {
  _SurfacePainter({
    required this.water,
    required this.faceUp,
    required this.lift,
  }) : super(repaint: water);

  final Animation<double> water;
  final bool faceUp;
  final double lift;

  /// Laid out once per size, not every frame.
  TextPainter? _question;

  @override
  void paint(Canvas canvas, Size size) {
    if (_shape?.size != size) _question = null;
    final shape = shapeFor(size);
    final h = size.height;
    final ripple = water.value;
    canvas
      ..save()
      ..clipPath(shape.aroundTop)
      ..drawPath(
        shape.tri(Offset(0, shape.waterline)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _foam.withValues(
            alpha: (0.55 + 0.25 * sin(ripple * 2 * pi * 5)) * (1 - lift),
          ),
      )
      ..restore();
    if (faceUp) return;

    // The Ál back: rolling waves, and a question.
    canvas
      ..save()
      ..clipPath(shape.top);
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
          y + sin(x / size.width * 4 * pi + row + ripple * 2 * pi) * h * 0.022,
        );
      }
      canvas.drawPath(path, wave);
    }
    canvas.restore();
    final q = _question ??= TextPainter(
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
    canvas.drawPath(
      shape.top,
      Paint()
        ..color = _TileShape.outline(_TileShape.face(0, faceUp: false))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_SurfacePainter old) =>
      old.water != water || old.faceUp != faceUp || old.lift != lift;
}

/// The tile itself: its shadow, its sides and its dry top face.
class _TilePainter extends CustomPainter {
  _TilePainter({
    required this.value,
    required this.faceUp,
    required this.picked,
    required this.lift,
    required this.label,
  });

  final int value;
  final bool faceUp;
  final bool picked;
  final double lift;
  final bool label;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = _TileShape(size);
    final h = size.height;
    final thick = shape.thick;
    final face = _TileShape.face(value, faceUp: faceUp);
    final side = Color.lerp(face, Colors.black, 0.45)!;

    // Shadow on the pool floor, softer and further away when lifted. Flat
    // layers stand in for a blur, which would be worked out again every
    // frame as the water under it moves.
    // Fine steps, from a wide faint rim in to a dark core, read as a soft
    // edge.
    final floor = Offset(thick * 1.3, thick * (2.4 + lift * 2.5));
    final darkness = 0.8 - lift * 0.25;
    final spread = 7 + lift * 10;
    for (var i = 0; i < 6; i++) {
      canvas.drawPath(
        shape.outset(floor, spread * (1 - i / 3.5)),
        Paint()..color = _floorShadow.withValues(alpha: darkness * 0.2),
      );
    }

    // The tile's thickness, mostly under water.
    canvas.drawPath(shape.tri(Offset(0, thick)), Paint()..color = side);
    final submerged = Path.combine(
      PathOperation.difference,
      shape.tri(Offset(0, thick)),
      shape.tri(Offset(0, shape.waterline * (1 + lift * 3))),
    );
    canvas.drawPath(
      submerged,
      Paint()..color = _aqua.withValues(alpha: 0.45 * (1 - lift)),
    );

    // The dry top face.
    canvas.drawPath(
      shape.top,
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
        name
          ..paint(canvas, Offset(size.width / 2 - name.width / 2, h * 0.64))
          ..dispose();
      }
    }
    canvas.drawPath(
      shape.top,
      Paint()
        ..color = picked ? _gold : _TileShape.outline(face)
        ..style = PaintingStyle.stroke
        ..strokeWidth = picked ? 4 : 1.5,
    );
  }

  @override
  bool shouldRepaint(_TilePainter old) =>
      old.value != value ||
      old.faceUp != faceUp ||
      old.picked != picked ||
      old.lift != lift ||
      old.label != label;
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
