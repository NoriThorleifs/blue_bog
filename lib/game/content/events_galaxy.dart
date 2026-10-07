import '../captain/species.dart';
import '../faction.dart';
import '../galaxy/galaxy.dart';
import '../run_state.dart';
import '../story/keys.dart';
import '../story/rules.dart';
import '../story/story.dart';

/// Events that happen in systems, on arrival or while holding position.
final galaxyEvents = <GameEvent>[
  // Queued by story beats ---------------------------------------------------
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
        condition: const HumansAtLeast(1),
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

  // Act 1 locations ---------------------------------------------------------
  GameEvent(
    id: 'railing_standards',
    title: 'Not up to code',
    condition: const AllOf([AtSystem(Sys.orcha), NoFlag(Flag.orchaRaid)]),
    weight: 2,
    text:
        'The humans are building a three-level walkway along Orcha\'s '
        'promenade and are badly behind schedule. They have torn the whole '
        'thing down and started again. The foreman explains, in public, '
        'that the first attempt was "not up to code".',
    choices: [
      Choice.simple(
        'Ask which code',
        'The foreman smiles. "Railing safety standards." Your humans '
            'find this hilarious.',
        effects: const [Drift(4), Loyalty(3)],
      ),
      Choice.simple(
        'Report the delay to station authority',
        'The station authority thanks you. The foreman remembers your '
            'face.',
        effects: const [AddCounter(Counter.influence, 1), Loyalty(-4)],
      ),
    ],
  ),
  const GameEvent(
    id: 'owie_experiments',
    title: 'Dr. Ái Á á Á á á á',
    condition: AllOf([AtTag(Tag.station), ActIs(1), HumansAtLeast(2)]),
    text:
        'An Ál scientist who insists you call him Owie is recruiting '
        'human volunteers to measure their durability. He pays well. He is '
        'evasive about the final experiment.',
    choices: [
      Choice(
        'Volunteer some of your humans',
        outcomes: [
          Outcome(
            'The humans come back very durable and very relaxed. Some of '
            'them ask when Owie is hiring again.',
            weight: 1.5,
            effects: [Credits(40), Loyalty(4), Drift(-4)],
          ),
          Outcome(
            'The humans come back furious, and they know exactly who signed '
            'them up.',
            effects: [Credits(40), Loyalty(-12)],
          ),
        ],
      ),
      Choice(
        'Decline',
        outcomes: [
          Outcome(
            'Owie wanders off, already looking at the next ship\'s '
            'crew.',
          ),
        ],
      ),
    ],
  ),
  GameEvent(
    id: 'two_sided_brothel',
    title: 'A wall with a hole in it',
    triggers: const {Trigger.arrival, Trigger.hold},
    condition: const AllOf([
      AtTag(Tag.station),
      AtTag(Tag.neutral),
      HumansAtLeast(1),
    ]),
    text:
        'This neutral station hosts a two-sided brothel: two entrances, '
        'one wet, one dry, a wall with a hole in it, and a legal theory so '
        'convoluted it may never be challenged. Your humans would like '
        'shore leave.',
    choices: [
      Choice.simple(
        'Grant shore leave',
        'The humans come back exhausted and cheerful.',
        hint: '15 credits',
        effects: const [Credits(-15), Loyalty(10), Drift(-3)],
      ),
      Choice.simple(
        'Invest in the business',
        'Both sides of the wall pay. You take a cut of both.',
        condition: const IsSpecies(Species.al),
        effects: const [Credits(45), Drift(4)],
      ),
      Choice.simple(
        'Deny it',
        'There is muttering below decks.',
        effects: const [Loyalty(-5)],
      ),
    ],
  ),
  GameEvent(
    id: 'ternary_dispute',
    title: '729',
    condition: const AllOf([AtTag(Tag.station), HumansAtLeast(1)]),
    text:
        'Your human quartermaster is screaming at a supplier. "Did I '
        'stutter? I said 729. I don\'t want 730. I won\'t take the last one '
        'even if you pay me." The supplier looks to you for help.',
    choices: [
      Choice.simple(
        'Back the quartermaster',
        '"Because the captain counts in threes!" The supplier gives up and '
            'knocks the price down to make the human go away.',
        effects: const [Credits(15), Loyalty(6), Drift(-3)],
      ),
      Choice.simple(
        'Take the free one',
        'The quartermaster stares at you for a very long time.',
        effects: const [Credits(5), Loyalty(-6)],
      ),
      Choice.simple(
        'Explain that 729 is three to the sixth',
        'The supplier does not care. Your quartermaster nearly cries with '
            'joy.',
        condition: const IsSpecies(Species.tern),
        effects: const [Loyalty(12), Drift(4)],
      ),
    ],
  ),
  GameEvent(
    id: 'bhrun_trade',
    title: 'Ben',
    condition: const AtSystem(Sys.bhrunGai),
    text:
        'Ben Buru\'hyrem\'him Burhuge would like to trade. Very slowly. He '
        'speaks warmly of the humans, who protect his people out of '
        'friendship. He is sure that is the reason.',
    choices: [
      Choice.simple(
        'Trade patiently',
        'It takes the whole day. It is a good deal.',
        effects: const [Credits(35)],
      ),
      Choice.simple(
        'Tell him why the humans really protect Bhrun-Gai',
        'Ben thinks about it for a long time, and then says he would '
            'never lift a finger for them anyway. Your humans laugh.',
        effects: const [Loyalty(4), Drift(3)],
      ),
    ],
  ),
  const GameEvent(
    id: 'kepler_observation',
    title: 'The observation post',
    condition: AllOf([AtSystem(Sys.kepler), NoFlag(Flag.keplerTouchdown)]),
    text:
        'The observation crew are still arguing about the day the humans '
        'arrived: was it first contact, or was the station hacked? Their '
        'computer insists on the former. They would like someone to take '
        'their reports to the Center.',
    choices: [
      Choice(
        'Carry the reports',
        outcomes: [
          Outcome(
            'They pay in research credits, which spend like any other kind.',
            effects: [Credits(25), AddCounter(Counter.influence, 1)],
          ),
        ],
      ),
      Choice(
        'Let your humans talk to them',
        outcomes: [
          Outcome(
            'The scientists learn more about humans in one afternoon than '
            'in a year of watching. Your humans enjoy being the experts.',
            effects: [Loyalty(5), Drift(5)],
          ),
        ],
      ),
    ],
  ),
  GameEvent(
    id: 'gor_patrol',
    title: 'Gor inspection',
    condition: const AllOf([AtTag(Tag.gor), NotInHell()]),
    once: false,
    weight: 0.8,
    text:
        'A Gor patrol demands to inspect your ship. They are very '
        'interested in your humans.',
    choices: [
      Choice.simple(
        'Submit to the inspection',
        'The Gor are rough with the humans, and the humans remember it.',
        effects: const [Loyalty(-8), AddCounter(Counter.gorAggression, 1)],
      ),
      Choice.simple(
        'Bribe them',
        'Gor honour has a price, and it is reasonable.',
        condition: const CreditsAtLeast(20),
        hint: '20 credits',
        effects: const [Credits(-20)],
      ),
      Choice.simple(
        'Pull rank',
        'They back off from one of their own. Your humans notice how much '
            'you sounded like them.',
        condition: const IsSpecies(Species.gor),
        effects: const [Drift(-6), Loyalty(-3)],
      ),
      const Choice(
        'Refuse',
        outcomes: [
          Outcome(
            '',
            effects: [
              Combat(
                'a Gor patrol',
                7,
                win: [
                  Credits(30),
                  Loyalty(10),
                  AddCounter(Counter.gorAggression, 1),
                ],
                lose: [Hull(-90), Credits(-20)],
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  const GameEvent(
    id: 'ur_gor_natives',
    title: 'The people of Ur-Gor',
    condition: AtSystem(Sys.urGor),
    text:
        'The natives of Ur-Gor are why the Gor are the way they are: the '
        'galaxy voted that they were people, so the Gor could not take the '
        'planet. The natives would like to trade. They have heard about the '
        'humans and are fascinated.',
    choices: [
      Choice(
        'Introduce them to your humans',
        outcomes: [
          Outcome(
            'The two get on very well. The Gor overseers do not like it at '
            'all.',
            effects: [
              Loyalty(6),
              Drift(4),
              Credits(20),
              AddCounter(Counter.gorAggression, 1),
            ],
          ),
        ],
      ),
      Choice(
        'Just trade',
        outcomes: [
          Outcome('A modest profit.', effects: [Credits(25)]),
        ],
      ),
    ],
  ),
  GameEvent(
    id: 'hive_world',
    title: 'The hive world',
    condition: const AllOf([
      AtSystem(Sys.neoTerra),
      NoFlag(Flag.neoTerraClaimed),
    ]),
    once: false,
    always: true,
    text:
        'The planet crawls. The shipbuilding gantry in orbit is still '
        'working, and every Consumer ship in the system has turned toward '
        'you.',
    choices: [
      const Choice(
        'Attack the gantry',
        outcomes: [
          Outcome(
            '',
            effects: [
              Combat(
                'the hive fleet',
                14,
                win: [
                  Credits(120),
                  AddCounter(Counter.consumerThreat, -1),
                  AddCounter(Counter.influence, 2),
                  Loyalty(15),
                ],
                lose: [Hull(-180)],
              ),
            ],
          ),
        ],
      ),
      Choice.simple('Retreat', 'Discretion.', effects: const [Hull(-30)]),
    ],
  ),
  const GameEvent(
    id: 'neo_terra_border',
    title: 'Neo Terran border patrol',
    condition: AllOf([AtSystem(Sys.neoTerra), HasFlag(Flag.neoTerraClaimed)]),
    always: true,
    text:
        'A human border patrol meets you at the edge of the system and '
        'tells you to leave. Behind them is a mine maze and a megastructure '
        'of radio jammers thousands strong.',
    choices: [
      Choice(
        'Let your humans talk to them',
        outcomes: [
          Outcome(
            'Your humans speak with the patrol for a long time. You are waved '
            'through the mines and see a war-torn world, with a space station '
            'bombarding one point on its surface at a steady pace. Your '
            'humans are allowed home leave. They come back changed.',
            condition: BondAtLeast(45),
            effects: [
              Loyalty(15),
              Drift(10),
              Humans(3),
              MaybeAgent(0.3),
              AddCounter(Counter.hellbornAwareness, 1),
            ],
          ),
          Outcome(
            'The patrol listens politely and says no. Your humans seem '
            'embarrassed, though you are not sure for whom.',
            effects: [Loyalty(-3)],
          ),
        ],
      ),
      Choice('Turn back', outcomes: [Outcome('You turn back.')]),
    ],
  ),

  // Anywhere ----------------------------------------------------------------
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
    id: 'human_recruits',
    title: 'Humans looking for a berth',
    condition: const AllOf([AtTag(Tag.humans), NotInHell()]),
    once: false,
    bondWeight: 0.5,
    text:
        'A handful of humans are asking around the docks for a ship. '
        'They have heard about you, for better or worse.',
    choices: [
      Choice.simple(
        'Sign three of them on',
        'They bring their own tools and their own opinions.',
        condition: const CreditsAtLeast(15),
        hint: '15 credits',
        effects: const [Credits(-15), Humans(3), Loyalty(2), MaybeAgent(0.3)],
      ),
      Choice.simple('Not today', 'They try the next ship over.'),
    ],
  ),
  GameEvent(
    id: 'courier_job',
    title: 'Courier contract',
    condition: const AtTag(Tag.station),
    once: false,
    text:
        'A sealed crate needs to be somewhere else, quietly. The pay is '
        'good, which is worrying.',
    choices: [
      const Choice(
        'Take it',
        outcomes: [
          Outcome('Easy money.', weight: 2, effects: [Credits(30)]),
          Outcome(
            'The crate was full of Consumer eggs. Some of them hatched.',
            effects: [Credits(30), Hull(-75), QueueEvent('roach_hatchling')],
          ),
        ],
      ),
      Choice.simple('Pass', 'Someone else takes it.'),
    ],
  ),

  // Holding position ----------------------------------------------------------
  const GameEvent(
    id: 'culture_night',
    title: 'Whose holiday?',
    triggers: {Trigger.hold},
    condition: HumansAtLeast(1),
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
    condition: AllOf([HumansAtLeast(3), HasFlag(Flag.orchaRaid)]),
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

  // Act 2 -----------------------------------------------------------------
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
      HumansAtLeast(3),
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

  // Act 3 -----------------------------------------------------------------
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

  // The Consumers' secret ------------------------------------------------
  // Consumers are cockroaches from Sol, taken and modified by the Eldest.
  // The humans have always known who visited them, and only something that
  // looks like a cockroach will make them say so.
  GameEvent(
    id: 'roach_hatchling',
    title: 'Something small',
    triggers: const {Trigger.queued},
    condition: const AllOf([HumansAtLeast(1), NoFlag(Flag.roachTruth)]),
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
      HumansAtLeast(3),
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

  // Shining-head --------------------------------------------------------------
  // He can only be killed by destroying his complex, 10 km under the capital.
  GameEvent(
    id: 'deep_complex',
    title: 'Ten kilometres down',
    triggers: const {Trigger.hold},
    condition: const AllOf([
      AtSystem(Sys.neoTerra),
      HasFlag(Flag.neoTerraClaimed),
      NoFlag(Flag.shiningHeadDead),
      AnyOf([
        HasFlag(Flag.overseerSuspects),
        HasFlag(Flag.uploadedFormed),
        HasFlag(Flag.captainFoundBroadcast),
      ]),
    ]),
    weight: 10,
    text:
        'Your humans take you to the station that does nothing but bombard '
        'one point on the surface, over and over. Ten kilometres under the '
        'capital is a complex, and in it is the voice. The colonists tried '
        'digging once. It threatened to crack the planet\'s core. They '
        'think it was bluffing. They would like a ship with real guns to '
        'help them find out.',
    choices: [
      const Choice(
        'Lend them your guns',
        outcomes: [
          Outcome(
            '',
            effects: [
              Combat(
                'Shining-head\'s defences',
                13,
                win: [
                  SetFlag(Flag.shiningHeadDead),
                  Transfer(Faction.uploaded, Faction.colonists),
                  AddCounter(Counter.humanPower, 2),
                  AddCounter(Counter.influence, 2),
                  Loyalty(15),
                  Note(
                    'Helped the colonists destroy the complex under Neo '
                    'Terra. Shining-head was bluffing.',
                  ),
                ],
                lose: [Hull(-150)],
              ),
            ],
          ),
        ],
      ),
      Choice.simple(
        'Not your fight',
        'The bombardment goes on without you.',
        effects: const [Loyalty(-3)],
      ),
    ],
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
