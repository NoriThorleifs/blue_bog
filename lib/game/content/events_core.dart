import '../captain/species.dart';
import '../run_state.dart';
import '../story/keys.dart';
import '../story/rules.dart';
import '../story/story.dart';

/// Events the engine queues itself, plus the Hell pool.
final coreEvents = <GameEvent>[
  GameEvent(
    id: 'opening',
    title: 'Captain\'s log, turn one',
    triggers: const {Trigger.queued},
    text:
        'A battered colony ship called the Promethius crawled into the '
        'Kepler system at sublight, carrying a species nobody had heard of. '
        'Humans. They say they flew for six thousand years from a dying sun. '
        'The council at the Center has been arguing about what to do with '
        'them ever since.\n\n'
        'Meanwhile they live at Orcha Station on temporary permits and sign '
        'on to any ship that will have them. Yours has a few. They are '
        'small, dense, friendly and very, very good at math.',
    choices: [
      Choice.simple(
        'Welcome them properly',
        'You spend more than you should on a welcome dinner. The humans '
            'seem to understand what it cost.',
        effects: const [MaybeAgent(0.25), Credits(-10), Loyalty(8)],
      ),
      Choice.simple(
        'Remind them who is captain',
        'They nod politely. One of them starts a list.',
        effects: const [MaybeAgent(0.25), Loyalty(-6), Drift(-5)],
      ),
      Choice.simple(
        'Ask them about their number system',
        'They count in tens. You count in threes. The argument lasts all '
            'night and nobody has ever enjoyed one more.',
        condition: const IsSpecies(Species.tern),
        effects: const [MaybeAgent(0.25), Loyalty(12), Drift(6)],
      ),
      Choice.simple(
        'Measure them',
        'You can\'t help it. The humans tolerate a full sensory survey with '
            'surprising good humour. One asks if you\'re going to buy them a '
            'drink first.',
        condition: const IsSpecies(Species.al),
        effects: const [MaybeAgent(0.25), Loyalty(4), Drift(3)],
      ),
    ],
  ),
  GameEvent(
    id: 'mutiny',
    title: 'The bridge door is welded shut',
    triggers: const {Trigger.queued},
    once: false,
    text:
        'The humans have sealed themselves into engineering and welded the '
        'bridge door shut, with you on the wrong side of it. Their '
        'spokesperson is very calm. They are prepared to vent the reactor '
        'if that is what it takes to be rid of you.',
    choices: [
      Choice.simple(
        'Pay them what they\'re owed, and then some',
        'The door is cut open. Nobody apologises, but the crew goes back '
            'to work.',
        condition: const CreditsAtLeast(30),
        hint: '30 credits',
        effects: const [Credits(-30), Loyalty(30)],
      ),
      const Choice(
        'Promise things will change',
        outcomes: [
          Outcome(
            'They believe you. Barely. You had better mean it.',
            weight: 2,
            bondWeight: 1,
            effects: [Loyalty(20), Drift(10)],
          ),
          Outcome(
            'They have heard that before. The reactor goes critical.',
            effects: [EndRun(Ending.mutiny)],
          ),
        ],
      ),
      const Choice(
        'Cut through the door',
        outcomes: [
          // Not a ship battle: a brawl in the corridors.
          Outcome(
            'You get through. Several humans end up in the airlock and the '
            'rest go back to work. Nobody will forget this.',
            effects: [Humans(-6), Loyalty(25), Note('Put down a mutiny.')],
          ),
          Outcome(
            'You get through the door. They were waiting on the other side.',
            effects: [EndRun(Ending.mutiny)],
          ),
        ],
      ),
      Choice.simple(
        'Let them off at the next port',
        'Every human aboard leaves. The ship is very quiet.',
        effects: const [Humans(-99), Loyalty(50)],
      ),
    ],
  ),
  GameEvent(
    id: 'hell_breach',
    title: 'Teeth',
    triggers: const {Trigger.queued},
    once: false,
    text:
        'Halfway through the pipe the barrier tears. There are teeth on '
        'the other side, thousands of them, in no mouth at all, and they '
        'drag the ship through.\n\n'
        'You are in Hell. Outside the hull is an alcoholic sea of metallic '
        'flesh. Inside, the clocks have started to disagree. The torn pipe '
        'is still around you, for now.',
    choices: [
      Choice.simple(
        'Hold course inside the pipe',
        'You hug the inside of the barrier and wait for a way out.',
      ),
      Choice.simple(
        'Leave the pipe',
        'You steer out through the tear into open Hell. It is the most '
            'dangerous thing you have ever done, and everyone aboard knows it. '
            'Some of them are smiling.',
        effects: const [EnterHell(HellZone.deep), Drift(5)],
      ),
      const Choice(
        'Burn straight back at the tear',
        outcomes: [
          Outcome(
            'The teeth let go. The pipe spits you out.',
            effects: [EscapeHell()],
          ),
          Outcome(
            'The teeth do not let go. Something gives, and it is the hull.',
            weight: 2,
            effects: [Hull(-45)],
          ),
        ],
      ),
    ],
  ),
  GameEvent(
    id: 'code_green',
    title: 'Code Green',
    triggers: const {Trigger.queued},
    text:
        'The humans ask for the comms array. They are not asking.\n\n'
        'They send a short burst on a frequency none of your equipment '
        'recognises, a phrase repeated three times. Then they wait. Out in '
        'the dark, something that looks very much like a human ship turns '
        'toward you.',
    choices: [
      Choice(
        'Let them finish',
        outcomes: [
          Outcome(
            'The ships that come for you are human, more or less. They tow '
            'you to the barrier, patch your hull with something that '
            'breathes and push you out through a gateway. Your humans will '
            'not say a word about it. They look at you differently now.',
            condition: const ActIs(1),
            effects: _codeGreen,
          ),
          Outcome(
            'The ships that come for you are human, more or less. Before '
            'they push you out through a gateway, one of them teaches your '
            'pilot a manoeuvre: hit the gateway at an angle and speed no '
            'sane species would try. Your humans look very pleased.',
            condition: const ActIs(2),
            effects: [..._codeGreen, SetFlag(Flag.wrongWarping)],
          ),
          Outcome(
            'The ships that come for you are human, more or less, and there '
            'are a great many of them. They tow you out. As they leave, '
            'they turn toward Kyndari, where something huge is pressing on '
            'the barrier.',
            condition: const ActIs(3),
            effects: [..._codeGreen, SetFlag(Flag.demonsStirring)],
          ),
        ],
      ),
      Choice.simple(
        'Cut the transmission',
        'You pull the plug. The humans don\'t argue. The ones who sent the '
            'message don\'t speak to you again.',
        effects: const [Loyalty(-20), Drift(-10)],
      ),
    ],
  ),
  GameEvent(
    id: 'the_code',
    title: 'The code',
    triggers: const {Trigger.queued},
    text:
        'Every human aboard stops what they are doing at the same moment. '
        'A short burst is moving through every gateway pipe in the network, '
        'one word repeated three times.\n\n'
        'Your humans tell you, with no expression at all, that the '
        'Promethius was never a colony ship. Its whole history was made up. '
        'Its captain carried four codes, one for each way the Republic '
        'might treat them. One of them has just been sent.',
    choices: [
      Choice.simple(
        'Ask which one',
        'They tell you.',
        effects: const [ResolveEnding()],
      ),
    ],
  ),

  // Hell ------------------------------------------------------------------
  const GameEvent(
    id: 'hell_chew_toy',
    title: 'The chewer',
    triggers: {Trigger.hell},
    condition: InHell(HellZone.pipe),
    once: false,
    text:
        'A demon with no mouth, only teeth, is gnawing on the pipe the '
        'way a dog works a bone. Every bite opens a hole in the barrier. '
        'Every hole closes again.',
    choices: [
      Choice(
        'Wait for a bite near an exit',
        outcomes: [
          Outcome(
            'A bite opens close to a gateway mouth and you slip out.',
            weight: 2,
            bondWeight: 0.5,
            effects: [EscapeHell()],
          ),
          Outcome('The teeth find the ship instead.', effects: [Hull(-30)]),
        ],
      ),
      Choice(
        'Squeeze out through the bite marks',
        outcomes: [
          Outcome(
            'You slip out into open Hell. The chewer doesn\'t notice.',
            effects: [EnterHell(HellZone.deep)],
          ),
        ],
      ),
    ],
  ),
  const GameEvent(
    id: 'hell_backwards_clocks',
    title: 'Running backwards',
    triggers: {Trigger.hell},
    condition: InHell(HellZone.pipe),
    once: false,
    text:
        'The analog clock on the bridge is going backwards. The humans '
        'have started placing bets on what day it will be when you get out.',
    choices: [
      Choice(
        'Ride the current',
        outcomes: [
          Outcome(
            'The current carries you to a gateway. You leave before you '
            'arrived, roughly.',
            effects: [EscapeHell(), Credits(15)],
          ),
          Outcome('The current goes nowhere useful.', weight: 1.5),
        ],
      ),
      Choice(
        'Burn hard for the nearest gateway',
        outcomes: [
          Outcome(
            'You make it, though the hull complains.',
            effects: [Hull(-30), EscapeHell()],
          ),
        ],
      ),
    ],
  ),
  const GameEvent(
    id: 'hell_harvest',
    title: 'Metallic flesh',
    triggers: {Trigger.hell},
    condition: AllOf([InHell(HellZone.deep), NoFlag(Flag.mournerPull)]),
    once: false,
    text:
        'Something enormous died here, if things here die. Its flesh is '
        'metal and its blood is a fine vintage. Heavy elements are '
        'everywhere, and they sell for a fortune back home.',
    choices: [
      Choice(
        'Harvest it',
        outcomes: [
          Outcome(
            'You fill the hold. Nothing complains.',
            weight: 2,
            effects: [Credits(90), Hull(-15)],
          ),
          Outcome('It was not dead.', effects: [Credits(40), Hull(-90)]),
        ],
      ),
      Choice(
        'Look for the barrier',
        outcomes: [
          Outcome(
            'You find a pipe and slip back inside it.',
            weight: 2,
            effects: [EnterHell(HellZone.pipe)],
          ),
          Outcome('Nothing out here looks like a way home.'),
        ],
      ),
    ],
  ),
  const GameEvent(
    id: 'hell_hunter',
    title: 'Something follows',
    triggers: {Trigger.hell},
    condition: AllOf([InHell(HellZone.deep), NoFlag(Flag.mournerPull)]),
    once: false,
    text:
        'A demon the size of a moon has noticed you. It moves with '
        'unhurried interest, the way a cat moves toward something small.',
    choices: [
      Choice(
        'Fight it',
        outcomes: [
          Outcome(
            '',
            effects: [
              Combat(
                'a demon',
                10,
                win: [
                  Credits(150),
                  Note(
                    'Killed a demon in open Hell and stripped what we could.',
                  ),
                ],
                lose: [Hull(-120)],
              ),
            ],
          ),
        ],
      ),
      Choice(
        'Run for the barrier',
        outcomes: [
          Outcome(
            'You reach a pipe and dive in.',
            effects: [EnterHell(HellZone.pipe), Hull(-30)],
          ),
          Outcome('It is faster than you.', effects: [Hull(-75)]),
        ],
      ),
    ],
  ),
  const GameEvent(
    id: 'hell_hellborn',
    title: 'Familiar shapes',
    triggers: {Trigger.hell},
    condition: AllOf([HumansAtLeast(3), NoFlag(Flag.mournerPull)]),
    text:
        'Ships drift past in the gloom, close enough to see figures at '
        'the windows. They are shaped almost exactly like your crew. Your '
        'humans have gone very quiet.',
    choices: [
      Choice(
        'Hail them',
        outcomes: [
          Outcome(
            'They answer in a language your translator handles easily, '
            'because it is the one your crew speaks. They guide you to a '
            'gateway and leave without another word.',
            bondWeight: 1.5,
            condition: BondAtLeast(40),
            effects: [
              AddCounter(Counter.hellbornAwareness, 2),
              Drift(8),
              EscapeHell(),
            ],
          ),
          Outcome(
            'They are gone before the message finishes. Your humans say it '
            'was a reflection.',
            effects: [AddCounter(Counter.hellbornAwareness, 1)],
          ),
        ],
      ),
      Choice(
        'Ask your humans what they are',
        outcomes: [
          Outcome(
            '"Reflections, captain. Hell does that." Nobody meets your eye.',
            effects: [Loyalty(-3)],
          ),
        ],
      ),
    ],
  ),
  // The Mourner is the last Havi left in Hell, a god holding its dead home
  // world at the lip of a black hole. It is far stronger than the Overseer,
  // and the only thing that can kill it. You only get away by asking
  // politely, and only a Hellborn would know that.
  const GameEvent(
    id: 'hell_mourner',
    title: 'The Mourner',
    triggers: {Trigger.hell},
    condition: AnyOf([
      HasFlag(Flag.mournerPull),
      AllOf([InHell(HellZone.deep), ActAtLeast(2)]),
    ]),
    weight: 0.25,
    once: false,
    text:
        'A planet hangs at the lip of a black hole, and something vast and '
        'unknowable is holding it there, forever pulling it back from the '
        'edge and never quite far enough. The ship has drifted too close. '
        'The engines are at full burn and the black hole is winning. Every '
        'spacer has heard of this place. Almost nobody has heard of anyone '
        'coming back.',
    choices: [
      Choice(
        'Burn everything to break free',
        outcomes: [
          Outcome(
            'Somehow it works. You claw back into a gateway pipe with the '
            'engines on fire.',
            weight: 0.4,
            effects: [
              ClearFlag(Flag.mournerPull),
              EnterHell(HellZone.pipe),
              Hull(-120),
            ],
          ),
          Outcome(
            'The black hole does not notice your engines.',
            weight: 3,
            effects: [SetFlag(Flag.mournerPull), Hull(-150)],
          ),
        ],
      ),
      Choice(
        'Try to console it',
        outcomes: [
          Outcome(
            'It does not want your pity. It shows you why, and the hull '
            'buckles.',
            effects: [SetFlag(Flag.mournerPull), Hull(-180)],
          ),
        ],
      ),
      Choice(
        'Demand that it let you go',
        outcomes: [
          Outcome(
            'Nothing. You are slipping closer.',
            effects: [SetFlag(Flag.mournerPull), Hull(-120)],
          ),
        ],
      ),
      Choice(
        'Ask politely for help leaving',
        condition: HasFlag(Flag.mournerLore),
        outcomes: [
          Outcome(
            'It does not look at you. The ship is simply elsewhere: outside '
            'a gateway, hull mended, everyone alive. Something is waiting in '
            'the hold that wasn\'t there before. For your trouble.',
            effects: [
              ClearFlag(Flag.mournerPull),
              GrantCard('mourner'),
              EscapeHell(),
              Hull(150),
            ],
          ),
        ],
      ),
      Choice(
        'One of your humans is shouting at you to let them speak',
        condition: AllOf([
          HasFlag(Flag.hellbornAgentAboard),
          NoFlag(Flag.mournerLore),
        ]),
        outcomes: [
          Outcome(
            'It is the quiet one, the one whose stories never added up. '
            '"Ask it politely. Just ask. Please." When you hesitate they '
            'do it themselves, in a dialect of your own language you have '
            'never heard. The ship is simply elsewhere: outside a gateway, '
            'hull mended, everyone alive, and something waiting in the hold '
            'that wasn\'t there before. For your trouble.\n\n'
            'Then they tell you the truth to save their own life. They were '
            'born in Hell. There are a great many more of them, and they '
            'have been watching you for a long time. They seem to like what '
            'they saw.',
            effects: [
              ClearFlag(Flag.mournerPull),
              ClearFlag(Flag.hellbornAgentAboard),
              SetFlag(Flag.mournerLore),
              GrantCard('mourner'),
              // Outing themselves to the Mourner counts as Code Green.
              SetFlag(Flag.codeGreenUsed),
              SetFlag(Flag.hellbornAlly),
              AddCounter(Counter.hellbornAwareness, 3),
              AddCounter(Counter.humanPower, 2),
              Drift(10),
              Hull(150),
              EscapeHell(),
            ],
          ),
        ],
      ),
    ],
  ),
  GameEvent(
    id: 'odd_crewman',
    title: 'Stories that don\'t add up',
    triggers: const {Trigger.hold},
    condition: const HasFlag(Flag.hellbornAgentAboard),
    text:
        'One of your humans, a quiet engineer, tells the mess about growing '
        'up on the Promethius: a red sky through the viewports, clocks '
        'that ran the wrong way, a warm sea that smelled like brandy. The '
        'other humans have gone quiet. None of that sounds like a colony '
        'ship.',
    choices: [
      Choice.simple(
        'Ask where that was',
        'They laugh and say they were a strange child. They don\'t tell '
            'stories in the mess again.',
        effects: const [Loyalty(-2)],
      ),
      Choice.simple(
        'Let it go',
        'You let it go. They notice that you did.',
        effects: const [Loyalty(2)],
      ),
    ],
  ),
];

const _codeGreen = <Effect>[
  SetFlag(Flag.codeGreenUsed),
  SetFlag(Flag.hellbornAlly),
  AddCounter(Counter.hellbornAwareness, 3),
  AddCounter(Counter.humanPower, 2),
  Loyalty(15),
  Drift(10),
  Hull(180),
  Credits(60),
  EscapeHell(),
];
