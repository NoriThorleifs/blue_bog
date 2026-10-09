/// 27, the Ál counting game.
///
/// The count starts at zero. Each turn the dealer lays out a triad: three
/// tiles from a deck of nine Singles, nine Couples and nine Threes, one
/// face up and two face down. The captain takes one and adds it to the
/// count.
///
/// - One over a multiple of three (1, 4, 7 … 25) loses the stake.
/// - 9, Holy 2: walk away with 1.5 times the stake, or keep counting.
/// - 27, Holy 3: 4.5 times the stake.
/// - Past 27: the count overshot, and the stake is lost.
library;

import '../rng.dart';

/// Tile values: a Single, a Couple and a Three.
const tileValues = [1, 2, 3];

/// The two holy numbers that pay.
const holyStop = 9;
const holyGoal = 27;

/// Payouts, in halves of the stake: 3/2 at 9, 9/2 at 27.
int walkPayout(int stake) => stake * 3 ~/ 2;
int goalPayout(int stake) => stake * 9 ~/ 2;

/// Whether the count busts here: one over a multiple of three, or past 27.
bool busts(int count) => count % 3 == 1 || count > holyGoal;

/// Stakes on offer, as at the roulette table. All in is always allowed.
const twentySevenStakes = [20, 50];

enum CountStatus {
  /// Waiting for the captain to take a tile.
  counting,

  /// On 9: walk away or keep counting.
  holy,

  /// Busted: the stake is gone.
  bust,

  /// Walked away at 9.
  walked,

  /// Reached 27.
  won,
}

/// A game of 27 in progress, or just finished.
class TwentySeven {
  const TwentySeven({
    required this.stake,
    required this.count,
    required this.deck,
    required this.triad,
    required this.status,
    this.lastTriad,
    this.lastPick,
  });

  final int stake;
  final int count;

  /// Tiles still to be dealt, top first.
  final List<int> deck;

  /// The tiles on the table. The first is face up, the other two face down.
  final List<int> triad;
  final CountStatus status;

  /// The previous triad, all revealed, and which of its tiles was taken.
  final List<int>? lastTriad;
  final int? lastPick;

  bool get over => switch (status) {
    CountStatus.bust || CountStatus.walked || CountStatus.won => true,
    _ => false,
  };

  /// Credits handed back: the payout for walking or winning, else nothing.
  int get payout => switch (status) {
    CountStatus.walked => walkPayout(stake),
    CountStatus.won => goalPayout(stake),
    _ => 0,
  };

  /// A fresh game: a shuffled deck and the first triad.
  static TwentySeven deal(int stake, GameRng rng) {
    final deck = _fresh(rng);
    return TwentySeven(
      stake: stake,
      count: 0,
      deck: deck.sublist(3),
      triad: deck.sublist(0, 3),
      status: CountStatus.counting,
    );
  }

  static List<int> _fresh(GameRng rng) =>
      rng.shuffled([for (final v in tileValues) ...List.filled(9, v)]);

  /// Takes the tile at [index] of the triad.
  TwentySeven take(int index, GameRng rng) {
    assert(status == CountStatus.counting);
    final count = this.count + triad[index];
    final next = busts(count)
        ? CountStatus.bust
        : count == holyGoal
        ? CountStatus.won
        : count == holyStop
        ? CountStatus.holy
        : CountStatus.counting;
    return _next(count, next, rng, lastTriad: triad, lastPick: index);
  }

  /// On 9, keeps counting.
  TwentySeven keepCounting(GameRng rng) {
    assert(status == CountStatus.holy);
    return _next(count, CountStatus.counting, rng);
  }

  /// On 9, walks away with the payout.
  TwentySeven walk() {
    assert(status == CountStatus.holy);
    return TwentySeven(
      stake: stake,
      count: count,
      deck: deck,
      triad: triad,
      status: CountStatus.walked,
      lastTriad: lastTriad,
      lastPick: lastPick,
    );
  }

  TwentySeven _next(
    int count,
    CountStatus status,
    GameRng rng, {
    List<int>? lastTriad,
    int? lastPick,
  }) {
    var deck = this.deck;
    var triad = this.triad;
    // Deal the next triad only when there will be a next turn.
    if (status == CountStatus.counting) {
      if (deck.length < 3) deck = [...deck, ..._fresh(rng)];
      triad = deck.sublist(0, 3);
      deck = deck.sublist(3);
    }
    return TwentySeven(
      stake: stake,
      count: count,
      deck: deck,
      triad: triad,
      status: status,
      lastTriad: lastTriad ?? this.lastTriad,
      lastPick: lastPick ?? this.lastPick,
    );
  }
}
