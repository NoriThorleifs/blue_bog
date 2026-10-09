import '../brawl_events.dart';

/// Hell, once per turn there.
final brawlHellEvents = <BrawlEvent>[
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
            GainCards([hellBrandy, hellBrandy]),
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
            GainCards([hellBrandy]),
            HullChange(-30),
          ],
        ),
      ]),
      Choice('Fill two, and run the engines hot', [
        Outcome(
          'Two casks, and a hull that is groaning about it.',
          weight: 2,
          effects: [
            GainCards([hellBrandy, hellBrandy]),
            HullChange(-80),
          ],
        ),
        Outcome(
          'The loops burst. You get one cask and a great deal of fire.',
          effects: [
            GainCards([hellBrandy]),
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
