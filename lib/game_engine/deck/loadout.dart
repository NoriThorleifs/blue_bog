import 'dart:math';

import '../combat/catalog.dart';
import '../combat/equipment.dart';

/// Where a card sits: one of the nine slots, the cargo bay slot, the hold,
/// or the colony grid.
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

/// The cargo bay's own slot, outside the triforce.
class CargoSpot extends CardSpot {
  const CargoSpot();
  @override
  bool operator ==(Object other) => other is CargoSpot;
  @override
  int get hashCode => 999;
}

class ColonySpot extends CardSpot {
  const ColonySpot(this.index);
  final int index;
  @override
  bool operator ==(Object other) => other is ColonySpot && other.index == index;
  @override
  int get hashCode => 1000 + index;
}

/// The ship's cards.
///
/// Nine slots, arranged as three small triangles that make one big one,
/// like a triforce: slots 0–2 are the top triangle, 3–5 the bottom left,
/// 6–8 the bottom right. Equipment only works in a slot. Supplies work
/// from a slot or the hold.
///
/// The hold has no room at all until a cargo pod goes in the cargo bay, a
/// slot of its own outside the triforce. Only the pod there counts; spare
/// pods wait in the hold or a slot until three of them merge. Three copies
/// of a card anywhere merge into one of the next tier.
///
/// The human colony has its own grid, [colonySide] by [colonySide], that
/// never fights. Only colony cards fit there, and they fit nowhere else but
/// the hold.
class Loadout {
  Loadout({
    List<String?>? slots,
    this.cargo,
    List<String>? hold,
    List<String?>? colony,
  }) : slots = slots ?? List.filled(slotCount, null),
       hold = hold ?? [],
       colony = colony ?? List.filled(colonyCount, null);

  static const slotCount = 9;
  static const colonySide = 3;
  static const colonyCount = colonySide * colonySide;

  final List<String?> slots;

  /// The cargo pod in the cargo bay slot.
  String? cargo;
  final List<String> hold;
  final List<String?> colony;

  Loadout copy() => Loadout(
    slots: [...slots],
    cargo: cargo,
    hold: [...hold],
    colony: [...colony],
  );

  Iterable<String> get all => [
    ...slots.whereType<String>(),
    ?cargo,
    ...hold,
    ...colony.whereType<String>(),
  ];

  /// Every spot with a card in it: slots, cargo bay, hold, then colony.
  Iterable<CardSpot> get occupiedSpots => [
    for (var i = 0; i < slotCount; i++)
      if (slots[i] != null) SlotSpot(i),
    if (cargo != null) const CargoSpot(),
    for (var i = 0; i < hold.length; i++) HoldSpot(i),
    for (var i = 0; i < colonyCount; i++)
      if (colony[i] != null) ColonySpot(i),
  ];

  /// The colony's cards, working in its grid.
  Iterable<Equipment> get colonyCards =>
      colony.whereType<String>().map(equipmentById);

  /// Whether [id] may sit at [spot]: colony cards only in the colony grid
  /// or the hold, and nothing else in the colony grid; nothing but cargo
  /// pods in the cargo bay.
  static bool fits(String id, CardSpot spot) {
    final card = equipmentById(id);
    final colonyCard = card.kind == CardKind.colony;
    return switch (spot) {
      ColonySpot() => colonyCard,
      CargoSpot() => card.isCargoBay,
      SlotSpot() => !colonyCard,
      HoldSpot() => true,
    };
  }

  /// Why swapping the cards at [from] and [to] would put one where it
  /// doesn't fit, or null if it wouldn't.
  String? whyNotMove(CardSpot from, CardSpot to) {
    final a = at(from);
    if (a == null) return 'Nothing there';
    final b = at(to);
    for (final (id, spot) in [(a, to), if (b != null) (b, from)]) {
      if (fits(id, spot)) continue;
      return switch (spot) {
        CargoSpot() => 'Only a cargo pod goes in the cargo bay',
        ColonySpot() => 'Only colony cards go in the colony',
        _ => 'Colony cards only go in the colony',
      };
    }
    return null;
  }

