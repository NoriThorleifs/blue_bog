import '../../captain/species.dart';
import '../../combat/combat.dart';
import '../brawl_events.dart';
import '../brawl_state.dart';

/// The human colony's story in a brawl, told in transit between a fight
/// and the next dock: the war for Neo Terra and its draft, the veterans
/// who come back, simple petitions to the captain, the Hellborn cell
/// hiding among the humans, and news of the other elected captains. Plus
/// the wrong warp a Hellborn representative can talk the captain into,
/// which happens on the way out of a station.
final colonyEvents = <BrawlEvent>[
  // The war for Neo Terra ---------------------------------------------------
  BrawlEvent(
    id: 'neo_terra_war',
    title: 'The war for Neo Terra',
    aftermath: true,
    always: true,
    condition: (s) => s.round >= _warRound && !s.drafted && _hasHumans(s),
    text:
        'The humans have gone to war for the hive world. A decoy fleet has '
        'drawn the Consumer armada away, and the main fleet is fighting for '
        'the shipbuilding gantry. The Promethius has declared a universal '
        'draft: every human of fighting age, wherever they live, is called '
        'up, and that includes your colony. A transport will meet you at '
        'every dock until the war is won.',
    choices: [
      Choice('See them off properly', [
        Outcome(
          'You open the hangar and let the colony say its goodbyes. The '
          'representatives thank you, stiffly, and mean it.',
          effects: [StartDraft(), ColonyChange(loyalty: 8)],
        ),
      ]),
      Choice('Remind them whose ship this is', [
        Outcome(
          'The transports dock anyway. It\'s their law, not yours, and every '
          'one of them knows it.',
          effects: [StartDraft(), ColonyChange(loyalty: -5, drift: -5)],
        ),
      ]),
    ],
  ),
  BrawlEvent(
    id: 'veterans_home',
    title: 'Coming home',
    aftermath: true,
    weight: (s) => 1.5,
    condition: (s) =>
        s.drafted && s.round >= s.counter(draftRoundKey) + _tourOfDuty,
    text:
        'A transport from Neo Terra docks with veterans who served their '
        'time. They walk off thinner than they left, and quieter. Some of '
        'them still have their helmets on.',
    choices: [
      Choice('Throw them a welcome', [
        Outcome(
          'The colony turns out for them. So do you, and they notice.',
          effects: [
            GainCredits(-20),
            ColonyChange(humans: 25, loyalty: 8),
            SetFlag(_veteransHome),
          ],
        ),
      ], available: (s) => s.credits >= 20),
      Choice('Let the colony look after its own', [
        Outcome(
          'The colony takes them in. Nobody asks you for anything.',
          effects: [
            ColonyChange(humans: 25, loyalty: 2),
            SetFlag(_veteransHome),
          ],
        ),
      ]),
    ],
  ),
  BrawlEvent(
    id: 'the_helmet',
    title: 'The old soldier',
    aftermath: true,
    always: true,
    condition: (s) =>
        s.flags.contains(_veteransHome) && !s.flags.contains(_helmetSeen),
    text:
        'One of the veterans still wears his helmet. It locks at the back, '
        'and only his commanding officer has the key: Neo Terra\'s soldiers '
        'can\'t take them off until they are home and signed out, so nobody '
        'deserts. His officer didn\'t come back. Later you find him curled '
        'up in a corridor, hands over his ears, listening to explosions that '
        'aren\'t there.',
    choices: [
      Choice('Sit with him', [
        Outcome(
          'You say nothing, and that is the right thing to say. Word gets '
          'around the colony.',
          effects: [ColonyChange(loyalty: 10, drift: 5), SetFlag(_helmetSeen)],
        ),
      ]),
      Choice('Leave him his dignity', [
        Outcome(
          'The colony has a key-cutter in one of its workshops. Of course it '
          'does. You never mention it, and neither does he.',
          effects: [ColonyChange(loyalty: 3), SetFlag(_helmetSeen)],
        ),
      ]),
    ],
  ),

  // Petitions ---------------------------------------------------------------
  BrawlEvent(
    id: 'petition_rifles',
    title: 'A petition: the rifles',
    aftermath: true,
    condition: (s) =>
        s.humans.count >= 100 && !s.flags.contains('petition_rifles'),
    text:
        'The representatives come to the bridge. The colony\'s workshops '
        'have been making rifles: small, dense, very good rifles. They would '
        'like to keep them.',
    choices: [
      Choice('They can keep them', [
        Outcome(
          'They thank you. You notice afterwards that they had not been '
          'asking.',
          effects: [
            ColonyChange(loyalty: 6, drift: 5),
            SetFlag('petition_rifles'),
          ],
        ),
      ]),
      Choice('Confiscate them', [
        Outcome(
          'You sell the rifles at the next station for a good price. The '
          'colony does not forget.',
          effects: [
            GainCredits(40),
            ColonyChange(loyalty: -8),
            SetFlag('petition_rifles'),
          ],
        ),
      ]),
    ],
  ),
  BrawlEvent(
    id: 'petition_gravity',
    title: 'A petition: gravity',
    aftermath: true,
    condition: (s) => _hasHumans(s) && !s.flags.contains('petition_gravity'),
    text:
        'The colony asks for the habitat\'s spin to be raised to their home '
        'gravity. Their bones are going soft in yours. It means paying for '
        'a heavier spin rig at the next dock.',
    choices: [
      Choice('Pay for it', [
        Outcome(
          'The habitat spins up. Your humans stop drifting through the '
          'corridors and start stomping through them.',
          effects: [
            GainCredits(-30),
            ColonyChange(loyalty: 6),
            SetFlag('petition_gravity'),
          ],
        ),
      ], available: (s) => s.credits >= 30),
      Choice('Not now', [
        Outcome(
          'The representatives say they understand.',
          effects: [ColonyChange(loyalty: -3), SetFlag('petition_gravity')],
        ),
      ]),
    ],
  ),
  BrawlEvent(
    id: 'petition_wreck',
    title: 'A petition: the wreck',
    aftermath: true,
    condition: (s) =>
        _hasHumans(s) &&
        s.lastCombat?.result.outcome == CombatOutcome.win &&
        !s.inHell,
    text:
        'Before you scrap what\'s left of the enemy, the colony\'s scavengers '
        'ask for first pick. Their workshops are always short of parts.',
    choices: [
      Choice('Let them', [
        Outcome(
          'They strip it to the frame in an hour. The workshops are humming '
          'all the way to the next dock.',
          effects: [ColonyChange(loyalty: 4)],
        ),
      ]),
      Choice('Scrap it all', [
        Outcome(
          'The scrapyard pays a little more for a whole wreck.',
          effects: [GainCredits(15), ColonyChange(loyalty: -2)],
        ),
      ]),
    ],
  ),

  // The Hellborn cell -------------------------------------------------------
  // Agents never out themselves to the captain, but to the other humans
  // something is plainly off about them.
  BrawlEvent(
    id: 'hell_headcount',
    title: 'The headcount',
    aftermath: true,
    always: true,
    condition: (s) =>
        s.leavingHell && s.hellTurns >= 2 && _hasHumans(s) && _room(s),
    text:
        'Clear of Hell, your humans do a headcount. Then they do another. It '
        'doesn\'t add up: there are more of them aboard than there were '
        'when the ship went in. The new faces say they have been here all '
        'along.',
    choices: [
      Choice('Ask how', [
        Outcome(
          'Nobody can say. The newcomers insist they were born aboard and '
          'never left. Your other humans keep their distance, and quietly '
          'point out what you would never have noticed: the newcomers\' eyes '
          'are red, not brown or blue, and they drank the galley\'s brandy '
          'all night without slurring a word.',
          effects: [ColonyChange(humans: 20), CellChange(1)],
        ),
      ]),
      Choice('Make room for them', [
        Outcome(
          'More hands are more hands. The newcomers settle in as if they had '
          'always been aboard, and your humans stop talking about it when '
          'you walk past.',
          effects: [ColonyChange(humans: 20, loyalty: 1), CellChange(1)],
        ),
      ]),
    ],
  ),
  BrawlEvent(
    id: 'red_eyes',
    title: 'Something off',
    aftermath: true,
    condition: (s) => s.hellbornCell >= 1 && !s.flags.contains('red_eyes'),
    text:
        'A few of your humans ask to see you privately. They are worried '
        'about some of the others: whose eyes are red rather than brown or '
        'blue, who drink the galley\'s brandy all night without slurring, '
        'and who nobody can remember signing on.',
    choices: [
      Choice('Take it to the representatives', [
        Outcome(
          'One of the representatives, a quiet engineer, says she will look '
          'into it. She smiles while she says it.',
          effects: [ColonyChange(loyalty: -2), SetFlag('red_eyes')],
        ),
      ]),
      Choice('It\'s their business, not yours', [
        Outcome(
          'They look relieved, and a little disappointed.',
          effects: [
            ColonyChange(loyalty: 3),
            CellChange(1),
            SetFlag('red_eyes'),
          ],
        ),
      ]),
    ],
  ),
  BrawlEvent(
    id: 'wrong_warp_offer',
    title: 'An idea about the next jump',
    aftermath: true,
    condition: (s) =>
        s.hellbornCell >= 2 && !s.flags.contains('wrong_warp_offered'),
    text:
        'The quiet engineer who speaks for part of the colony has an idea. '
        'Hit the next gateway at a steep angle and full burn, she says, and '
        'you\'ll be out the far end before the pipe has finished pulling you '
        'in. You would skip whatever is waiting on the way. She can\'t say '
        'how she knows. She doesn\'t try.',
    choices: [
      Choice('Try it next time', [
        Outcome(
          'She nods, as if you had passed something.',
          effects: [SetFlag(_wrongWarp), SetFlag('wrong_warp_offered')],
        ),
      ]),
      Choice('Fly like everybody else', [
        Outcome(
          'She shrugs. "Your ship."',
          effects: [SetFlag('wrong_warp_offered')],
        ),
      ]),
    ],
  ),
  BrawlEvent(
    id: 'wrong_warp',
    title: 'Wrong warp',
    always: true,
    condition: (s) => s.flags.contains(_wrongWarp) && !s.inHell,
    text:
        'You take the gateway at an angle no sane captain would, at full '
        'burn. Alarms you didn\'t know the ship had go off all at once.',
    choices: [
      Choice('Hold on', [
        Outcome(
          'For a moment the pipe is all around you, and then it isn\'t. You '
          'come out the far end with nothing waiting for you.',
          weight: 3,
          effects: [NoFight(), ClearFlag(_wrongWarp)],
        ),
        Outcome(
          'The angle was wrong. The barrier tears, and what is on the other '
          'side takes you through.',
          effects: [EnterHell(), ClearFlag(_wrongWarp)],
        ),
      ]),
    ],
  ),

  // The colony and its captain ----------------------------------------------
  BrawlEvent(
    id: 'colony_strike',
    title: 'Strike',
    aftermath: true,
    always: true,
    condition: (s) =>
        _hasHumans(s) &&
        s.humans.loyalty < strikeLoyalty &&
        !s.flags.contains(colonyStrike),
    text:
        'The colony has stopped patching the hull. The representatives say '
        'they will start again when they have a captain worth patching for.',
    choices: [
      Choice('Make amends', [
        Outcome(
          'It costs you, and they make sure you know it was worth it.',
          effects: [GainCredits(-40), ColonyChange(loyalty: 25)],
        ),
      ], available: (s) => s.credits >= 40),
      Choice('Wait them out', [
        Outcome(
          'The corridors go very quiet. The hull stays as it is.',
          effects: [SetFlag(colonyStrike)],
        ),
      ]),
    ],
  ),
  BrawlEvent(
    id: 'kepler_refused',
    title: 'Blue bog',
    aftermath: true,
    condition: (s) =>
        s.round >= 6 && _hasHumans(s) && !s.flags.contains('kepler_refused'),
    text:
        'The council has turned the humans down again: still no landing on '
        'Kepler. A heavy world around a blue sun with nothing on it that can '
        'talk, watched from an observation platform for a thousand years. '
        'The Republic calls it one unimportant blue bog. The humans flew six '
        'thousand years to reach it. The representatives ask you to sign '
        'their petition.',
    choices: [
      Choice('Sign it', [
        Outcome(
          'Your name goes on the list, under four others like it.',
          effects: [
            ColonyChange(loyalty: 6, drift: 4),
            SetFlag('kepler_refused'),
          ],
        ),
      ]),
      Choice('Stay out of it', [
        Outcome(
          'They don\'t argue. They do remember.',
          effects: [ColonyChange(loyalty: -2), SetFlag('kepler_refused')],
        ),
      ]),
    ],
  ),
  BrawlEvent(
    id: 'elephant_crate',
    title: 'A favour',
    aftermath: true,
    condition: (s) =>
        s.round >= 10 &&
        s.loadout.hold.isNotEmpty &&
        _hasHumans(s) &&
        !s.flags.contains('elephant_crate'),
    text:
        'The representatives ask a favour. On the way, drop one of the '
        'crates in the hold at an asteroid off the lane. No questions. '
        'Somebody out there is building something, and would rather nobody '
        'knew.',
    choices: [
      Choice('Drop it off', [
        Outcome(
          'Nobody meets you. The crate is gone when you look back, and a '
          'trumpet sounds on the radio, once.',
          effects: [
            LoseCargo(),
            ColonyChange(loyalty: 8, drift: 3),
            SetFlag('elephant_crate'),
          ],
        ),
      ]),
      Choice('No questions means no', [
        Outcome(
          'The representatives say they will find another way.',
          effects: [ColonyChange(loyalty: -2), SetFlag('elephant_crate')],
        ),
      ]),
    ],
  ),

  // The other elected captains ----------------------------------------------
  BrawlEvent(
    id: 'gor_colony_mutiny',
    title: 'News from the Gor colony ship',
    aftermath: true,
    condition: (s) =>
        s.round >= 3 &&
        s.species != Species.gor &&
        !s.flags.contains('gor_colony_mutiny'),
    text:
        'Word comes over the relay: the colony on the Gor captain\'s ship has '
        'mutinied. The Gor say it was put down. The humans say it was '
        'something else. The Republic is watching the other elected captains '
        'very closely now, you included.',
    choices: [
      Choice('Tell your colony you are not him', [
        Outcome(
          'They listen politely. It helps a little.',
          effects: [ColonyChange(loyalty: 4), SetFlag('gor_colony_mutiny')],
        ),
      ]),
      Choice('Say nothing', [
        Outcome(
          'The colony talks about it for days, mostly when you can hear.',
          effects: [SetFlag('gor_colony_mutiny')],
        ),
      ]),
    ],
  ),
  BrawlEvent(
    id: 'tern_colony_stays',
    title: 'News from the Tern colony ship',
    aftermath: true,
    condition: (s) =>
        s.round >= 12 &&
        s.species != Species.tern &&
        !s.flags.contains('tern_colony_stays'),
    text:
        'The colony on the Tern captain\'s ship has asked to stay aboard for '
        'good, whatever the council decides about Kepler. The Tern captain '
        'said yes before the question was finished. Your representatives '
        'mention it to you, in passing, twice.',
    choices: [
      Choice('Good for them', [
        Outcome(
          'The representatives wait to see if you will say anything else.',
          effects: [SetFlag('tern_colony_stays')],
        ),
      ]),
      Choice('So can you', [
        Outcome(
          'It is the first time you have seen the representatives smile.',
          effects: [
            ColonyChange(loyalty: 8, drift: 4),
            SetFlag('tern_colony_stays'),
          ],
        ),
      ]),
    ],
  ),
];

/// The fight at which the war for Neo Terra starts, and the draft with it.
const _warRound = 5;

/// Fights a drafted human serves on Neo Terra before coming home.
const _tourOfDuty = 3;

const _veteransHome = 'veterans_home';
const _helmetSeen = 'helmet_seen';
const _wrongWarp = 'wrong_warp';

bool _hasHumans(BrawlState s) => s.humans.count > 0;
bool _room(BrawlState s) => s.stats.housing > s.humans.count;
