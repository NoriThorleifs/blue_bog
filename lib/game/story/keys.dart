/// Story flags. Some are already set when a run starts (see [Flag.history]);
/// the rest are set by story beats and the captain's choices.
abstract final class Flag {
  // Already happened when the game starts.
  static const gatecrash = 'gatecrash';
  static const gorDemilitarised = 'gor_demilitarised';
  static const firstContact = 'first_contact';
  static const humansAtOrcha = 'humans_at_orcha';

  static const history = {
    gatecrash,
    gorDemilitarised,
    firstContact,
    humansAtOrcha,
  };

  // Act 1 galactic story.
  static const orchaRaid = 'orcha_raid';
  static const hiveLocated = 'hive_located';
  static const overseerOffer = 'overseer_offer';
  static const keplerTouchdown = 'kepler_touchdown';
  static const neoTerraWar = 'neo_terra_war';
  static const neoTerraClaimed = 'neo_terra_claimed';
  static const humansGrantedPlanet = 'humans_granted_planet';
  static const gorBhrunWar = 'gor_bhrun_war';
  static const gorBhrunWarOver = 'gor_bhrun_war_over';
  static const gorFleetLost = 'gor_fleet_lost';
  static const bhrunSubjugated = 'bhrun_subjugated';
  static const bhrunInvasion = 'bhrun_invasion';

  // Act 2.
  static const traeGateRestored = 'trae_gate_restored';
  static const wrongWarping = 'wrong_warping';
  static const overseerSuspects = 'overseer_suspects';

  /// The Overseer is dead. Only the Mourner can do that.
  static const overseerGone = 'overseer_gone';
  static const keplerVoteHeld = 'kepler_vote_held';
  static const keplerEvicted = 'kepler_evicted';

  // Act 3.
  static const kyndariRevealed = 'kyndari_revealed';
  static const eldestExposed = 'eldest_exposed';
  static const demonsStirring = 'demons_stirring';

  /// The captain's humans have told them the Consumers are modified
  /// cockroaches from Sol, and how they know who took them.
  static const roachTruth = 'roach_truth';

  /// The Solar human army has let the captain into Sol.
  static const solEntered = 'sol_entered';

  /// Shining-head is dead. Only destroying his complex, 10 km under Neo
  /// Terra's capital, can do that.
  static const shiningHeadDead = 'shining_head_dead';

  /// A secret Hellborn agent is among the humans aboard. Hidden from the
  /// player; only hinted at by crew whose stories don't add up.
  static const hellbornAgentAboard = 'hellborn_agent_aboard';

  /// The ship is caught in the pull of the Mourner's black hole.
  static const mournerPull = 'mourner_pull';

  /// The captain knows you have to ask the Mourner politely.
  static const mournerLore = 'mourner_lore';

  // Factions.
  static const uploadedFormed = 'uploaded_formed';
  static const ternSecession = 'tern_secession';
  static const warRed = 'war_red';
  static const warYellow = 'war_yellow';
  static const elephantFound = 'elephant_found';
  static const elephantWelcome = 'elephant_welcome';
  static const elephantEnemy = 'elephant_enemy';
  static const fuelRatsEnemy = 'fuel_rats_enemy';

  // Hell and the codes.
  static const codeGreenUsed = 'code_green_used';
  static const hellbornAlly = 'hellborn_ally';

  // Things the captain personally did.
  static const captainFoughtRaid = 'captain_fought_raid';
  static const captainFledRaid = 'captain_fled_raid';
  static const captainBackedOffer = 'captain_backed_offer';
  static const captainOpposedOffer = 'captain_opposed_offer';
  static const captainFoundBroadcast = 'captain_found_broadcast';
  static const captainFixedGate = 'captain_fixed_gate';
}

/// Story counters.
abstract final class Counter {
  /// -100 to 100. How the Republic feels about the humans. Drives the ending.
  static const republicStance = 'republic_stance';

  /// How bad the Consumer problem is.
  static const consumerThreat = 'consumer_threat';
  static const gorAggression = 'gor_aggression';

  /// How much military and political weight the humans have.
  static const humanPower = 'human_power';

  /// The captain's small but significant political capital.
  static const influence = 'influence';

  /// How aware the Hellborn are of this captain. Raised by Hell visits,
  /// human-leaning culture drift, and Code Green.
  static const hellbornAwareness = 'hellborn_awareness';

  /// Extra percentage chance of slipping into Hell in any gateway pipe.
  static const pipeInstability = 'pipe_instability';

  /// How fed up the Tern are with the Overseer: the weakest of the Havi,
  /// given the Center as a joke job, and now ruling by default because it
  /// was the only one left after the gatecrash.
  static const ternDiscontent = 'tern_discontent';

  /// Credits owed to the Fuel Rats.
  static const fuelRatsDebt = 'fuel_rats_debt';

  /// Hull upgrades bought at shipyards. Each adds 100 maximum hull.
  static const hullUpgrades = 'hull_upgrades';

  /// Turns since a war-starting code was sent.
  static const warTurns = 'war_turns';

  static const initial = {
    republicStance: 5,
    consumerThreat: 3,
    gorAggression: 2,
    humanPower: 1,
    influence: 1,
    hellbornAwareness: 0,
    pipeInstability: 0,
  };
}
