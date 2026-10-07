import '../faction.dart';
import '../galaxy/galaxy.dart';
import '../story/keys.dart';
import '../story/rules.dart';
import '../story/story.dart';

/// Minor factions and the wars that follow Code Red and Code Yellow.
final factionEvents = <GameEvent>[
  // The House of the Elephant -----------------------------------------------
  // Shady, but mostly humans trying to build their own spaceport on an
  // asteroid near a sublight lane.
  const GameEvent(
    id: 'elephant_trumpet',
    title: 'A trumpet in the dark',
    triggers: {Trigger.sublight},
    condition: AllOf([
      AnyOf([AtSystem(Sys.ghorDum), AtSystem(Sys.urGor)]),
      NoFlag(Flag.elephantFound),
    ]),
    text:
        'Halfway through the burn, the short-range radio picks up something '
        'nobody aboard recognises except the humans: an elephant trumpeting. '
        'It comes from a mine, one of many, strung around an asteroid well '
        'off the lane. Your humans are grinning.',
    choices: [
      Choice(
        'Mark it on the chart',
        outcomes: [
          Outcome(
            '"The House of the Elephant," your humans say. "They\'re all '
            'right. Mostly."',
            effects: [Reveal(Sys.elephantHq), SetFlag(Flag.elephantFound)],
          ),
        ],
      ),
    ],
  ),
  GameEvent(
    id: 'elephant_rumour',
    title: 'Rumours',
    triggers: const {Trigger.arrival, Trigger.hold},
    condition: const AllOf([
      AtTag(Tag.station),
      HumansAtLeast(1),
      NoFlag(Flag.elephantFound),
    ]),
    weight: 0.5,
    text:
        'Over a drink, a human trader complains about a rock off the '
        '{sys:ghor_dum} lane where the mines trumpet like elephants and the '
        'docking fees are criminal. "Best repair yard this side of the '
        'Center, though."',
    choices: [
      Choice.simple(
        'Buy the coordinates',
        'They are scrawled on a napkin. They are correct.',
        condition: const CreditsAtLeast(10),
        hint: '10 credits',
        effects: const [
          Credits(-10),
          Reveal(Sys.elephantHq),
          SetFlag(Flag.elephantFound),
        ],
      ),
      Choice.simple(
        'Let your humans ask around',
        'Your humans come back with the coordinates and a hangover.',
        condition: const BondAtLeast(30),
        effects: const [Reveal(Sys.elephantHq), SetFlag(Flag.elephantFound)],
      ),
      Choice.simple('Ignore it', 'Probably nonsense.'),
    ],
  ),
  GameEvent(
    id: 'elephant_mines',
    title: 'The minefield',
    condition: const AllOf([
      AtSystem(Sys.elephantHq),
      NoFlag(Flag.elephantWelcome),
    ]),
    always: true,
    once: false,
    text:
        'Every mine you pass trumpets at you over short-range radio. '
        'Further in, a bored human voice says: "This is the House of the '
        'Elephant. Lady Idun\'s rock, Lady Idun\'s rules. State your '
        'business or go around. The mines don\'t care which."',
    choices: [
      Choice(
        'Let your humans answer',
        condition: const HumansAtLeast(1),
        outcomes: [
          Outcome(
            'Your humans mention the Promethius, and that you treat them '
            'right. A channel through the mines lights up.',
            condition: const AllOf([
              BondAtLeast(25),
              NoFlag(Flag.elephantEnemy),
            ]),
            effects: const [SetFlag(Flag.elephantWelcome)],
          ),
          Outcome(
            '"Doesn\'t sound like it," says the voice. The mines keep '
            'trumpeting until you leave.',
            condition: const AnyOf([
              Not(BondAtLeast(25)),
              HasFlag(Flag.elephantEnemy),
            ]),
            effects: const [Retreat()],
          ),
        ],
      ),
      const Choice(
        'Push through the mines',
        outcomes: [
          Outcome(
            'The mines don\'t care. Then their ships come out to finish '
            'the job.',
            effects: [
              Hull(-90),
              SetFlag(Flag.elephantEnemy),
              Combat(
                'House of the Elephant pickets',
                8,
                win: [Credits(60), Note('Shot our way into Elephant Rock.')],
                lose: [Hull(-90), Retreat()],
              ),
            ],
          ),
        ],
      ),
      Choice.simple('Go around', 'You go around.', effects: const [Retreat()]),
    ],
  ),
  GameEvent(
    id: 'elephant_port',
    title: 'Elephant Rock',
    condition: const AllOf([
      AtSystem(Sys.elephantHq),
      HasFlag(Flag.elephantWelcome),
    ]),
    once: false,
    weight: 20,
    text:
        'Half a spaceport, bolted to an asteroid. Everything is for sale, '
        'nothing has a receipt, and the repair crews are excellent. Lady '
        'Idun the Giantess watches the docks from a balcony built for '
        'someone her size, which is to say very large.',
    choices: [
      Choice.simple(
        'Repairs, no questions asked',
        'Done by morning.',
        condition: const CreditsAtLeast(20),
        hint: '20 credits',
        effects: const [Credits(-20), Hull(225)],
      ),
      Choice.simple(
        'Sell what you picked up in Hell',
        'They don\'t ask where it came from. They pay well.',
        condition: const CounterAtLeast(Counter.hellbornAwareness, 1),
        effects: const [Credits(45)],
      ),
      Choice.simple(
        'Take on crew',
        'A few humans who want to see more of the galaxy than one rock.',
        condition: const CreditsAtLeast(10),
        hint: '10 credits',
        effects: const [Credits(-10), Humans(3), MaybeAgent(0.3)],
      ),
      Choice.simple(
        'Buy salvaged ship parts',
        'Nobody asks where it came from. Nobody tells you either.',
        condition: const CreditsAtLeast(30),
        hint: '30 credits',
        effects: const [Credits(-30), GrantCard('salvage')],
      ),
      Choice.simple('Just look around', 'Shady, you decide. But nice.'),
    ],
  ),
  GameEvent(
    id: 'elephant_raiders',
    title: 'The Elephant remembers',
    condition: const AllOf([
      HasFlag(Flag.elephantEnemy),
      AnyOf([AtTag(Tag.frontier), AtTag(Tag.gor)]),
    ]),
    once: false,
    weight: 1.5,
    text: 'Two House of the Elephant gunships drop in behind you, trumpeting.',
    choices: [
      const Choice(
        'Fight',
        outcomes: [
          Outcome(
            '',
            effects: [
              Combat(
                'House of the Elephant gunships',
                7,
                win: [Credits(40)],
                lose: [Hull(-105)],
              ),
            ],
          ),
        ],
      ),
      Choice.simple(
        'Pay for the dent you made in their minefield',
        'They take the money and the grudge with it.',
        condition: const CreditsAtLeast(50),
        hint: '50 credits',
        effects: const [Credits(-50), ClearFlag(Flag.elephantEnemy)],
      ),
    ],
  ),

  // The Fuel Rats -------------------------------------------------------------
  // A human merchants' guild of fuel and essentials. First to answer a
  // distress call, and they charge an arm and a leg. Their tab is real: it
  // comes due a few turns later, and they collect.
  GameEvent(
    id: 'fuel_rats_stranded',
    title: 'The Fuel Rats',
    triggers: const {Trigger.arrival, Trigger.hold},
    condition: _stranded,
    always: true,
    once: false,
    text:
        'Your tanks are dry. A human tender is already pulling alongside, '
        'as if they\'d been waiting. "Fuel Rats. Out of fuel in the middle '
        'of nowhere? Embarrassing. We can fix that. It\'ll cost you."',
    choices: _ratChoices,
  ),
  GameEvent(
    id: 'fuel_rats',
    title: 'The Fuel Rats',
    triggers: const {Trigger.arrival, Trigger.hold},
    condition: const AllOf([
      NotInHell(),
      NoFlag(Flag.fuelRatsEnemy),
      HullAtMost(0.3),
    ]),
    once: false,
    weight: 8,
    text:
        'Your ship is in a state, and someone noticed. A human tender pulls '
        'alongside before you\'ve even decided whether to call for help. '
        '"Fuel Rats. Saw your situation. Embarrassing. We can fix it. '
        'It\'ll cost you."',
    choices: _ratChoices,
  ),
  GameEvent(
    id: 'fuel_rats_collect',
    title: 'The Fuel Rats would like a word',
    triggers: const {Trigger.queued},
    text:
        'A Fuel Rats tender matches course with you. "Your tab is due, '
        'captain. {counter:fuel_rats_debt} credits. We take cash, or we take it out of your '
        'tanks."',
    choices: [
      Choice.simple(
        'Settle up',
        'Paid in full. They are almost friendly about it.',
        condition: const CanAffordCounter(Counter.fuelRatsDebt),
        effects: const [SettleDebt(Counter.fuelRatsDebt)],
      ),
      Choice.simple(
        'You can\'t pay',
        'They take every credit you have and siphon your tanks dry. Then '
            'they close your account. The next time you\'re stranded, nobody '
            'is coming.',
        effects: const [
          Credits(-9999),
          Fuel(-9999),
          AddCounter(Counter.fuelRatsDebt, -9999),
          SetFlag(Flag.fuelRatsEnemy),
          Loyalty(-6),
        ],
      ),
    ],
  ),
  GameEvent(
    id: 'stranded_alone',
    title: 'Dead in space',
    triggers: const {Trigger.arrival, Trigger.hold},
    condition: const AllOf([_strandedHere, HasFlag(Flag.fuelRatsEnemy)]),
    always: true,
    once: false,
    text:
        'Your tanks are dry and the Fuel Rats aren\'t coming. There is a '
        'wreck drifting a few thousand kilometres off.',
    choices: [
      Choice.simple(
        'Siphon what you can from the wreck',
        'It takes all day and some of your hull, but you can move again.',
        effects: const [Fuel(3), Hull(-30)],
      ),
    ],
  ),

  // Human pirates -------------------------------------------------------------
  // They won't kill humans. A ship without any is fair game.
  GameEvent(
    id: 'pirate_shakedown',
    title: 'Human pirates',
    condition: const AllOf([
      HumansAtLeast(1),
      AnyOf([AtTag(Tag.frontier), AtTag(Tag.ruins), AtTag(Tag.neutral)]),
    ]),
    once: false,
    weight: 0.3,
    text:
        'Three ships with no transponders box you in. Their hail is very '
        'polite. They have noticed your humans and would rather not shoot '
        'anyone, so let\'s talk about a toll.',
    choices: [
      Choice.simple(
        'Pay the toll',
        'They thank you and wish your humans well.',
        condition: const CreditsAtLeast(25),
        hint: '25 credits',
        effects: const [Credits(-25)],
      ),
      const Choice(
        'Let your humans talk to them',
        outcomes: [
          Outcome(
            'Your humans vouch for you. The pirates let you go and throw in '
            'a tip about a soft cargo hauler nearby.',
            condition: BondAtLeast(40),
            effects: [Credits(15), Drift(4)],
          ),
          Outcome(
            'Your humans talk to them for a long time. Two of them leave '
            'with the pirates.',
            condition: Not(BondAtLeast(40)),
            effects: [Humans(-2), Loyalty(-4)],
          ),
        ],
      ),
      Choice.simple(
        'Refuse',
        'They board you with stun weapons, take what they want, and leave '
            'everybody breathing.',
        effects: const [Credits(-40), Loyalty(-3)],
      ),
    ],
  ),
  const GameEvent(
    id: 'pirate_hunt',
    title: 'Human pirates',
    condition: AllOf([
      Not(HumansAtLeast(1)),
      AnyOf([AtTag(Tag.frontier), AtTag(Tag.ruins), AtTag(Tag.neutral)]),
    ]),
    once: false,
    weight: 1.5,
    text:
        'Three ships with no transponders scan you, find no humans aboard, '
        'and open fire without a word.',
    choices: [
      Choice(
        'Fight',
        outcomes: [
          Outcome(
            '',
            effects: [
              Combat(
                'human pirates',
                9,
                win: [Credits(40)],
                lose: [Hull(-150), Credits(-30)],
              ),
            ],
          ),
        ],
      ),
    ],
  ),

  // The wars after the code ---------------------------------------------------
  const GameEvent(
    id: 'war_red_begins',
    title: 'Code Red',
    triggers: {Trigger.queued},
    text:
        'Code Red. The Republic decided to be rid of the humans, and the '
        'humans have answered. Out of the gateway at Kyndari come ships '
        'that grew up in Hell, under the command of General Grönigen. They '
        'intend to take the galaxy, one gate at a time.',
    choices: [
      Choice('Brace', outcomes: [Outcome('Nine turns of war.')]),
    ],
  ),
  const GameEvent(
    id: 'war_yellow_begins',
    title: 'Code Yellow',
    triggers: {Trigger.queued},
    text:
        'Code Yellow. The humans are fighting something that isn\'t the '
        'Republic, and it has just broken through. The gatecrash is '
        'happening again: barriers are failing between random gate pairs, '
        'and the demons are spilling out.',
    choices: [
      Choice('Brace', outcomes: [Outcome('Nine turns of war.')]),
    ],
  ),
  GameEvent(
    id: 'hellborn_checkpoint',
    title: 'Hellborn checkpoint',
    condition: const AllOf([
      HasFlag(Flag.warRed),
      ControlledBy(Faction.hellborn),
    ]),
    always: true,
    once: false,
    text:
        'Hellborn warships hold this system. They are human, mostly. They '
        'are scanning you.',
    choices: [
      const Choice(
        'Let your humans speak for you',
        condition: HumansAtLeast(1),
        outcomes: [
          Outcome(
            'Your humans talk. The Hellborn listen, and wave you on.',
            condition: AnyOf([BondAtLeast(50), HasFlag(Flag.hellbornAlly)]),
          ),
          Outcome(
            'The Hellborn are not convinced. They escort you out.',
            condition: Not(
              AnyOf([BondAtLeast(50), HasFlag(Flag.hellbornAlly)]),
            ),
            effects: [Retreat()],
          ),
        ],
      ),
      const Choice(
        'Fight your way through',
        outcomes: [
          Outcome(
            '',
            effects: [
              Combat(
                'a Hellborn battle group',
                14,
                win: [Credits(80)],
                lose: [Hull(-180), Retreat()],
              ),
            ],
          ),
        ],
      ),
      Choice.simple('Retreat', 'You leave.', effects: const [Retreat()]),
    ],
  ),
  GameEvent(
    id: 'demon_infestation',
    title: 'Overrun',
    condition: const ControlledBy(Faction.demons),
    always: true,
    once: false,
    text:
        'This system belongs to Hell now. Metallic flesh is growing over '
        'the stations, and something with too many teeth is coming for you.',
    choices: [
      const Choice(
        'Fight',
        outcomes: [
          Outcome(
            '',
            effects: [
              Combat(
                'demons',
                11,
                win: [Credits(70)],
                lose: [Hull(-150), Retreat()],
              ),
            ],
          ),
        ],
      ),
      Choice.simple(
        'Run',
        'You get out, minus some hull.',
        effects: const [Hull(-60), Retreat()],
      ),
    ],
  ),
];

