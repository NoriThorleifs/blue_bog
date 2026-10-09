import 'dart:math';

import 'package:flutter/material.dart';

import '../cards/card_widgets.dart';

/// A steady pseudo-random number in [0, 1) for event [i], so each shot
/// keeps its own arc and landing spot from frame to frame.
double jitter(int i, int salt) {
  final x = sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

void paintBeam(
  Canvas canvas,
  Offset from,
  Offset to,
  Color colour,
  double age, {
  double width = 3,
}) {
  const life = 0.4;
  if (age < 0 || age > life) return;
  final fade = 1 - age / life;
  canvas
    ..drawLine(
      from,
      to,
      Paint()
        ..color = colour.withValues(alpha: 0.5 * fade)
        ..strokeWidth = width * 3
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    )
    ..drawLine(
      from,
      to,
      Paint()
        ..color = Colors.white.withValues(alpha: fade)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
}

/// A rail slug's streak: white-hot, heavy, and slow to fade.
void paintRail(
  Canvas canvas,
  Offset from,
  Offset to,
  double age, {
  bool faint = false,
}) {
  const life = 0.55;
  if (age < 0 || age > life) return;
  final fade = (1 - age / life) * (faint ? 0.5 : 1);
  canvas
    ..drawLine(
      from,
      to,
      Paint()
        ..color = const Color(0xFFB8C8FF).withValues(alpha: 0.4 * fade)
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    )
    ..drawLine(
      from,
      to,
      Paint()
        ..color = Colors.white.withValues(alpha: fade)
        ..strokeWidth = faint ? 2 : 5 * (1 - age / life) + 1
        ..strokeCap = StrokeCap.round,
    );
  // The muzzle flash.
  if (!faint && age < 0.1) {
    canvas.drawCircle(
      from,
      14 * (1 - age / 0.1),
      Paint()..color = Colors.white.withValues(alpha: 1 - age / 0.1),
    );
  }
}

void paintBolt(
  Canvas canvas,
  int i,
  Offset from,
  Offset to,
  Color colour,
  double age,
) {
  const life = 0.3;
  if (age < 0 || age > life) return;
  final fade = 1 - age / life;
  final normal = Offset(-(to - from).dy, (to - from).dx) / (to - from).distance;
  final path = Path()..moveTo(from.dx, from.dy);
  const steps = 9;
  for (var k = 1; k < steps; k++) {
    // The bolt crackles: a new zigzag every few hundredths of a second.
    final wobble = (jitter(i * 31 + k, (age * 30).floor()) - 0.5) * 24;
    final p = Offset.lerp(from, to, k / steps)! + normal * wobble;
    path.lineTo(p.dx, p.dy);
  }
  path.lineTo(to.dx, to.dy);
  canvas
    ..drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = colour.withValues(alpha: 0.45 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    )
    ..drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: fade),
    );
}

/// Where a lobbed shot is at progress [t], on a gentle arc.
Offset arcPoint(int i, Offset from, Offset to, double t) {
  final mid = Offset.lerp(from, to, 0.5)!;
  final d = to - from;
  final normal = Offset(-d.dy, d.dx) / max(d.distance, 1);
  final control = mid + normal * (d.distance * 0.25 * (jitter(i, 3) - 0.5));
  final a = Offset.lerp(from, control, t)!;
  final b = Offset.lerp(control, to, t)!;
  return Offset.lerp(a, b, t)!;
}

void paintMissile(
  Canvas canvas,
  int i,
  Offset from,
  Offset to,
  Color colour,
  double age,
  double flight,
) {
  final t = (age + flight) / flight;
  if (t < 0 || t >= 1) return;
  for (var k = 6; k >= 0; k--) {
    final tk = t - k * 0.03;
    if (tk < 0) continue;
    final p = arcPoint(i, from, to, tk);
    canvas.drawCircle(
      p,
      k == 0 ? 3.5 : 3 - k * 0.3,
      Paint()
        ..color = (k == 0 ? Colors.white : colour).withValues(alpha: 1 - k / 7),
    );
  }
}

