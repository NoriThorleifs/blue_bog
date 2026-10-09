import '../../captain/species.dart';
import '../../faction.dart';
import '../../galaxy/galaxy.dart';
import '../../story/keys.dart';
import '../../story/rules.dart';
import '../../story/story.dart';

/// Events at particular act 1 systems.
final placeEvents = <GameEvent>[
  GameEvent(
    id: 'railing_standards',
    title: 'Not up to code',
    condition: const AllOf([AtSystem(Sys.orcha), NoFlag(Flag.orchaRaid)]),
    weight: 2,
    text:
        'The humans are building a three-level walkway along Orcha\'s '
        'promenade and are badly behind schedule. They have torn the whole '
        'thing down and started again. The foreman explains, in public, '
        'that the first attempt was "not up to code".',
    choices: [
      Choice.simple(
        'Ask which code',
        'The foreman smiles. "Railing safety standards." Your humans '
            'find this hilarious.',
        effects: const [Drift(4), Loyalty(3)],
      ),
      Choice.simple(
        'Report the delay to station authority',
        'The station authority thanks you. The foreman remembers your '
            'face.',
        effects: const [AddCounter(Counter.influence, 1), Loyalty(-4)],
      ),
    ],
  ),
  const GameEvent(
    id: 'owie_experiments',
    title: 'Dr. Ái Á á Á á á á',
    condition: AllOf([AtTag(Tag.station), ActIs(1), HumansAtLeast(50)]),
    text:
        'An Ál scientist who insists you call him Owie is recruiting '
        'human volunteers to measure their durability. He pays well. He is '
        'evasive about the final experiment.',
    choices: [
      Choice(
        'Volunteer some of your humans',
        outcomes: [
          Outcome(
            'The humans come back very durable and very relaxed. Some of '
            'them ask when Owie is hiring again.',
            weight: 1.5,
            effects: [Credits(40), Loyalty(4), Drift(-4)],
          ),
          Outcome(
            'The humans come back furious, and they know exactly who signed '
            'them up.',
            effects: [Credits(40), Loyalty(-12)],
          ),
        ],
      ),
      Choice(
        'Decline',
        outcomes: [
          Outcome(
            'Owie wanders off, already looking at the next ship\'s '
            'crew.',
          ),
        ],
      ),
    ],
  ),
  GameEvent(
    id: 'two_sided_brothel',
    title: 'A wall with a hole in it',
    triggers: const {Trigger.arrival, Trigger.hold},
    condition: const AllOf([
      AtTag(Tag.station),
      AtTag(Tag.neutral),
      HumansAtLeast(25),
    ]),
    text:
        'This neutral station hosts a two-sided brothel: two entrances, '
        'one wet, one dry, a wall with a hole in it, and a legal theory so '
        'convoluted it may never be challenged. Your humans would like '
        'shore leave.',
    choices: [
      Choice.simple(
        'Grant shore leave',
        'The humans come back exhausted and cheerful.',
        hint: '15 credits',
        effects: const [Credits(-15), Loyalty(10), Drift(-3)],
      ),
      Choice.simple(
        'Invest in the business',
        'Both sides of the wall pay. You take a cut of both.',
        condition: const IsSpecies(Species.al),
        effects: const [Credits(45), Drift(4)],
      ),
      Choice.simple(
        'Deny it',
        'There is muttering below decks.',
        effects: const [Loyalty(-5)],
      ),
    ],
  ),
  GameEvent(
    id: 'ternary_dispute',
    title: '729',
    condition: const AllOf([AtTag(Tag.station), HumansAtLeast(25)]),
    text:
        'Your human quartermaster is screaming at a supplier. "Did I '
        'stutter? I said 729. I don\'t want 730. I won\'t take the last one '
        'even if you pay me." The supplier looks to you for help.',
    choices: [
      Choice.simple(
        'Back the quartermaster',
        '"Because the captain counts in threes!" The supplier gives up and '
            'knocks the price down to make the human go away.',
        effects: const [Credits(15), Loyalty(6), Drift(-3)],
      ),
      Choice.simple(
        'Take the free one',
        'The quartermaster stares at you for a very long time.',
        effects: const [Credits(5), Loyalty(-6)],
      ),
      Choice.simple(
        'Explain that 729 is three to the sixth',
        'The supplier does not care. Your quartermaster nearly cries with '
            'joy.',
        condition: const IsSpecies(Species.tern),
        effects: const [Loyalty(12), Drift(4)],
      ),
    ],
  ),
  GameEvent(
    id: 'bhrun_trade',
    title: 'Ben',
    condition: const AtSystem(Sys.bhrunGai),
    text:
        'Ben Buru\'hyrem\'him Burhuge would like to trade. Very slowly. He '
        'speaks warmly of the humans, who protect his people out of '
        'friendship. He is sure that is the reason.',
    choices: [
      Choice.simple(
        'Trade patiently',
        'It takes the whole day. It is a good deal.',
        effects: const [Credits(35)],
      ),
      Choice.simple(
        'Tell him why the humans really protect Bhrun-Gai',
        'Ben thinks about it for a long time, and then says he would '
            'never lift a finger for them anyway. Your humans laugh.',
        effects: const [Loyalty(4), Drift(3)],
      ),
    ],
  ),
  const GameEvent(
    id: 'kepler_observation',
    title: 'The observation post',
    condition: AllOf([AtSystem(Sys.kepler), NoFlag(Flag.keplerTouchdown)]),
    text:
        'The observation crew are still arguing about the day the humans '
        'arrived: was it first contact, or was the station hacked? Their '
        'computer insists on the former. They would like someone to take '
        'their reports to the Center.',
    choices: [
      Choice(
        'Carry the reports',
        outcomes: [
          Outcome(
            'They pay in research credits, which spend like any other kind.',
            effects: [Credits(25), AddCounter(Counter.influence, 1)],
          ),
        ],
      ),
      Choice(
        'Let your humans talk to them',
        outcomes: [
          Outcome(
            'The scientists learn more about humans in one afternoon than '
            'in a year of watching. Your humans enjoy being the experts.',
            effects: [Loyalty(5), Drift(5)],
          ),
        ],
      ),
    ],
  ),
  GameEvent(
    id: 'gor_patrol',
    title: 'Gor inspection',
    condition: const AllOf([AtTag(Tag.gor), NotInHell()]),
    once: false,
    weight: 0.8,
    text:
        'A Gor patrol demands to inspect your ship. They are very '
        'interested in your humans.',
    choices: [
      Choice.simple(
        'Submit to the inspection',
        'The Gor are rough with the humans, and the humans remember it.',
        effects: const [Loyalty(-8), AddCounter(Counter.gorAggression, 1)],
      ),
      Choice.simple(
        'Bribe them',
        'Gor honour has a price, and it is reasonable.',
        condition: const CreditsAtLeast(20),
        hint: '20 credits',
        effects: const [Credits(-20)],
      ),
      Choice.simple(
        'Pull rank',
        'They back off from one of their own. Your humans notice how much '
            'you sounded like them.',
        condition: const IsSpecies(Species.gor),
        effects: const [Drift(-6), Loyalty(-3)],
      ),
      const Choice(
        'Refuse',
        outcomes: [
          Outcome(
            '',
            effects: [
              Combat(
                'a Gor patrol',
                7,
                win: [
                  Credits(30),
                  Loyalty(10),
                  AddCounter(Counter.gorAggression, 1),
                ],
                lose: [Hull(-90), Credits(-20)],
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  const GameEvent(
    id: 'ur_gor_natives',
    title: 'The people of Ur-Gor',
    condition: AtSystem(Sys.urGor),
    text:
        'The natives of Ur-Gor are why the Gor are the way they are: the '
        'galaxy voted that they were people, so the Gor could not take the '
        'planet. The natives would like to trade. They have heard about the '
        'humans and are fascinated.',
    choices: [
      Choice(
        'Introduce them to your humans',
        outcomes: [
          Outcome(
            'The two get on very well. The Gor overseers do not like it at '
            'all.',
            effects: [
              Loyalty(6),
              Drift(4),
              Credits(20),
              AddCounter(Counter.gorAggression, 1),
            ],
          ),
        ],
      ),
      Choice(
        'Just trade',
        outcomes: [
          Outcome('A modest profit.', effects: [Credits(25)]),
        ],
      ),
    ],
  ),
  GameEvent(
    id: 'hive_world',
    title: 'The hive world',
    condition: const AllOf([
      AtSystem(Sys.neoTerra),
      NoFlag(Flag.neoTerraClaimed),
    ]),
    once: false,
    always: true,
    text:
        'The planet crawls. The shipbuilding gantry in orbit is still '
        'working, and every Consumer ship in the system has turned toward '
        'you.',
    choices: [
      const Choice(
        'Attack the gantry',
        outcomes: [
          Outcome(
            '',
            effects: [
              Combat(
                'the hive fleet',
                14,
                win: [
                  Credits(120),
                  AddCounter(Counter.consumerThreat, -1),
                  AddCounter(Counter.influence, 2),
                  Loyalty(15),
                ],
                lose: [Hull(-180)],
              ),
            ],
          ),
        ],
      ),
      Choice.simple('Retreat', 'Discretion.', effects: const [Hull(-30)]),
    ],
  ),
  const GameEvent(
    id: 'neo_terra_border',
    title: 'Neo Terran border patrol',
    condition: AllOf([AtSystem(Sys.neoTerra), HasFlag(Flag.neoTerraClaimed)]),
    always: true,
    text:
        'A human border patrol meets you at the edge of the system and '
        'tells you to leave. Behind them is a mine maze and a megastructure '
        'of radio jammers thousands strong.',
    choices: [
      Choice(
        'Let your humans talk to them',
        outcomes: [
          Outcome(
            'Your humans speak with the patrol for a long time. You are waved '
            'through the mines and see a war-torn world, with a space station '
            'bombarding one point on its surface at a steady pace. Your '
            'humans are allowed home leave. They come back changed.',
            condition: BondAtLeast(45),
            effects: [
              Loyalty(15),
              Drift(10),
              Humans(30),
              MaybeAgent(0.3),
              AddCounter(Counter.hellbornAwareness, 1),
            ],
          ),
          Outcome(
            'The patrol listens politely and says no. Your humans seem '
            'embarrassed, though you are not sure for whom.',
            effects: [Loyalty(-3)],
          ),
        ],
      ),
      Choice('Turn back', outcomes: [Outcome('You turn back.')]),
    ],
  ),
  // Shining-head can only be killed by destroying his complex, 10 km under
  // the capital.
  GameEvent(
    id: 'deep_complex',
    title: 'Ten kilometres down',
    triggers: const {Trigger.hold},
    condition: const AllOf([
      AtSystem(Sys.neoTerra),
      HasFlag(Flag.neoTerraClaimed),
      NoFlag(Flag.shiningHeadDead),
      AnyOf([
        HasFlag(Flag.overseerSuspects),
        HasFlag(Flag.uploadedFormed),
        HasFlag(Flag.captainFoundBroadcast),
      ]),
    ]),
    weight: 10,
    text:
        'Your humans take you to the station that does nothing but bombard '
        'one point on the surface, over and over. Ten kilometres under the '
        'capital is a complex, and in it is the voice. The colonists tried '
        'digging once. It threatened to crack the planet\'s core. They '
        'think it was bluffing. They would like a ship with real guns to '
        'help them find out.',
    choices: [
      const Choice(
        'Lend them your guns',
        outcomes: [
          Outcome(
            '',
            effects: [
              Combat(
                'Shining-head\'s defences',
                13,
                win: [
                  SetFlag(Flag.shiningHeadDead),
                  Transfer(Faction.uploaded, Faction.colonists),
                  AddCounter(Counter.humanPower, 2),
                  AddCounter(Counter.influence, 2),
                  Loyalty(15),
                  Note(
                    'Helped the colonists destroy the complex under Neo '
                    'Terra. Shining-head was bluffing.',
                  ),
                ],
                lose: [Hull(-150)],
              ),
            ],
          ),
        ],
      ),
      Choice.simple(
        'Not your fight',
        'The bombardment goes on without you.',
        effects: const [Loyalty(-3)],
      ),
    ],
  ),
];
