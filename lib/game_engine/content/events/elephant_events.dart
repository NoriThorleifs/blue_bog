import '../../galaxy/galaxy.dart';
import '../../story/keys.dart';
import '../../story/rules.dart';
import '../../story/story.dart';

/// The House of the Elephant: shady, but mostly humans trying to build
/// their own spaceport on an asteroid near a sublight lane.
final elephantEvents = <GameEvent>[
  const GameEvent(
    id: 'elephant_trumpet',
    title: 'A trumpet in the dark',
    triggers: {Trigger.sublight},
    condition: AllOf([
      AnyOf([AtSystem(Sys.ghorDum), AtSystem(Sys.urGor)]),
      NoFlag(Flag.elephantFound),
    ]),
    text:
        'Halfway through the burn, the short-range radio picks up something '
        'nobody aboard recognises except the humans: an elephant trumpeting. '
        'It comes from a mine, one of many, strung around an asteroid well '
        'off the lane. Your humans are grinning.',
    choices: [
      Choice(
        'Mark it on the chart',
        outcomes: [
          Outcome(
            '"The House of the Elephant," your humans say. "They\'re all '
            'right. Mostly."',
            effects: [Reveal(Sys.elephantHq), SetFlag(Flag.elephantFound)],
          ),
        ],
      ),
    ],
  ),
  GameEvent(
    id: 'elephant_rumour',
    title: 'Rumours',
    triggers: const {Trigger.arrival, Trigger.hold},
    condition: const AllOf([
      AtTag(Tag.station),
      HumansAtLeast(1),
      NoFlag(Flag.elephantFound),
    ]),
    weight: 0.5,
    text:
        'Over a drink, a human trader complains about a rock off the '
        '{sys:ghor_dum} lane where the mines trumpet like elephants and the '
        'docking fees are criminal. "Best repair yard this side of the '
        'Center, though."',
    choices: [
      Choice.simple(
        'Buy the coordinates',
        'They are scrawled on a napkin. They are correct.',
        condition: const CreditsAtLeast(10),
        hint: '10 credits',
        effects: const [
          Credits(-10),
          Reveal(Sys.elephantHq),
          SetFlag(Flag.elephantFound),
        ],
      ),
      Choice.simple(
        'Let your humans ask around',
        'Your humans come back with the coordinates and a hangover.',
        condition: const BondAtLeast(30),
        effects: const [Reveal(Sys.elephantHq), SetFlag(Flag.elephantFound)],
      ),
      Choice.simple('Ignore it', 'Probably nonsense.'),
    ],
  ),
  GameEvent(
    id: 'elephant_mines',
    title: 'The minefield',
    condition: const AllOf([
      AtSystem(Sys.elephantHq),
      NoFlag(Flag.elephantWelcome),
    ]),
    always: true,
    once: false,
    text:
        'Every mine you pass trumpets at you over short-range radio. '
        'Further in, a bored human voice says: "This is the House of the '
        'Elephant. Lady Idun\'s rock, Lady Idun\'s rules. State your '
        'business or go around. The mines don\'t care which."',
    choices: [
      Choice(
        'Let your humans answer',
        condition: const HumansAtLeast(1),
        outcomes: [
          Outcome(
            'Your humans mention the Promethius, and that you treat them '
            'right. A channel through the mines lights up.',
            condition: const AllOf([
              BondAtLeast(25),
              NoFlag(Flag.elephantEnemy),
            ]),
            effects: const [SetFlag(Flag.elephantWelcome)],
          ),
          Outcome(
            '"Doesn\'t sound like it," says the voice. The mines keep '
            'trumpeting until you leave.',
            condition: const AnyOf([
              Not(BondAtLeast(25)),
              HasFlag(Flag.elephantEnemy),
            ]),
            effects: const [Retreat()],
          ),
        ],
      ),
      const Choice(
        'Push through the mines',
        outcomes: [
          Outcome(
            'The mines don\'t care. Then their ships come out to finish '
            'the job.',
            effects: [
              Hull(-90),
              SetFlag(Flag.elephantEnemy),
              Combat(
                'House of the Elephant pickets',
                8,
                win: [Credits(60), Note('Shot our way into Elephant Rock.')],
                lose: [Hull(-90), Retreat()],
              ),
            ],
          ),
        ],
      ),
      Choice.simple('Go around', 'You go around.', effects: const [Retreat()]),
    ],
  ),
  GameEvent(
    id: 'elephant_port',
    title: 'Elephant Rock',
    condition: const AllOf([
      AtSystem(Sys.elephantHq),
      HasFlag(Flag.elephantWelcome),
    ]),
    once: false,
    weight: 20,
    text:
        'Half a spaceport, bolted to an asteroid. Everything is for sale, '
        'nothing has a receipt, and the repair crews are excellent. Lady '
        'Idun the Giantess watches the docks from a balcony built for '
        'someone her size, which is to say very large.',
    choices: [
      Choice.simple(
        'Repairs, no questions asked',
        'Done by morning.',
        condition: const CreditsAtLeast(20),
        hint: '20 credits',
        effects: const [Credits(-20), Hull(225)],
      ),
      Choice.simple(
        'Sell what you picked up in Hell',
        'They don\'t ask where it came from. They pay well.',
        condition: const CounterAtLeast(Counter.hellbornAwareness, 1),
        effects: const [Credits(45)],
      ),
      Choice.simple(
        'Take on crew',
        'A few humans who want to see more of the galaxy than one rock.',
        condition: const CreditsAtLeast(10),
        hint: '10 credits',
        effects: const [Credits(-10), Humans(3), MaybeAgent(0.3)],
      ),
      Choice.simple(
        'Buy salvaged ship parts',
        'Nobody asks where it came from. Nobody tells you either.',
        condition: const CreditsAtLeast(30),
        hint: '30 credits',
        effects: const [Credits(-30), GrantCard('salvage')],
      ),
      Choice.simple('Just look around', 'Shady, you decide. But nice.'),
    ],
  ),
  GameEvent(
    id: 'elephant_raiders',
    title: 'The Elephant remembers',
    condition: const AllOf([
      HasFlag(Flag.elephantEnemy),
      AnyOf([AtTag(Tag.frontier), AtTag(Tag.gor)]),
    ]),
    once: false,
    weight: 1.5,
    text: 'Two House of the Elephant gunships drop in behind you, trumpeting.',
    choices: [
      const Choice(
        'Fight',
        outcomes: [
          Outcome(
            '',
            effects: [
              Combat(
                'House of the Elephant gunships',
                7,
                win: [Credits(40)],
                lose: [Hull(-105)],
              ),
            ],
          ),
        ],
      ),
      Choice.simple(
        'Pay for the dent you made in their minefield',
        'They take the money and the grudge with it.',
        condition: const CreditsAtLeast(50),
        hint: '50 credits',
        effects: const [Credits(-50), ClearFlag(Flag.elephantEnemy)],
      ),
    ],
  ),
];
