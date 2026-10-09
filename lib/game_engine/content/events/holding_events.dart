import '../../combat/equipment.dart';
import '../../story/rules.dart';
import '../../story/story.dart';

/// Holding position anywhere, with nothing in particular going on. Most
/// repeat, and several scrape together credits or fuel, so a captain is
/// never stuck with no way forward.
final holdingEvents = <GameEvent>[
  const GameEvent(
    id: 'hold_debris',
    title: 'A debris field',
    triggers: {Trigger.hold},
    condition: NotInHell(),
    once: false,
    weight: 1.2,
    text:
        'Something broke up near here, long ago or last week. There is a '
        'drifting field of wreckage a short hop away, and nobody else has '
        'picked it over yet.',
    choices: [
      Choice(
        'Sift through it',
        outcomes: [
          Outcome(
            'Sealed crates, still good.',
            weight: 2,
            effects: [GrantCard('commodity')],
          ),
          Outcome(
            'A cache of ship supplies, still in their wrapping.',
            effects: [GrantCard('supplies')],
          ),
          Outcome(
            'Scrap metal. Somebody will buy it.',
            weight: 2,
            effects: [Credits(18)],
          ),
          Outcome(
            'The wreckage was not all the way dead. It took a bite out of '
            'the hull before your humans cut it apart.',
            effects: [Hull(-40), Credits(10)],
          ),
        ],
      ),
      Choice('Leave it be', outcomes: [Outcome('Someone else\'s luck.')]),
    ],
  ),
  GameEvent(
    id: 'hold_ice',
    title: 'Comet ice',
    triggers: const {Trigger.hold},
    condition: const NotInHell(),
    once: false,
    weight: 1,
    text:
        'A comet is passing through the system, trailing ice. Ice cracks '
        'into hydrogen, and hydrogen burns.',
    choices: [
      Choice.simple(
        'Crack it into fuel',
        'Slow, messy work. The tanks fill a little.',
        effects: const [Fuel(3)],
      ),
      Choice.simple(
        'Cut blocks to sell',
        'You stack the cargo bay with ice. Somewhere, someone is thirsty.',
        effects: const [GrantCard('goods_ice')],
      ),
      Choice.simple('Let it pass', 'It passes.'),
    ],
  ),
  GameEvent(
    id: 'hold_trader',
    title: 'A passing trader',
    triggers: const {Trigger.hold},
    condition: const NotInHell(),
    once: false,
    weight: 0.9,
    text:
        'A slow freighter matches course and offers to trade. Its captain '
        'has the relaxed manner of someone who knows you have no '
        'alternative.',
    choices: [
      Choice.simple(
        'Buy fuel at his prices',
        '"Pleasure doing business."',
        condition: const CreditsAtLeast(12),
        hint: '4 fuel for 12 credits',
        effects: const [Credits(-12), Fuel(4)],
      ),
      Choice.simple(
        'Sell him some cargo',
        'He pays a fair price, almost.',
        condition: const HasCardKind(CardKind.commodity),
        effects: const [SellCommodity(0.9)],
      ),
      Choice.simple('No thanks', 'He wanders off at three-quarters impulse.'),
    ],
  ),
  GameEvent(
    id: 'hold_survey',
    title: 'Survey work',
    triggers: const {Trigger.hold},
    condition: const NotInHell(),
    once: false,
    weight: 0.8,
    text:
        'The Republic\'s gateway survey office pays anyone who will point '
        'a sensor at the sky and send them the numbers. It is dull work. It '
        'pays.',
    choices: [
      Choice.simple(
        'Run the survey',
        'A day of sweeps and a modest payment.',
        effects: const [Credits(15)],
      ),
      Choice.simple(
        'Let your humans run it',
        'They finish in half the time, find three errors in the office\'s '
            'own charts, and are insufferable about it all evening.',
        condition: const HumansAtLeast(75),
        effects: const [Credits(22), Loyalty(2)],
      ),
    ],
  ),
  const GameEvent(
    id: 'hold_card_game',
    title: 'The card game',
    triggers: {Trigger.hold},
    condition: HumansAtLeast(50),
    once: false,
    weight: 0.8,
    text:
        'The humans have a card game going in the mess. It has rules that '
        'change depending on who is losing. They invite you to sit in.',
    choices: [
      Choice(
        'Play',
        outcomes: [
          Outcome(
            'You win. They insist that you cheated, and are delighted.',
            effects: [Credits(15), Loyalty(4)],
          ),
          Outcome(
            'You lose badly. They are gentle about it, which is worse.',
            weight: 1.5,
            effects: [Credits(-10), Loyalty(6), Drift(3)],
          ),
        ],
      ),
      Choice(
        'Watch',
        outcomes: [Outcome('You learn nothing. It\'s still fun.')],
      ),
    ],
  ),
  const GameEvent(
    id: 'hold_distress',
    title: 'A distress call',
    triggers: {Trigger.hold, Trigger.arrival},
    condition: NotInHell(),
    once: false,
    weight: 0.7,
    text:
        'A weak distress signal from a small ship with its engines out. '
        'It could be anyone. It could be bait.',
    choices: [
      Choice(
        'Answer it',
        outcomes: [
          Outcome(
            'A family of Bhrun traders, stranded for days. They pay you in '
            'goods and gratitude.',
            weight: 2,
            effects: [GrantCard('commodity'), Loyalty(3)],
          ),
          Outcome(
            'A crew of humans who lost their ship. They ask to move into '
            'your colony, and they do.',
            effects: [Humans(20), MaybeAgent(0.3)],
          ),
          Outcome(
            'It was bait.',
            effects: [
              Combat('pirates', 6, win: [Credits(30)], lose: [Credits(-20)]),
            ],
          ),
        ],
      ),
      Choice(
        'Ignore it',
        outcomes: [
          Outcome(
            'The signal fades. Your humans don\'t say anything.',
            effects: [Loyalty(-3)],
          ),
        ],
      ),
    ],
  ),
];
