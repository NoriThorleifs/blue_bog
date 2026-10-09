import '../../galaxy/galaxy.dart';
import '../../story/keys.dart';
import '../../story/rules.dart';
import '../../story/story.dart';

/// The Consumers, and their secret: they are cockroaches from Sol, taken
/// and modified by the Eldest. The humans have always known who visited
/// them, and only something that looks like a cockroach will make them say
/// so.
final consumerEvents = <GameEvent>[
  GameEvent(
    id: 'consumer_scouts',
    title: 'Consumer scouts',
    condition: const AllOf([
      NotInHell(),
      AnyOf([AtTag(Tag.frontier), AtTag(Tag.ruins), AtTag(Tag.consumers)]),
      CounterAtLeast(Counter.consumerThreat, 1),
    ]),
    once: false,
    text:
        'A pack of Consumer scouts has found you. They are fast, hungry '
        'and new. Every generation they come back with something you '
        'haven\'t seen before.',
    choices: [
      const Choice(
        'Fight',
        outcomes: [
          Outcome(
            '',
            effects: [
              Combat(
                'Consumer scouts',
                5,
                win: [Credits(25), Loyalty(3)],
                lose: [Hull(-75)],
              ),
            ],
          ),
        ],
      ),
      Choice.simple(
        'Run',
        'You burn away. They chew some hull on the way.',
        effects: const [Hull(-30)],
      ),
    ],
  ),
  GameEvent(
    id: 'roach_hatchling',
    title: 'Something small',
    triggers: const {Trigger.queued},
    condition: const AllOf([HumansAtLeast(25), NoFlag(Flag.roachTruth)]),
    text:
        'One of the hatchlings from the crate escapes into the mess. It is '
        'barely the size of a thumb, brown, flat and very fast. Every human '
        'in the room goes silent. One of them stamps on it and says, very '
        'quietly, "That\'s a cockroach."',
    choices: _roachChoices,
  ),
  GameEvent(
    id: 'roach_stowaway',
    title: 'Something in the hydroponics',
    triggers: const {Trigger.hold},
    condition: const AllOf([
      HumansAtLeast(75),
      ActAtLeast(2),
      NoFlag(Flag.roachTruth),
      CounterAtLeast(Counter.consumerThreat, 1),
    ]),
    weight: 0.35,
    text:
        'A Consumer nymph got aboard at the last port and has been living '
        'in the hydroponics bay. Before its first moult it is small, brown '
        'and flat. Your humans gather round it like they are looking at a '
        'ghost. "That\'s a cockroach," one of them says. "That\'s just a '
        'cockroach."',
    choices: _roachChoices,
  ),
];

final _roachChoices = [
  const Choice(
    'Ask what a cockroach is',
    outcomes: [
      Outcome(
        'They look at each other, then tell you. Cockroaches are insects '
        'from Sol. The Consumers are cockroaches that someone took from '
        'Sol and changed. And they know who: their oldest cave paintings '
        'show visitors bearing the Unfortunates\' mark. They have known '
        'since first contact, and they have been waiting for someone to ask.',
        bondWeight: 1,
        condition: BondAtLeast(40),
        effects: [SetFlag(Flag.roachTruth), Drift(8), Loyalty(8)],
      ),
      Outcome(
        '"A bug from home, captain. Nothing important." They spend the '
        'rest of the night talking quietly among themselves.',
        effects: [Loyalty(-2)],
      ),
    ],
  ),
  Choice.simple(
    'Get it off the ship',
    'You space it. The humans don\'t argue, but they watch it go.',
  ),
];
