import '../../captain/species.dart';
import '../../galaxy/galaxy.dart';
import '../../story/keys.dart';
import '../../story/rules.dart';
import '../../story/story.dart';

/// The home worlds of the captain species.
final speciesHomeEvents = <GameEvent>[
  GameEvent(
    id: 'gor_pits',
    title: 'The duelling pits',
    condition: const AtTag(Tag.gor),
    once: false,
    weight: 0.8,
    text:
        'The Gor settle disputes, debts and boredom in the duelling pits. '
        'Any ship may enter a champion. Several of your humans are '
        'volunteering, loudly.',
    choices: [
      const Choice(
        'Send a human champion',
        condition: HumansAtLeast(1),
        outcomes: [
          Outcome(
            'The human wins. The Gor are furious, then fascinated. You '
            'collect the purse.',
            weight: 2,
            bondWeight: 0.5,
            effects: [
              Credits(40),
              Loyalty(5),
              AddCounter(Counter.gorAggression, 1),
            ],
          ),
          Outcome(
            'The human loses, and has to be carried out. Nobody dies. '
            'Probably.',
            effects: [Credits(-10), Loyalty(-3)],
          ),
        ],
      ),
      Choice.simple(
        'Fight yourself',
        'You win. The Gor treat you as one of their own for a whole day.',
        condition: const IsSpecies(Species.gor),
        effects: const [Credits(30), Drift(-4)],
      ),
      Choice.simple('Watch', 'Loud, bloody and very well attended.'),
    ],
  ),
  GameEvent(
    id: 'bhrun_wrangling',
    title: 'Megafauna wrangling',
    condition: const AtTag(Tag.bhrun),
    once: false,
    weight: 0.8,
    text:
        'Something enormous has wandered into a Bhrun settlement and won\'t '
        'leave. The Bhrun will pay anyone who can move it, eventually, in '
        'their own time.',
    choices: [
      Choice.simple(
        'Move it with the ship\'s tractor field',
        'It takes all day. It is the strangest money you have ever earned.',
        effects: const [Credits(25)],
      ),
      Choice.simple(
        'Let your humans try',
        'The humans move it with food, noise and a great deal of shouting. '
            'The Bhrun are deeply impressed.',
        condition: const HumansAtLeast(3),
        effects: const [Credits(30), Loyalty(3)],
      ),
    ],
  ),
  GameEvent(
    id: 'al_scan',
    title: 'Curious scientists',
    condition: const AtTag(Tag.al),
    once: false,
    weight: 0.8,
    text:
        'An Ál research team would like to scan your ship, your cargo and '
        'especially your crew. They are paying.',
    choices: [
      Choice.simple(
        'Let them scan the ship',
        'Thorough, damp and well paid.',
        effects: const [Credits(20)],
      ),
      Choice.simple(
        'Let them scan the humans',
        'The humans are paid too, which helps.',
        condition: const HumansAtLeast(1),
        effects: const [Credits(35), Loyalty(-2), Drift(-2)],
      ),
      Choice.simple('Decline', 'They are visibly disappointed.'),
    ],
  ),
  GameEvent(
    id: 'tern_calibration',
    title: 'Relay calibration',
    condition: const AtTag(Tag.tern),
    once: false,
    weight: 0.8,
    text:
        'The local Tern relay has drifted out of phase with the rest of '
        'the network. Recalibrating it needs a ship to fly a slow figure '
        'three around it.',
    choices: [
      Choice.simple(
        'Fly the pattern',
        'The relay hums back into step. The Tern pay exactly what they said.',
        effects: const [Credits(27)],
      ),
      Choice.simple(
        'Merge with the relay and fix it from inside',
        'A strange, pleasant afternoon. The Tern pay you double, in threes.',
        condition: const IsSpecies(Species.tern),
        effects: const [Credits(54), Drift(-3)],
      ),
    ],
  ),
];
