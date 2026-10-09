import 'dart:math';

import 'package:flutter/material.dart';

import '../../game_engine/combat/catalog.dart';
import '../../game_engine/combat/combat.dart';
import '../cards/card_widgets.dart';
import '../deck/triforce.dart';
import '../theme.dart';
import 'shot_painting.dart';

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

  Offset _impact(int i, _Ship target) {
    final a = jitter(i, 1) * 2 * pi;
    final r = jitter(i, 2) * target.width * 0.16;
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
      paintDiamond(canvas, p, 5, Palette.codeGreen);
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
        paintBeam(canvas, from, hit, colour, age, width: _isLance(e) ? 5 : 3);
        paintNumber(canvas, hit, '-${e.value}', colour, age);
      case CombatEventKind.laserAbsorbed:
        final edge = Offset.lerp(target.centre, from, 0.42)!;
        paintBeam(canvas, from, edge, colour, age, width: _isLance(e) ? 5 : 3);
        paintNumber(canvas, edge, 'blocked', _shieldColour, age, small: true);
      case CombatEventKind.ionHit:
        paintBolt(canvas, i, from, hit, colour, age);
        if ((e.value ?? 0) > 0) {
          paintNumber(canvas, hit, '-${e.value}', colour, age);
        }
      case CombatEventKind.missileHit:
        paintMissile(canvas, i, from, hit, colour, age, launchLead(e.kind));
        if (age >= 0) {
          paintBlast(canvas, hit, colour, age, 0.4, target.width * 0.12);
          paintNumber(canvas, hit, '-${e.value}', colour, age);
        }
      case CombatEventKind.missileIntercepted:
        // Shot down by a drone out on its orbit.
        final dir = from - target.centre;
        final stop = target.centre + dir / dir.distance * target.width * 0.45;
        paintMissile(canvas, i, from, stop, colour, age, launchLead(e.kind));
        if (age >= 0) {
          paintBlast(
            canvas,
            stop,
            Palette.codeGreen,
            age,
            0.3,
            target.width * 0.07,
          );
        }
      case CombatEventKind.hellfireHit:
        paintFireball(canvas, i, from, hit, age, launchLead(e.kind), time);
        if (age >= 0) {
          paintBlast(canvas, hit, hellishRed, age, 0.45, target.width * 0.14);
          paintBlast(canvas, from, hellishRed, age, 0.3, source.width * 0.06);
          paintNumber(canvas, hit, '-${e.value}', hellishRed, age);
        }
      case CombatEventKind.teleportHit:
        paintImplosion(canvas, hit, colour, age, target.width * 0.2);
        paintRings(canvas, from, colour, age, 0.3, source.width * 0.06);
        paintNumber(canvas, hit, '-${e.value}', colour, age);
      case CombatEventKind.teleportJammed:
        paintImplosion(canvas, hit, Palette.muted, age, target.width * 0.14);
        paintNumber(canvas, hit, 'jammed', Palette.muted, age, small: true);
      case CombatEventKind.flakHit || CombatEventKind.flakShrapnel:
        for (var k = 0; k < 3; k++) {
          final a = jitter(i, 10 + k) * 2 * pi;
          final p =
              target.centre +
              Offset(cos(a) * target.width * 0.42, sin(a) * target.width * 0.3);
          paintStar(canvas, p, colour, age - k * 0.07, target.width * 0.05);
        }
        if (e.kind == CombatEventKind.flakShrapnel && (e.value ?? 0) > 0) {
          paintNumber(canvas, hit, '-${e.value}', colour, age);
        }
      case CombatEventKind.repaired:
        paintNumber(
          canvas,
          source.centre,
          '+${e.value}',
          Palette.codeGreen,
          age,
        );
      case CombatEventKind.droneBuilt:
        paintRings(
          canvas,
          from,
          Palette.codeGreen,
          age,
          0.35,
          source.width * 0.05,
        );
      case CombatEventKind.outOfAmmo:
        paintNumber(canvas, from, 'empty', Palette.muted, age, small: true);
      case CombatEventKind.railHit:
        paintRail(canvas, from, hit, age);
        if (age >= 0) {
          paintBlast(canvas, hit, Colors.white, age, 0.5, target.width * 0.18);
          paintNumber(canvas, hit, '-${e.value}', colour, age);
        }
      case CombatEventKind.railDeflected:
        // The slug hits the shield's edge and skips off into space.
        final edge = Offset.lerp(target.centre, from, 0.42)!;
        final d = edge - from;
        final turn = (jitter(i, 5) < 0.5 ? -1 : 1) * 0.9;
        final away = Offset(
          d.dx * cos(turn) - d.dy * sin(turn),
          d.dx * sin(turn) + d.dy * cos(turn),
        );
        paintRail(canvas, from, edge, age);
        paintRail(canvas, edge, edge + away * 1.5, age - 0.03, faint: true);
        paintRings(canvas, edge, _shieldColour, age, 0.3, target.width * 0.08);
        paintNumber(canvas, edge, 'deflected', _shieldColour, age, small: true);
      case CombatEventKind.boarded:
        break; // Drawn over everything by [_ending].
      case CombatEventKind.shieldsCharged || CombatEventKind.jamsReady:
        break;
    }
  }

  bool _isLance(CombatEvent e) =>
      _slots(e.side)[e.slot]?.startsWith('lance') ?? false;

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
      final a = jitter(k, 40) * 2 * pi;
      final r = jitter(k, 41) * ship.width * 0.3;
      paintBlast(
        canvas,
        ship.centre + Offset(cos(a), sin(a)) * r,
        k.isEven ? const Color(0xFFFFB547) : Colors.white,
        age - k * 0.12,
        0.6,
        ship.width * (0.1 + jitter(k, 42) * 0.1),
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
