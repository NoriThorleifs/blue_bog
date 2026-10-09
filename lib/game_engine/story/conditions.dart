import 'dart:math';

import '../captain/species.dart';
import '../combat/catalog.dart';
import '../combat/equipment.dart';
import '../faction.dart';
import '../galaxy/galaxy.dart';
import '../run_state.dart';

/// A test against the run state, used to gate events, choices, outcomes and
/// story beats.
sealed class Condition {
  const Condition();
  bool test(RunState s);
}

class HasFlag extends Condition {
  const HasFlag(this.flag);
  final String flag;
  @override
  bool test(RunState s) => s.has(flag);
}

class NoFlag extends Condition {
  const NoFlag(this.flag);
  final String flag;
  @override
  bool test(RunState s) => !s.has(flag);
}

class CounterAtLeast extends Condition {
  const CounterAtLeast(this.counter, this.value);
  final String counter;
  final int value;
  @override
  bool test(RunState s) => s.counter(counter) >= value;
}

class CounterBelow extends Condition {
  const CounterBelow(this.counter, this.value);
  final String counter;
  final int value;
  @override
  bool test(RunState s) => s.counter(counter) < value;
}

class ActAtLeast extends Condition {
  const ActAtLeast(this.act);
  final int act;
  @override
  bool test(RunState s) => s.act >= act;
}

class ActIs extends Condition {
  const ActIs(this.act);
  final int act;
  @override
  bool test(RunState s) => s.act == act;
}

class TurnAtLeast extends Condition {
  const TurnAtLeast(this.turn);
  final int turn;
  @override
  bool test(RunState s) => s.turn >= turn;
}

class TurnsInActAtLeast extends Condition {
  const TurnsInActAtLeast(this.turns);
  final int turns;
  @override
  bool test(RunState s) => s.turnsInAct >= turns;
}

/// In Hell, optionally in a specific zone.
class InHell extends Condition {
  const InHell([this.zone]);
  final HellZone? zone;
  @override
  bool test(RunState s) => s.inHell && (zone == null || s.hell == zone);
}

class NotInHell extends Condition {
  const NotInHell();
  @override
  bool test(RunState s) => !s.inHell;
}

class AtSystem extends Condition {
  const AtSystem(this.systemId);
  final String systemId;
  @override
  bool test(RunState s) => !s.inHell && s.location == systemId;
}

class AtTag extends Condition {
  const AtTag(this.tag);
  final String tag;
  @override
  bool test(RunState s) => !s.inHell && s.here.tags.contains(tag);
}

/// The current system has a gateway that doesn't work.
class AtDeadGateway extends Condition {
  const AtDeadGateway();
  @override
  bool test(RunState s) =>
      !s.inHell &&
      s.galaxy.gatewaysOf(s.location).any((g) => !s.isGatewayActive(g));
}

/// The ship can't afford any route out of here, and can't buy fuel here
/// either.
class Stranded extends Condition {
  const Stranded();
  @override
  bool test(RunState s) {
    if (s.inHell) return false;
    final here = s.location;
    final costs = [
      for (final g in s.galaxy.gatewaysOf(here))
        if (s.isGatewayActive(g)) gatewayFuelCost,
      for (final l in s.galaxy.lanesOf(here))
        if (s.revealed.contains(l.other(here))) sublightFuelCost,
    ];
    if (costs.isEmpty) return false;
    final cheapest = costs.reduce(min);
    if (s.fuel >= cheapest) return false;
    final canBuy =
        s.here.tags.contains(Tag.station) && s.credits >= cheapest - s.fuel;
    return !canBuy;
  }
}

/// Cargo is due here.
class DeliveryHere extends Condition {
  const DeliveryHere();
  @override
  bool test(RunState s) =>
      !s.inHell && s.deliveries.any((d) => d.to == s.location);
}

/// The captain is carrying cargo for [systemId].
class DeliveryTo extends Condition {
  const DeliveryTo(this.systemId);
  final String systemId;
  @override
  bool test(RunState s) => s.deliveries.any((d) => d.to == systemId);
}

/// The ship carries at least one card of this kind.
class HasCardKind extends Condition {
  const HasCardKind(this.kind);
  final CardKind kind;
  @override
  bool test(RunState s) => s.cards.any((id) => equipmentById(id).kind == kind);
}

/// The current system is controlled by [faction].
class ControlledBy extends Condition {
  const ControlledBy(this.faction);
  final Faction faction;
  @override
  bool test(RunState s) => !s.inHell && s.control[s.location] == faction;
}

/// The hull is at or below this fraction of its maximum.
class HullAtMost extends Condition {
  const HullAtMost(this.fraction);
  final double fraction;
  @override
  bool test(RunState s) => s.hull <= s.stats.maxHull * fraction;
}

class FuelBelow extends Condition {
  const FuelBelow(this.fuel);
  final int fuel;
  @override
  bool test(RunState s) => s.fuel < fuel;
}

/// The captain has at least as many credits as [counter] holds, say a debt.
class CanAffordCounter extends Condition {
  const CanAffordCounter(this.counter);
  final String counter;
  @override
  bool test(RunState s) => s.credits >= s.counter(counter);
}

class CreditsBelow extends Condition {
  const CreditsBelow(this.credits);
  final int credits;
  @override
  bool test(RunState s) => s.credits < credits;
}

class Visited extends Condition {
  const Visited(this.systemId);
  final String systemId;
  @override
  bool test(RunState s) => s.visited.contains(systemId);
}

class IsSpecies extends Condition {
  const IsSpecies(this.species);
  final Species species;
  @override
  bool test(RunState s) => s.species == species;
}

/// Hidden from the player: how bonded the humans aboard are to the captain.
class BondAtLeast extends Condition {
  const BondAtLeast(this.bond);
  final int bond;
  @override
  bool test(RunState s) => s.humans.bond >= bond;
}

class HumansAtLeast extends Condition {
  const HumansAtLeast(this.count);
  final int count;
  @override
  bool test(RunState s) => s.humans.count >= count;
}

class LoyaltyBelow extends Condition {
  const LoyaltyBelow(this.loyalty);
  final int loyalty;
  @override
  bool test(RunState s) => s.humans.loyalty < loyalty;
}

/// Positive means the captain has gone human; negative means the humans have
/// gone native.
class DriftAtLeast extends Condition {
  const DriftAtLeast(this.drift);
  final int drift;
  @override
  bool test(RunState s) => s.humans.drift >= drift;
}

class DriftAtMost extends Condition {
  const DriftAtMost(this.drift);
  final int drift;
  @override
  bool test(RunState s) => s.humans.drift <= drift;
}

class CreditsAtLeast extends Condition {
  const CreditsAtLeast(this.credits);
  final int credits;
  @override
  bool test(RunState s) => s.credits >= credits;
}

class AllOf extends Condition {
  const AllOf(this.conditions);
  final List<Condition> conditions;
  @override
  bool test(RunState s) => conditions.every((c) => c.test(s));
}

class AnyOf extends Condition {
  const AnyOf(this.conditions);
  final List<Condition> conditions;
  @override
  bool test(RunState s) => conditions.any((c) => c.test(s));
}

class Not extends Condition {
  const Not(this.condition);
  final Condition condition;
  @override
  bool test(RunState s) => !condition.test(s);
}
