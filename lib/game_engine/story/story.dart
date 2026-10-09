import 'rules.dart';

/// When an event can come up.
enum Trigger {
  /// On arriving in a system.
  arrival,

  /// When holding position in a system for a turn.
  hold,

  /// Each turn spent in Hell.
  hell,

  /// Sometimes, on arriving at the end of a sublight burn.
  sublight,

  /// Only when queued explicitly by a story beat or another event.
  queued,
}

/// One possible result of a choice. When a choice has several outcomes, one
/// is picked at random by weight.
class Outcome {
  const Outcome(
    this.text, {
    this.effects = const [],
    this.weight = 1,
    this.bondWeight = 0,
    this.condition,
  });

  final String text;
  final List<Effect> effects;
  final double weight;

  /// Hidden influence of the humans aboard. The weight is multiplied by
  /// `1 + bondWeight * bond / 100`, so 1.0 doubles the odds at full bond and
  /// a negative value makes the outcome rarer the more the humans like you.
  final double bondWeight;
  final Condition? condition;
}

class Choice {
  const Choice(this.label, {required this.outcomes, this.condition, this.hint});

  /// A choice with a single, certain outcome.
  Choice.simple(
    String label,
    String text, {
    List<Effect> effects = const [],
    Condition? condition,
    String? hint,
  }) : this(
         label,
         outcomes: [Outcome(text, effects: effects)],
         condition: condition,
         hint: hint,
       );

  final String label;
  final List<Outcome> outcomes;

  /// Choices whose condition fails are hidden.
  final Condition? condition;

  /// Short note shown under the label, like a cost.
  final String? hint;
}

class GameEvent {
  const GameEvent({
    required this.id,
    required this.title,
    required this.text,
    required this.choices,
    this.triggers = const {Trigger.arrival},
    this.condition,
    this.weight = 1,
    this.bondWeight = 0,
    this.once = true,
    this.always = false,
  });

  final String id;
  final String title;
  final String text;
  final List<Choice> choices;
  final Set<Trigger> triggers;
  final Condition? condition;
  final double weight;

  /// Hidden human influence on how often this comes up. See
  /// [Outcome.bondWeight].
  final double bondWeight;
  final bool once;

  /// Arrival events only: fires on every arrival where its condition holds,
  /// instead of being one of the random candidates. For guards, blockades
  /// and other things you can't sneak past.
  final bool always;
}

/// Something that happens in the wider galaxy whether or not the captain is
/// involved. Beats are checked at the end of every turn.
class StoryBeat {
  const StoryBeat({
    required this.id,
    required this.headline,
    required this.condition,
    required this.chance,
    this.outcomes = const [],
    this.effects = const [],
    this.modifiers = const [],
    this.delay = 0,
    this.deadline,
    this.localEvent,
    this.repeatable = false,
  });

  final String id;
  final String headline;
  final Condition condition;

  /// Base chance per turn of firing once [condition] holds.
  final double chance;

  /// Multipliers on [chance] that apply when their condition holds. This is
  /// how the captain's choices and the humans aboard nudge the galaxy.
  final List<(Condition, double)> modifiers;

  /// Turns the condition must hold before the beat can fire at all, so
  /// that the captain has time to get involved.
  final int delay;

  /// If set, the beat fires anyway once its condition has held this many
  /// turns, so the story can't stall.
  final int? deadline;

  /// One of these is picked at random. Its text becomes the news report.
  final List<Outcome> outcomes;

  /// Applied whichever outcome happens.
  final List<Effect> effects;

  /// Event queued for the captain if they are where it happens.
  final (Condition where, String eventId)? localEvent;
  final bool repeatable;
}
