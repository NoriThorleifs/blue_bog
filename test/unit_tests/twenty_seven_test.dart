import 'package:blue_bog/game_engine/brawl/brawl.dart';
import 'package:blue_bog/game_engine/captain/species.dart';
import 'package:blue_bog/game_engine/engine.dart' show IllegalMove;
import 'package:blue_bog/game_engine/gambling/twenty_seven.dart';
import 'package:blue_bog/game_engine/rng.dart';
import 'package:flutter_test/flutter_test.dart';

const engine = BrawlEngine();

BrawlState at(String station) => engine.start(Species.tern, seed: 1).clone()
  ..station = station
  ..credits = 500;

TwentySeven table(int count, List<int> triad, {int stake = 20}) => TwentySeven(
  stake: stake,
  count: count,
  deck: const [3, 3, 3, 3, 3, 3],
  triad: triad,
  status: CountStatus.counting,
);

void main() {
  test('one over a multiple of three busts, and so does passing 27', () {
    expect(
      [
        for (var n = 0; n <= 27; n++)
          if (busts(n)) n,
      ],
      [
        1, 4, 7, 10, 13, 16, 19, 22, 25, //
      ],
    );
    expect(busts(28), isTrue);
    expect(busts(29), isTrue);
    expect(busts(9) || busts(27), isFalse);
  });

  test('a deal uses a full deck of nine of each tile', () {
    final g = TwentySeven.deal(20, GameRng(4));
    final tiles = [...g.triad, ...g.deck]..sort();
    expect(tiles, [
      ...List.filled(9, 1),
      ...List.filled(9, 2),
      ...List.filled(9, 3),
    ]);
    expect(g.count, 0);
  });

  test('taking a tile adds it to the count', () {
    final rng = GameRng(1);
    expect(table(6, [3, 1, 2]).take(0, rng).status, CountStatus.holy);
    expect(table(6, [3, 1, 2]).take(1, rng).status, CountStatus.bust);
    final on = table(6, [3, 1, 2]).take(2, rng);
    expect(on.count, 8);
    expect(on.status, CountStatus.counting);
    expect(on.lastTriad, [3, 1, 2]);
    expect(on.lastPick, 2);
    expect(table(26, [2, 1, 3]).take(0, rng).status, CountStatus.bust);
    expect(table(24, [3]).take(0, rng).status, CountStatus.won);
  });

  test('9 pays 1.5 times the stake to walk away, 27 pays 4.5 times', () {
    final rng = GameRng(1);
    final nine = table(6, [3, 1, 2]).take(0, rng);
    expect(nine.walk().payout, 30);
    expect(table(24, [3]).take(0, rng).payout, 90);
    expect(table(6, [3, 1, 2]).take(1, rng).payout, 0);
    expect(nine.keepCounting(rng).status, CountStatus.counting);
  });

  test('the engine takes the stake up front and pays on a win', () {
    final s = engine.dealTwentySeven(at('ulaval'), 50);
    expect(s.credits, 450);
    expect(
      () => engine.dealTwentySeven(s, 20),
      throwsA(isA<IllegalMove>()),
      reason: 'one count at a time',
    );
    final rigged = s.clone()..twentySeven = table(24, [3], stake: 50);
    final won = engine.takeTile(rigged, 0);
    expect(won.credits, 450 + 225);
    expect(won.twentySeven!.status, CountStatus.won);
  });

  test('27 is played only where the Ál game runs, and all in is allowed', () {
    expect(
      () => engine.dealTwentySeven(at('orcha'), 20),
      throwsA(isA<IllegalMove>()),
    );
    expect(
      () => engine.dealTwentySeven(at('ulaval'), 30),
      throwsA(isA<IllegalMove>()),
    );
    expect(engine.dealTwentySeven(at('ulaval'), 500).credits, 0);
  });

  test('launching mid-count forfeits the stake', () {
    final s = engine.dealTwentySeven(at('ulaval'), 20);
    final gone = engine.launch(s);
    expect(gone.twentySeven, isNull);
    expect(gone.credits, 480);
  });

  test('walking at 9 returns close to the stake on average', () {
    final rng = GameRng(7);
    var paid = 0;
    const games = 20000;
    for (var i = 0; i < games; i++) {
      var g = TwentySeven.deal(100, rng);
      while (!g.over) {
        if (g.status == CountStatus.holy) {
          g = g.walk();
          continue;
        }
        final up = g.triad[0];
        final target = g.count < holyStop ? holyStop : holyGoal;
        final safe = !busts(g.count + up);
        final pick = safe && (g.count + up <= target || g.count > holyStop)
            ? 0
            : 1;
        g = g.take(pick, rng);
      }
      paid += g.payout;
    }
    final returned = paid / (games * 100);
    expect(returned, inInclusiveRange(0.85, 1.05));
  });
}
