import 'brawl.dart';

/// What an outcome does to a brawl.
sealed class BrawlEffect {
  const BrawlEffect();
}

/// Credits gained, or lost if negative. Never below zero.
class GainCredits extends BrawlEffect {
  const GainCredits(this.amount);
  final int amount;
}

/// Hull repaired, or damage if negative. A [lethal] hit can destroy the
/// ship; otherwise it leaves at least 1 hull.
class HullChange extends BrawlEffect {
  const HullChange(this.amount, {this.lethal = true});
  final int amount;
  final bool lethal;
}

/// Cards for the ship. Without room they're left behind, unless [force]d
/// aboard in exchange for the ship's cheapest card.
class GainCards extends BrawlEffect {
  const GainCards(this.ids, {this.force = false});
  final List<String> ids;
  final bool force;
}

/// [count] cards picked at random from [pool].
class GainRandom extends BrawlEffect {
  const GainRandom(this.pool, {this.count = 1});
  final List<String> pool;
  final int count;
}

/// Loses a random card from the hold.
class LoseCargo extends BrawlEffect {
  const LoseCargo();
}

/// Replaces the fight that follows. With [demon] set, one of [demons];
/// with [special] set, that ship; otherwise the scheduled enemy,
/// [roundsAhead] fights early.
class Fight extends BrawlEffect {
  const Fight({
    this.demon,
    this.special,
    this.roundsAhead = 0,
    this.tractorBeam = false,
    this.scrap = 1,
    this.winCredits = 0,
    this.winCards = const [],
  });
  final int? demon;
  final SpecialEnemy? special;
  final int roundsAhead;

  /// No breaking away at the time limit: it's a fight to the death.
  final bool tractorBeam;

  /// Multiplies the scrap paid for a win.
  final double scrap;

  /// Paid on top of scrap for a win.
  final int winCredits;

  /// Taken for a win, forced aboard in place of the cheapest card if
  /// there's no room.
  final List<String> winCards;
}

/// No fight follows.
class NoFight extends BrawlEffect {
  const NoFight();
}

/// Through the barrier into Hell.
class EnterHell extends BrawlEffect {
  const EnterHell();
}

/// Out of Hell to a station. Hell's clocks move the ship's place in the
/// difficulty curve.
class LeaveHell extends BrawlEffect {
  const LeaveHell();
}

class SetFlag extends BrawlEffect {
  const SetFlag(this.flag);
  final String flag;
}

class Outcome {
  const Outcome(this.text, {this.weight = 1, this.effects = const []});
  final String text;
  final double weight;
  final List<BrawlEffect> effects;
}

class Choice {
  const Choice(this.label, this.outcomes, {this.available});
  final String label;
  final List<Outcome> outcomes;

  /// Whether the captain can pick this. Shown greyed out when not.
  final bool Function(BrawlState)? available;
}

class BrawlEvent {
  const BrawlEvent({
    required this.id,
    required this.title,
    required this.text,
    required this.choices,
    this.hell = false,
    this.always = false,
    this.weight,
    this.condition,
  });

  final String id;
  final String title;
  final String text;
  final List<Choice> choices;

  /// Met in Hell rather than on the way out of a station.
  final bool hell;

  /// Comes up ahead of anything else, in or out of Hell, whenever its
  /// [condition] holds.
  final bool always;
  final double Function(BrawlState)? weight;
  final bool Function(BrawlState)? condition;
}
