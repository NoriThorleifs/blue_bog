import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../game/combat/catalog.dart';
import '../../game/combat/combat.dart';
import '../cards/card_widgets.dart';
import '../deck/deck_screen.dart' show Triforce;

/// Fight seconds a shot spends in flight before the moment it lands, which
/// is the moment the fight records it. Beams land the instant they fire.
double launchLead(CombatEventKind kind) => switch (kind) {
  CombatEventKind.missileHit || CombatEventKind.missileIntercepted => 0.6,
  CombatEventKind.hellfireHit => 0.35,
  _ => 0,
};

/// Fight seconds the replay keeps running after the fight ends, for the
/// loser to blow up.
const outroSeconds = 1.4;

/// Shots, impacts, shields, drones and numbers, drawn over both ships.
///
/// Everything is worked out from the fight record and the replay clock, so
/// scrubbing, speeding up and skipping all just work: nothing is spawned or
/// remembered between frames.
class BattleEffects extends CustomPainter {
  BattleEffects({
    required this.record,
    required this.time,
    required this.layer,
    required this.triforces,
    required this.maxShield,
  });

  final FightRecord record;
  final double time;

  /// The layer this paints on, and each side's triforce, for finding where
  /// the ships are on screen.
  final GlobalKey layer;
  final List<GlobalKey> triforces;
  final List<int> maxShield;

  static const _shieldColour = Color(0xFF7FA8FF);

  @override
  void paint(Canvas canvas, Size size) {
    final ships = [for (var side = 0; side < 2; side++) _ship(side)];
    if (ships.contains(null)) return;
    final geo = ships.cast<_Ship>();
    final now = record.result.at(min(time, record.result.seconds));
    for (var side = 0; side < 2; side++) {
      _shield(canvas, geo[side], side, now.shield[side]);
      _drones(canvas, geo[side], now.drones[side]);
    }
    for (final (i, e) in record.result.events.indexed) {
      final age = time - e.time;
      if (age < -1 || age > 1.2) continue;
      _event(canvas, i, e, age, geo);
    }
    _ending(canvas, size, geo);
  }

  _Ship? _ship(int side) {
    final layerBox = layer.currentContext?.findRenderObject() as RenderBox?;
    final box =
        triforces[side].currentContext?.findRenderObject() as RenderBox?;
    if (layerBox == null || box == null || !box.hasSize) return null;
    return _Ship(
      layerBox.globalToLocal(box.localToGlobal(Offset.zero)),
      box.size.width,
    );
  }

  List<String?> _slots(int side) =>
      side == 0 ? record.player.slots : record.enemy.slots;

  Color _colour(int side, int slot) => switch (_slots(side)[slot]) {
    final id? => cardColour(equipmentById(id)),
    null => Colors.white,
  };

  /// A steady pseudo-random number in [0, 1) for event [i], so each shot
  /// keeps its own arc and landing spot from frame to frame.
  static double _jitter(int i, int salt) {
    final x = sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  Offset _impact(int i, _Ship target) {
    final a = _jitter(i, 1) * 2 * pi;
    final r = _jitter(i, 2) * target.width * 0.16;
    return target.centre + Offset(cos(a), sin(a)) * r;
  }

  // Defences --------------------------------------------------------------

  void _shield(Canvas canvas, _Ship ship, int side, int shield) {
    final cap = maxShield[side];
    if (cap <= 0) return;
    final full = shield / cap;
    // Shields brighten as they charge and ripple when they block a shot.
    var pulse = 0.0;
    for (final e in record.result.events) {
      final age = time - e.time;
      if (age < 0 || age > 0.4) continue;
      final ours = e.side == side && e.kind == CombatEventKind.shieldsCharged;
      final blocked =
          e.side != side &&
          (e.kind == CombatEventKind.laserAbsorbed ||
              e.kind == CombatEventKind.railDeflected);
      if (ours || blocked) pulse = max(pulse, 1 - age / 0.4);
    }
    if (full <= 0 && pulse <= 0) return;
    final path = ship.bubble;
    canvas
      ..drawPath(
        path,
        Paint()..color = _shieldColour.withValues(alpha: 0.02 + 0.04 * full),
      )
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 + 2 * pulse
          ..strokeJoin = StrokeJoin.round
          ..color = _shieldColour.withValues(
            alpha: (0.25 + 0.5 * full + 0.4 * pulse).clamp(0, 1),
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4),
      );
  }

  void _drones(Canvas canvas, _Ship ship, int drones) {
    final shown = min(drones, 18);
    for (var k = 0; k < shown; k++) {
      final a = time * 0.9 + k * 2 * pi / shown;
      final p =
          ship.centre +
          Offset(cos(a) * ship.width * 0.42, sin(a) * ship.width * 0.32);
      _diamond(canvas, p, 5, Palette.codeGreen);
    }
  }

  // Events ----------------------------------------------------------------

