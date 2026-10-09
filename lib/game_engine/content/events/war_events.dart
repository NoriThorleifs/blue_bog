import '../../faction.dart';
import '../../story/keys.dart';
import '../../story/rules.dart';
import '../../story/story.dart';

/// The wars that follow Code Red and Code Yellow.
final warEvents = <GameEvent>[
  const GameEvent(
    id: 'war_red_begins',
    title: 'Code Red',
    triggers: {Trigger.queued},
    text:
        'Code Red. The Republic decided to be rid of the humans, and the '
        'humans have answered. Out of the gateway at Kyndari come ships '
        'that grew up in Hell, under the command of General Grönigen. They '
        'intend to take the galaxy, one gate at a time.',
    choices: [
      Choice('Brace', outcomes: [Outcome('Nine turns of war.')]),
    ],
  ),
  const GameEvent(
    id: 'war_yellow_begins',
    title: 'Code Yellow',
    triggers: {Trigger.queued},
    text:
        'Code Yellow. The humans are fighting something that isn\'t the '
        'Republic, and it has just broken through. The gatecrash is '
        'happening again: barriers are failing between random gate pairs, '
        'and the demons are spilling out.',
    choices: [
      Choice('Brace', outcomes: [Outcome('Nine turns of war.')]),
    ],
  ),
  GameEvent(
    id: 'hellborn_checkpoint',
    title: 'Hellborn checkpoint',
    condition: const AllOf([
      HasFlag(Flag.warRed),
      ControlledBy(Faction.hellborn),
    ]),
    always: true,
    once: false,
    text:
        'Hellborn warships hold this system. They are human, mostly. They '
        'are scanning you.',
    choices: [
      const Choice(
        'Let your humans speak for you',
        condition: HumansAtLeast(1),
        outcomes: [
          Outcome(
            'Your humans talk. The Hellborn listen, and wave you on.',
            condition: AnyOf([BondAtLeast(50), HasFlag(Flag.hellbornAlly)]),
          ),
          Outcome(
            'The Hellborn are not convinced. They escort you out.',
            condition: Not(
              AnyOf([BondAtLeast(50), HasFlag(Flag.hellbornAlly)]),
            ),
            effects: [Retreat()],
          ),
        ],
      ),
      const Choice(
        'Fight your way through',
        outcomes: [
          Outcome(
            '',
            effects: [
              Combat(
                'a Hellborn battle group',
                14,
                win: [Credits(80)],
                lose: [Hull(-180), Retreat()],
              ),
            ],
          ),
        ],
      ),
      Choice.simple('Retreat', 'You leave.', effects: const [Retreat()]),
    ],
  ),
  GameEvent(
    id: 'demon_infestation',
    title: 'Overrun',
    condition: const ControlledBy(Faction.demons),
    always: true,
    once: false,
    text:
        'This system belongs to Hell now. Metallic flesh is growing over '
        'the stations, and something with too many teeth is coming for you.',
    choices: [
      const Choice(
        'Fight',
        outcomes: [
          Outcome(
            '',
            effects: [
              Combat(
                'demons',
                11,
                win: [Credits(70)],
                lose: [Hull(-150), Retreat()],
              ),
            ],
          ),
        ],
      ),
      Choice.simple(
        'Run',
        'You get out, minus some hull.',
        effects: const [Hull(-60), Retreat()],
      ),
    ],
  ),
];
