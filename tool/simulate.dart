// ignore_for_file: avoid_print
// Plays the game headlessly with a random bot to check pacing and balance.
//
//   dart run tool/simulate.dart            # 2000 runs, summary only
//   dart run tool/simulate.dart 500        # 500 runs
//   dart run tool/simulate.dart story 42   # print the full log of seed 42
import 'dart:math';

import 'package:blue_bog/game_engine/captain/species.dart';
import 'package:blue_bog/game_engine/combat/catalog.dart';
import 'package:blue_bog/game_engine/content/content.dart';
import 'package:blue_bog/game_engine/engine.dart';
import 'package:blue_bog/game_engine/rng.dart';
import 'package:blue_bog/game_engine/run_state.dart';

final engine = GameEngine(storyContent);

void main(List<String> args) {
  if (args.firstOrNull == 'story') {
    final seed = int.parse(args.elementAtOrNull(1) ?? '1');
    final s = play(seed, Species.values[seed % Species.values.length]);
    for (final e in s.log) {
      final title = e.title == null ? '' : '${e.title}: ';
      print('[${e.turn}] ${e.kind.name.padRight(4)} $title${e.text}');
    }
    print('\nEnded on turn ${s.turn} with ${s.ending}');
    return;
  }

  final runs = int.tryParse(args.firstOrNull ?? '') ?? 2000;
  final endings = <String, int>{};
  final actTurns = {2: <int>[], 3: <int>[]};
  final lengths = <int>[];
  final hellVisits = <int>[];
  var codeGreens = 0;
  for (var seed = 0; seed < runs; seed++) {
    final s = play(seed, Species.values[seed % Species.values.length]);
    final key = s.ending?.name ?? 'unfinished';
    endings[key] = (endings[key] ?? 0) + 1;
    lengths.add(s.turn);
    if (s.has('code_green_used')) codeGreens++;
    hellVisits.add(s.log.where((e) => e.kind == LogKind.hell).length);
    for (final e in s.log) {
      final act = e.title?.startsWith('Act III') == true
          ? 3
          : e.title?.startsWith('Act II') == true
          ? 2
          : null;
      if (act != null) actTurns[act]!.add(e.turn);
    }
  }
  print('$runs runs');
  print(
    'Endings: ${endings.entries.map((e) => '${e.key} ${pct(e.value, runs)}').join(', ')}',
  );
  print('Run length: ${stats(lengths)}');
  print(
    'Act 2 starts: ${stats(actTurns[2]!)} (${pct(actTurns[2]!.length, runs)} of runs)',
  );
  print(
    'Act 3 starts: ${stats(actTurns[3]!)} (${pct(actTurns[3]!.length, runs)} of runs)',
  );
  print('Hell entries per run: ${stats(hellVisits)}');
  print('Code Green used: ${pct(codeGreens, runs)}');
}

/// A bot that picks uniformly at random among legal actions.
RunState play(int seed, Species species) {
  final bot = GameRng(seed * 7919 + 1);
  var s = engine.newRun(species, seed: seed);
  for (var step = 0; step < 2000 && !s.isOver; step++) {
    final pending = s.pending;
    if (pending != null) {
      s = pending.result != null
          ? engine.acknowledge(s)
          : engine.choose(s, pickChoice(s, bot));
    } else if (s.inHell) {
      s = engine.canCodeGreen(s) && bot.chance(0.7)
          ? engine.codeGreen(s)
          : engine.pressOn(s);
    } else {
      if (engine.fuelForSale(s) > 0) s = engine.refuel(s);
      s = shop(s);
      final routes = [
        for (final r in engine.routesFrom(s))
          if (engine.canTake(s, r)) r,
      ];
      s = routes.isEmpty || bot.chance(0.25)
          ? engine.hold(s)
          : engine.travel(s, bot.pick(routes).to);
    }
  }
  return s;
}

/// A random choice, but never a fight against a ship with more hull than
/// we have left, if there's any other option.
int pickChoice(RunState s, GameRng bot) {
  final choices = engine.choicesFor(s);
  final safe = [
    for (final (i, c) in choices.indexed)
      if ((engine.combatIn(s, c)?.hull ?? 0) <= s.hull) i,
  ];
  return safe.isEmpty ? bot.nextInt(choices.length) : bot.pick(safe);
}

/// What a cautious player does at a market: repair, then buy combat
/// equipment while keeping some credits back for fuel and wages.
RunState shop(RunState s) {
  if (engine.repairCost(s) != null && s.credits > 0) s = engine.repair(s);
  final market = s.market;
  if (market == null || s.pending != null) return s;
  for (final (i, offer) in market.offers.indexed) {
    final card = equipmentById(offer.cardId);
    final useful = card.action != null || card.hull > 0;
    if (!offer.sold && useful && s.credits - offer.price >= 40) {
      try {
        s = engine.buy(s, i);
      } on IllegalMove {
        // No room.
      }
    }
  }
  return s;
}

String pct(int n, int of) => '${(100 * n / of).toStringAsFixed(1)}%';

String stats(List<int> xs) {
  if (xs.isEmpty) return 'n/a';
  final sorted = [...xs]..sort();
  final mean = xs.reduce((a, b) => a + b) / xs.length;
  return 'mean ${mean.toStringAsFixed(1)}, median ${sorted[xs.length ~/ 2]}, '
      'min ${sorted.first}, max ${sorted.last}';
}

int maxOf(List<int> xs) => xs.reduce(max);
