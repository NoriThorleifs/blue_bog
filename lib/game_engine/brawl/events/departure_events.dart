import '../brawl.dart';
import '../brawl_events.dart';

/// What can happen as the ship leaves a station.
final departureEvents = <BrawlEvent>[
  BrawlEvent(
    id: 'chewer',
    title: 'Teeth on the barrier',
    weight: (_) => 1.5,
    text:
        'Halfway down the pipe the barrier shudders. On the other side, '
        'something with no mouth and a great many teeth is chewing on it, '
        'the way a dog works a bone.\n\n'
        'Every bite punches a hole in the barrier. Every hole heals over in '
        'seconds. Pipes have survived far worse, and so will you if you '
        'keep going. But a hole is a hole, and a captain mad enough could '
        'fly through one.',
    choices: const [
      Choice('Keep going. The pipe will hold.', [
        Outcome(
          'The barrier closes behind every bite. You come out of the far '
          'end on schedule, where the usual trouble is waiting.',
        ),
      ]),
      Choice('Wait for a bite, then dive through', [
        Outcome(
          'You time it to the bite. The teeth close a hair behind your '
          'engines and the pipe heals shut at your back.\n\n'
          'Outside the hull is an alcoholic sea full of metallic flesh. '
          'The clocks on the bridge have started to disagree. There are no '
          'stations here and no shipyards. You are in Hell, on purpose.',
          effects: [EnterHell()],
        ),
      ]),
    ],
  ),
  BrawlEvent(
    id: 'toll',
    title: 'Toll collectors',
    text:
        'Three gunships idle across the pipe exit with their weapons warm. '
        'Their captain calls it a toll, and says it the way people say '
        'things they had to look up.',
    choices: [
      Choice('Pay the 40 credits', const [
        Outcome(
          'They wave you through with exaggerated courtesy. The lane '
          'beyond is empty.',
          effects: [GainCredits(-40), NoFight()],
        ),
      ], available: (s) => s.credits >= 40),
      const Choice('Refuse', [
        Outcome(
          'Their best ship peels off to make an example of you. It is '
          'tougher than what usually waits out here, and carries more worth '
          'scrapping.',
          effects: [Fight(roundsAhead: 1, scrap: 1.5)],
        ),
      ]),
    ],
  ),
  BrawlEvent(
    id: 'wreck',
    title: 'A drifting wreck',
    text:
        'A freighter tumbles slowly through the lane, lights out. The '
        'cargo doors are open. Something might still be bolted down in '
        'there.',
    choices: [
      Choice('Board it', [
        Outcome(
          'Most of it was stripped, but not all of it.',
          weight: 3,
          effects: [GainRandom(_cheapCards)],
        ),
        const Outcome(
          'It was bait. The mines go off as you dock.',
          weight: 2,
          effects: [HullChange(-60)],
        ),
      ]),
      const Choice('Leave it be', [
        Outcome('Somebody else\'s problem. You fly on.'),
      ]),
    ],
  ),
  const BrawlEvent(
    id: 'neo_terra',
    title: 'The exclusion zone',
    // Early on, crossing the line is certain death rather than a gamble.
    condition: _pastFight7,
    text:
        'The lane out of the pipe skirts the Neo Terran exclusion zone. '
        'Warning buoys repeat themselves in every language the Republic '
        'uses: the defence network fires on anything that crosses the '
        'line. No exceptions, no appeals.\n\n'
        'Straight across the zone is the short way to the next station, '
        'and a defence platform would be worth a fortune in scrap to '
        'anyone who could take one apart.',
    choices: [
      Choice('Keep to the lane', [
        Outcome(
          'You fly the long way round, the buoys nagging at you until '
          'they fall out of range. The usual trouble is waiting at the '
          'end of it.',
        ),
      ]),
      Choice('Cross the line', [
        Outcome(
          'The buoys go quiet the moment you cross, which is worse. A '
          'platform swings its teleporters toward you.',
          effects: [
            Fight(
              special: SpecialEnemy.neoTerranPlatform,
              scrap: 2,
              winCredits: 100,
            ),
          ],
        ),
      ]),
    ],
  ),
  BrawlEvent(
    id: 'smuggler',
    title: 'Unlabelled crates',
    text:
        'A Bhrun hauler drifts alongside and opens a channel. Two crates, '
        'no labels, 30 credits for the pair. The pilot swears on several '
        'gods that they are worth more than that somewhere.',
    choices: [
      Choice(
        'Buy them, sight unseen',
        const [
          Outcome(
            'The crates are bolted into your hold before you can change '
            'your mind.',
            effects: [GainCredits(-30), GainRandom(_goods, count: 2)],
          ),
        ],
        available: (s) =>
            s.credits >= 30 &&
            s.loadout.holdCapacity - s.loadout.hold.length >= 2,
      ),
      const Choice('No thanks', [
        Outcome('The hauler drifts off to try someone else.'),
      ]),
    ],
  ),
  BrawlEvent(
    id: 'leak',
    title: 'Brandy in the pipe',
    text:
        'The barrier is weeping. Something from the far side has seeped '
        'through a crack and beaded on the inside of the pipe: clear, '
        'heavy, and smelling strongly of brandy. Hell\'s sea, distilled by '
        'the barrier itself.',
    choices: const [
      Choice('Scoop some up', [
        Outcome(
          'You fill a cask. Something on the other side presses against '
          'the barrier where you were and scrapes along your hull.',
          weight: 2,
          effects: [
            GainCards([hellBrandy]),
            HullChange(-25),
          ],
        ),
        Outcome(
          'The crack seals as you reach it, and something on the far side '
          'bites where your hull just was. Not quite where.',
          effects: [HullChange(-40)],
        ),
      ]),
      Choice('Do not touch it', [Outcome('Wise. Probably.')]),
    ],
  ),
  BrawlEvent(
    id: 'quiet_lane',
    title: 'A quiet lane',
    text:
        'Traffic control offers you an old freight lane nobody uses any '
        'more. Nobody uses it because there is nothing out there, which '
        'cuts both ways.',
    choices: const [
      Choice('Take the quiet lane', [
        Outcome(
          'Not a soul the whole way. No trouble, and no scrap either.',
          effects: [NoFight()],
        ),
      ]),
      Choice('Go looking for trouble', [
        Outcome(
          'You find it, and it\'s carrying more than usual.',
          effects: [Fight(scrap: 1.5)],
        ),
      ]),
    ],
  ),
  BrawlEvent(
    id: 'convoy',
    title: 'Escort wanted',
    text:
        'A Tern convoy is short an escort. They will pay 60 credits if you '
        'fly point through a stretch where something nasty has been '
        'waiting for them.',
    choices: const [
      Choice('Take the job', [
        Outcome(
          'Something nasty is indeed waiting.',
          effects: [Fight(roundsAhead: 2, winCredits: 60)],
        ),
      ]),
      Choice('Not your convoy', [
        Outcome('The Tern note your refusal, to three decimal places.'),
      ]),
    ],
  ),
];

bool _pastFight7(BrawlState s) => s.round >= 7;

final _cheapCards = [for (final f in brawlFamilies) f.tiers.first.id];

const _goods = [
  'goods_grain',
  'goods_ice',
  'goods_ore',
  'goods_chitin',
  'goods_medicine',
  'goods_nanopaste',
  'goods_relics',
];
