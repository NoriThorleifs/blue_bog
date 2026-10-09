import 'dart:math';

import 'package:flutter/material.dart';

import '../../functions/roulette_motion.dart';
import '../../game_engine/gambling/roulette.dart';

const rouletteRed = Color(0xFFC62828);

const rouletteBlack = Color(0xFF1C1C22);

const rouletteGreen = Color(0xFF2E7D32);

Color pocketColour(int n) =>
    n == 0 ? rouletteGreen : (isRed(n) ? rouletteRed : rouletteBlack);

class RouletteWheelPainter extends CustomPainter {
  RouletteWheelPainter({
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
      canvas.drawPath(path, Paint()..color = pocketColour(n));
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
  bool shouldRepaint(RouletteWheelPainter old) =>
      old.wheel != wheel ||
      old.ball != ball ||
      old.ballRadius != ballRadius ||
      old.highlight != highlight;
}
