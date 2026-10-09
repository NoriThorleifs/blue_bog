import '../faction.dart';
import '../run_state.dart';
import 'conditions.dart';

export 'conditions.dart';

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

/// Takes on [cardId] to deliver to a known station within two jumps, for
/// [reward] credits. If [preferWhen] holds and [prefer] is in reach, it's
/// almost always the destination.
class StartDelivery extends Effect {
  const StartDelivery(this.cardId, this.reward, {this.prefer, this.preferWhen});
  final String cardId;
  final int reward;
  final String? prefer;
  final Condition? preferWhen;
}

/// Hands over everything due here, and collects payment if [paid].
class CompleteDeliveries extends Effect {
  const CompleteDeliveries({this.paid = true});
  final bool paid;
}

/// Sells the most valuable commodity aboard at this system's going rate
/// times [markup]. Nothing happens if there's no cargo.
class SellCommodity extends Effect {
  const SellCommodity(this.markup);
  final double markup;
}

/// Gives the captain a card: `salvage` for a random basic piece of
/// equipment, `commodity` or `supplies` for one of those, `mourner` for a
/// unique gift, or a card id for that exact card.
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
