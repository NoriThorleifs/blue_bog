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
/// otherwise the scheduled enemy, [roundsAhead] fights early.
class Fight extends BrawlEffect {
  const Fight({
    this.demon,
    this.roundsAhead = 0,
    this.tractorBeam = false,
    this.scrap = 1,
    this.winCredits = 0,
  });
  final int? demon;
  final int roundsAhead;

  /// No breaking away at the time limit: it's a fight to the death.
  final bool tractorBeam;

  /// Multiplies the scrap paid for a win.
  final double scrap;

  /// Paid on top of scrap for a win.
  final int winCredits;
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

/// The flag set once the Backwards Clock has been found.
const foundClock = 'clock';

const _brandy = 'goods_brandy';

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
          'A brass clock hangs in the murk, ticking backwards. When you '
          'bring it aboard every other clock on the ship agrees with it '
          'at once.',
          effects: [
            GainCards(['mourner_backwards_clock']),
            SetFlag(foundClock),
          ],
        ),
        Outcome(
          'The ticking was coming from inside something.',
          weight: 2,
          effects: [HullChange(-40), Fight(demon: 1)],
        ),
      ], available: (s) => !s.flags.contains(foundClock)),
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
    condition: (s) => s.hellTurns >= 2 && !s.flags.contains(metMourner),
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
          'your hold: a greasy black stone ball, warm, with a hole in the '
          'world at its centre. For your trouble.\n\n'
          'When the stars come back they are ordinary ones.',
          effects: [
            GainCards(['cursed_orb'], force: true),
            SetFlag(metMourner),
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
          'anyway: a greasy black stone ball, warm, with a hole in the '
          'world at its centre. It sets you down somewhere safe.',
          effects: [
            HullChange(-120, lethal: false),
            GainCards(['cursed_orb'], force: true),
            SetFlag(metMourner),
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
          'safe, as gently as it holds its world. There is a greasy black '
          'stone ball in your hold that was not there before.',
          effects: [
            HullChange(-250, lethal: false),
            GainCards(['cursed_orb'], force: true),
            SetFlag(metMourner),
            LeaveHell(),
            NoFight(),
          ],
        ),
      ]),
    ],
  ),
];

final brawlEventsById = {for (final e in brawlEvents) e.id: e};
