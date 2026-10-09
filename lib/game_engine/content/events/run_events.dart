import '../../captain/species.dart';
import '../../run_state.dart';
import '../../story/rules.dart';
import '../../story/story.dart';

/// The run's own moments, queued by the engine: the opening log, mutiny
/// and sending the code.
final runEvents = <GameEvent>[
  GameEvent(
    id: 'opening',
    title: 'Captain\'s log, turn one',
    triggers: const {Trigger.queued},
    text:
        'A battered colony ship called the Promethius crawled into the '
        'Kepler system at sublight, carrying a species nobody had heard of. '
        'Humans. They say they flew for six thousand years from a dying sun. '
        'The council at the Center has been arguing about what to do with '
        'them ever since.\n\n'
        'Meanwhile they live aboard the Promethius and at Orcha Station on '
        'temporary permits, and nobody will let them land. The council\'s '
        'compromise: each species elects one captain to take a colony of '
        'humans aboard. Your people elected you.\n\n'
        'The Republic paid for the retrofit. Hundreds of humans now live in '
        'the colony extension bolted to your hull, and they get everywhere. '
        'They are small, dense, friendly, armed and very, very good at math. '
        'They run their own affairs, but it is your ship, and they know it.',
    choices: [
      Choice.simple(
        'Welcome them properly',
        'You spend more than you should on a welcome feast. The humans '
            'seem to understand what it cost.',
        effects: const [MaybeAgent(0.25), Credits(-10), Loyalty(8)],
      ),
      Choice.simple(
        'Remind them who is captain',
        'They nod politely. One of them starts a list.',
        effects: const [MaybeAgent(0.25), Loyalty(-6), Drift(-5)],
      ),
      Choice.simple(
        'Ask them about their number system',
        'They count in tens. You count in threes. The argument lasts all '
            'night and nobody has ever enjoyed one more.',
        condition: const IsSpecies(Species.tern),
        effects: const [MaybeAgent(0.25), Loyalty(12), Drift(6)],
      ),
      Choice.simple(
        'Measure them',
        'You can\'t help it. The humans tolerate a full sensory survey with '
            'surprising good humour. One asks if you\'re going to buy them a '
            'drink first.',
        condition: const IsSpecies(Species.al),
        effects: const [MaybeAgent(0.25), Loyalty(4), Drift(3)],
      ),
    ],
  ),
  GameEvent(
    id: 'mutiny',
    title: 'The bridge door is welded shut',
    triggers: const {Trigger.queued},
    once: false,
    text:
        'The humans have sealed themselves into engineering and welded the '
        'bridge door shut, with you on the wrong side of it. Their '
        'spokesperson is very calm. They are prepared to vent the reactor '
        'if that is what it takes to be rid of you.',
    choices: [
      Choice.simple(
        'Pay them what they\'re owed, and then some',
        'The door is cut open. Nobody apologises, but the crew goes back '
            'to work.',
        condition: const CreditsAtLeast(30),
        hint: '30 credits',
        effects: const [Credits(-30), Loyalty(30)],
      ),
      const Choice(
        'Promise things will change',
        outcomes: [
          Outcome(
            'They believe you. Barely. You had better mean it.',
            weight: 2,
            bondWeight: 1,
            effects: [Loyalty(20), Drift(10)],
          ),
          Outcome(
            'They have heard that before. The reactor goes critical.',
            effects: [EndRun(Ending.mutiny)],
          ),
        ],
      ),
      const Choice(
        'Cut through the door',
        outcomes: [
          // Not a ship battle: a brawl in the corridors.
          Outcome(
            'You get through. The ringleaders end up in the airlock and the '
            'rest go back to work. Nobody will forget this.',
            effects: [Humans(-25), Loyalty(25), Note('Put down a mutiny.')],
          ),
          Outcome(
            'You get through the door. They were waiting on the other side.',
            effects: [EndRun(Ending.mutiny)],
          ),
        ],
      ),
      Choice.simple(
        'Let them off at the next port',
        'Every human aboard leaves. The ship is very quiet.',
        effects: const [Humans(-Humans.everyone), Loyalty(50)],
      ),
    ],
  ),
  GameEvent(
    id: 'the_code',
    title: 'The code',
    triggers: const {Trigger.queued},
    text:
        'Every human aboard stops what they are doing at the same moment. '
        'A short burst is moving through every gateway pipe in the network, '
        'one word repeated three times.\n\n'
        'Your humans tell you, with no expression at all, that the '
        'Promethius was never a colony ship. Its whole history was made up. '
        'Its captain carried four codes, one for each way the Republic '
        'might treat them. One of them has just been sent.',
    choices: [
      Choice.simple(
        'Ask which one',
        'They tell you.',
        effects: const [ResolveEnding()],
      ),
    ],
  ),
];
