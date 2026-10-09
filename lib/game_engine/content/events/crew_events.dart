import '../../galaxy/galaxy.dart';
import '../../story/keys.dart';
import '../../story/rules.dart';
import '../../story/story.dart';

/// The humans aboard: who signs on, what they get up to, and who they
/// really are.
final crewEvents = <GameEvent>[
  GameEvent(
    id: 'odd_crewman',
    title: 'Stories that don\'t add up',
    triggers: const {Trigger.hold},
    condition: const HasFlag(Flag.hellbornAgentAboard),
    text:
        'One of your humans, a quiet engineer, tells the mess about growing '
        'up on the Promethius: a red sky through the viewports, clocks '
        'that ran the wrong way, a warm sea that smelled like brandy. The '
        'other humans have gone quiet. None of that sounds like a colony '
        'ship.',
    choices: [
      Choice.simple(
        'Ask where that was',
        'They laugh and say they were a strange child. They don\'t tell '
            'stories in the mess again.',
        effects: const [Loyalty(-2)],
      ),
      Choice.simple(
        'Let it go',
        'You let it go. They notice that you did.',
        effects: const [Loyalty(2)],
      ),
    ],
  ),
  GameEvent(
    id: 'human_recruits',
    title: 'Humans looking for a home',
    condition: const AllOf([AtTag(Tag.humans), NotInHell(), HousingFree(40)]),
    once: false,
    bondWeight: 0.5,
    text:
        'A few families are asking around the docks for room on a ship. '
        'They have heard about your colony, for better or worse.',
    choices: [
      Choice.simple(
        'Take them in',
        'They bring their own tools and their own opinions.',
        effects: const [Humans(40), Loyalty(2), MaybeAgent(0.3)],
      ),
      Choice.simple('Not today', 'They try the next ship over.'),
    ],
  ),
  const GameEvent(
    id: 'culture_night',
    title: 'Whose holiday?',
    triggers: {Trigger.hold},
    condition: HumansAtLeast(25),
    once: false,
    weight: 1.5,
    text:
        'The humans are celebrating something they won\'t explain, '
        'with food that is technically legal. By coincidence it is also a '
        'holiday for your people.',
    choices: [
      Choice(
        'Join the humans\' party',
        outcomes: [
          Outcome(
            'You are terrible at it. They love that you tried.',
            effects: [Drift(8), Loyalty(6)],
          ),
        ],
      ),
      Choice(
        'Host your own culture\'s celebration',
        outcomes: [
          Outcome(
            'The humans join in with an enthusiasm that is almost suspicious.',
            effects: [Drift(-8), Loyalty(3)],
          ),
        ],
      ),
    ],
  ),
  const GameEvent(
    id: 'the_helmet',
    title: 'The old soldier',
    triggers: {Trigger.hold},
    condition: AllOf([HumansAtLeast(75), HasFlag(Flag.orchaRaid)]),
    text:
        'One of the older humans has a helmet that locks at the back and '
        'needs someone else\'s key to remove. "It\'s a safety thing," he '
        'says, too quickly. Later you find him curled up in his chair, '
        'hands over his ears, listening to explosions that aren\'t there.',
    choices: [
      Choice(
        'Sit with him',
        outcomes: [
          Outcome(
            'You say nothing, and that is the right thing to say. Word '
            'gets around.',
            effects: [Loyalty(10), Drift(5)],
          ),
        ],
      ),
      Choice(
        'Leave him his dignity',
        outcomes: [
          Outcome(
            'You never mention it. Neither does he.',
            effects: [Loyalty(3)],
          ),
        ],
      ),
    ],
  ),
];
