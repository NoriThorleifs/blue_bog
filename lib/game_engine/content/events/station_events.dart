import '../../combat/equipment.dart';
import '../../galaxy/galaxy.dart';
import '../../story/rules.dart';
import '../../story/story.dart';

/// Ordinary stations.
final stationEvents = <GameEvent>[
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
];
