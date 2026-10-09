import '../brawl.dart';
import '../brawl_event_model.dart';
import '../brawl_events.dart';

/// The elites, each once per brawl and only during its stage, and Nobody,
/// once per brawl any time from fight 9.
final eliteEvents = <BrawlEvent>[
  BrawlEvent(
    id: _shakedown,
    title: 'Human pirates',
    condition: (s) => _elite(s, _shakedown, 4, 5),
    text:
        'Three ships with no transponders box you in, and a fourth, much '
        'bigger, settles in behind them. The Last Vote, by its paint. '
        'There are no humans aboard your ship, so nobody over there has to '
        'be polite, but they would still rather be paid than shoot. This '
        'is a shakedown, their captain explains, and you are the one being '
        'shaken.',
    choices: [
      Choice('Pay them 60 credits', const [
        Outcome(
          'They count it twice and wave you off. Whatever was waiting '
          'down the lane has heard who works it, and has gone elsewhere.',
          effects: [GainCredits(-60), NoFight(), SetFlag(_shakedown)],
        ),
      ], available: (s) => s.credits >= 60),
      Choice('Let them take some cargo', const [
        Outcome(
          'They board you, help themselves to two crates and leave a '
          'receipt. Nobody else bothers you on the way.',
          effects: [LoseCargo(), LoseCargo(), NoFight(), SetFlag(_shakedown)],
        ),
      ], available: (s) => s.loadout.hold.isNotEmpty),
      const Choice('Refuse', [
        Outcome(
          'The little ships scatter to watch. The Last Vote comes about '
          'and runs out its guns. Its captain will have to win this to '
          'win the next vote.',
          effects: [
            Fight(
              special: SpecialEnemy.lastVote,
              scrap: 1.5,
              winCredits: 50,
              winCards: ['trophy_last_vote'],
            ),
            SetFlag(_shakedown),
          ],
        ),
      ]),
    ],
  ),
  BrawlEvent(
    id: _duel,
    title: 'A challenge',
    condition: (s) => _elite(s, _duel, 8, 10),
    text:
        'A Gor warship hangs across the pipe exit, broadcasting on every '
        'channel. Its champion has come a long way to find an opponent '
        'worth the trip, and has decided, on no evidence at all, that you '
        'are one.\n\n'
        'A duel, then: the two of you, to the end. Gor duels have no '
        'breaking away. The winner takes the loser\'s shield.',
    choices: const [
      Choice('Accept', [
        Outcome(
          'A tractor beam locks your two ships together. Nobody leaves '
          'this early.',
          effects: [
            Fight(
              special: SpecialEnemy.gorChampion,
              tractorBeam: true,
              scrap: 1.5,
              winCredits: 100,
              winCards: ['trophy_champions_bulwark'],
            ),
            SetFlag(_duel),
          ],
        ),
      ]),
      Choice('Decline', [
        Outcome(
          'The champion tells every channel what you are, at length, then '
          'goes looking for someone braver. The usual trouble is waiting '
          'further down the lane.',
          effects: [SetFlag(_duel)],
        ),
      ]),
    ],
  ),
  BrawlEvent(
    id: _foundry,
    title: 'Unmerged',
    condition: (s) => _elite(s, _foundry, 11, 14),
    text:
        'A Tern relay hails you with a bounty. One of their foundry ships '
        'has drifted out of radio range of every other Tern and stopped '
        'answering. The Tern call that unmerged, the way other species say '
        'dead. It is still working, though: eating wrecks in the lane and '
        'building itself bigger out of them.\n\n'
        'They will pay 200 credits to have it stopped, and they don\'t '
        'want back whatever is left.',
    choices: const [
      Choice('Take the bounty', [
        Outcome(
          'You find it by the wrecks it hasn\'t finished eating. A cloud '
          'of drones turns toward you as one.',
          effects: [
            Fight(
              special: SpecialEnemy.unmergedFoundry,
              scrap: 1.5,
              winCredits: 200,
              winCards: ['trophy_nanoforge'],
            ),
            SetFlag(_foundry),
          ],
        ),
      ]),
      Choice('Leave it to the Tern', [
        Outcome(
          'The relay logs your refusal and goes looking for someone else. '
          'The usual trouble is waiting down the lane.',
          effects: [SetFlag(_foundry)],
        ),
      ]),
    ],
  ),
  BrawlEvent(
    id: _nobody,
    title: 'Nobody',
    condition: (s) => !s.flags.contains(_nobody) && s.round >= 9,
    weight: (_) => 0.5,
    text:
        'A small human ship with no markings matches your course out of '
        'the pipe and hails you. A pleasant voice asks what species you '
        'are, and where you are headed.\n\n'
        'Something about it makes you ask, half joking, whether the humans '
        'keep anyone specially trained to kill your kind.\n\n'
        '"Nobody," says the voice.\n\n'
        'Your sensors find a drone swarm and a shield generator bigger '
        'than anything a ship that size should carry, and one more thing, '
        'charging slowly. A boarding teleporter, sized for one man.',
    choices: const [
      Choice('Run for it', [
        Outcome(
          'You burn for the nearest lane with everything you have. The '
          'drones chew on your hull the whole way, but the teleporter never '
          'finishes charging. Behind you, the little ship turns back. It '
          'was only asking.',
          effects: [
            HullChange(-100, lethal: false),
            NoFight(),
            SetFlag(_nobody),
          ],
        ),
      ]),
      Choice('Kill him before it charges', [
        Outcome(
          'You have forty seconds. When the teleporter charges, Nobody '
          'comes aboard, and that is the end of you.',
          effects: [
            Fight(special: SpecialEnemy.nobody, scrap: 2, winCredits: 300),
            SetFlag(_nobody),
          ],
        ),
      ]),
    ],
  ),
];

const _shakedown = 'shakedown';

const _duel = 'gor_duel';

const _foundry = 'unmerged_foundry';

const _nobody = 'nobody';

/// Elite events come up once per brawl, and only between fights [from]
/// and [to]. Miss the window and the elite is gone.
bool _elite(BrawlState s, String flag, int from, int to) =>
    !s.flags.contains(flag) && s.round >= from && s.round <= to;
