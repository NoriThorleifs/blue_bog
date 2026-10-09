import 'dart:math';

import '../combat/catalog.dart';
import '../deck/loadout.dart';
import '../rng.dart';
import 'brawl_events.dart';
import 'brawl_state.dart';

/// Applies one effect of a brawl event's choice.
void applyBrawlEffect(
  BrawlState s,
  GameRng rng,
  BrawlEffect effect,
  List<String> lines,
) {
  switch (effect) {
    case GainCredits(:final amount):
      s.credits = max(0, s.credits + amount);
    case HullChange(:final amount, :final lethal):
      s.hull = min(s.stats.maxHull, s.hull + amount);
      if (s.hull <= 0) {
        if (lethal) {
          s
            ..hull = 0
            ..lost = true;
          lines.add('Your ship breaks apart.');
        } else {
          s.hull = 1;
        }
      }
    case GainCards(:final ids, :final force):
      for (final id in ids) {
        gainCard(s, id, lines, force: force);
      }
    case GainRandom(:final pool, :final count):
      for (var i = 0; i < count; i++) {
        gainCard(s, rng.pick(pool), lines);
      }
    case LoseCargo():
      if (s.loadout.hold.isNotEmpty) {
        final i = rng.nextInt(s.loadout.hold.length);
        final id = s.loadout.hold.removeAt(i);
        lines.add('Lost ${equipmentById(id).name}.');
      }
    case Fight():
      s.plannedFight = effect;
    case NoFight():
      s.plannedFight = null;
    case EnterHell():
      s
        ..inHell = true
        ..hellTurns = 0
        ..plannedFight = null;
    case LeaveHell():
      s
        ..inHell = false
        ..leavingHell = true;
    case SetFlag(:final flag):
      s.flags.add(flag);
  }
}

void gainCard(
  BrawlState s,
  String id,
  List<String> lines, {
  bool force = false,
}) {
  final name = equipmentById(id).name;
  final merges = s.loadout.add(id);
  if (merges != null) {
    lines
      ..add('Gained $name.')
      ..addAll(merges);
    return;
  }
  if (!force) {
    s.wreckage.add(id);
    lines.add(wreckageNote([id]));
    return;
  }
  // No refusing this one: it takes the place of the cheapest card aboard
  // in a spot it fits, though never the pod that opens the hold.
  int price(CardSpot spot) => equipmentById(s.loadout.at(spot)!).price;
  final spot = s.loadout.occupiedSpots
      .where((spot) => spot is! CargoSpot && Loadout.fits(id, spot))
      .reduce((a, b) => price(a) <= price(b) ? a : b);
  final cheapest = s.loadout.at(spot)!;
  s.loadout.takeOut(spot);
  lines.add(
    'There was no room, so ${equipmentById(cheapest).name} is gone and '
    '$name is in its place.',
  );
  s.loadout.add(id);
}

/// Tells the captain what's waiting in the wreckage for want of room.
String wreckageNote(List<String> ids) {
  final names = [for (final id in ids) equipmentById(id).name].join(', ');
  return 'No room for $names. It waits in the wreckage until you move on: '
      'jettison something to take it.';
}
