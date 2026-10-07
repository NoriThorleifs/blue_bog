import '../captain/species.dart';
import '../faction.dart';
import '../run_state.dart';

// Conditions --------------------------------------------------------------

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

// Effects -----------------------------------------------------------------

/// A change to the run. Effects are plain data; the engine applies them.
sealed class Effect {
  const Effect();
}

class Credits extends Effect {
  const Credits(this.amount);
  final int amount;
}

/// Adds fuel, up to the ship's capacity.
class Fuel extends Effect {
  const Fuel(this.amount);
  final int amount;
}

/// Pays off the debt in [counter] if the captain can afford it.
class SettleDebt extends Effect {
  const SettleDebt(this.counter);
  final String counter;
}

class Hull extends Effect {
  const Hull(this.amount);
  final int amount;
}

/// Humans join or leave, capped by the ship's berths.
class Humans extends Effect {
  const Humans(this.amount);
  final int amount;
}

class Loyalty extends Effect {
  const Loyalty(this.amount);
  final int amount;
}

/// Positive pulls the captain toward human culture, negative pulls the
/// humans toward the captain's.
class Drift extends Effect {
  const Drift(this.amount);
  final int amount;
}

class SetFlag extends Effect {
  const SetFlag(this.flag);
  final String flag;
}

class ClearFlag extends Effect {
  const ClearFlag(this.flag);
  final String flag;
}

class AddCounter extends Effect {
  const AddCounter(this.counter, this.amount);
  final String counter;
  final int amount;
}

class Reveal extends Effect {
  const Reveal(this.systemId);
  final String systemId;
}

class Rename extends Effect {
  const Rename(this.systemId, this.name);
  final String systemId;
  final String name;
}

/// Brings a specific dead gateway back online.
class RestoreGateway extends Effect {
  const RestoreGateway(this.a, this.b);
  final String a;
  final String b;
}

/// Brings a random dead gateway touching the known network back online.
///
/// Gateways leading into a later act's systems are only picked when
/// [towardAct] asks for that act, so ordinary restorations can't skip ahead.
/// With [here], only a gateway in the current system is restored, wherever
/// it leads: that is the captain's own doing.
class RestoreDeadGateway extends Effect {
  const RestoreDeadGateway({this.towardAct, this.here = false});
  final int? towardAct;
  final bool here;
}

/// Pulls the ship into Hell.
class EnterHell extends Effect {
  const EnterHell(this.zone);
  final HellZone zone;
}

/// Hands a system to another faction.
class SetControl extends Effect {
  const SetControl(this.systemId, this.faction);
  final String systemId;
  final Faction faction;
}

/// Spreads [faction] one hop along the gateway network: each gateway from a
/// system it holds to one it doesn't is taken with probability [chance].
/// With [throughDeadGateways], dead gateways count too, which is how things
/// that live in Hell travel.
class Expand extends Effect {
  const Expand(
    this.faction, {
    required this.chance,
    this.only,
    this.throughDeadGateways = false,
    this.verb = 'fell to',
  });
  final Faction faction;
  final double chance;

  /// For the news: "Orcha Station [verb] the Hellborn."
  final String verb;

  /// If set, only systems held by this faction can be taken.
  final Faction? only;
  final bool throughDeadGateways;
}

/// Hands every system with [tag] to [faction].
class ClaimTagged extends Effect {
  const ClaimTagged(this.tag, this.faction);
  final String tag;
  final Faction faction;
}

/// Hands everything [from] holds to [to].
class Transfer extends Effect {
  const Transfer(this.from, this.to);
  final Faction from;
  final Faction to;
}

/// With probability [chance], one of the humans just taken aboard is a
/// secret Hellborn agent.
class MaybeAgent extends Effect {
  const MaybeAgent(this.chance);
  final double chance;
}

/// Gives the captain a card from [pool]: `salvage` for a random basic card,
/// or a name in `cardPools`. Unique pools never repeat a card.
class GrantCard extends Effect {
  const GrantCard(this.pool);
  final String pool;
}

/// Tears open [pairs] random gateways from the Hell side. Both ends of each
/// fall to [faction] and the gateways open, dead or not.
class Breach extends Effect {
  const Breach(this.faction, this.pairs);
  final Faction faction;
  final int pairs;
}

/// Sends the ship back to the system it just came from.
class Retreat extends Effect {
  const Retreat();
}

/// Spits the ship out of a random gateway the act allows.
class EscapeHell extends Effect {
  const EscapeHell();
}

class QueueEvent extends Effect {
  const QueueEvent(this.eventId);
  final String eventId;
}

/// A line in the ship's log.
class Note extends Effect {
  const Note(this.text);
  final String text;
}

/// A real fight. See `fight` in `combat/combat.dart`.
class Combat extends Effect {
  const Combat(
    this.enemy,
    this.strength, {
    this.win = const [],
    this.lose = const [],
    this.tractorBeam = false,
  });
  final String enemy;

  /// Roughly 5 (a scout) to 14 (an elite); higher is a dreadnought. Scaled
  /// up with each act.
  final int strength;

  /// Applied on a win, after scrapping the enemy.
  final List<Effect> win;

  /// Applied when both ships get away at the time limit. Losing the fight
  /// outright destroys the ship.
  final List<Effect> lose;

  /// Story bosses: no escape at the time limit.
  final bool tractorBeam;
}

/// Ends the run with whichever code the state of the galaxy calls for.
class ResolveEnding extends Effect {
  const ResolveEnding();
}

class EndRun extends Effect {
  const EndRun(this.ending);
  final Ending ending;
}