/// Out of fuel, somewhere you can't buy any.
const _strandedHere = AllOf([
  NotInHell(),
  FuelBelow(1),
  Not(AllOf([AtTag(Tag.station), CreditsAtLeast(2)])),
]);

const _stranded = AllOf([_strandedHere, NoFlag(Flag.fuelRatsEnemy)]);

final _ratChoices = [
  Choice.simple(
    'Pay their price',
    'Tanks full, hull patched. They\'re gone within the hour.',
    condition: const CreditsAtLeast(45),
    hint: '45 credits',
    effects: const [Credits(-45), Fuel(99), Hull(150)],
  ),
  Choice.simple(
    'Put it on your tab',
    '"Seventy, due in four turns. We\'ll find you." They will.',
    condition: const CounterBelow(Counter.fuelRatsDebt, 140),
    hint: '+70 credits owed',
    effects: const [Fuel(99), Hull(150), AddCounter(Counter.fuelRatsDebt, 70)],
  ),
  Choice.simple(
    'Let them strip something for parts',
    'Your tab is full, so they take payment in plating. You can move '
        'again. Your ship is a little less of a ship.',
    condition: const AllOf([
      Not(CreditsAtLeast(45)),
      Not(CounterBelow(Counter.fuelRatsDebt, 140)),
    ]),
    effects: const [Fuel(4), Hull(-120)],
  ),
  Choice.simple(
    'Wave them off',
    '"Your funeral." They wait just out of range, in case.',
  ),
];
