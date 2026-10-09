import 'dart:math';

import '../rng.dart';
import 'galaxy.dart';
import 'galaxy_attempt.dart';

/// Thrown when no valid galaxy could be generated for a seed. With the
/// current constraints this should never happen; it exists so a bad tweak
/// to the constraints fails loudly instead of looping forever.
class GalaxyGenerationError extends Error {
  GalaxyGenerationError(this.seed);
  final int seed;
  @override
  String toString() => 'No valid galaxy found for seed $seed';
}

/// Builds a random galaxy that always satisfies the lore constraints:
///
/// Act 1: the Center has three working gateways plus a dead one to
/// Træ Træ Tene. Kepler's only gateway goes to Bhrun-Gai, Bhrun-Gai's two go
/// to Kepler and Ghor-Dum, and Ghor-Dum has one more to somewhere random,
/// never more than two jumps from the Center. Neo Terra (sublight from
/// Orcha) and Ur-Gor (sublight from Ghor-Dum) have no gateways.
///
/// Act 2: Træ Træ Tene's network includes Úlamora, with Úlaval at sublight.
///
/// Act 3: Kyndari's network has a working gateway to Sol, which is at
/// sublight from Kepler. Dead gateways link the act 2 and act 3 networks so
/// restoring one can start act 3.
///
/// The Center is not at the galactic core. It sits off toward the edge,
/// 2600 ly from Sol, and the galaxy opens up away from it in later acts.
///
/// For a readable map, pipes (gateways and sublight lanes) never cross,
/// never pass right next to a system, and meet at a system at an angle of
/// at least [minPipeAngle]. A star holds at most four gateways, per
/// `lore/how FTL works.md`.
class GalaxyGenerator {
  static const maxGatewaysPerStar = 4;
  static const maxJumpsCenterToGhorDum = 2;
  static const minPipeAngle = 22.5 * pi / 180;

  /// How close a pipe may pass to a system it doesn't connect to.
  static const minPipeClearance = 50.0;
  static const galacticCore = Point(1486.0, 1400.0);
  static const solPosition = Point(1488.0, 2308.0);
  static const margin = 130.0;
  static const minSpacing = 130.0;

  Galaxy generate(int seed) {
    for (var attempt = 0; attempt < 3000; attempt++) {
      final rng = GameRng(seed ^ (attempt * 0x9E3779B9));
      final galaxy = GalaxyAttempt(rng, seed).build();
      if (galaxy != null) return galaxy;
    }
    throw GalaxyGenerationError(seed);
  }
}
