import 'dart:collection';
import 'dart:math' show max;

import '../galaxy/galaxy.dart';
import '../market.dart';
import '../rng.dart';
import '../run_state.dart';
import '../story/keys.dart';
import 'story_content.dart';

/// Working state for one engine action.
class EngineTurn {
  EngineTurn(this.s, this.rng, this.content);
  final RunState s;
  final GameRng rng;
  final StoryContent content;

  void log(LogKind kind, String text, {String? title}) =>
      s.log.add(LogEntry(s.turn, kind, text, title: title));
}

/// Rolls a fresh shop for this visit, if there's one here.
void openMarket(RunState s, GameRng rng) {
  final tags = s.here.tags;
  s.market = tags.contains(Tag.market) || tags.contains(Tag.tradingPost)
      ? Market.roll(
          s.location,
          rng,
          s.galaxy.seed,
          tradingPost: !tags.contains(Tag.market),
          time: s.turn,
        )
      : null;
}

void addCounter(RunState s, String counter, int amount) {
  final value = s.counter(counter) + amount;
  // Only the Republic's stance can go negative.
  s.counters[counter] = counter == Counter.republicStance
      ? value.clamp(-100, 100)
      : max(0, value);
}

double eventWeight(RunState s, double weight, double bondWeight) =>
    max(0, weight * (1 + bondWeight * s.humans.bond / 100));

/// Systems reachable from the Center through working gateways.
Set<String> gatewayNetwork(RunState s) {
  final seen = {Sys.center};
  final queue = Queue.of([Sys.center]);
  while (queue.isNotEmpty) {
    final id = queue.removeFirst();
    for (final g in s.galaxy.gatewaysOf(id)) {
      if (s.isGatewayActive(g) && seen.add(g.other(id))) {
        queue.add(g.other(id));
      }
    }
  }
  return seen;
}
