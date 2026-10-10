import 'dart:math';

import '../colony.dart';
import '../combat/catalog.dart';
import '../combat/equipment.dart';
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
    case ClearFlag(:final flag):
      s.flags.remove(flag);
    case ColonyChange(:final humans, :final loyalty, :final drift):
      final before = s.humans.count;
      s.humans = s.humans.copyWith(
        count: Colony.changed(before, humans, s.stats),
        loyalty: s.humans.loyalty + loyalty,
        drift: s.humans.drift + drift,
      );
      final moved = s.humans.count - before;
      if (moved > 0) lines.add('$moved humans joined the colony.');
      if (moved < 0) lines.add('${-moved} humans left the colony.');
    case GainCopy():
      final cards = [
        for (final id in s.loadout.slots.whereType<String>())
          if (equipmentById(id) case final e
              when e.merges && e.kind == CardKind.equipment)
            baseId(id),
      ];
      if (cards.isEmpty) {
        lines.add('There was nothing aboard worth copying.');
      } else {
        gainCard(s, rng.pick(cards), lines);
      }
    case GainAmmo():
      final ammo = [
        for (final id in s.loadout.slots.whereType<String>())
          if (_ammoFor[equipmentById(id).family] case final family?)
            '${family}_${equipmentById(id).tier.index + 1}',
      ];
      if (ammo.isEmpty) {
        lines.add('There was nothing aboard to load.');
      } else {
        gainCard(s, rng.pick(ammo), lines);
      }
    case HullUpgrade():
      s
        ..hullUpgrades += 1
        ..hull += ShipStats.hullPerUpgrade;
      lines.add('+${ShipStats.hullPerUpgrade} maximum hull, for good.');
    case MarkRound(:final key):
      s.counters[key] = s.round;
    case CellChange(:final amount):
      s.counters[hellbornCellKey] = max(0, s.hellbornCell + amount);
    case StartDraft():
      s.flags.add(draftOn);
      s.counters[draftRoundKey] = s.round;
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

/// The supplies each launcher family fires, for [GainAmmo].
const _ammoFor = {
  'missiles': 'missile_crate',
  'teleporter': 'teleport_charges',
  'fabricator': 'feedstock',
};
