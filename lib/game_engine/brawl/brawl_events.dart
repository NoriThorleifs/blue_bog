import 'brawl_event_model.dart';
import 'events/colony_events.dart';
import 'events/colony_gift_events.dart';
import 'events/departure_events.dart';
import 'events/elite_events.dart';
import 'events/finale_events.dart';
import 'events/hell_events.dart';

export 'brawl_event_model.dart';

/// The flag set once the Mourner has given its gift.
const metMourner = 'mourner';

/// The flag set once the captain has the Hell Clock, from the Mourner or
/// found in the murk. There is only one per brawl.
const hasHellClock = 'hell_clock';

/// The flag set once the captain has beaten any of the final bosses and
/// won the brawl. Each boss has its own flag too.
const wonBrawl = 'won';

/// The flags set for beating each final boss: Satan, Lady Idun and
/// Shining-head.
const beatSatan = 'beat_satan';
const beatIdun = 'beat_idun';
const beatShiningHead = 'beat_shining_head';

/// The final bosses, by the flag for beating them, in the words the end
/// screens use.
const finalBossNames = {
  beatSatan: 'Satan',
  beatIdun: 'Lady Idun',
  beatShiningHead: 'Shining-head',
};

/// The flag set the first time every triforce slot holds a Super card or
/// the Hell Clock. It stays set, and draws the herald in Hell.
const fullBuild = 'full_build';

/// Which of [demons] is the demon lord's herald.
const heraldDemon = 3;

/// The flag set when a captain with a [fullBuild] kills the herald: Satan
/// comes next.
const satanSummoned = 'satan_summoned';

/// The flag set when the colony has voted to leave the captain for the
/// House of the Elephant.
const colonySeceded = 'colony_seceded';

/// At fight 27 a colony below this loyalty (Grumbling or worse) secedes,
/// and Lady Idun comes for the ship. A captain whose colony isn't at least
/// Content by then has decided against it, or never built it up.
const secedeBelow = 60;

/// The flag set when a captain who has won chooses to keep going.
const wentEndless = 'endless';

/// The flag set once the universal draft for Neo Terra has started.
const draftOn = 'draft';

/// The counter holding the fight the draft started at.
const draftRoundKey = 'draft_round';

/// The counter holding the size of the Hellborn cell in the colony.
const hellbornCellKey = 'hellborn_cell';

/// The flag set while the colony refuses to patch the hull.
const colonyStrike = 'colony_strike';

/// Below this loyalty the colony goes on strike.
const strikeLoyalty = 20;

/// The flag set while human volunteers are waiting to board the next
/// enemy, which then starts the fight at [boardedHull] of its hull.
const boardingParty = 'boarding_party';
const boardedHull = 0.8;

/// Hell Brandy, which Hell and the pipe both deal in.
const hellBrandy = 'goods_brandy';

/// Every brawl event. Departure events come up each time the ship leaves a
/// station; Hell events once per turn in Hell.
final brawlEvents = <BrawlEvent>[
  ...finaleEvents,
  ...colonyEvents,
  ...colonyGiftEvents,
  ...departureEvents,
  ...eliteEvents,
  ...brawlHellEvents,
];

final brawlEventsById = {for (final e in brawlEvents) e.id: e};
