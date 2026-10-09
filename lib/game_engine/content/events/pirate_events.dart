import '../../galaxy/galaxy.dart';
import '../../story/rules.dart';
import '../../story/story.dart';

/// Human pirates. They won't kill humans. A ship without any is fair game.
final pirateEvents = <GameEvent>[
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
];
