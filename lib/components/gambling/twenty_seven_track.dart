import 'dart:math';

import 'package:flutter/material.dart';

import '../../game_engine/gambling/twenty_seven.dart';
import 'twenty_seven_colours.dart';

/// The board, 0 to 27, winding upward: 0 to 13 along the bottom row, then
/// 14 to 27 back along the top. A black Ál tentacle reaches in from the
/// pool and covers every number already passed, its tip on the count.
class CountTrack extends StatelessWidget {
  const CountTrack({super.key, required this.count, required this.water});
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
        ? SeaColours.gold
        : busts(n)
        ? SeaColours.bust
        : SeaColours.foam;
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
          color: colour == SeaColours.foam ? Colors.white : colour,
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
