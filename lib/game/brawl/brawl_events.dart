import 'brawl.dart';

/// What an outcome does to a brawl.
sealed class BrawlEffect {
  const BrawlEffect();
}

/// Credits gained, or lost if negative. Never below zero.
class GainCredits extends BrawlEffect {
  const GainCredits(this.amount);
  final int amount;
}

/// Hull repaired, or damage if negative. A [lethal] hit can destroy the
/// ship; otherwise it leaves at least 1 hull.
class HullChange extends BrawlEffect {
  const HullChange(this.amount, {this.lethal = true});
  final int amount;
  final bool lethal;
}

/// Cards for the ship. Without room they're left behind, unless [force]d
/// aboard in exchange for the ship's cheapest card.
class GainCards extends BrawlEffect {
  const GainCards(this.ids, {this.force = false});
  final List<String> ids;
  final bool force;
}

/// [count] cards picked at random from [pool].
class GainRandom extends BrawlEffect {
  const GainRandom(this.pool, {this.count = 1});
  final List<String> pool;
  final int count;
}

/// Loses a random card from the hold.
class LoseCargo extends BrawlEffect {
  const LoseCargo();
}

/// Replaces the fight that follows. With [demon] set, one of [demons];
/// with [special] set, that ship; otherwise the scheduled enemy,
/// [roundsAhead] fights early.
class Fight extends BrawlEffect {
  const Fight({
    this.demon,
    this.special,
    this.roundsAhead = 0,
    this.tractorBeam = false,
    this.scrap = 1,
    this.winCredits = 0,
    this.winCards = const [],
  });
  final int? demon;
  final SpecialEnemy? special;
  final int roundsAhead;

  /// No breaking away at the time limit: it's a fight to the death.
  final bool tractorBeam;

  /// Multiplies the scrap paid for a win.
  final double scrap;

  /// Paid on top of scrap for a win.
  final int winCredits;

  /// Taken for a win, forced aboard in place of the cheapest card if
  /// there's no room.
  final List<String> winCards;
}

/// No fight follows.
class NoFight extends BrawlEffect {
  const NoFight();
}

/// Through the barrier into Hell.
class EnterHell extends BrawlEffect {
  const EnterHell();
}

/// Out of Hell to a station. Hell's clocks move the ship's place in the
/// difficulty curve.
class LeaveHell extends BrawlEffect {
  const LeaveHell();
}

class SetFlag extends BrawlEffect {
  const SetFlag(this.flag);
  final String flag;
}

class Outcome {
  const Outcome(this.text, {this.weight = 1, this.effects = const []});
  final String text;
  final double weight;
  final List<BrawlEffect> effects;
}

class Choice {
  const Choice(this.label, this.outcomes, {this.available});
  final String label;
  final List<Outcome> outcomes;

  /// Whether the captain can pick this. Shown greyed out when not.
  final bool Function(BrawlState)? available;
}

class BrawlEvent {
  const BrawlEvent({
    required this.id,
    required this.title,
    required this.text,
    required this.choices,
    this.hell = false,
    this.weight,
    this.condition,
  });

  final String id;
  final String title;
  final String text;
  final List<Choice> choices;

  /// Met in Hell rather than on the way out of a station.
  final bool hell;
  final double Function(BrawlState)? weight;
  final bool Function(BrawlState)? condition;
}

/// The flag set once the Mourner has given its gift.
const metMourner = 'mourner';

/// The flag set once the captain has the Hell Clock, from the Mourner or
/// found in the murk. There is only one per brawl.
const hasHellClock = 'hell_clock';

const _brandy = 'goods_brandy';

bool _pastFight7(BrawlState s) => s.round >= 7;

const _shakedown = 'shakedown';
const _duel = 'gor_duel';
const _foundry = 'unmerged_foundry';
const _nobody = 'nobody';

/// Elite events come up once per brawl, and only between fights [from]
/// and [to]. Miss the window and the elite is gone.
bool _elite(BrawlState s, String flag, int from, int to) =>
    !s.flags.contains(flag) && s.round >= from && s.round <= to;

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