  void _event(
    Canvas canvas,
    int i,
    CombatEvent e,
    double age,
    List<_Ship> geo,
  ) {
    final source = geo[e.side];
    final target = geo[1 - e.side];
    final from = source.slot(e.slot);
    final colour = _colour(e.side, e.slot);
    final hit = _impact(i, target);
    switch (e.kind) {
      case CombatEventKind.laserHit:
        _beam(canvas, from, hit, colour, age, width: _isLance(e) ? 5 : 3);
        _number(canvas, hit, '-${e.value}', colour, age);
      case CombatEventKind.laserAbsorbed:
        final edge = Offset.lerp(target.centre, from, 0.42)!;
        _beam(canvas, from, edge, colour, age, width: _isLance(e) ? 5 : 3);
        _number(canvas, edge, 'blocked', _shieldColour, age, small: true);
      case CombatEventKind.ionHit:
        _bolt(canvas, i, from, hit, colour, age);
        if ((e.value ?? 0) > 0) {
          _number(canvas, hit, '-${e.value}', colour, age);
        }
      case CombatEventKind.missileHit:
        _missile(canvas, i, from, hit, colour, age, launchLead(e.kind));
        if (age >= 0) {
          _blast(canvas, hit, colour, age, 0.4, target.width * 0.12);
          _number(canvas, hit, '-${e.value}', colour, age);
        }
      case CombatEventKind.missileIntercepted:
        // Shot down by a drone out on its orbit.
        final dir = from - target.centre;
        final stop = target.centre + dir / dir.distance * target.width * 0.45;
        _missile(canvas, i, from, stop, colour, age, launchLead(e.kind));
        if (age >= 0) {
          _blast(
            canvas,
            stop,
            Palette.codeGreen,
            age,
            0.3,
            target.width * 0.07,
          );
        }
      case CombatEventKind.hellfireHit:
        _fireball(canvas, i, from, hit, age, launchLead(e.kind));
        if (age >= 0) {
          _blast(canvas, hit, hellishRed, age, 0.45, target.width * 0.14);
          _blast(canvas, from, hellishRed, age, 0.3, source.width * 0.06);
          _number(canvas, hit, '-${e.value}', hellishRed, age);
        }
      case CombatEventKind.teleportHit:
        _implosion(canvas, hit, colour, age, target.width * 0.2);
        _rings(canvas, from, colour, age, 0.3, source.width * 0.06);
        _number(canvas, hit, '-${e.value}', colour, age);
      case CombatEventKind.teleportJammed:
        _implosion(canvas, hit, Palette.muted, age, target.width * 0.14);
        _number(canvas, hit, 'jammed', Palette.muted, age, small: true);
      case CombatEventKind.flakHit || CombatEventKind.flakShrapnel:
        for (var k = 0; k < 3; k++) {
          final a = _jitter(i, 10 + k) * 2 * pi;
          final p =
              target.centre +
              Offset(cos(a) * target.width * 0.42, sin(a) * target.width * 0.3);
          _star(canvas, p, colour, age - k * 0.07, target.width * 0.05);
        }
        if (e.kind == CombatEventKind.flakShrapnel && (e.value ?? 0) > 0) {
          _number(canvas, hit, '-${e.value}', colour, age);
        }
      case CombatEventKind.repaired:
        _number(canvas, source.centre, '+${e.value}', Palette.codeGreen, age);
      case CombatEventKind.droneBuilt:
        _rings(canvas, from, Palette.codeGreen, age, 0.35, source.width * 0.05);
      case CombatEventKind.outOfAmmo:
        _number(canvas, from, 'empty', Palette.muted, age, small: true);
      case CombatEventKind.railHit:
        _rail(canvas, from, hit, age);
        if (age >= 0) {
          _blast(canvas, hit, Colors.white, age, 0.5, target.width * 0.18);
          _number(canvas, hit, '-${e.value}', colour, age);
        }
      case CombatEventKind.railDeflected:
        // The slug hits the shield's edge and skips off into space.
        final edge = Offset.lerp(target.centre, from, 0.42)!;
        final d = edge - from;
        final turn = (_jitter(i, 5) < 0.5 ? -1 : 1) * 0.9;
        final away = Offset(
          d.dx * cos(turn) - d.dy * sin(turn),
          d.dx * sin(turn) + d.dy * cos(turn),
        );
        _rail(canvas, from, edge, age);
        _rail(canvas, edge, edge + away * 1.5, age - 0.03, faint: true);
        _rings(canvas, edge, _shieldColour, age, 0.3, target.width * 0.08);
        _number(canvas, edge, 'deflected', _shieldColour, age, small: true);
      case CombatEventKind.boarded:
        break; // Drawn over everything by [_ending].
      case CombatEventKind.shieldsCharged || CombatEventKind.jamsReady:
        break;
    }
  }

