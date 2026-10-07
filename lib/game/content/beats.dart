import '../faction.dart';
import '../galaxy/galaxy.dart';
import '../story/keys.dart';
import '../story/rules.dart';
import '../story/story.dart';

/// The galaxy's timeline from the start of the game, following `outline.md`.
/// Everything up to the humans' temporary residence at Orcha has already
/// happened (see [Flag.history]).
///
/// Order matters: beats are checked top to bottom at the end of each turn.
final storyBeats = <StoryBeat>[
  // Act 1 -----------------------------------------------------------------
  StoryBeat(
    id: 'orcha_raid',
    headline: 'Consumers strike Orcha Station',
    condition: const AllOf([TurnAtLeast(3), NoFlag(Flag.orchaRaid)]),
    chance: 0.2,
    deadline: 6,
    effects: const [
      SetFlag(Flag.orchaRaid),
      AddCounter(Counter.consumerThreat, 1),
      AddCounter(Counter.humanPower, 1),
      AddCounter(Counter.republicStance, 5),
    ],
    outcomes: const [
      Outcome(
        'Consumers boarded Orcha Station without warning. Station security '
        'were still reaching for the alarms when the humans started pulling '
        'guns out of the promenade railings. The raid was beaten back. The '
        'other species are grateful, and a little frightened.',
      ),
    ],
    localEvent: (const AtSystem(Sys.orcha), 'raid_at_orcha'),
  ),
  StoryBeat(
    id: 'hive_located',
    headline: 'Consumer hive world found',
    condition: const HasFlag(Flag.orchaRaid),
    chance: 0.2,
    deadline: 6,
    effects: const [SetFlag(Flag.hiveLocated), Reveal(Sys.neoTerra)],
    outcomes: const [
      Outcome(
        'Republic scouts have traced the Consumers to {sys:neo_terra}, a '
        'plain Havi agri-world a sublight burn from Orcha. It is thoroughly '
        'infested and guarded by a shipbuilding gantry. Nobody can send an '
        'army without blowing the planet up, nobody wants to fly there at '
        'sublight, and nobody but a Consumer could stand its gravity.',
      ),
    ],
  ),
  StoryBeat(
    id: 'overseer_offer',
    headline: 'The Overseer makes an offer',
    condition: const HasFlag(Flag.hiveLocated),
    chance: 0.25,
    deadline: 5,
    effects: const [SetFlag(Flag.overseerOffer)],
    outcomes: const [
      Outcome(
        'After many useless plans and arguments, the Overseer proposes that '
        'the humans be given the hive world if they clear the Consumers out '
        'of it. The humans accept, despite having no ships and no military. '
        'They also use the offer to press the council about Kepler.',
      ),
    ],
    localEvent: (const AtSystem(Sys.center), 'council_session'),
  ),
  StoryBeat(
    id: 'kepler_touchdown',
    headline: '"Misunderstanding" at Kepler',
    condition: const HasFlag(Flag.overseerOffer),
    chance: 0.2,
    deadline: 6,
    modifiers: const [(HasFlag(Flag.captainBackedOffer), 1.5)],
    effects: const [
      SetFlag(Flag.keplerTouchdown),
      AddCounter(Counter.republicStance, -8),
      AddCounter(Counter.ternDiscontent, 1),
      AddCounter(Counter.humanPower, 1),
    ],
    outcomes: const [
      Outcome(
        'Due to what the humans call a misunderstanding, the Promethius '
        'has landed its colonists on Kepler\'s surface. The observation '
        'station is apoplectic. Census figures from the new colony are '
        'suspiciously small.',
      ),
    ],
    localEvent: (const AtSystem(Sys.kepler), 'touchdown_witness'),
  ),
  StoryBeat(
    id: 'neo_terra_war',
    headline: 'Humans attack the hive world',
    condition: const HasFlag(Flag.keplerTouchdown),
    chance: 0.2,
    deadline: 6,
    effects: const [SetFlag(Flag.neoTerraWar)],
    outcomes: const [
      Outcome(
        'A human decoy fleet drew the Consumer armada to a neighbouring '
        'system while the main fleet took the shipbuilding gantry. The '
        'humans have mined the approaches and renamed {sys:neo_terra} Neo '
        'Terra. '
        'The council has ratified their ownership.',
        weight: 3,
        bondWeight: 0.5,
        condition: NoFlag(Flag.captainOpposedOffer),
        effects: [..._claimNeoTerra, SetFlag(Flag.humansGrantedPlanet)],
      ),
      Outcome(
        'The humans have taken {sys:neo_terra}\'s orbit and renamed it Neo '
        'Terra. The council has ratified the deal, though one captain\'s '
        'objection made the vote closer than anyone expected.',
        condition: HasFlag(Flag.captainOpposedOffer),
        effects: [..._claimNeoTerra, SetFlag(Flag.humansGrantedPlanet)],
      ),
      Outcome(
        'The humans have taken {sys:neo_terra}\'s orbit and renamed it Neo '
        'Terra. The council has stalled on ratifying the deal, since nobody '
        'expected them to win.',
        weight: 1.5,
        effects: _claimNeoTerra,
      ),
      Outcome(
        'The assault on the hive world has bogged down. The humans hold '
        'part of the orbit and none of the surface.',
        bondWeight: -0.5,
        effects: [AddCounter(Counter.consumerThreat, 1)],
      ),
    ],
  ),
  StoryBeat(
    id: 'neo_terra_retaken',
    headline: 'Neo Terra falls to the humans',
    condition: const AllOf([
      HasFlag(Flag.neoTerraWar),
      NoFlag(Flag.neoTerraClaimed),
    ]),
    chance: 0.12,
    deadline: 10,
    effects: _claimNeoTerra,
    outcomes: const [
      Outcome(
        'After months of grinding orbital war the humans hold '
        '{sys:neo_terra}. They call it Neo Terra and are already building a capital '
        'over the shallowest hives.',
      ),
    ],
  ),
  StoryBeat(
    id: 'gor_bhrun_war',
    headline: 'Gor armada moves on Bhrun-Gai',
    condition: const AllOf([TurnAtLeast(10), NoFlag(Flag.gorBhrunWar)]),
    chance: 0.12,
    deadline: 10,
    modifiers: const [(CounterAtLeast(Counter.gorAggression, 4), 2)],
    effects: const [SetFlag(Flag.gorBhrunWar)],
    outcomes: const [
      Outcome(
        'The Gor have massed their fleet at the Bhrun-Gai gateway. The '
        'Bhrun are preparing to appease them. Five human ships have '
        'arrived, uninvited, and announced that they are going to help. '
        'Travel through the Ghor-Dum pipe is not recommended.',
      ),
    ],
    localEvent: (
      const AnyOf([AtSystem(Sys.bhrunGai), AtSystem(Sys.ghorDum)]),
      'war_at_the_pipe',
    ),
  ),
  StoryBeat(
    id: 'gor_bhrun_war_ends',
    headline: 'Battle of the Bhrun-Gai pipe',
    condition: const AllOf([
      HasFlag(Flag.gorBhrunWar),
      NoFlag(Flag.gorBhrunWarOver),
    ]),
    chance: 0.3,
    delay: 2,
    deadline: 5,
    effects: const [SetFlag(Flag.gorBhrunWarOver)],
    outcomes: const [
      Outcome(
        'None of the Gor armada made it through the pipe. Nobody can '
        'explain it. Scattered, jammed transmissions mention something '
        'that looked like humans.',
        weight: 2,
        condition: HasFlag(Flag.keplerTouchdown),
        effects: _gorFleetLost,
      ),
      Outcome(
        'None of the Gor armada made it through the pipe. The last '
        'transmission from the flagship was a single word: "Green."',
        weight: 8,
        condition: HasFlag(Flag.codeGreenUsed),
        effects: _gorFleetLost,
      ),
      Outcome(
        'The human ships were too few and too late. Bhrun-Gai has '
        'submitted to the Gor. The humans have quietly noted that they '
        'are next.',
        effects: [
          SetFlag(Flag.bhrunSubjugated),
          AddCounter(Counter.ternDiscontent, 1),
          AddCounter(Counter.gorAggression, 2),
          AddCounter(Counter.republicStance, -3),
        ],
      ),
    ],
  ),
  StoryBeat(
    id: 'bhrun_invasion',
    headline: 'Consumers invade Bhrun-Gai',
    condition: const AllOf([
      HasFlag(Flag.gorBhrunWarOver),
      HasFlag(Flag.neoTerraWar),
    ]),
    chance: 0.2,
    deadline: 8,
    effects: const [
      SetFlag(Flag.bhrunInvasion),
      AddCounter(Counter.humanPower, 2),
      AddCounter(Counter.republicStance, -6),
      AddCounter(Counter.consumerThreat, -1),
    ],
    outcomes: const [
      Outcome(
        'A Consumer swarm hit Bhrun-Gai just as the human ships passed '
        'through on their way home. The humans have fought Consumers their '
        'entire lives. They used orbital bombardment and an AI-driven '
        'system called the "Direction Remover", which shoots anything '
        'that moves and isn\'t human. The Republic is asking how anyone on '
        'Neo Terra got weapons like that. Then it realises nobody has '
        'actually been to Neo Terra to check.',
      ),
    ],
    localEvent: (const AtSystem(Sys.bhrunGai), 'direction_remover'),
  ),
  StoryBeat(
    id: 'trae_restoration',
    headline: 'The fourth gateway reopens',
    condition: const AllOf([
      ActIs(1),
      AnyOf([
        AllOf([HasFlag(Flag.neoTerraWar), TurnAtLeast(16)]),
        TurnAtLeast(24),
      ]),
    ]),
    chance: 0.15,
    deadline: 6,
    modifiers: const [(CounterAtLeast(Counter.humanPower, 6), 1.5)],
    effects: const [
      RestoreGateway(Sys.center, Sys.traeTraeTene),
      SetFlag(Flag.traeGateRestored),
      AddCounter(Counter.ternDiscontent, 1),
    ],
    outcomes: const [
      Outcome(
        'Rattled by how strong the humans have become, the council '
        'pushed a Tern repair crew through. The Unfortunates "consulted". '
        'For the first time anyone can remember, the Overseer\'s veto '
        'failed. The Center\'s fourth gateway is open again.',
      ),
    ],
  ),

  // Act 2 -----------------------------------------------------------------
  StoryBeat(
    id: 'wrong_warping',
    headline: 'Humans attempt "wrong warping"',
    condition: const AllOf([ActAtLeast(2), NoFlag(Flag.wrongWarping)]),
    chance: 0.15,
    deadline: 8,
    modifiers: const [(HasFlag(Flag.codeGreenUsed), 3)],
    effects: const [
      SetFlag(Flag.wrongWarping),
      AddCounter(Counter.pipeInstability, 3),
      AddCounter(Counter.humanPower, 1),
    ],
    outcomes: const [
      Outcome(
        'Human ships have been seen entering gateways at extreme speed and '
        'impossible angles, reaching the exit before Hell has finished '
        'taking them. There are no laws against it, because no species was '
        'ever insane enough to try. Every pipe in the network feels '
        'shakier for it.',
      ),
    ],
  ),
  StoryBeat(
    id: 'training_broadcast',
    headline: 'The Overseer grows suspicious',
    condition: const AllOf([
      ActAtLeast(2),
      HasFlag(Flag.neoTerraClaimed),
      NoFlag(Flag.overseerSuspects),
    ]),
    chance: 0.1,
    deadline: 10,
    effects: const [SetFlag(Flag.overseerSuspects)],
    outcomes: const [
      Outcome(
        'A Tern captain tuned in to the training program every drafted '
        'human must watch. It tells soldiers to ignore radio calls from '
        'strangers and to report strange noises. Consumers cannot imitate '
        'speech. The Overseer\'s reaction was immediate and, for once, '
        'assertive. It has not said why. Those who remember the Havi civil '
        'war, fought between the Havi who uploaded their minds and those who '
        'kept their bodies, can guess which side the voice on Neo Terra was '
        'on.',
      ),
    ],
  ),
  StoryBeat(
    id: 'overseer_mission',
    headline: 'The Overseer goes to Neo Terra',
    condition: const HasFlag(Flag.overseerSuspects),
    chance: 0.25,
    delay: 1,
    deadline: 5,
    // Shining-head only dies when his complex is destroyed. The Overseer
    // only dies to the Mourner.
    outcomes: const [
      Outcome(
        'The Overseer and five councillors went to Neo Terra, which no '
        'longer answers to the Republic. The Uploaded humans stood between '
        'the Overseer and the complex under their capital, and for all its '
        'power the Overseer would not fight its way through them. It came '
        'back with nothing, and the whole Republic saw it.',
        weight: 50,
        condition: AllOf([
          HasFlag(Flag.uploadedFormed),
          NoFlag(Flag.shiningHeadDead),
        ]),
        effects: [AddCounter(Counter.republicStance, -10)],
      ),
      Outcome(
        'The Overseer went to Neo Terra to finish Shining-head, and found '
        'his complex already a crater. The human leader thanked it, then '
        'warped it and five councillors to the domain of the Mourner. The '
        'councillors asked politely to leave and were let go. The Overseer '
        'did not ask. The Mourner took it.',
        weight: 50,
        condition: HasFlag(Flag.shiningHeadDead),
        effects: [
          SetFlag(Flag.overseerGone),
          AddCounter(Counter.republicStance, 5),
        ],
      ),
      Outcome(
        'The Overseer and five councillors went to Neo Terra. The Overseer '
        'teleported 10 km down into Shining-head\'s complex and destroyed '
        'it. Then the human leader warped them all to the domain of the '
        'Mourner. The councillors asked politely to leave and were let go. '
        'The Mourner kept the Overseer. The councillors tell the story of a '
        'mad AI and a human who saved them from it.',
        bondWeight: 0.5,
        condition: AllOf([
          NoFlag(Flag.uploadedFormed),
          NoFlag(Flag.shiningHeadDead),
        ]),
        effects: [
          ..._overseerKillsShiningHead,
          AddCounter(Counter.republicStance, 10),
        ],
      ),
      Outcome(
        'The Overseer and five councillors went to Neo Terra. Only the '
        'councillors came back. The Overseer destroyed the complex under '
        'Neo Terra, they say, and then a blind human psychic delivered it '
        'to the Mourner, the one being that could kill it. The Republic '
        'has no god left, and it knows who to blame.',
        condition: AllOf([
          NoFlag(Flag.uploadedFormed),
          NoFlag(Flag.shiningHeadDead),
        ]),
        effects: [
          ..._overseerKillsShiningHead,
          AddCounter(Counter.republicStance, -10),
        ],
      ),
    ],
  ),
  StoryBeat(
    id: 'gateway_restoration',
    headline: 'Gateway crews push outward',
    condition: const ActIs(2),
    chance: 0.08,
    repeatable: true,
    modifiers: const [
      (HasFlag(Flag.overseerGone), 2.5),
      (HasFlag(Flag.wrongWarping), 1.5),
    ],
    effects: const [RestoreDeadGateway()],
    outcomes: const [
      Outcome(
        'With the old network slowly giving up its secrets, another dead '
        'gateway hums back to life.',
      ),
    ],
  ),
  StoryBeat(
    id: 'kyndari_bridge',
    headline: 'A gateway into the dark',
    condition: const AllOf([ActIs(2), TurnsInActAtLeast(10)]),
    chance: 0.12,
    deadline: 8,
    modifiers: const [(HasFlag(Flag.overseerGone), 2)],
    effects: const [RestoreDeadGateway(towardAct: 3)],
    outcomes: const [
      Outcome(
        'Engineers have restored a gateway that the old charts say leads '
        'toward Kyndari, where the gatecrash began.',
      ),
    ],
  ),
  StoryBeat(
    id: 'kepler_vote',
    headline: 'The council votes on Kepler',
    condition: const AllOf([
      ActAtLeast(2),
      HasFlag(Flag.keplerTouchdown),
      NoFlag(Flag.keplerVoteHeld),
    ]),
    chance: 0.12,
    deadline: 12,
    effects: const [SetFlag(Flag.keplerVoteHeld)],
    outcomes: const [
      Outcome(
        'By a narrow margin, the council has made the Kepler settlement '
        'legal. The pre-war law protecting the planet is annulled.',
        weight: 2,
        bondWeight: 0.5,
        condition: CounterAtLeast(Counter.republicStance, -10),
        effects: [
          SetFlag(Flag.humansGrantedPlanet),
          AddCounter(Counter.republicStance, 5),
          AddCounter(Counter.ternDiscontent, 2),
        ],
      ),
      Outcome(
        'The council has voted to evict the humans from Kepler. The humans '
        'have acknowledged the ruling. They have not said anything else.',
        condition: CounterBelow(Counter.republicStance, 0),
        effects: [
          SetFlag(Flag.keplerEvicted),
          SetControl(Sys.kepler, Faction.republic),
        ],
      ),
    ],
  ),

  // Act 3 -----------------------------------------------------------------
  StoryBeat(
    id: 'human_gateway',
    headline: 'A gateway nobody built',
    condition: const ActIs(3),
    chance: 1,
    effects: const [
      Reveal(Sys.sol),
      AddCounter(Counter.humanPower, 3),
      AddCounter(Counter.republicStance, -5),
    ],
    outcomes: const [
      Outcome(
        'Survey ships at Kyndari have found a working gateway that '
        'appears on no Havi chart. It leads to Sol, the humans\' "doomed" '
        'home system. The humans restored it themselves, without the '
        'Havi, the Unfortunates or the Tern. Nobody knows how.',
      ),
    ],
  ),
  StoryBeat(
    id: 'eldest_exposed',
    headline: 'The Eldest speaks',
    condition: const AllOf([
      ActIs(3),
      TurnsInActAtLeast(2),
      NoFlag(Flag.eldestExposed),
    ]),
    chance: 0.2,
    deadline: 6,
    modifiers: const [(HasFlag(Flag.roachTruth), 2)],
    effects: const [SetFlag(Flag.eldestExposed)],
    outcomes: const [
      Outcome(
        'Under pressure from the human gateway, the Eldest of the '
        'Unfortunates has admitted it: they built a gateway to Sol long '
        'ago, visited, and covered up the collapse. The humans already '
        'knew. They wanted to hear it said.',
        bondWeight: 0.5,
        effects: [AddCounter(Counter.republicStance, 10)],
      ),
      Outcome(
        'In open council a human set a cockroach on the floor, then '
        'photographs of cave paintings bearing the Unfortunates\' mark. The '
        'Consumers were bred from Sol\'s cockroaches, and the Eldest '
        'collected the samples himself. He did not deny it. The Republic '
        'is reconsidering who it should have been afraid of.',
        weight: 4,
        condition: HasFlag(Flag.roachTruth),
        effects: [
          AddCounter(Counter.republicStance, 15),
          AddCounter(Counter.humanPower, 1),
        ],
      ),
      Outcome(
        'The Eldest has made a statement about Kyndari. It is long, '
        'technical and says nothing at all. The humans are not amused.',
        effects: [AddCounter(Counter.republicStance, -5)],
      ),
    ],
  ),
  StoryBeat(
    id: 'demons_stirring',
    headline: 'Something presses on the barrier',
    condition: const AllOf([ActIs(3), NoFlag(Flag.demonsStirring)]),
    chance: 0.12,
    modifiers: const [
      (CounterAtLeast(Counter.hellbornAwareness, 4), 2),
      (HasFlag(Flag.codeGreenUsed), 1.5),
    ],
    effects: const [
      SetFlag(Flag.demonsStirring),
      AddCounter(Counter.pipeInstability, 3),
    ],
    outcomes: const [
      Outcome(
        'Every gateway near Kyndari is shuddering. Something enormous is '
        'pushing at the barrier from the other side, the way it did before '
        'the gatecrash.',
      ),
    ],
  ),
  StoryBeat(
    id: 'the_code',
    headline: 'A signal in the pipes',
    condition: const AllOf([
      ActIs(3),
      AnyOf([HasFlag(Flag.solEntered), TurnsInActAtLeast(12)]),
    ]),
    chance: 1,
    effects: const [QueueEvent('the_code')],
    outcomes: const [
      Outcome('A coded burst is moving through every gateway pipe at once.'),
    ],
  ),
];

const _claimNeoTerra = <Effect>[
  SetFlag(Flag.neoTerraClaimed),
  Rename(Sys.neoTerra, 'Neo Terra'),
  SetControl(Sys.neoTerra, Faction.colonists),
  AddCounter(Counter.humanPower, 2),
  AddCounter(Counter.consumerThreat, -2),
];

const _overseerKillsShiningHead = <Effect>[
  SetFlag(Flag.shiningHeadDead),
  SetFlag(Flag.overseerGone),
  AddCounter(Counter.humanPower, 2),
  AddCounter(Counter.consumerThreat, -2),
];

const _gorFleetLost = <Effect>[
  SetFlag(Flag.gorFleetLost),
  AddCounter(Counter.gorAggression, -3),
  AddCounter(Counter.humanPower, 2),
  AddCounter(Counter.hellbornAwareness, 1),
];
