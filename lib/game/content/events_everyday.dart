import '../captain/species.dart';
import '../combat/equipment.dart';
import '../galaxy/galaxy.dart';
import '../story/keys.dart';
import '../story/rules.dart';
import '../story/story.dart';

/// The everyday: what happens at ordinary stations, out on the frontier, and
/// when you hold position somewhere with nothing in particular going on.
///
/// Most of these repeat, and several are ways to scrape together credits or
/// fuel anywhere, so a captain is never stuck with no way forward.
final everydayEvents = <GameEvent>[
  // Holding position, anywhere ---------------------------------------------
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
        condition: const HumansAtLeast(3),
        effects: const [Credits(22), Loyalty(2)],
      ),
    ],
  ),
  const GameEvent(
    id: 'hold_card_game',
    title: 'The card game',
    triggers: {Trigger.hold},
    condition: HumansAtLeast(2),
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
            'A crew of humans who lost their ship. They ask to sign on.',
            effects: [Humans(2), MaybeAgent(0.3)],
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

  // Ordinary stations -------------------------------------------------------
  GameEvent(
    id: 'station_buyer',
    title: 'A buyer',
    triggers: const {Trigger.arrival, Trigger.hold},
    condition: const AllOf([
      AtTag(Tag.station),
      HasCardKind(CardKind.commodity),
    ]),
    once: false,
    weight: 1.2,
    text:
        'A station quartermaster has heard what\'s in your hold and is '
        'short of exactly that. She is in a hurry, which is good for you.',
    choices: [
      Choice.simple(
        'Sell at her price',
        'Well above the going rate.',
        effects: const [SellCommodity(1.7)],
      ),
      Choice.simple('Keep it', 'She finds someone else.'),
    ],
  ),
  GameEvent(
    id: 'station_bounty',
    title: 'The bounty board',
    condition: const AtTag(Tag.station),
    once: false,
    weight: 0.8,
    text:
        'The bounty board lists a raider working the lanes nearby. The '
        'station will pay for proof it\'s gone.',
    choices: [
      const Choice(
        'Take the bounty',
        outcomes: [
          Outcome(
            '',
            effects: [
              Combat('a lane raider', 6, win: [Credits(60)]),
            ],
          ),
        ],
      ),
      Choice.simple('Not today', 'Someone else will get it. Or won\'t.'),
    ],
  ),
  GameEvent(
    id: 'station_auction',
    title: 'Salvage auction',
    condition: const AtTag(Tag.station),
    once: false,
    weight: 0.7,
    text:
        'The station is auctioning off the contents of an impounded ship, '
        'sight unseen.',
    choices: [
      Choice.simple(
        'Bid',
        'You win a crate of ship parts.',
        condition: const CreditsAtLeast(25),
        hint: '25 credits',
        effects: const [Credits(-25), GrantCard('salvage')],
      ),
      Choice.simple('Watch the bidding', 'A Gor overpays for a toaster.'),
    ],
  ),
  GameEvent(
    id: 'station_fees',
    title: 'Docking fees',
    condition: const AllOf([AtTag(Tag.station), Not(AtTag(Tag.capital))]),
    once: false,
    weight: 0.6,
    text:
        'The dockmaster has invented a new fee. It is due now, in cash, to '
        'him personally.',
    choices: [
      Choice.simple(
        'Pay it',
        'He makes a note of your generosity.',
        condition: const CreditsAtLeast(10),
        hint: '10 credits',
        effects: const [Credits(-10)],
      ),
      Choice.simple(
        'Let your humans explain the station\'s own regulations to him',
        'They quote three subsections at him. The fee is withdrawn.',
        condition: const BondAtLeast(30),
        effects: const [Loyalty(3)],
      ),
      Choice.simple(
        'Refuse',
        'He fines you anyway, and stamps your papers very hard.',
        effects: const [Credits(-15)],
      ),
    ],
  ),
  const GameEvent(
    id: 'station_brawl',
    title: 'Dockside brawl',
    condition: AllOf([AtTag(Tag.station), HumansAtLeast(2)]),
    once: false,
    weight: 0.6,
    text:
        'Some of your humans got into a fight with a crew of Gor dockers. '
        'Station security is holding everyone until somebody pays for the '
        'damage.',
    choices: [
      Choice(
        'Pay the damages',
        outcomes: [
          Outcome(
            'Your humans come back bruised and proud. The Gor do not come '
            'back at all, for a while.',
            effects: [Credits(-20), Loyalty(5)],
          ),
        ],
      ),
      Choice(
        'Leave them in the cells overnight',
        outcomes: [
          Outcome(
            'They are released in the morning and they remember it.',
            effects: [Loyalty(-8)],
          ),
        ],
      ),
    ],
  ),
  GameEvent(
    id: 'station_refugees',
    title: 'Passengers',
    condition: const AtTag(Tag.station),
    once: false,
    weight: 0.7,
    text:
        'A family whose home system was cut off in the gatecrash, three '
        'generations ago, has finally saved enough to go looking for it. '
        'They need passage, and they can pay a little.',
    choices: [
      Choice.simple(
        'Take them aboard',
        'They pay up front and tell stories the whole way. Your humans '
            'love them.',
        effects: const [Credits(20), Loyalty(4)],
      ),
      Choice.simple('No room', 'They try the next ship.'),
    ],
  ),
  GameEvent(
    id: 'station_market_stall',
    title: 'A cheap stall',
    condition: const AllOf([AtTag(Tag.station), Not(AtTag(Tag.market))]),
    once: false,
    weight: 0.7,
    text:
        'There\'s no real market here, but someone has set up a stall at '
        'the end of the docks selling whatever came off the last ship.',
    choices: [
      Choice.simple(
        'Buy a crate of something',
        'You get what you pay for.',
        condition: const CreditsAtLeast(8),
        hint: '8 credits',
        effects: const [Credits(-8), GrantCard('commodity')],
      ),
      Choice.simple(
        'Sell them some cargo',
        'Cheap, but quick.',
        condition: const HasCardKind(CardKind.commodity),
        effects: const [SellCommodity(0.8)],
      ),
      Choice.simple('Browse', 'Mostly broken things.'),
    ],
  ),

  // Frontier and ruins --------------------------------------------------------
  const GameEvent(
    id: 'frontier_derelict',
    title: 'A derelict',
    condition: AnyOf([AtTag(Tag.frontier), AtTag(Tag.ruins)]),
    once: false,
    weight: 1,
    text:
        'A Havi-era ship drifts at the edge of the system, dark and cold. '
        'Its hull is scored with something that looks like teeth marks.',
    choices: [
      Choice(
        'Board it',
        outcomes: [
          Outcome(
            'In the hold, sealed in Havi glass: relics. Someone will pay a '
            'great deal.',
            effects: [GrantCard('goods_relics')],
          ),
          Outcome(
            'Its stores are intact.',
            weight: 2,
            effects: [GrantCard('supplies'), Fuel(2)],
          ),
          Outcome(
            'Something is still aboard.',
            effects: [
              Combat(
                'whatever lived in the derelict',
                5,
                win: [GrantCard('salvage')],
              ),
            ],
          ),
        ],
      ),
      Choice(
        'Strip the hull',
        outcomes: [
          Outcome('Scrap, and plenty of it.', effects: [Credits(25)]),
        ],
      ),
      Choice('Leave it', outcomes: [Outcome('Some things should stay dark.')]),
    ],
  ),
  const GameEvent(
    id: 'frontier_nest',
    title: 'A Consumer nest',
    condition: AllOf([
      AnyOf([AtTag(Tag.frontier), AtTag(Tag.ruins)]),
      CounterAtLeast(Counter.consumerThreat, 1),
    ]),
    once: false,
    weight: 0.7,
    text:
        'A small Consumer nest is growing on an asteroid here. Left alone it '
        'will be a big one. The chitin is worth money.',
    choices: [
      Choice(
        'Burn it out',
        outcomes: [
          Outcome(
            '',
            effects: [
              Combat(
                'a Consumer nest',
                5,
                win: [
                  GrantCard('goods_chitin'),
                  AddCounter(Counter.consumerThreat, -1),
                ],
              ),
            ],
          ),
        ],
      ),
      Choice(
        'Report it and move on',
        outcomes: [
          Outcome(
            'The Republic thanks you, eventually.',
            effects: [Credits(8)],
          ),
        ],
      ),
    ],
  ),
  GameEvent(
    id: 'frontier_prospectors',
    title: 'Prospectors',
    condition: const AtTag(Tag.frontier),
    once: false,
    weight: 0.8,
    text:
        'A camp of human prospectors on a rock in the middle of nowhere. '
        'They have ore and they want everything else.',
    choices: [
      Choice.simple(
        'Trade for ore',
        'They throw in a little fuel to close the deal.',
        condition: const CreditsAtLeast(10),
        hint: '10 credits',
        effects: const [Credits(-10), GrantCard('goods_ore'), Fuel(1)],
      ),
      Choice.simple(
        'Sell them supplies from your hold',
        'They pay well, out here.',
        condition: const HasCardKind(CardKind.commodity),
        effects: const [SellCommodity(1.3)],
      ),
      Choice.simple(
        'Let your humans visit',
        'Your humans come back with news, gossip and two new friends.',
        condition: const HumansAtLeast(1),
        effects: const [Loyalty(4), Humans(1), MaybeAgent(0.3)],
      ),
    ],
  ),

  // Species homes ----------------------------------------------------------
  GameEvent(
    id: 'gor_pits',
    title: 'The duelling pits',
    condition: const AtTag(Tag.gor),
    once: false,
    weight: 0.8,
    text:
        'The Gor settle disputes, debts and boredom in the duelling pits. '
        'Any ship may enter a champion. Several of your humans are '
        'volunteering, loudly.',
    choices: [
      const Choice(
        'Send a human champion',
        condition: HumansAtLeast(1),
        outcomes: [
          Outcome(
            'The human wins. The Gor are furious, then fascinated. You '
            'collect the purse.',
            weight: 2,
            bondWeight: 0.5,
            effects: [
              Credits(40),
              Loyalty(5),
              AddCounter(Counter.gorAggression, 1),
            ],
          ),
          Outcome(
            'The human loses, and has to be carried out. Nobody dies. '
            'Probably.',
            effects: [Credits(-10), Loyalty(-3)],
          ),
        ],
      ),
      Choice.simple(
        'Fight yourself',
        'You win. The Gor treat you as one of their own for a whole day.',
        condition: const IsSpecies(Species.gor),
        effects: const [Credits(30), Drift(-4)],
      ),
      Choice.simple('Watch', 'Loud, bloody and very well attended.'),
    ],
  ),
  GameEvent(
    id: 'bhrun_wrangling',
    title: 'Megafauna wrangling',
    condition: const AtTag(Tag.bhrun),
    once: false,
    weight: 0.8,
    text:
        'Something enormous has wandered into a Bhrun settlement and won\'t '
        'leave. The Bhrun will pay anyone who can move it, eventually, in '
        'their own time.',
    choices: [
      Choice.simple(
        'Move it with the ship\'s tractor field',
        'It takes all day. It is the strangest money you have ever earned.',
        effects: const [Credits(25)],
      ),
      Choice.simple(
        'Let your humans try',
        'The humans move it with food, noise and a great deal of shouting. '
            'The Bhrun are deeply impressed.',
        condition: const HumansAtLeast(3),
        effects: const [Credits(30), Loyalty(3)],
      ),
    ],
  ),
  GameEvent(
    id: 'al_scan',
    title: 'Curious scientists',
    condition: const AtTag(Tag.al),
    once: false,
    weight: 0.8,
    text:
        'An Ál research team would like to scan your ship, your cargo and '
        'especially your crew. They are paying.',
    choices: [
      Choice.simple(
        'Let them scan the ship',
        'Thorough, damp and well paid.',
        effects: const [Credits(20)],
      ),
      Choice.simple(
        'Let them scan the humans',
        'The humans are paid too, which helps.',
        condition: const HumansAtLeast(1),
        effects: const [Credits(35), Loyalty(-2), Drift(-2)],
      ),
      Choice.simple('Decline', 'They are visibly disappointed.'),
    ],
  ),
  GameEvent(
    id: 'tern_calibration',
    title: 'Relay calibration',
    condition: const AtTag(Tag.tern),
    once: false,
    weight: 0.8,
    text:
        'The local Tern relay has drifted out of phase with the rest of '
        'the network. Recalibrating it needs a ship to fly a slow figure '
        'three around it.',
    choices: [
      Choice.simple(
        'Fly the pattern',
        'The relay hums back into step. The Tern pay exactly what they said.',
        effects: const [Credits(27)],
      ),
      Choice.simple(
        'Merge with the relay and fix it from inside',
        'A strange, pleasant afternoon. The Tern pay you double, in threes.',
        condition: const IsSpecies(Species.tern),
        effects: const [Credits(54), Drift(-3)],
      ),
    ],
  ),
];
