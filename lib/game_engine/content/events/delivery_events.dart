import '../../galaxy/galaxy.dart';
import '../../story/keys.dart';
import '../../story/rules.dart';
import '../../story/story.dart';

/// Courier work: cargo to carry, and getting paid for it.
final deliveryEvents = <GameEvent>[
  // Before the raid, the crate is nearly always bound for Orcha Station,
  // and the raid waits for it to arrive.
  GameEvent(
    id: 'courier_job',
    title: 'Courier contract',
    condition: const AllOf([AtTag(Tag.station), Not(DeliveryHere())]),
    once: false,
    weight: 1.5,
    text:
        'A sealed crate needs to be somewhere else, quietly. The pay is '
        'good, which is worrying.',
    choices: [
      Choice.simple(
        'Take it',
        'You sign for the crate without reading the manifest.',
        effects: const [
          StartDelivery(
            'parcel_sealed',
            45,
            prefer: Sys.orcha,
            preferWhen: NoFlag(Flag.orchaRaid),
          ),
        ],
      ),
      Choice.simple('Pass', 'Someone else takes it.'),
    ],
  ),
  GameEvent(
    id: 'parcel_delivered',
    title: 'The recipient',
    condition: const DeliveryHere(),
    always: true,
    once: false,
    text:
        'Someone is waiting at the dock for your crate. They don\'t give a '
        'name, and they keep looking at the station\'s outer hull.',
    choices: [
      Choice.simple(
        'Hand it over',
        'They pay and leave quickly.',
        effects: const [CompleteDeliveries()],
      ),
      const Choice(
        'Open it first',
        outcomes: [
          Outcome(
            'Havi relics, packed in foam. Contraband, but harmless. You '
            'reseal it and they pay anyway, with a look.',
            weight: 2,
            effects: [CompleteDeliveries()],
          ),
          Outcome(
            'Consumer eggs. Some of them have already hatched. The recipient '
            'is gone before you look up.',
            effects: [
              Hull(-75),
              QueueEvent('roach_hatchling'),
              CompleteDeliveries(paid: false),
            ],
          ),
        ],
      ),
    ],
  ),
];