  bool _isLance(CombatEvent e) =>
      _slots(e.side)[e.slot]?.startsWith('lance') ?? false;

  void _beam(
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
  void _rail(
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

  void _bolt(
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
    final normal =
        Offset(-(to - from).dy, (to - from).dx) / (to - from).distance;
    final path = Path()..moveTo(from.dx, from.dy);
    const steps = 9;
    for (var k = 1; k < steps; k++) {
      // The bolt crackles: a new zigzag every few hundredths of a second.
      final wobble = (_jitter(i * 31 + k, (age * 30).floor()) - 0.5) * 24;
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
  Offset _arc(int i, Offset from, Offset to, double t) {
    final mid = Offset.lerp(from, to, 0.5)!;
    final d = to - from;
    final normal = Offset(-d.dy, d.dx) / max(d.distance, 1);
    final control = mid + normal * (d.distance * 0.25 * (_jitter(i, 3) - 0.5));
    final a = Offset.lerp(from, control, t)!;
    final b = Offset.lerp(control, to, t)!;
    return Offset.lerp(a, b, t)!;
  }

  void _missile(
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
      final p = _arc(i, from, to, tk);
      canvas.drawCircle(
        p,
        k == 0 ? 3.5 : 3 - k * 0.3,
        Paint()
          ..color = (k == 0 ? Colors.white : colour).withValues(
            alpha: 1 - k / 7,
          ),
      );
    }
  }

  void _fireball(
    Canvas canvas,
    int i,
    Offset from,
    Offset to,
    double age,
    double flight,
  ) {
    final t = (age + flight) / flight;
    if (t < 0 || t >= 1) return;
    final p = _arc(i, from, to, t);
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

  void _blast(
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

  void _rings(
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
  void _implosion(
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
      _blast(canvas, at, colour, age, flash, radius * 0.8);
    }
  }

  void _star(Canvas canvas, Offset at, Color colour, double age, double r) {
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

  void _diamond(Canvas canvas, Offset at, double r, Color colour) {
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
  void _number(
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

  // The end ---------------------------------------------------------------

  void _ending(Canvas canvas, Size size, List<_Ship> geo) {
    final result = record.result;
    final age = time - result.seconds;
    final boarded =
        result.events.isNotEmpty &&
        result.events.last.kind == CombatEventKind.boarded;
    if (boarded) {
      final since = time - result.events.last.time;
      if (since >= 0 && since < 1.6) {
        final fade = 1 - since / 1.6;
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = Palette.hell.withValues(alpha: 0.45 * fade),
        );
        final painter = TextPainter(
          text: TextSpan(
            text: 'NOBODY IS ABOARD',
            style: TextStyle(
              fontSize: 30,
              letterSpacing: 6,
              fontWeight: FontWeight.w900,
              color: Colors.white.withValues(alpha: fade),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: size.width);
        painter.paint(
          canvas,
          size.center(Offset.zero) -
              Offset(painter.width / 2, painter.height / 2),
        );
      }
      return;
    }
    if (age < 0 || result.outcome == CombatOutcome.escape) return;
    final loser = result.outcome == CombatOutcome.win ? 1 : 0;
    final ship = geo[loser];
    // A spread of blasts across the wreck, one after another.
    for (var k = 0; k < 7; k++) {
      final a = _jitter(k, 40) * 2 * pi;
      final r = _jitter(k, 41) * ship.width * 0.3;
      _blast(
        canvas,
        ship.centre + Offset(cos(a), sin(a)) * r,
        k.isEven ? const Color(0xFFFFB547) : Colors.white,
        age - k * 0.12,
        0.6,
        ship.width * (0.1 + _jitter(k, 42) * 0.1),
      );
    }
  }

  @override
  bool shouldRepaint(BattleEffects old) => true;
}

/// A ship's triforce on the effects layer.
class _Ship {
  _Ship(this.origin, this.width);
  final Offset origin;
  final double width;

  late final _slots = Triforce.slotCentres(width);
  double get _tile => width * 0.145;
  double get _height => (width - _tile) * sqrt(3) / 2;

  Offset get _top => origin + Offset(width / 2, _tile / 2);
  Offset get _left => origin + Offset(_tile / 2, _tile / 2 + _height);
  Offset get _right => origin + Offset(width - _tile / 2, _tile / 2 + _height);

  Offset slot(int i) => origin + _slots[i];

  /// The middle of the big triangle.
  Offset get centre => (_top + _left + _right) / 3;

  /// The shield: the triangle, swollen out past its slots.
  Path get bubble {
    Offset out(Offset p) => centre + (p - centre) * 1.16;
    final t = out(_top);
    final l = out(_left);
    final r = out(_right);
    return Path()
      ..moveTo(t.dx, t.dy)
      ..lineTo(r.dx, r.dy)
      ..lineTo(l.dx, l.dy)
      ..close();
  }
}
