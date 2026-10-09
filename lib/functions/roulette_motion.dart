import 'dart:math';

import 'package:flutter/material.dart';

import '../game_engine/gambling/roulette.dart';

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