/// Every brawl event. Departure events come up each time the ship leaves a
/// station; Hell events once per turn in Hell.
final brawlEvents = <BrawlEvent>[
  // Leaving a station -----------------------------------------------------
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
            GainCards([_brandy]),
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

  // Elites: once per brawl each, and only during their stage ---------------
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

  // Nobody: once per brawl, any time from fight 9 ----------------------------
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

  // Hell -------------------------------------------------------------------
  BrawlEvent(
    id: 'hell_flesh',
    title: 'Metallic flesh',
    hell: true,
    text:
        'Something enormous died here, if things here die. Its flesh is '
        'metal and its blood is a fine vintage. Heavy elements glitter in '
        'every wound.',
    choices: const [
      Choice('Graft its hide over your hull', [
        Outcome(
          'The flesh settles over the holes in your hull as if it '
          'belonged there. It is warm to the touch.',
          weight: 2,
          effects: [HullChange(150)],
        ),
        Outcome('It was not dead.', effects: [Fight(demon: 2)]),
      ]),
      Choice('Drain its blood into crates', [
        Outcome(
          'Hell brandy, straight from the source. It sells for a fortune '
          'anywhere with a sense of taste.',
          weight: 2,
          effects: [
            GainCards([_brandy, _brandy]),
          ],
        ),
        Outcome(
          'It was not dead, and it would like its blood back.',
          effects: [Fight(demon: 2)],
        ),
      ]),
      Choice('Leave it alone', [
        Outcome('You give it a wide berth. It does not follow.'),
      ]),
    ],
  ),
  BrawlEvent(
    id: 'hell_hunter',
    title: 'Something follows',
    hell: true,
    text:
        'A demon the size of a moon has noticed you. It drifts closer with '
        'unhurried interest, the way a cat moves toward something small.',
    choices: const [
      Choice('Turn and fight', [
        Outcome(
          'It was hoping you would.',
          effects: [Fight(demon: 1, scrap: 1.5)],
        ),
      ]),
      Choice('Run', [
        Outcome(
          'You lose it in a bank of brandy fog, though not before it rakes '
          'your stern.',
          effects: [HullChange(-60)],
        ),
        Outcome(
          'It is faster than you, and it does not let go.',
          effects: [Fight(demon: 1, tractorBeam: true)],
        ),
      ]),
    ],
  ),
  BrawlEvent(
    id: 'hell_swarm',
    title: 'Teeth in the dark',
    hell: true,
    text:
        'A cloud of loose teeth, with no jaws to hold them, turns as one '
        'and comes at you.',
    choices: [
      const Choice('Stand and fight', [
        Outcome('They hit like hail.', effects: [Fight(demon: 0)]),
      ]),
      Choice('Throw them some cargo', const [
        Outcome(
          'They swarm a crate you dump out of the hold and chew it to '
          'nothing. You slip away while they\'re busy.',
          effects: [LoseCargo(), NoFight()],
        ),
      ], available: (s) => s.loadout.hold.isNotEmpty),
    ],
  ),
  BrawlEvent(
    id: 'hell_still',
    title: 'The still',
    hell: true,
    text:
        'Here the sea is thin and hot, and boils off the hull in sheets. '
        'Run it through the coolant loops and it would condense into '
        'something very strong indeed.',
    choices: const [
      Choice('Fill a cask', [
        Outcome(
          'A cask of Hell Brandy, fresh from the sea. The coolant loops will never be the '
          'same.',
          effects: [
            GainCards([_brandy]),
            HullChange(-30),
          ],
        ),
      ]),
      Choice('Fill two, and run the engines hot', [
        Outcome(
          'Two casks, and a hull that is groaning about it.',
          weight: 2,
          effects: [
            GainCards([_brandy, _brandy]),
            HullChange(-80),
          ],
        ),
        Outcome(
          'The loops burst. You get one cask and a great deal of fire.',
          effects: [
            GainCards([_brandy]),
            HullChange(-120),
          ],
        ),
      ]),
      Choice('Move on', [Outcome('You leave the sea to boil.')]),
    ],
  ),
  BrawlEvent(
    id: 'hell_clocks',
    title: 'Running backwards',
    hell: true,
    text:
        'Every clock on the bridge is running backwards, some of them '
        'faster than others. Somewhere out in the murk, something is '
        'ticking.',
    choices: [
      const Choice('Ride the current', [
        Outcome(
          'The current carries you to a gateway and spits you out. You '
          'arrive before you left, roughly.',
          weight: 2,
          effects: [LeaveHell()],
        ),
        Outcome('The current goes in a circle, and so do you.'),
      ]),
      Choice('Follow the ticking', const [
        Outcome(
          'A brass clock hangs in the murk, ticking backwards, set into a '
          'greasy black stone ball. There is a hole in the world at its '
          'centre. When you bring it aboard every other clock on the ship '
          'agrees with it at once, and everything made in Hell starts to '
          'hum.',
          effects: [
            GainCards(['hell_clock'], force: true),
            SetFlag(hasHellClock),
          ],
        ),
        Outcome(
          'The ticking was coming from inside something.',
          weight: 2,
          effects: [HullChange(-40), Fight(demon: 1)],
        ),
      ], available: (s) => !s.flags.contains(hasHellClock)),
    ],
  ),
  BrawlEvent(
    id: 'hell_barrier',
    title: 'A glow in the murk',
    hell: true,
    weight: (s) => 0.3 + 0.3 * s.hellTurns,
    text:
        'Far off, the faint blue line of a gateway pipe\'s barrier cuts '
        'through Hell. Something has been chewing on it. There are bite '
        'marks you could squeeze through, if you were quick.',
    choices: const [
      Choice('Squeeze back into the pipe', [
        Outcome(
          'You slip through a bite as it heals and come out at a station, '
          'stinking of brandy.',
          weight: 3,
          effects: [LeaveHell(), NoFight()],
        ),
        Outcome(
          'The teeth that made the hole are still there. You get through, '
          'but not alone.',
          effects: [LeaveHell(), Fight(demon: 0)],
        ),
      ]),
      Choice('Stay. There is more to find.', [
        Outcome('You turn your back on the way home.'),
      ]),
    ],
  ),
  BrawlEvent(
    id: 'hell_herald',
    title: 'A herald',
    hell: true,
    condition: (s) => s.hellTurns >= 3,
    text:
        'A demon lord\'s herald crosses your bow, armoured in the hulls of '
        'ships it has eaten. Lesser things scatter from it. It is looking '
        'for something to bring home to its master.',
    choices: const [
      Choice('Fight it', [
        Outcome(
          'It accepts with something like delight. It will not let you '
          'go until one of you is scrap.',
          effects: [Fight(demon: 3, tractorBeam: true, scrap: 2)],
        ),
      ]),
      Choice('Go dark and hide in the brandy fog', [
        Outcome('It passes by. You breathe again.', weight: 2),
        Outcome(
          'It smells you.',
          effects: [Fight(demon: 3, tractorBeam: true, scrap: 2)],
        ),
      ]),
    ],
  ),
  // The Mourner is the last Havi left in Hell, holding its dead home world
  // at the lip of the black hole that killed it. It doesn't want pity. Ask
  // it politely and it moves you out of harm's way.
  BrawlEvent(
    id: 'hell_mourner',
    title: 'The Mourner',
    hell: true,
    condition: (s) =>
        s.hellTurns >= 2 &&
        !s.flags.contains(metMourner) &&
        !s.flags.contains(hasHellClock),
    weight: (s) => 0.4 + 0.3 * s.hellTurns,
    text:
        'A planet hangs at the lip of a black hole. Something vast and '
        'unknowable holds it there, forever pulling it back from the brink '
        'and never quite far enough. You are falling toward the same '
        'brink.\n\n'
        'It turns its attention on you. It is old, and it is grieving, and '
        'it has seen your kind of ship before.',
    choices: const [
      Choice('Ask it, politely, for the way home', [
        Outcome(
          'It considers you for a long time. Then the black hole lets go '
          'of your ship, and something small and heavy is pressed into '
          'your hold: a brass clock ticking backwards, set into a greasy '
          'black stone ball with a hole in the world at its centre. For '
          'your trouble.\n\n'
          'When the stars come back they are ordinary ones.',
          effects: [
            GainCards(['hell_clock'], force: true),
            SetFlag(metMourner),
            SetFlag(hasHellClock),
            LeaveHell(),
            NoFight(),
          ],
        ),
      ]),
      Choice('Tell it you understand its loss', [
        Outcome(
          'It does not want your pity. It lets you know this at length, '
          'and your hull lets you know too.\n\n'
          'Then, as if remembering its manners, it gives you something '
          'anyway: a brass clock ticking backwards, set into a greasy black '
          'stone ball. It sets you down somewhere safe.',
          effects: [
            HullChange(-120, lethal: false),
            GainCards(['hell_clock'], force: true),
            SetFlag(metMourner),
            SetFlag(hasHellClock),
            LeaveHell(),
            NoFight(),
          ],
        ),
      ]),
      Choice('Open fire', [
        Outcome(
          'It does not notice. The black hole does: it is a long time '
          'before your ship stops screaming.\n\n'
          'When it is over, the Mourner is setting you down somewhere '
          'safe, as gently as it holds its world. There is a clock in your '
          'hold that was not there before, ticking backwards inside a '
          'greasy black stone ball.',
          effects: [
            HullChange(-250, lethal: false),
            GainCards(['hell_clock'], force: true),
            SetFlag(metMourner),
            SetFlag(hasHellClock),
            LeaveHell(),
            NoFight(),
          ],
        ),
      ]),
    ],
  ),
];

final brawlEventsById = {for (final e in brawlEvents) e.id: e};
