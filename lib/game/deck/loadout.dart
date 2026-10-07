import 'dart:math';

import '../combat/catalog.dart';
import '../combat/equipment.dart';

/// Where a card sits: one of the nine slots, or the hold.
sealed class CardSpot {
  const CardSpot();
}

class SlotSpot extends CardSpot {
  const SlotSpot(this.index);
  final int index;
  @override
  bool operator ==(Object other) => other is SlotSpot && other.index == index;
  @override
  int get hashCode => index;
}

class HoldSpot extends CardSpot {
  const HoldSpot(this.index);
  final int index;
  @override
  bool operator ==(Object other) => other is HoldSpot && other.index == index;
  @override
  int get hashCode => -1 - index;
}

/// The ship's cards.
///
/// Nine slots, arranged as three small triangles that make one big one,
/// like a triforce: slots 0–2 are the top triangle, 3–5 the bottom left,
/// 6–8 the bottom right. Equipment only works in a slot. The hold starts
/// with no room at all; cargo pods add space. Supplies work from either.
/// Three copies of a card anywhere merge into one of the next tier.
class Loadout {
  Loadout({List<String?>? slots, List<String>? hold})
    : slots = slots ?? List.filled(slotCount, null),
      hold = hold ?? [];

  static const slotCount = 9;

  final List<String?> slots;
  final List<String> hold;

  Loadout copy() => Loadout(slots: [...slots], hold: [...hold]);

  Iterable<String> get all => [...slots.whereType<String>(), ...hold];
  int copiesOf(String id) => all.where((c) => c == id).length;

  Iterable<Equipment> get slotted =>
      slots.whereType<String>().map(equipmentById);

  /// Hold spaces from slotted cargo pods.
  int get holdCapacity => slotted
      .where((e) => e.kind == CardKind.equipment)
      .fold(0, (t, e) => t + e.hold);

  CombatLoadout get forCombat => CombatLoadout(slots, hold: hold);

  String? at(CardSpot spot) => switch (spot) {
    SlotSpot(:final index) => slots[index],
    HoldSpot(:final index) => index < hold.length ? hold[index] : null,
  };

  /// Adds a card, merging triples. Cargo goes to the hold first, equipment
  /// to a free slot first. Returns what happened, for the log, or null if
  /// there was no room for it.
  List<String>? add(String id, {SlotSpot? preferred}) {
    final card = equipmentById(id);
    final upgraded = upgradeOf(card);
    if (upgraded != null && copiesOf(id) >= 2) {
      final keep = _removeCopies(id, 2) ?? preferred;
      final rest = add(upgraded.id, preferred: keep) ?? const <String>[];
      return ['Three ${card.name} merged into ${upgraded.name}.', ...rest];
    }
    final cargo = card.kind != CardKind.equipment;
    final holdFree = hold.length < holdCapacity;
    if (preferred != null && slots[preferred.index] == null) {
      slots[preferred.index] = id;
    } else if (cargo && holdFree) {
      hold.add(id);
    } else if (slots.contains(null)) {
      slots[slots.indexOf(null)] = id;
    } else if (holdFree) {
      hold.add(id);
    } else {
      return null;
    }
    return const [];
  }

  /// Takes one copy of [id] off the ship, hold first. Returns false if
  /// there isn't one.
  bool remove(String id) {
    final inHold = hold.indexOf(id);
    if (inHold >= 0) {
      hold.removeAt(inHold);
      return true;
    }
    final inSlot = slots.indexOf(id);
    if (inSlot < 0) return false;
    slots[inSlot] = null;
    return true;
  }

  /// Removes [count] copies of [id], hold first, and returns the first slot
  /// one was taken from.
  SlotSpot? _removeCopies(String id, int count) {
    SlotSpot? freed;
    for (var n = 0; n < count; n++) {
      final inHold = hold.indexOf(id);
      if (inHold >= 0) {
        hold.removeAt(inHold);
        continue;
      }
      final inSlot = slots.indexOf(id);
      slots[inSlot] = null;
      freed ??= SlotSpot(inSlot);
    }
    return freed;
  }

  /// Swaps whatever is at [from] and [to]. Moving onto an empty hold spot
  /// moves to the end of the hold, if there's room.
  void move(CardSpot from, CardSpot to) {
    final a = at(from);
    final b = at(to);
    if (a == null) return;
    switch ((from, to)) {
      case (SlotSpot(index: final i), SlotSpot(index: final j)):
        slots[i] = b;
        slots[j] = a;
      case (SlotSpot(index: final i), HoldSpot(index: final j)):
        if (b == null) {
          hold.add(a);
        } else {
          hold[j] = a;
        }
        slots[i] = b;
      case (HoldSpot(index: final i), SlotSpot(index: final j)):
        if (b == null) {
          hold.removeAt(i);
        } else {
          hold[i] = b;
        }
        slots[j] = a;
      case (HoldSpot(index: final i), HoldSpot(index: final j)):
        if (b != null) {
          hold[i] = b;
          hold[j] = a;
        }
    }
  }

  /// Whether the hold fits what's in it. Pulling a cargo pod out of a slot
  /// can leave it overfull.
  bool get holdFits => hold.length <= holdCapacity;
}

/// A ship's real stats: the shared hull plus every slotted card.
class ShipStats {
  const ShipStats({
    required this.maxHull,
    required this.berths,
    required this.hospital,
    required this.hellShielding,
    required this.fuelCapacity,
    required this.holdCapacity,
  });

  /// Maximum hull gained per hull upgrade bought at a shipyard.
  static const hullPerUpgrade = 100;

  /// Fuel capacity before any tanks.
  static const baseFuel = 6;

  factory ShipStats.of(Loadout loadout, {int hullUpgrades = 0}) {
    final gear = loadout.slotted.where((e) => e.kind == CardKind.equipment);
    int sum(int Function(Equipment) f) => gear.fold(0, (t, e) => t + f(e));
    return ShipStats(
      maxHull: baseHull + hullUpgrades * hullPerUpgrade + sum((e) => e.hull),
      berths: sum((e) => e.berths),
      hospital: sum((e) => e.hospital),
      hellShielding: min(0.9, gear.fold(0.0, (t, e) => t + e.hellShielding)),
      fuelCapacity: baseFuel + sum((e) => e.fuel),
      holdCapacity: loadout.holdCapacity,
    );
  }

  final int maxHull;
  final int berths;
  final int hospital;
  final double hellShielding;
  final int fuelCapacity;
  final int holdCapacity;
}
