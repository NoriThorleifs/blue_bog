import 'dart:math';

import 'combat/equipment.dart';
import 'deck/loadout.dart';
import 'rng.dart';

/// The human colony's rules, shared by story and brawl mode.
abstract final class Colony {
  /// Hull the humans patch between turns or fights: a little for every
  /// [humansPerHull] of them, plus whatever crawlspace crews do.
  static const humansPerHull = 12;

  /// The humans never patch the hull past this share of its maximum,
  /// unless crawlspace crews know better (see [PatchCap]).
  static const patchCap = 0.75;

  /// The hull after the humans have patched [hull], given [humans] aboard
  /// and the ship's [stats].
  static int patched(int hull, int humans, ShipStats stats) {
    final cap = (stats.maxHull * stats.patchCap).floor();
    final patch = humans ~/ humansPerHull + stats.crawlspace;
    return hull < cap && patch > 0 ? min(cap, hull + patch) : hull;
  }

  /// The colony after [amount] humans join (or leave, if negative), capped
  /// by housing.
  static int changed(int humans, int amount, ShipStats stats) =>
      (humans + amount).clamp(0, stats.housing);

  /// A loss this big empties the colony.
  static const everyone = 1000000;

  /// The share of the colony born each time it grows, in percent: the
  /// usual [baseBirths], and more for every [hospital] level (see
  /// [birthsPerHospital]).
  static double birthRate(int hospital) =>
      baseBirths + min(hospital * birthsPerHospital, maxHospitalBirths);

  /// How many humans move into the colony's free housing: children born
  /// aboard wherever the ship is, more with [hospital]s (see [birthRate]),
  /// and at a [station], adults signing on, more where humans live, the
  /// better the colony thinks of its captain, and the more [signOn]
  /// (percentage points, see [SignOn]) the colony's cards add.
  static ({int born, int joined}) growth({
    required int humans,
    required int housing,
    required int loyalty,
    required bool station,
    required bool humanStation,
    required GameRng rng,
    int signOn = 0,
    int hospital = 0,
  }) {
    final free = housing - humans;
    if (free <= 0) return (born: 0, joined: 0);
    final born = min(free, (humans * birthRate(hospital) / 100).ceil());
    if (!station) return (born: born, joined: 0);
    final share =
        (0.05 + 0.25 * loyalty / 100 + signOn / 100) *
        (humanStation ? 1 : 0.33);
    final joined = min(
      free - born,
      (free * share * rng.rangeDouble(0.5, 1.5)).round(),
    );
    return (born: born, joined: joined);
  }

  /// What the colony's businesses pay when the ship docks at a station: so
  /// many credits per hundred [humans], or a gamble on it, plus any flat
  /// income (see [FlatIncome]).
  static int dividends(Loadout loadout, int humans, GameRng rng) {
    var paid = 0;
    for (final card in loadout.colonyCards) {
      for (final p in card.perks.whereType<FlatIncome>()) {
        paid += p.credits;
      }
      if (card.dividend == 0) continue;
      final base = card.dividend * humans / 100;
      paid += (card.gamble ? base * rng.rangeDouble(0, 3) : base).round();
    }
    return paid;
  }
}
