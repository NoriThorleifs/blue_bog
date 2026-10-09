import '../galaxy/galaxy.dart';
import '../run_state.dart';
import '../story/rules.dart';
import '../story/story.dart';

/// Everything the engine needs from the writers.
class StoryContent {
  const StoryContent({
    required this.events,
    required this.beats,
    required this.openingEvent,
    required this.hellEntryEvent,
    required this.codeGreenEvent,
    required this.mutinyEvent,
    required this.actHeadlines,
    required this.endingFor,
    this.codeEffects = const {},
    this.extraHellRisk,
  });

  final List<GameEvent> events;
  final List<StoryBeat> beats;

  /// Event ids the engine queues itself.
  final String openingEvent;
  final String hellEntryEvent;
  final String codeGreenEvent;
  final String mutinyEvent;

  /// News headline and text when an act begins, keyed by act number.
  final Map<int, (String, String)> actHeadlines;

  /// Picks Code Blue, Red or Yellow from the state of the galaxy.
  final Ending Function(RunState) endingFor;

  /// What happens when a code is sent. A code listed here doesn't end the
  /// run straight away: its effects start whatever comes next (a war, say),
  /// and story beats end the run later. Unlisted codes end the run at once.
  final Map<Ending, List<Effect>> codeEffects;

  /// Additional chance of falling into Hell on a specific gateway jump.
  final double Function(RunState, Gateway)? extraHellRisk;
}
