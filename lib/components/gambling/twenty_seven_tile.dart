import 'dart:math';

import 'package:flutter/material.dart';

import '../../functions/three_thirds/ternary_number_translator.dart';
import 'twenty_seven_colours.dart';

/// A triangular tile standing in shallow water. [flip] turns it over
/// (0 to 1); [lift] raises it out of the water.
///
/// The tile is painted in three layers: ripples spreading under it and the
/// water's surface over it move every frame, while the tile itself only
/// changes when it's picked or flipped, so it has a layer of its own and
/// is painted once.
class CountTile extends StatelessWidget {
  const CountTile({
    super.key,
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
      ? Color.lerp(SeaColours.deep, switch (value) {
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
          ..color = SeaColours.foam.withValues(alpha: (1 - r) * 0.28),
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
          ..color = SeaColours.foam.withValues(
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
      ..color = SeaColours.aqua.withValues(alpha: 0.5)
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
        Paint()
          ..color = SeaColours.floorShadow.withValues(alpha: darkness * 0.2),
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
      Paint()..color = SeaColours.aqua.withValues(alpha: 0.45 * (1 - lift)),
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
        ..color = picked ? SeaColours.gold : _TileShape.outline(face)
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
