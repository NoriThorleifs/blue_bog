/// European roulette: one zero, 37 pockets.
library;

/// The numbers in the order they sit around the wheel, clockwise from zero.
const wheelOrder = [
  0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, //
  5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26,
];

const _red = {
  1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36, //
};

bool isRed(int n) => _red.contains(n);
bool isBlack(int n) => n != 0 && !isRed(n);

/// The pocket a number sits in, counting clockwise from zero.
int pocketOf(int n) => wheelOrder.indexOf(n);

enum BetKind {
  red('Red', 1),
  black('Black', 1),
  number('Number', 35);

  const BetKind(this.label, this.odds);
  final String label;

  /// Paid per credit staked on a win, on top of the stake back.
  final int odds;
}

/// Bet sizes on offer. Going all in ignores the table limit: that is the
/// point of going all in.
const rouletteStakes = [25, 50];

class RouletteBet {
  const RouletteBet(this.kind, this.stake, {this.number = 0})
    : assert(kind != BetKind.number || (number >= 0 && number <= 36));

  final BetKind kind;
  final int stake;

  /// For a number bet: 0 to 36. Zero is a number bet on 0.
  final int number;

  bool wins(int result) => switch (kind) {
    BetKind.red => isRed(result),
    BetKind.black => isBlack(result),
    BetKind.number => result == number,
  };

  /// Credits handed back for [result]: the stake plus winnings, or nothing.
  int payout(int result) => wins(result) ? stake * (kind.odds + 1) : 0;

  String get label => switch (kind) {
    BetKind.number when number == 0 => 'Zero',
    BetKind.number => '$number',
    _ => kind.label,
  };
}

/// A finished spin, for the wheel to play back.
class RouletteSpin {
  const RouletteSpin(this.bet, this.result);
  final RouletteBet bet;

  /// The number the ball landed on.
  final int result;

  int get payout => bet.payout(result);
  int get net => payout - bet.stake;
}
