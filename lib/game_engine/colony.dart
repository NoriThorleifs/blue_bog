import 'dart:math';

import 'deck/loadout.dart';
import 'rng.dart';

/// The human colony's rules, shared by story and brawl mode.
abstract final class Colony {
  /// Hull the humans patch between turns or fights: a little for every
  /// [humansPerHull] of them, plus whatever crawlspace crews do.
  static const humansPerHull = 12;

  /// The humans never patch the hull past this share of its maximum.
  static const patchCap = 0.75;

  /// The hull after the humans have patched [hull], given [humans] aboard
  /// and the ship's [stats].
  static int patched(int hull, int humans, ShipStats stats) {
    final cap = (stats.maxHull * patchCap).floor();
    final patch = humans ~/ humansPerHull + stats.crawlspace;
    return hull < cap && patch > 0 ? min(cap, hull + patch) : hull;
  }

  /// How many humans move into the colony's free housing: children born
  /// aboard wherever the ship is, and at a [station], adults signing on,
  /// more where humans live and the better the colony thinks of its
  /// captain.
  static ({int born, int joined}) growth({
    required int humans,
    required int housing,
    required int loyalty,
    required bool station,
    required bool humanStation,
    required GameRng rng,
  }) {
    final free = housing - humans;
    if (free <= 0) return (born: 0, joined: 0);
    final born = min(free, (humans * 0.01).ceil());
    if (!station) return (born: born, joined: 0);
    final share = (0.05 + 0.25 * loyalty / 100) * (humanStation ? 1 : 0.33);
    final joined = min(
      free - born,
      (free * share * rng.rangeDouble(0.5, 1.5)).round(),
    );
    return (born: born, joined: joined);
  }

  /// What the colony's businesses pay when the ship docks at a station: so
  /// many credits per hundred [humans], or a gamble on it.
  static int dividends(Loadout loadout, int humans, GameRng rng) {
    var paid = 0;
    for (final card in loadout.colonyCards) {
      if (card.dividend == 0) continue;
      final base = card.dividend * humans / 100;
      paid += (card.gamble ? base * rng.rangeDouble(0, 3) : base).round();
    }
    return paid;
  }
}
