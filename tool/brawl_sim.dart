// ignore_for_file: avoid_print
// Headless bot brawls, to check the difficulty curve and the economy.
//
//   dart run tool/brawl_sim.dart [runs]
import 'dart:math';

import 'package:blue_bog/game_engine/brawl/brawl.dart';
import 'package:blue_bog/game_engine/brawl/brawl_events.dart';
import 'package:blue_bog/game_engine/captain/species.dart';
import 'package:blue_bog/game_engine/combat/catalog.dart';
import 'package:blue_bog/game_engine/combat/equipment.dart';
import 'package:blue_bog/game_engine/deck/loadout.dart';
import 'package:blue_bog/game_engine/engine.dart' show IllegalMove;

const engine = BrawlEngine();

/// Sells cargo worth more here than usual, repairs, buys commodities that
/// are cheap here, then spends what's left on weapons and defences.
BrawlState shop(BrawlState s) {
  BrawlState attempt(BrawlState Function() f) {
    try {
      return f();
    } on IllegalMove {
      return s;
    }
  }

  for (var i = s.loadout.hold.length - 1; i >= 0; i--) {
    final id = s.loadout.hold[i];
    final card = equipmentById(id);
    if (card.kind == CardKind.commodity &&
        engine.sellValue(s, id) > engine.median(s, id)) {
      s = attempt(() => engine.sell(s, HoldSpot(i)));
    }
  }
  if (engine.repairCost(s) != null) s = attempt(() => engine.repair(s));
  for (final (i, offer) in s.market.offers.indexed) {
    final card = equipmentById(offer.cardId);
    if (offer.sold || s.credits - offer.price < 30) continue;
    final good = switch (card.kind) {
      CardKind.commodity =>
        offer.price < engine.median(s, offer.cardId) * 0.85 &&
            s.loadout.hold.length < s.loadout.holdCapacity,
      CardKind.equipment => card.action != null || card.hull > 0,
      _ => false,
    };
    if (good) s = attempt(() => engine.buy(s, i));
  }
  return s;
}

/// Plays one brawl. A [diver] takes every chance to dive into Hell and
/// otherwise picks at random; a careful bot always keeps going.
BrawlState play(Species species, int seed, {required bool diver}) {
  var s = engine.start(species, seed: seed);
  final rng = Random(seed);
  var steps = 0;
  while (!s.lost && s.fightsWon < 30 && steps++ < 500) {
    if (s.docked) {
      s = engine.launch(shop(s));
      continue;
    }
    if (s.awaitingVerdict) {
      s = engine.goEndless(s);
      continue;
    }
    if (s.result != null) {
      s = engine.proceed(s);
      continue;
    }
    final event = s.currentEvent!;
    final options = [
      for (var i = 0; i < event.choices.length; i++)
        if (engine.canChoose(s, i)) i,
    ];
    final pick = switch (event.id) {
      'chewer' => diver ? 1 : 0,
      _ when !diver => options.first,
      _ => options[rng.nextInt(options.length)],
    };
    s = engine.choose(s, pick);
  }
  return s;
}

void main(List<String> args) {
  final runs = args.isEmpty ? 500 : int.parse(args.first);
  for (final diver in [false, true]) {
    print(diver ? '\nDivers (into Hell at every chance):' : 'Careful bots:');
    for (final species in Species.values) {
      final won = <int>[];
      var orbs = 0;
      var diedInHell = 0;
      for (var seed = 0; seed < runs; seed++) {
        final s = play(species, seed, diver: diver);
        won.add(s.fightsWon);
        if (s.flags.contains(hasHellClock)) orbs++;
        if (s.lost && s.inHell) diedInHell++;
      }
      won.sort();
      String pct(int p) => '${won[(won.length - 1) * p ~/ 100]}';
      print(
        '  ${species.name.padRight(12)} fights won '
        'p10 ${pct(10)}  median ${pct(50)}  p90 ${pct(90)}  '
        'max ${won.last}   died in Hell ${100 * diedInHell ~/ runs}%  '
        'got the Hell Clock ${100 * orbs ~/ runs}%',
      );
    }
  }
}
