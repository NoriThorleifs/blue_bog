import '../../captain/species.dart';
import '../../galaxy/galaxy.dart';
import '../../run_state.dart';
import '../../story/keys.dart';
import '../../story/rules.dart';
import '../../story/story.dart';

/// Act 2: Træ Træ Tene, Úlamora and the restored gateway network.
final act2Events = <GameEvent>[
  const GameEvent(
    id: 'trae_contact',
    title: 'Cut off since the gatecrash',
    condition: AtSystem(Sys.traeTraeTene),
    weight: 5,
    text:
        'Træ Træ Tene has been alone for generations. The station crew '
        'want to know everything: who is alive, who is in charge, and '
        'what in the void a human is.',
    choices: [
      Choice(
        'Tell them everything',
        outcomes: [
          Outcome(
            'They pay for news in the old currency, which spends fine.',
            effects: [Credits(40), AddCounter(Counter.influence, 1)],
          ),
        ],
      ),
      Choice(
        'Let your humans introduce themselves',
        outcomes: [
          Outcome(
            'By the time you leave, there are three human bars on the '
            'station.',
            effects: [
              Loyalty(5),
              Drift(4),
              AddCounter(Counter.republicStance, 2),
            ],
          ),
        ],
      ),
    ],
  ),
  GameEvent(
    id: 'ulamora_homecoming',
    title: 'Úlamora',
    condition: const AtSystem(Sys.ulamora),
    weight: 5,
    text:
        'The Ál homeworld is all water, all tentacles, and very, very '
        'curious about your humans.',
    choices: [
      Choice.simple(
        'Come home',
        'Your people are delighted to see you, and more delighted by your '
            'crew. You leave with supplies and a dozen requests for '
            '"interviews".',
        condition: const IsSpecies(Species.al),
        effects: const [Credits(40), Hull(120), Drift(-5)],
      ),
      Choice.simple(
        'Rent your humans out for science',
        'Science pays. The humans have opinions about it.',
        effects: const [Credits(50), Loyalty(-8)],
      ),
      Choice.simple(
        'Keep the humans aboard',
        'They appreciate it.',
        effects: const [Loyalty(4)],
      ),
    ],
  ),
  GameEvent(
    id: 'tern_forge',
    title: 'Tern forge',
    condition: const AllOf([AtTag(Tag.tern), ActAtLeast(2)]),
    text:
        'A Tern forge offers to repair your hull with fresh nanobots. '
        'The price is calculated to a fraction of a credit.',
    choices: [
      Choice.simple(
        'Pay for repairs',
        'The hull knits itself back together.',
        condition: const CreditsAtLeast(27),
        hint: '27 credits',
        effects: const [Credits(-27), Hull(180)],
      ),
      Choice.simple(
        'Merge for a while',
        'You join the local hive for an afternoon and come back repaired '
            'and slightly less yourself.',
        condition: const IsSpecies(Species.tern),
        effects: const [Hull(270), Drift(-4)],
      ),
      Choice.simple('Decline', 'The forge hums on.'),
    ],
  ),
  GameEvent(
    id: 'the_revelation',
    title: 'The training program',
    triggers: const {Trigger.arrival, Trigger.hold},
    condition: const AllOf([
      IsSpecies(Species.tern),
      ActAtLeast(2),
      HasFlag(Flag.neoTerraClaimed),
      NoFlag(Flag.overseerSuspects),
      BondAtLeast(40),
    ]),
    weight: 4,
    text:
        'You are spending some time with your humans, and they have put '
        'on the training program every drafted human must watch. It tells '
        'soldiers to ignore radio calls from people they do not know and to '
        'report strange noises immediately.\n\n'
        'Consumers cannot imitate speech. They cannot mimic anything at '
        'all. As you think it through, everything begins to click into '
        'place, like an engine that has been running ragged and starts to '
        'fire on all cylinders.',
    choices: [
      Choice.simple(
        'Take it to the Overseer',
        'The Overseer hears you out in silence. Then it begins to prepare '
            'for a journey.',
        effects: const [
          SetFlag(Flag.overseerSuspects),
          SetFlag(Flag.captainFoundBroadcast),
          AddCounter(Counter.influence, 2),
        ],
      ),
      Choice.simple(
        'Ask your humans first',
        '"There\'s something under the capital, captain. It talks." They '
            'are relieved that someone finally asked.',
        effects: const [
          SetFlag(Flag.overseerSuspects),
          SetFlag(Flag.captainFoundBroadcast),
          Loyalty(15),
          Drift(8),
        ],
      ),
    ],
  ),
  GameEvent(
    id: 'kepler_lobbying',
    title: 'The Kepler question',
    condition: const AllOf([
      AtSystem(Sys.center),
      ActAtLeast(2),
      HasFlag(Flag.keplerTouchdown),
      NoFlag(Flag.keplerVoteHeld),
    ]),
    weight: 4,
    text:
        'The council will soon vote on whether the humans may stay on '
        'Kepler. Your crew is a well-known mixed crew, and delegates keep '
        'asking you what humans are really like.',
    choices: [
      Choice.simple(
        'Tell them the humans belong here',
        'You spend your influence freely. Delegates are listening.',
        condition: const CounterAtLeast(Counter.influence, 1),
        hint: '1 influence',
        effects: const [
          AddCounter(Counter.influence, -1),
          AddCounter(Counter.republicStance, 10),
          Loyalty(10),
        ],
      ),
      Choice.simple(
        'Tell them the truth: you have no idea what humans want',
        'It is honest, and it does the humans no favours.',
        effects: const [AddCounter(Counter.republicStance, -6), Loyalty(-6)],
      ),
      Choice.simple('Stay out of politics', 'Nobody quotes you.'),
    ],
  ),
  GameEvent(
    id: 'unfortunate_gate',
    title: 'You know how this works',
    condition: const AllOf([
      IsSpecies(Species.unfortunate),
      ActIs(2),
      TurnsInActAtLeast(4),
      AtDeadGateway(),
      NoFlag(Flag.captainFixedGate),
    ]),
    weight: 3,
    text:
        'There is a dead gateway in this system. You know, the way your '
        'people know these things, exactly what is wrong with it. Fixing '
        'it would mean admitting that you know.',
    choices: [
      Choice.simple(
        'Fix it',
        'It takes a night of quiet work and nobody sees you do it. '
            'Your humans see you do it.',
        effects: const [
          RestoreDeadGateway(here: true),
          SetFlag(Flag.captainFixedGate),
          Loyalty(10),
          Drift(5),
        ],
      ),
      Choice.simple(
        'Leave it',
        'The Eldest would approve. Your humans look at you like they know '
            'something.',
        effects: const [Loyalty(-4)],
      ),
    ],
  ),
  GameEvent(
    id: 'wrong_warp_lesson',
    title: 'Wrong warping lessons',
    condition: const AllOf([
      HasFlag(Flag.wrongWarping),
      AtTag(Tag.station),
      HumansAtLeast(75),
    ]),
    text:
        'One of your human pilots wants to show you how to hit a gateway '
        'at an angle no sane species would try.',
    choices: [
      const Choice(
        'Let them try',
        outcomes: [
          Outcome(
            'You arrive before Hell has finished taking you, with your cargo '
            'delivered early. Very early.',
            weight: 2,
            bondWeight: 0.5,
            effects: [Credits(50), Loyalty(8), Drift(6)],
          ),
          Outcome(
            'Hell finishes taking you.',
            effects: [EnterHell(HellZone.pipe)],
          ),
        ],
      ),
      Choice.simple(
        'Absolutely not',
        'They sulk.',
        effects: const [Loyalty(-3)],
      ),
    ],
  ),
];