/// A Hellfire shot, flickering by the replay [time].
void paintFireball(
  Canvas canvas,
  int i,
  Offset from,
  Offset to,
  double age,
  double flight,
  double time,
) {
  final t = (age + flight) / flight;
  if (t < 0 || t >= 1) return;
  final p = arcPoint(i, from, to, t);
  final flicker = 1 + 0.25 * sin(time * 60 + i);
  canvas
    ..drawCircle(
      p,
      9 * flicker,
      Paint()
        ..color = hellishRed.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    )
    ..drawCircle(p, 4, Paint()..color = const Color(0xFFFFD27A));
}

void paintBlast(
  Canvas canvas,
  Offset at,
  Color colour,
  double age,
  double life,
  double radius,
) {
  if (age < 0 || age > life) return;
  final t = age / life;
  canvas
    ..drawCircle(
      at,
      radius * (0.4 + t),
      Paint()
        ..color = colour.withValues(alpha: 0.55 * (1 - t))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    )
    ..drawCircle(
      at,
      radius * 0.35 * (1 - t),
      Paint()..color = Colors.white.withValues(alpha: 1 - t),
    );
}

void paintRings(
  Canvas canvas,
  Offset at,
  Color colour,
  double age,
  double life,
  double radius,
) {
  if (age < 0 || age > life) return;
  final t = age / life;
  canvas.drawCircle(
    at,
    radius * (0.5 + t),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = colour.withValues(alpha: 1 - t),
  );
}

/// Rings closing in on the spot, then a flash: something arriving from
/// nowhere.
void paintImplosion(
  Canvas canvas,
  Offset at,
  Color colour,
  double age,
  double radius,
) {
  const close = 0.3;
  const flash = 0.3;
  if (age < -close || age > flash) return;
  if (age < 0) {
    final t = (age + close) / close;
    for (var k = 0; k < 3; k++) {
      final r = radius * (1 - t) * (1 + k * 0.4);
      if (r <= 0) continue;
      canvas.drawCircle(
        at,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = colour.withValues(alpha: t * (1 - k * 0.25)),
      );
    }
  } else {
    paintBlast(canvas, at, colour, age, flash, radius * 0.8);
  }
}

void paintStar(Canvas canvas, Offset at, Color colour, double age, double r) {
  const life = 0.3;
  if (age < 0 || age > life) return;
  final t = age / life;
  final paint = Paint()
    ..color = colour.withValues(alpha: 1 - t)
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;
  for (var k = 0; k < 8; k++) {
    final a = k * pi / 4;
    final d = Offset(cos(a), sin(a));
    canvas.drawLine(at + d * r * t * 0.4, at + d * r * (0.4 + t), paint);
  }
}

void paintDiamond(Canvas canvas, Offset at, double r, Color colour) {
  final path = Path()
    ..moveTo(at.dx, at.dy - r)
    ..lineTo(at.dx + r, at.dy)
    ..lineTo(at.dx, at.dy + r)
    ..lineTo(at.dx - r, at.dy)
    ..close();
  canvas
    ..drawPath(
      path,
      Paint()
        ..color = colour.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    )
    ..drawPath(path, Paint()..color = colour);
}

/// A number or word that floats up off the spot and fades.
void paintNumber(
  Canvas canvas,
  Offset at,
  String text,
  Color colour,
  double age, {
  bool small = false,
}) {
  const life = 0.9;
  if (age < 0 || age > life) return;
  final t = age / life;
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: small ? 13 : 18,
        fontWeight: FontWeight.w800,
        color: Color.lerp(
          Colors.white,
          colour,
          0.5,
        )!.withValues(alpha: (1 - t * t).clamp(0, 1)),
        shadows: const [Shadow(blurRadius: 4)],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(
    canvas,
    at - Offset(painter.width / 2, painter.height / 2 + 40 * t),
  );
}
