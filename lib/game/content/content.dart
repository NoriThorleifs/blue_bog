import '../engine.dart';
import '../galaxy/galaxy.dart';
import '../run_state.dart';
import '../story/keys.dart';
import '../faction.dart';
import '../story/rules.dart';
import 'beats.dart';
import 'events_core.dart';
import 'events_factions.dart';
import 'faction_beats.dart';
import 'events_galaxy.dart';

/// All written content, bundled for the engine.
final storyContent = StoryContent(
  events: [...coreEvents, ...galaxyEvents, ...factionEvents],
  beats: [...storyBeats, ...factionBeats],
  openingEvent: 'opening',
  hellEntryEvent: 'hell_breach',
  codeGreenEvent: 'code_green',
  mutinyEvent: 'mutiny',
  actHeadlines: const {
    2: (
      'Act II: Reunification',
      'With the Center\'s fourth gateway open, the Republic has remembered '
          'that it used to be bigger. Efforts are mounting to restore the '
          'old gateway network.',
    ),
    3: (
      'Act III: Kyndari',
      'A restored gateway has reconnected Kyndari, where the gatecrash '
          'began, to the network.',
    ),
  },
  endingFor: endingFor,
  codeEffects: const {
    Ending.codeRed: [
      SetFlag(Flag.warRed),
      SetControl(Sys.kyndari, Faction.hellborn),
      QueueEvent('war_red_begins'),
    ],
    Ending.codeYellow: [
      SetFlag(Flag.warYellow),
      Breach(Faction.demons, 3),
      QueueEvent('war_yellow_begins'),
    ],
  },
  extraHellRisk: _extraHellRisk,
);

/// Code Red if the Republic has turned on the humans, Code Blue if they
/// have a planet and the Republic's trust, otherwise Code Yellow.
Ending endingFor(RunState s) {
  final stance = s.counter(Counter.republicStance);
  if (s.has(Flag.keplerEvicted) || stance <= -30) return Ending.codeRed;
  if (s.has(Flag.humansGrantedPlanet) && stance >= 15) return Ending.codeBlue;
  return Ending.codeYellow;
}

double _extraHellRisk(RunState s, Gateway g) {
  final warPipe = g.touches(Sys.bhrunGai) && g.touches(Sys.ghorDum);
  final atWar = s.has(Flag.gorBhrunWar) && !s.has(Flag.gorBhrunWarOver);
  return warPipe && atWar ? 0.25 : 0;
}

String _held(RunState s, Faction f) {
  final n = s.control.values.where((c) => c == f).length;
  return n == 1 ? 'one system' : '$n systems';
}

/// Title and closing text for each ending.
(String, String) endingText(Ending ending, RunState s) => switch (ending) {
  Ending.codeBlue => (
    'Code Blue',
    'The humans have been accepted by the Republic and have become '
        'meaningful allies to it. Somewhere beyond Sol, a Hellborn '
        'empire stands down and settles in to wait. This is the good '
        'ending. There is still trouble ahead.',
  ),
  Ending.codeRed => (
    'Code Red',
    '${s.has(Flag.keplerEvicted) ? 'The Republic evicted the humans from '
                  'Kepler.' : 'The Republic decided the humans must be '
                  'contained, enslaved or worse.'} The human gateway at Kyndari '
        'opened wide, and what came through was not a colony ship. After '
        'nine turns of war the Hellborn hold ${_held(s, Faction.hellborn)}.',
  ),
  Ending.codeYellow => (
    'Code Yellow',
    'The humans are fighting an existential threat, and it is not the '
        'Republic. The gatecrash happened again: barriers failed and the '
        'demons spilled out of the gateways. After nine turns of war they '
        'hold ${_held(s, Faction.demons)}'
        '${s.has(Flag.hellbornAlly) ? ', and the Hellborn marching to meet '
                  'them have your ship\'s name on their lips' : ''}.',
  ),
  Ending.shipDestroyed => (
    'Ship lost',
    s.inHell
        ? 'Hell kept your ship. Nobody will ever know what happened.'
        : 'Your ship broke apart. The galaxy moved on without you.',
  ),
  Ending.mutiny => (
    'Mutiny',
    'The humans were serious about the reactor. HR was not, it turns '
        'out, an unimportant stat.',
  ),
};
