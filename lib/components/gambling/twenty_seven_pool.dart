import 'dart:math';
import 'dart:ui' show FragmentProgram, FragmentShader;

import 'package:flutter/material.dart';

import 'twenty_seven_colours.dart';

/// The pool shader, loaded once and shared by every visit to the table.
final Future<FragmentProgram> _poolProgram = FragmentProgram.fromAsset(
  'shaders/pool.frag',
);

/// The pool: an aqua and deep-blue gradient that slowly drifts, with
/// caustic light playing over the floor. Drawn by `shaders/pool.frag`; until
/// the shader has loaded, the water is still.
class SeaPool extends StatefulWidget {
  const SeaPool({super.key, required this.water});
  final Animation<double> water;

  @override
  State<SeaPool> createState() => _PoolState();
}

class _PoolState extends State<SeaPool> {
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
          colors: [SeaColours.deep, Color(0xFF0B4F6C), SeaColours.deep],
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

/// Bubbles rising through the pool: a few for Holy 2, a golden flood for 27.
class PoolBubbles extends StatelessWidget {
  const PoolBubbles({super.key, required this.animation, required this.golden});
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
      final colour = golden && i.isEven ? SeaColours.gold : SeaColours.foam;
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
