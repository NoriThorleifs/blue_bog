import 'dart:developer';
import 'dart:math' show Random;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game_engine/captain/species.dart';
import '../game_engine/content/content.dart';
import '../game_engine/deck/loadout.dart';
import '../game_engine/engine.dart';
import '../game_engine/run_state.dart';

final engineProvider = Provider((ref) => GameEngine(storyContent));

/// The run in progress, or null on the title screen.
final runProvider = NotifierProvider<RunController, RunState?>(
  RunController.new,
);

class RunController extends Notifier<RunState?> {
  @override
  RunState? build() => null;

  GameEngine get _engine => ref.read(engineProvider);

  void start(Species species, {int? seed}) =>
      state = _engine.newRun(species, seed: seed ?? Random().nextInt(1 << 30));

  void abandon() => state = null;

  void travel(String to) => _update((s) => _engine.travel(s, to));
  void hold() => _update(_engine.hold);
  void pressOn() => _update(_engine.pressOn);
  void codeGreen() => _update(_engine.codeGreen);
  void choose(int index) => _update((s) => _engine.choose(s, index));
  void acknowledge() => _update(_engine.acknowledge);
  void refuel() => _update(_engine.refuel);

  /// Moves a card. Returns why not, if the move isn't allowed.
  String? arrange(CardSpot from, CardSpot to) =>
      _attempt((s) => _engine.arrange(s, from, to));

  String? buy(int offer) => _attempt((s) => _engine.buy(s, offer));
  String? sell(CardSpot spot) => _attempt((s) => _engine.sell(s, spot));
  String? rerollMarket() => _attempt(_engine.rerollMarket);
  String? repair() => _attempt(_engine.repair);
  String? upgradeHull() => _attempt(_engine.upgradeHull);

  /// Runs an action the player chose, returning why not if it's refused.
  String? _attempt(RunState Function(RunState) action) {
    final current = state;
    if (current == null) return null;
    try {
      state = action(current);
      return null;
    } on IllegalMove catch (e) {
      return e.message;
    }
  }

  void _update(RunState Function(RunState) action) {
    final current = state;
    if (current == null) return;
    try {
      state = action(current);
    } on IllegalMove catch (e, stack) {
      // The UI only offers legal moves, so this means a double tap or a bug.
      log('Ignored illegal move', error: e, stackTrace: stack, name: 'run');
    }
  }
}
