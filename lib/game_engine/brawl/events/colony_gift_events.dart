import '../brawl_events.dart';
import '../brawl_state.dart';

/// What a happy colony does for a captain who has made it feel at home:
/// you scratch our backs, we scratch yours. Gifts come up in transit, only
/// when the colony is Content (loyalty [_content]) or Devoted ([_devoted]),
/// and at most once every [_giftGap] fights.
final colonyGiftEvents = <BrawlEvent>[
  // Content -----------------------------------------------------------------
  BrawlEvent(
    id: 'gift_spares',
    title: 'Spare parts',
    aftermath: true,
    weight: (s) => 1.5,
    condition: (s) => _giftDue(s, _content),
    text:
        'The representatives come to the bridge with a crate. The colony\'s '
        'workshops have been studying your ship from the inside, and they '
        'have built you a copy of something you already use. Their '
        'tolerances are better than the factory\'s.',
    choices: [
      Choice('Thank them', [
        Outcome(
          'They pretend it was nothing. It wasn\'t.',
          effects: [GainCopy(), MarkRound(_giftKey)],
        ),
      ]),
      Choice('Tell them to keep it for themselves', [
        Outcome(
          'They are quiet for a moment, then very warm.',
          effects: [ColonyChange(loyalty: 5), MarkRound(_giftKey)],
        ),
      ]),
    ],
  ),
  BrawlEvent(
    id: 'gift_double_shift',
    title: 'A double shift',
    aftermath: true,
    weight: (s) => 1.5,
    condition: (s) => _giftDue(s, _content) && s.hull < s.stats.maxHull,
    text:
        'Nobody asked them to, but the crawlspace crews have signed up for a '
        'double shift. Hundreds of small, dense people are already in the '
        'walls with welding torches, patching the damage from the last '
        'fight.',
    choices: [
      Choice('Let them work', [
        Outcome(
          'They go well past what anyone could ask of them. You can hear '
          'them singing in the ducts.',
          effects: [HullChange(150), MarkRound(_giftKey)],
        ),
      ]),
    ],
  ),
  BrawlEvent(
    id: 'gift_collection',
    title: 'A collection',
    aftermath: true,
    weight: (s) => 1.5,
    condition: (s) => _giftDue(s, _content) && s.humans.count >= 100,
    text:
        'The colony has taken up a collection for its captain. Every family '
        'put something in. The representatives hand it over as if it were '
        'rent.',
    choices: [
      Choice('Accept it', [
        Outcome(
          'It adds up to more than you expected.',
          effects: [GainCredits(60), MarkRound(_giftKey)],
        ),
      ]),
      Choice('Put it into the colony instead', [
        Outcome(
          'They spend it on a school. The children wave at you in the '
          'corridors now.',
          effects: [ColonyChange(loyalty: 6, drift: 3), MarkRound(_giftKey)],
        ),
      ]),
    ],
  ),

  // Devoted -----------------------------------------------------------------
  BrawlEvent(
    id: 'gift_ammunition',
    title: 'Ammunition',
    aftermath: true,
    weight: (s) => 1.5,
    condition: (s) => _giftDue(s, _devoted) && _hasLauncher(s),
    text:
        'The colony\'s workshops have been running night and day, and the '
        'representatives would like you to see what for: a full load for '
        'one of your launchers, made to your own specifications, which '
        'nobody gave them.',
    choices: [
      Choice('Load it', [
        Outcome(
          'It fits perfectly. Of course it does.',
          effects: [GainAmmo(), MarkRound(_giftKey)],
        ),
      ]),
    ],
  ),
  BrawlEvent(
    id: 'gift_boarders',
    title: 'Volunteers',
    aftermath: true,
    weight: (s) => 1.5,
    condition: (s) =>
        _giftDue(s, _devoted) &&
        s.humans.count >= 100 &&
        !s.flags.contains(boardingParty),
    text:
        'A hundred humans in vacuum suits are waiting at the airlock, '
        'rifles slung. They want to go ahead of you to the next fight and '
        'get aboard the enemy before the shooting starts. They say they '
        'have done this before. They are very calm about it.',
    choices: [
      Choice('Let them go', [
        Outcome(
          'They are gone before you finish saying yes.',
          effects: [SetFlag(boardingParty), MarkRound(_giftKey)],
        ),
      ]),
      Choice('Not on my account', [
        Outcome(
          'They take it as the compliment it is.',
          effects: [ColonyChange(loyalty: 3), MarkRound(_giftKey)],
        ),
      ]),
    ],
  ),
  BrawlEvent(
    id: 'gift_shipwrights',
    title: 'Shipwrights',
    aftermath: true,
    weight: (s) => 1.5,
    condition: (s) =>
        _giftDue(s, _devoted) && !s.flags.contains('gift_shipwrights'),
    text:
        'The colony\'s shipwrights have been reinforcing your hull from the '
        'inside, rib by rib, for weeks. They would like you to come and see. '
        'They have signed their work.',
    choices: [
      Choice('Go and see', [
        Outcome(
          'There are hundreds of names, scratched small into the frames. '
          'Yours is at the top.',
          effects: [
            HullUpgrade(),
            SetFlag('gift_shipwrights'),
            MarkRound(_giftKey),
          ],
        ),
      ]),
    ],
  ),
];

/// Loyalty for a Content colony, and for a Devoted one.
const _content = 60;
const _devoted = 80;

/// Fights between gifts at the least.
const _giftGap = 3;
const _giftKey = 'colony_gift';

bool _giftDue(BrawlState s, int loyalty) =>
    s.humans.count > 0 &&
    s.humans.loyalty >= loyalty &&
    s.round >= s.counter(_giftKey) + _giftGap;

bool _hasLauncher(BrawlState s) => s.loadout.slots.any(
  (id) =>
      id != null &&
      (id.startsWith('missiles_') ||
          id.startsWith('teleporter_') ||
          id.startsWith('fabricator_')),
);
