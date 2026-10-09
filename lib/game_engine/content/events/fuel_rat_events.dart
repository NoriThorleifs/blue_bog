import '../../story/keys.dart';
import '../../story/rules.dart';
import '../../story/story.dart';

/// Being stranded, and the Fuel Rats: a human merchants' guild of fuel and
/// essentials. First to answer a distress call, and they charge an arm and
/// a leg. Their tab is real: it comes due a few turns later, and they
/// collect.
final fuelRatEvents = <GameEvent>[
  GameEvent(
    id: 'fuel_rats_stranded',
    title: 'The Fuel Rats',
    triggers: const {Trigger.arrival, Trigger.hold},
    condition: _stranded,
    always: true,
    once: false,
    text:
        'You don\'t have the fuel to go anywhere. A human tender is already '
        'pulling alongside, '
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
        'There isn\'t enough fuel to go anywhere, and the Fuel Rats aren\'t coming. There is a '
        'wreck drifting a few thousand kilometres off.',
    choices: [
      Choice.simple(
        'Siphon what you can from the wreck',
        'It takes all day and some of your hull, but you can move again.',
        effects: const [Fuel(3), Hull(-30)],
      ),
    ],
  ),
];

/// Not enough fuel for any route out, somewhere you can't buy any.
const _strandedHere = Stranded();

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
