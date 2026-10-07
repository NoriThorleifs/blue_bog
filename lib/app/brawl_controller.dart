import 'dart:math' show Random;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/brawl/brawl.dart';
import '../game/captain/species.dart';
import '../game/deck/loadout.dart';
import '../game/engine.dart' show IllegalMove;

final brawlEngineProvider = Provider((ref) => const BrawlEngine());

/// The brawl in progress, or null when not brawling.
final brawlProvider = NotifierProvider<BrawlController, BrawlState?>(
  BrawlController.new,
);

class BrawlController extends Notifier<BrawlState?> {
  @override
  BrawlState? build() => null;

  BrawlEngine get _engine => ref.read(brawlEngineProvider);

  void start(Species species, {int? seed}) =>
      state = _engine.start(species, seed: seed ?? Random().nextInt(1 << 30));

  void abandon() => state = null;

  String? buy(int offer) => _attempt((s) => _engine.buy(s, offer));
  String? sell(CardSpot spot) => _attempt((s) => _engine.sell(s, spot));
  String? arrange(CardSpot from, CardSpot to) =>
      _attempt((s) => _engine.arrange(s, from, to));
  String? reroll() => _attempt(_engine.reroll);
  String? repair() => _attempt(_engine.repair);
  String? upgradeHull() => _attempt(_engine.upgradeHull);
  String? launch() => _attempt(_engine.launch);
  String? choose(int index) => _attempt((s) => _engine.choose(s, index));
  String? proceed() => _attempt(_engine.proceed);
  String? use(CardSpot from, CardSpot to) =>
      _attempt((s) => _engine.use(s, from, to));

  /// Runs an action the player chose, returning why not if it's refused.
  String? _attempt(BrawlState Function(BrawlState) action) {
    final current = state;
    if (current == null) return null;
    try {
      state = action(current);
      return null;
    } on IllegalMove catch (e) {
      return e.message;
    }
  }
}
