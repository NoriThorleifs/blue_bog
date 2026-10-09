import '../../combat/equipment.dart';
import '../../galaxy/galaxy.dart';
import '../../story/keys.dart';
import '../../story/rules.dart';
import '../../story/story.dart';

/// The frontier and the ruins.
final frontierEvents = <GameEvent>[
  const GameEvent(
    id: 'frontier_derelict',
    title: 'A derelict',
    condition: AnyOf([AtTag(Tag.frontier), AtTag(Tag.ruins)]),
    once: false,
    weight: 1,
    text:
        'A Havi-era ship drifts at the edge of the system, dark and cold. '
        'Its hull is scored with something that looks like teeth marks.',
    choices: [
      Choice(
        'Board it',
        outcomes: [
          Outcome(
            'In the hold, sealed in Havi glass: relics. Someone will pay a '
            'great deal.',
            effects: [GrantCard('goods_relics')],
          ),
          Outcome(
            'Its stores are intact.',
            weight: 2,
            effects: [GrantCard('supplies'), Fuel(2)],
          ),
          Outcome(
            'Something is still aboard.',
            effects: [
              Combat(
                'whatever lived in the derelict',
                5,
                win: [GrantCard('salvage')],
              ),
            ],
          ),
        ],
      ),
      Choice(
        'Strip the hull',
        outcomes: [
          Outcome('Scrap, and plenty of it.', effects: [Credits(25)]),
        ],
      ),
      Choice('Leave it', outcomes: [Outcome('Some things should stay dark.')]),
    ],
  ),
  const GameEvent(
    id: 'frontier_nest',
    title: 'A Consumer nest',
    condition: AllOf([
      AnyOf([AtTag(Tag.frontier), AtTag(Tag.ruins)]),
      CounterAtLeast(Counter.consumerThreat, 1),
    ]),
    once: false,
    weight: 0.7,
    text:
        'A small Consumer nest is growing on an asteroid here. Left alone it '
        'will be a big one. The chitin is worth money.',
    choices: [
      Choice(
        'Burn it out',
        outcomes: [
          Outcome(
            '',
            effects: [
              Combat(
                'a Consumer nest',
                5,
                win: [
                  GrantCard('goods_chitin'),
                  AddCounter(Counter.consumerThreat, -1),
                ],
              ),
            ],
          ),
        ],
      ),
      Choice(
        'Report it and move on',
        outcomes: [
          Outcome(
            'The Republic thanks you, eventually.',
            effects: [Credits(8)],
          ),
        ],
      ),
    ],
  ),
  GameEvent(
    id: 'frontier_prospectors',
    title: 'Prospectors',
    condition: const AtTag(Tag.frontier),
    once: false,
    weight: 0.8,
    text:
        'A camp of human prospectors on a rock in the middle of nowhere. '
        'They have ore and they want everything else.',
    choices: [
      Choice.simple(
        'Trade for ore',
        'They throw in a little fuel to close the deal.',
        condition: const CreditsAtLeast(10),
        hint: '10 credits',
        effects: const [Credits(-10), GrantCard('goods_ore'), Fuel(1)],
      ),
      Choice.simple(
        'Sell them supplies from your hold',
        'They pay well, out here.',
        condition: const HasCardKind(CardKind.commodity),
        effects: const [SellCommodity(1.3)],
      ),
      Choice.simple(
        'Let your humans visit',
        'Your humans come back with news, gossip and a dozen new friends.',
        condition: const HumansAtLeast(25),
        effects: const [Loyalty(4), Humans(12), MaybeAgent(0.3)],
      ),
    ],
  ),
];
