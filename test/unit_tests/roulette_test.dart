import 'dart:math';

import 'package:blue_bog/functions/roulette_motion.dart';
import 'package:blue_bog/game_engine/brawl/brawl.dart';
import 'package:blue_bog/game_engine/captain/species.dart';
import 'package:blue_bog/game_engine/engine.dart' show IllegalMove;
import 'package:blue_bog/game_engine/gambling/roulette.dart';
import 'package:flutter_test/flutter_test.dart';

const engine = BrawlEngine();

BrawlState at(String station) => engine.start(Species.tern, seed: 1).clone()
  ..station = station
  ..credits = 500;

void main() {
  test('the wheel has every number once, half red and half black', () {
    expect(wheelOrder.toSet(), {for (var n = 0; n <= 36; n++) n});
    expect([for (var n = 1; n <= 36; n++) n].where(isRed), hasLength(18));
    expect(isRed(0) || isBlack(0), isFalse);
  });

  test('payouts: even money on colours, 35 to 1 on numbers', () {
    expect(const RouletteBet(BetKind.red, 10).payout(32), 20);
    expect(const RouletteBet(BetKind.red, 10).payout(15), 0);
    expect(const RouletteBet(BetKind.black, 10).payout(15), 20);
    expect(const RouletteBet(BetKind.black, 10).payout(0), 0);
    expect(const RouletteBet(BetKind.number, 10, number: 17).payout(17), 360);
    expect(const RouletteBet(BetKind.number, 10).payout(0), 360);
  });

  test('the house edge is one pocket in 37', () {
    double average(RouletteBet bet) =>
        wheelOrder.fold(0, (t, n) => t + bet.payout(n)) / wheelOrder.length;
    expect(average(const RouletteBet(BetKind.red, 37)), 36);
    expect(average(const RouletteBet(BetKind.number, 37, number: 5)), 36);
  });

  test('spinning moves credits and remembers the spin', () {
    final s = at('orcha');
    final after = engine.spinRoulette(s, const RouletteBet(BetKind.red, 25));
    final spin = after.lastSpin!;
    expect(after.credits, 500 + spin.net);
    expect(s.credits, 500, reason: 'the old state is untouched');
  });

  test('going all in ignores the table limit', () {
    final s = at('orcha');
    final after = engine.spinRoulette(s, const RouletteBet(BetKind.black, 500));
    expect(after.credits, after.lastSpin!.payout);
    expect([0, 1000], contains(after.credits));
  });

  test('roulette has table limits', () {
    expect(
      () => engine.spinRoulette(
        at('orcha'),
        const RouletteBet(BetKind.red, 1000),
      ),
      throwsA(isA<IllegalMove>()),
    );
    expect(
      () =>
          engine.spinRoulette(at('orcha'), const RouletteBet(BetKind.red, 100)),
      throwsA(isA<IllegalMove>()),
      reason: 'over the limit and not all in',
    );
    final broke = at('orcha')..credits = 4;
    expect(
      engine.spinRoulette(broke, const RouletteBet(BetKind.red, 4)).lastSpin,
      isNotNull,
      reason: 'all in is always allowed',
    );
    expect(
      () => engine.spinRoulette(broke, const RouletteBet(BetKind.red, 5)),
      throwsA(isA<IllegalMove>()),
    );
  });

  test('human stations run roulette, and the rest run 27', () {
    expect(stationGames.keys.toSet(), brawlStations.keys.toSet());
    expect(stationGames['orcha'], GamblingGame.roulette);
    expect(stationGames['kepler'], GamblingGame.roulette);
    expect(stationGames['ulaval'], GamblingGame.al);
  });

  test('the ball always comes to rest in the pocket the engine chose', () {
    double norm(double a) => ((a % (2 * pi)) + 2 * pi) % (2 * pi);
    final rng = Random(3);
    for (final n in wheelOrder) {
      final spin = RouletteSpin(const RouletteBet(BetKind.red, 5), n);
      final wheelFrom = rng.nextDouble() * 20;
      final ballFrom = rng.nextDouble() * 20 - 10;
      final target = pocketOf(n) * pocketAngle;
      for (final t in [0.8, 0.9, 1.0]) {
        final m = RouletteMotion.at(spin, wheelFrom, ballFrom, t);
        final offset = norm(m.ball - m.wheel - target);
        expect(
          min(offset, 2 * pi - offset),
          lessThan(1e-9),
          reason: '$n at $t',
        );
      }
      final start = RouletteMotion.at(spin, wheelFrom, ballFrom, 0);
      expect(start.ball - start.wheel, closeTo(ballFrom, 1e-9));
    }
  });
}