  /// Copies of a card, whatever tags they have picked up.
  int copiesOf(String id) => all.where((c) => baseId(c) == baseId(id)).length;

  Iterable<Equipment> get slotted =>
      slots.whereType<String>().map(equipmentById);

  /// Hold spaces from the cargo pod in the cargo bay.
  int get holdCapacity => cargo == null ? 0 : equipmentById(cargo!).hold;

  /// A snapshot for a fight. Copied, so salvage merged in afterwards
  /// doesn't change the fight's record.
  CombatLoadout get forCombat => CombatLoadout([...slots], hold: [...hold]);

  String? at(CardSpot spot) => switch (spot) {
    SlotSpot(:final index) => slots[index],
    CargoSpot() => cargo,
    HoldSpot(:final index) => index < hold.length ? hold[index] : null,
    ColonySpot(:final index) => colony[index],
  };

  /// Adds a card, merging triples. Cargo goes to the hold first, equipment
  /// to a free slot first. Returns what happened, for the log, or null if
  /// there was no room for it.
  ///
  /// Tagged and plain copies merge together, and the merged card keeps
  /// every tag any of the three had picked up.
  List<String>? add(String id, {SlotSpot? preferred}) {
    final card = equipmentById(id);
    final upgraded = upgradeOf(card);
    if (upgraded != null && copiesOf(id) >= 2) {
      final (freed, tags) = _removeCopies(id, 2);
      final next = equipmentById(
        taggedId(upgraded.id, {...tags, ...addedTags(id)}),
      );
      final rest = add(next.id, preferred: freed ?? preferred) ?? const [];
      return ['Three ${card.name} merged into ${next.name}.', ...rest];
    }
    final holdFree = hold.length < holdCapacity;
    if (card.isCargoBay && cargo == null) {
      cargo = id;
      return const [];
    }
    if (card.kind == CardKind.colony) {
      if (colony.contains(null)) {
        colony[colony.indexOf(null)] = id;
      } else if (holdFree) {
        hold.add(id);
      } else {
        return null;
      }
      return const [];
    }
    final toHold = card.kind != CardKind.equipment || card.isCargoBay;
    if (preferred != null && slots[preferred.index] == null) {
      slots[preferred.index] = id;
    } else if (toHold && holdFree) {
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
    if (inSlot >= 0) {
      slots[inSlot] = null;
      return true;
    }
    if (cargo == id) {
      cargo = null;
      return true;
    }
    final inColony = colony.indexOf(id);
    if (inColony < 0) return false;
    colony[inColony] = null;
    return true;
  }

  /// Removes [count] copies of [id], whatever their tags, hold first.
  /// Returns the first slot one was taken from, and the tags they had
  /// picked up.
  (SlotSpot?, Set<CardTag>) _removeCopies(String id, int count) {
    bool same(String? c) => c != null && baseId(c) == baseId(id);
    SlotSpot? freed;
    final tags = <CardTag>{};
    for (var n = 0; n < count; n++) {
      final inHold = hold.indexWhere(same);
      if (inHold >= 0) {
        tags.addAll(addedTags(hold.removeAt(inHold)));
        continue;
      }
      final inColony = colony.indexWhere(same);
      if (inColony >= 0) {
        colony[inColony] = null;
        continue;
      }
      if (same(cargo)) {
        tags.addAll(addedTags(cargo!));
        cargo = null;
        continue;
      }
      final inSlot = slots.indexWhere(same);
      tags.addAll(addedTags(slots[inSlot]!));
      slots[inSlot] = null;
      freed ??= SlotSpot(inSlot);
    }
    return (freed, tags);
  }

  /// Whether the card at [from] can be used on the card at [to].
  bool canUse(CardSpot from, CardSpot to) {
    final item = at(from);
    final target = at(to);
    if (item == null || target == null || from == to) return false;
    final tag = equipmentById(item).grantsTag;
    return tag != null && equipmentById(target).canTake(tag);
  }

  /// Uses up the card at [from], giving its tag to the card at [to]. See
  /// [Equipment.grantsTag]. Returns false if it can't.
  bool use(CardSpot from, CardSpot to) {
    if (!canUse(from, to)) return false;
    final tag = equipmentById(at(from)!).grantsTag!;
    _put(to, taggedId(at(to)!, {tag}));
    takeOut(from);
    return true;
  }

  void _put(CardSpot spot, String id) => switch (spot) {
    SlotSpot(:final index) => slots[index] = id,
    CargoSpot() => cargo = id,
    HoldSpot(:final index) => hold[index] = id,
    ColonySpot(:final index) => colony[index] = id,
  };

  /// Takes whatever is at [spot] off the ship, as when selling it.
  ///
  /// Emptying the cargo bay can leave the hold overfull. Then what doesn't
  /// fit drops into free slots, so selling your last pod with a crate
  /// aboard keeps the crate. Check [holdFits] after.
  void takeOut(CardSpot spot) {
    switch (spot) {
      case SlotSpot(:final index):
        slots[index] = null;
      case CargoSpot():
        cargo = null;
        while (hold.length > holdCapacity && slots.contains(null)) {
          slots[slots.indexOf(null)] = hold.removeLast();
        }
      case HoldSpot(:final index):
        hold.removeAt(index);
      case ColonySpot(:final index):
        colony[index] = null;
    }
  }

  /// Swaps whatever is at [from] and [to]. Moving onto an empty hold spot
  /// moves to the end of the hold, if there's room. Check [whyNotMove]
  /// first: this doesn't.
  void move(CardSpot from, CardSpot to) {
    final a = at(from);
    final b = at(to);
    if (a == null) return;
    if (b != null) {
      _put(from, b);
      _put(to, a);
    } else if (from is HoldSpot) {
      if (to is HoldSpot) return;
      hold.removeAt(from.index);
      _put(to, a);
    } else {
      _clear(from);
      if (to is HoldSpot) {
        hold.add(a);
      } else {
        _put(to, a);
      }
    }
  }

  /// Empties a slot or colony space.
  void _clear(CardSpot spot) => switch (spot) {
    SlotSpot(:final index) => slots[index] = null,
    CargoSpot() => cargo = null,
    ColonySpot(:final index) => colony[index] = null,
    HoldSpot() => throw ArgumentError('The hold has no empty spaces'),
  };

  /// Whether the hold fits what's in it. Taking the pod out of the cargo
  /// bay can leave it overfull.
  bool get holdFits => hold.length <= holdCapacity;
}

/// A ship's real stats: the shared hull plus every slotted card, and what
/// the colony grid adds.
class ShipStats {
  const ShipStats({
    required this.maxHull,
    required this.housing,
    required this.hospital,
    required this.crawlspace,
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
    int colony(int Function(Equipment) f) =>
        loadout.colonyCards.fold(0, (t, e) => t + f(e));
    return ShipStats(
      maxHull: baseHull + hullUpgrades * hullPerUpgrade + sum((e) => e.hull),
      housing: colony((e) => e.housing),
      hospital: colony((e) => e.hospital),
      crawlspace: colony((e) => e.crawlspace),
      hellShielding: min(0.9, gear.fold(0.0, (t, e) => t + e.hellShielding)),
      fuelCapacity: baseFuel + sum((e) => e.fuel),
      holdCapacity: loadout.holdCapacity,
    );
  }

  final int maxHull;

  /// Humans the colony has room for.
  final int housing;
  final int hospital;

  /// Hull the colony patches every turn, on top of what any humans do.
  final int crawlspace;
  final double hellShielding;
  final int fuelCapacity;
  final int holdCapacity;
}
