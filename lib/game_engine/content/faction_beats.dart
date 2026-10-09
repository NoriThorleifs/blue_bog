import '../faction.dart';
import '../galaxy/galaxy.dart';
import '../run_state.dart';
import '../story/keys.dart';
import '../story/rules.dart';
import '../story/story.dart';

/// Story beats that move borders.
final factionBeats = <StoryBeat>[
  StoryBeat(
    id: 'reunification',
    headline: 'Reunification',
    condition: const AllOf([ActAtLeast(2), NoFlag(Flag.warRed)]),
    chance: 0.3,
    repeatable: true,
    modifiers: const [(HasFlag(Flag.overseerGone), 0.5)],
    effects: const [
      Expand(
        Faction.republic,
        chance: 0.35,
        only: Faction.unaligned,
        verb: 'rejoined',
      ),
    ],
    outcomes: const [
      Outcome(
        'Republic envoys are reaching systems that have been alone since '
        'the gatecrash.',
      ),
    ],
  ),
  StoryBeat(
    id: 'siren_song',
    headline: 'A voice under Neo Terra',
    condition: const AllOf([
      ActAtLeast(2),
      HasFlag(Flag.neoTerraClaimed),
      NoFlag(Flag.shiningHeadDead),
      NoFlag(Flag.uploadedFormed),
      CounterBelow(Counter.republicStance, -10),
    ]),
    chance: 0.3,
    effects: const [
      SetFlag(Flag.uploadedFormed),
      SetControl(Sys.neoTerra, Faction.uploaded),
      SetControl(Sys.kepler, Faction.uploaded),
    ],
    outcomes: const [
      Outcome(
        'The humans of Neo Terra and Kepler have stopped answering the '
        'Republic. They have found a better listener: something under '
        'their capital that remembers the Havi empire, and promises them '
        'everything the Republic would not give. It calls its followers '
        'the Uploaded.',
      ),
    ],
  ),
  StoryBeat(
    id: 'uploaded_spread',
    headline: 'The Uploaded grow',
    condition: const AllOf([
      HasFlag(Flag.uploadedFormed),
      NoFlag(Flag.shiningHeadDead),
      ActAtLeast(3),
    ]),
    chance: 0.2,
    repeatable: true,
    effects: const [Expand(Faction.uploaded, chance: 0.25)],
    outcomes: const [
      Outcome('Shining-head\'s followers have taken more ground.'),
    ],
  ),
  StoryBeat(
    id: 'tern_secession',
    headline: 'The Tern withdraw',
    condition: const AllOf([
      ActAtLeast(2),
      NoFlag(Flag.ternSecession),
      CounterAtLeast(Counter.ternDiscontent, 5),
    ]),
    chance: 0.15,
    effects: const [
      SetFlag(Flag.ternSecession),
      ClaimTagged(Tag.tern, Faction.ternCollective),
    ],
    outcomes: const [
      Outcome(
        'The Tern remember what the Overseer was before the gatecrash: the '
        'weakest of the Havi, handed a tourist station because the others '
        'wanted it out of the way. It rules the Republic only because it '
        'was the last one left, and the Tern have had enough. They are not '
        'hostile. They simply no longer accept it as their leader. Every '
        'Tern relay now answers to the Collective.',
        condition: NoFlag(Flag.overseerGone),
      ),
      Outcome(
        'With the Overseer gone, the Tern see no reason to take orders from '
        'whatever is left of the Republic. They are not hostile. They simply '
        'govern themselves now.',
        condition: HasFlag(Flag.overseerGone),
      ),
    ],
  ),

  StoryBeat(
    id: 'fuel_rats_due',
    headline: 'Fuel Rats collection',
    condition: const AllOf([
      CounterAtLeast(Counter.fuelRatsDebt, 1),
      NotInHell(),
    ]),
    chance: 1,
    delay: 4,
    repeatable: true,
    outcomes: const [Outcome('Your tab with the Fuel Rats is due.')],
    localEvent: (const NotInHell(), 'fuel_rats_collect'),
  ),

  // Code Red: the Hellborn try to take the galaxy.
  StoryBeat(
    id: 'hellborn_advance',
    headline: 'The Hellborn advance',
    condition: const HasFlag(Flag.warRed),
    chance: 1,
    repeatable: true,
    effects: const [
      Expand(Faction.hellborn, chance: 0.45, throughDeadGateways: true),
      AddCounter(Counter.warTurns, 1),
    ],
    outcomes: const [
      Outcome(
        'General Grönigen\'s fleets come out of gateways nobody knew still '
        'worked.',
      ),
    ],
  ),

  // Code Yellow: the gatecrash happens again.
  StoryBeat(
    id: 'demon_tide',
    headline: 'The demons spread',
    condition: const HasFlag(Flag.warYellow),
    chance: 1,
    repeatable: true,
    effects: const [
      Expand(Faction.demons, chance: 0.3, throughDeadGateways: true),
      AddCounter(Counter.warTurns, 1),
    ],
    outcomes: const [Outcome('Another barrier has given way.')],
  ),
  for (final (flag, ending) in [
    (Flag.warRed, Ending.codeRed),
    (Flag.warYellow, Ending.codeYellow),
  ])
    StoryBeat(
      id: 'war_ends_${ending.name}',
      headline: 'The dust settles',
      condition: AllOf([
        HasFlag(flag),
        const CounterAtLeast(Counter.warTurns, 9),
      ]),
      chance: 1,
      effects: [EndRun(ending)],
      outcomes: const [Outcome('')],
    ),
];
