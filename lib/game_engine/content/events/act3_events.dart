import '../../captain/species.dart';
import '../../galaxy/galaxy.dart';
import '../../story/keys.dart';
import '../../story/rules.dart';
import '../../story/story.dart';

/// Act 3: Kyndari, where the gatecrash began.
final act3Events = <GameEvent>[
  const GameEvent(
    id: 'kyndari_ruins',
    title: 'The ruins of Kyndari',
    condition: AtSystem(Sys.kyndari),
    weight: 5,
    text:
        'The demons stripped Kyndari of everything they wanted and left '
        'the rest. Deep in the ruins there is a chart of the gateway '
        'network as it was before the gatecrash, and fresh human boot '
        'prints all around it.',
    choices: [
      Choice(
        'Search the ruins',
        outcomes: [
          Outcome(
            'You find Havi salvage worth a fortune.',
            weight: 2,
            effects: [Credits(80)],
          ),
          Outcome(
            'Something the demons left behind is still hungry.',
            effects: [Hull(-120), Credits(30)],
          ),
        ],
      ),
      Choice(
        'Ask your humans about the boot prints',
        outcomes: [
          Outcome(
            '"Surveyors, captain." They are lying, and they are lying '
            'warmly.',
            condition: BondAtLeast(40),
            effects: [Drift(6), AddCounter(Counter.hellbornAwareness, 1)],
          ),
          Outcome('"No idea, captain."', effects: [Loyalty(-2)]),
        ],
      ),
    ],
  ),
  GameEvent(
    id: 'eldest_secret',
    title: 'Your people\'s shame',
    condition: const AllOf([
      IsSpecies(Species.unfortunate),
      ActIs(3),
      NoFlag(Flag.eldestExposed),
    ]),
    weight: 5,
    text:
        'Your humans show you pictures of cave paintings from their home '
        'world, tens of thousands of years old. Among the hunters and the '
        'animals is your people\'s mark. They have known since the first '
        'day. They are not angry. They are waiting for you to say it.',
    choices: [
      Choice.simple(
        'Say it, publicly',
        'You tell the council what your people did at Sol. The Eldest will '
            'never forgive you. Your humans will never forget it.',
        effects: const [
          SetFlag(Flag.eldestExposed),
          AddCounter(Counter.republicStance, 12),
          Loyalty(25),
          Drift(10),
        ],
      ),
      Choice.simple(
        'Say nothing',
        'The silence goes on for a long time.',
        effects: const [Loyalty(-15)],
      ),
    ],
  ),
];
