import '../../captain/species.dart';
import '../../galaxy/galaxy.dart';
import '../../run_state.dart';
import '../../story/keys.dart';
import '../../story/rules.dart';
import '../../story/story.dart';

/// Events story beats queue where the captain is, so they can take part
/// in the galaxy's timeline.
final storyBeatEvents = <GameEvent>[
  const GameEvent(
    id: 'raid_at_orcha',
    title: 'Raid at Orcha Station',
    triggers: {Trigger.queued},
    text:
        'Consumers pour through hull breaches on the promenade. Station '
        'security is falling back. Then the humans start ripping thin metal '
        'plates off the railings, and there are guns behind every one of '
        'them. The new safety standards suddenly make sense.\n\n'
        'Up ahead, a Consumer bull is charging a Bhrun.',
    choices: [
      Choice(
        'Fight alongside the humans',
        outcomes: [
          Outcome(
            '',
            effects: [
              Combat(
                'Consumer boarders',
                6,
                win: [
                  SetFlag(Flag.captainFoughtRaid),
                  Loyalty(15),
                  Drift(10),
                  Credits(30),
                  AddCounter(Counter.influence, 1),
                  Note(
                    'Fought beside the humans at Orcha. They chanted '
                    'something about ripping and tearing.',
                  ),
                ],
                lose: [SetFlag(Flag.captainFoughtRaid), Hull(-90), Loyalty(8)],
              ),
            ],
          ),
        ],
      ),
      Choice(
        'Get your ship out',
        outcomes: [
          Outcome(
            'You undock under fire. Your humans watch the station shrink '
            'behind you and say nothing.',
            effects: [SetFlag(Flag.captainFledRaid), Loyalty(-15)],
          ),
        ],
      ),
    ],
  ),
  GameEvent(
    id: 'council_session',
    title: 'The council debates',
    condition: const AllOf([
      AtSystem(Sys.center),
      HasFlag(Flag.overseerOffer),
      NoFlag(Flag.keplerTouchdown),
      NoFlag(Flag.captainBackedOffer),
      NoFlag(Flag.captainOpposedOffer),
    ]),
    weight: 4,
    text:
        'The council chamber is arguing about the Overseer\'s offer: give '
        'the humans the hive world if they can clear it. You are a minor '
        'captain, but minor captains vote, and a few delegates want to know '
        'where you stand.',
    choices: [
      Choice.simple(
        'Speak for the humans',
        'You make the case. Your humans watch the broadcast in the mess, '
            'and someone starts clapping.',
        condition: const CounterAtLeast(Counter.influence, 1),
        hint: '1 influence',
        effects: const [
          SetFlag(Flag.captainBackedOffer),
          AddCounter(Counter.influence, -1),
          AddCounter(Counter.republicStance, 6),
          Loyalty(10),
        ],
      ),
      Choice.simple(
        'Take the Gor delegation\'s money and speak against it',
        'The speech pays well. Your humans watch it in the mess, and nobody '
            'claps.',
        effects: const [
          SetFlag(Flag.captainOpposedOffer),
          AddCounter(Counter.republicStance, -6),
          Credits(40),
          Loyalty(-15),
        ],
      ),
      Choice.simple('Keep your head down', 'Nobody notices you. Good.'),
    ],
  ),
  const GameEvent(
    id: 'touchdown_witness',
    title: 'Landers over Kepler',
    triggers: {Trigger.queued},
    text:
        'The Promethius is dropping landers onto the surface. The '
        'observation station is broadcasting protocol violations on every '
        'channel. A human pilot asks, very casually, whether you would '
        'mind flying top cover.',
    choices: [
      Choice(
        'Fly top cover',
        outcomes: [
          Outcome(
            'The landers make it down. The observation station logs your '
            'transponder.',
            effects: [
              Loyalty(15),
              Drift(10),
              AddCounter(Counter.republicStance, -3),
            ],
          ),
        ],
      ),
      Choice(
        'File a formal complaint',
        outcomes: [
          Outcome(
            'The council appreciates your diligence. Your crew does not.',
            effects: [AddCounter(Counter.influence, 1), Loyalty(-10)],
          ),
        ],
      ),
      Choice('Watch', outcomes: [Outcome('History happens. You watch it.')]),
    ],
  ),
  GameEvent(
    id: 'war_at_the_pipe',
    title: 'The Bhrun-Gai pipe',
    triggers: const {Trigger.queued},
    text:
        'The Gor armada is forming up at the gateway. Five human ships '
        'are lined up across the pipe mouth, which is absurd. A human '
        'captain hails you: "We could use one more."',
    choices: [
      const Choice(
        'Join the humans in the pipe',
        outcomes: [
          Outcome(
            'Halfway down the pipe, the barrier opens like a mouth. '
            'Something on the other side looks a lot like a human ship, '
            'and it pulls you through.',
            bondWeight: 1,
            effects: [Loyalty(10), Drift(5), EnterHell(HellZone.pipe)],
          ),
          Outcome(
            '',
            weight: 1.5,
            effects: [
              Combat(
                'the Gor vanguard',
                8,
                win: [
                  Loyalty(15),
                  Credits(40),
                  AddCounter(Counter.influence, 1),
                  AddCounter(Counter.gorAggression, -1),
                ],
                lose: [Hull(-120), Loyalty(5)],
              ),
            ],
          ),
        ],
      ),
      Choice.simple(
        'Fly with your people',
        'You take your place in the Gor line. Your humans go very quiet.',
        condition: const IsSpecies(Species.gor),
        effects: const [
          Drift(-10),
          Loyalty(-20),
          AddCounter(Counter.gorAggression, 1),
          Credits(50),
        ],
      ),
      Choice.simple(
        'Stay out of it',
        'You back away from the gateway. Probably wise. Your humans do not '
            'think so.',
        effects: const [Loyalty(-6)],
      ),
    ],
  ),
  const GameEvent(
    id: 'direction_remover',
    title: 'The Direction Remover',
    triggers: {Trigger.queued},
    text:
        'Consumers are swarming over Bhrun-Gai\'s towers. Then they are '
        'not. Something in orbit is picking off everything that moves '
        'that isn\'t human, quickly and without fuss. Your humans call it '
        'the Direction Remover, and they sound proud of it.',
    choices: [
      Choice(
        'Ask how it works',
        outcomes: [
          Outcome(
            '"It removes direction, captain." That is all they will say. They '
            'appreciated being asked.',
            effects: [Drift(10), Loyalty(5)],
          ),
        ],
      ),
      Choice(
        'Send a report to the council',
        outcomes: [
          Outcome(
            'The council is very interested. The humans notice you were the '
            'one who told them.',
            effects: [
              AddCounter(Counter.influence, 1),
              AddCounter(Counter.republicStance, -3),
              Loyalty(-8),
            ],
          ),
        ],
      ),
    ],
  ),
  GameEvent(
    id: 'solar_blockade',
    title: 'The Solar fleet',
    condition: const AllOf([AtSystem(Sys.sol), NoFlag(Flag.solEntered)]),
    always: true,
    once: false,
    text:
        'A human fleet is waiting at the gateway mouth, far larger than '
        'anything the Republic thinks the humans own. These ships were not '
        'built at Neo Terra. A calm voice tells you that Sol is closed, and '
        'that you will be turning around now.',
    choices: [
      Choice(
        'Let your humans talk to them',
        condition: const HumansAtLeast(25),
        outcomes: [
          Outcome(
            'Your humans speak for a long time, mostly about you. The fleet '
            'parts.',
            condition: const BondAtLeast(50),
            effects: const [
              SetFlag(Flag.solEntered),
              QueueEvent('sol_arrival'),
            ],
          ),
          Outcome(
            'Your humans try. The voice thanks them warmly and escorts you '
            'back through the gateway.',
            condition: const Not(BondAtLeast(50)),
            effects: const [Retreat(), Loyalty(-3)],
          ),
        ],
      ),
      Choice.simple(
        'Repeat the word your humans sent from Hell',
        'There is a pause. "Welcome home, friend of the family."',
        condition: const HasFlag(Flag.codeGreenUsed),
        effects: const [SetFlag(Flag.solEntered), QueueEvent('sol_arrival')],
      ),
      const Choice(
        'Force your way through',
        outcomes: [
          Outcome(
            '',
            effects: [
              Combat(
                'the Solar fleet',
                40,
                win: [
                  SetFlag(Flag.solEntered),
                  AddCounter(Counter.humanPower, -2),
                  QueueEvent('sol_arrival'),
                ],
                lose: [Hull(-225), Retreat()],
              ),
            ],
          ),
        ],
      ),
      Choice.simple(
        'Turn around',
        'You turn around.',
        effects: const [Retreat()],
      ),
    ],
  ),
  const GameEvent(
    id: 'sol_arrival',
    title: 'Sol',
    triggers: {Trigger.queued},
    text:
        'The humans\' "dying" sun is a perfectly healthy yellow dwarf. '
        'Out past the Kuiper belt something invisible tugs on everything '
        'around it. Your humans are not surprised by any of this.',
    choices: [
      Choice(
        'Ask them why they lied',
        outcomes: [
          Outcome(
            '"To get through the door, captain." It is the most honest '
            'answer anyone has given you in years.',
            effects: [Drift(10), Loyalty(5)],
          ),
        ],
      ),
    ],
  ),
];
