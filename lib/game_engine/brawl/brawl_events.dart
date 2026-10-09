import 'brawl_event_model.dart';
import 'events/departure_events.dart';
import 'events/elite_events.dart';
import 'events/hell_events.dart';

export 'brawl_event_model.dart';

/// The flag set once the Mourner has given its gift.
const metMourner = 'mourner';

/// The flag set once the captain has the Hell Clock, from the Mourner or
/// found in the murk. There is only one per brawl.
const hasHellClock = 'hell_clock';

/// Hell Brandy, which Hell and the pipe both deal in.
const hellBrandy = 'goods_brandy';

/// Every brawl event. Departure events come up each time the ship leaves a
/// station; Hell events once per turn in Hell.
final brawlEvents = <BrawlEvent>[
  ...departureEvents,
  ...eliteEvents,
  ...brawlHellEvents,
];

final brawlEventsById = {for (final e in brawlEvents) e.id: e};
