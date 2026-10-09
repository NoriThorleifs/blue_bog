import '../combat/catalog.dart';
import '../rng.dart';

/// The ships a brawl can meet, by stage of the difficulty curve.
///
/// Each stage has a pool of ships of about the same strength, built to
/// trouble different builds: shields stop lasers, drones stop missiles,
/// and teleport bombs go through everything. The first ship in each pool
/// is the one from [act1Enemies] that used to hold that stage alone.
final brawlPools = <List<EnemyTemplate>>[
  // Stage 0: fight 1.
  [
    act1Enemies[0],
    EnemyTemplate(
      'Fuel Rat tow-tug',
      200,
      CombatLoadout.of(['laser_1', 'fabricator_1'], hold: ['feedstock_1']),
    ),
  ],
  // Stage 1: fight 2.
  [
    act1Enemies[1],
    EnemyTemplate(
      'Ál survey boat',
      250,
      CombatLoadout.of(
        ['laser_1', 'shield_1', 'fabricator_1'],
        hold: ['feedstock_1'],
      ),
    ),
    EnemyTemplate(
      'Bhrun ore hauler',
      350,
      CombatLoadout.of(['laser_1', 'plating_1']),
      cargo: ['goods_ore', 'goods_ore'],
    ),
  ],
  // Stage 2: fights 3 and 4.
  [
    act1Enemies[2],
    EnemyTemplate(
      'Pirate picket boat',
      300,
      CombatLoadout.of(['missiles_1', 'missiles_1'], hold: ['missile_crate_1']),
    ),
    EnemyTemplate(
      'Republic customs cutter',
      300,
      CombatLoadout.of([
        'laser_1',
        'shield_1',
        'shield_1',
        'shield_capacitor_1',
      ]),
    ),
  ],
  // Stage 3: fights 5 and 6.
  [
    act1Enemies[3],
    EnemyTemplate(
      'Tern swarm node',
      400,
      CombatLoadout.of(
        ['laser_1', 'fabricator_1', 'fabricator_1', 'capacitors_1'],
        hold: ['feedstock_1', 'feedstock_1'],
      ),
    ),
    EnemyTemplate(
      'Bhrun grain barge',
      550,
      CombatLoadout.of(
        ['laser_1', 'missiles_1', 'plating_1', 'shield_1'],
        hold: ['missile_crate_1'],
      ),
      cargo: ['goods_grain', 'goods_grain', 'goods_chitin'],
    ),
  ],
  // Stage 4: fights 7 and 8.
  [
    act1Enemies[4],
    EnemyTemplate(
      'Gor boarding ram',
      650,
      CombatLoadout.of(
        ['missiles_1', 'missiles_1', 'quick_fuzes_1', 'flak_1', 'plating_1'],
        hold: ['missile_crate_1', 'missile_crate_1'],
      ),
    ),
    EnemyTemplate(
      'Unfortunate gate-wright',
      600,
      CombatLoadout.of(
        ['teleporter_1', 'laser_1', 'jammer_1', 'shield_1'],
        hold: ['teleport_charges_1'],
      ),
    ),
    EnemyTemplate(
      'Elephant galleon',
      800,
      CombatLoadout.of(['laser_1', 'laser_1', 'shield_1', 'plating_1']),
      cargo: ['goods_medicine', 'goods_relics'],
    ),
  ],
  // Stage 5: fights 9 and 10, and every fight after, scaled by act.
  [
    act1Enemies[5],
    EnemyTemplate(
      'Republic bastion',
      1200,
      CombatLoadout.of([
        'laser_2',
        'ion_1',
        'shield_2',
        'shield_1',
        'shield_capacitor_1',
        'shield_capacitor_1',
      ]),
    ),
    EnemyTemplate(
      'Tern hive ark',
      1200,
      CombatLoadout.of(
        ['laser_2', 'laser_1', 'fabricator_2', 'fabricator_1', 'repair_1'],
        hold: ['feedstock_2'],
      ),
    ),
    EnemyTemplate(
      'Gor siege ship',
      1100,
      CombatLoadout.of(
        [
          'missiles_2',
          'missiles_1',
          'quick_fuzes_1',
          'laser_1',
          'plating_1',
          'plating_1',
        ],
        hold: ['missile_crate_2'],
      ),
    ),
    EnemyTemplate(
      'Uploaded interceptor',
      900,
      CombatLoadout.of([
        'laser_2',
        'lance_1',
        'fire_control_2',
        'capacitors_1',
        'shield_1',
        'shield_1',
      ]),
    ),
  ],
];

/// Which pool each of the first fights draws from. After these, every
/// fight draws from the last pool, scaled up by act every four fights.
const _schedule = [0, 1, 2, 2, 3, 3, 4, 4, 5, 5];

/// The act a fight at [round] is scaled to.
int brawlAct(int round) {
  final i = round - 1;
  return i < _schedule.length ? 1 : 2 + (i - _schedule.length) ~/ 4;
}

List<EnemyTemplate> _poolFor(int round) {
  final i = round - 1;
  return brawlPools[i < _schedule.length
      ? _schedule[i]
      : brawlPools.length - 1];
}

/// The enemy waiting at the end of fight [round] in the brawl with [seed].
///
/// Picked from the round's pool by the seed alone, so the next enemy can
/// be shown before launch, and never the same ship twice in a row.
EnemyTemplate brawlEnemy(int round, int seed) {
  EnemyTemplate? last;
  for (var r = 1; r <= round; r++) {
    final pool = [
      for (final e in _poolFor(r))
        if (e.name != last?.name) e,
    ];
    last = GameRng(seed ^ (r * 0x9E3779B1)).pick(pool);
  }
  return last!.forAct(brawlAct(round));
}

/// Ships met only when an event sends the captain to them.
enum SpecialEnemy {
  /// The Neo Terran defence network, guarding the exclusion zone. Strong
  /// for its stage on purpose: the warnings were clear.
  neoTerranPlatform(
    EnemyTemplate(
      'Neo Terran defence platform',
      1100,
      CombatLoadout(
        [
          'teleporter_1',
          'teleporter_1',
          'laser_1',
          'plating_2',
          'plating_1',
          null,
          'laser_1',
          'shield_1',
          null,
        ],
        hold: ['teleport_charges_1', 'teleport_charges_1'],
      ),
    ),
    actsAhead: 1,
  ),

  /// Early elite: the pirate flagship behind the shakedown, named for how
  /// its captain got the job. Lasers boosted on top, fast missiles bottom
  /// left, shields bottom right.
  lastVote(
    EnemyTemplate(
      'The Last Vote',
      400,
      CombatLoadout(
        [
          'laser_1',
          'laser_1',
          'fire_control_1',
          'missiles_1',
          'missiles_1',
          'quick_fuzes_1',
          'shield_1',
          'shield_1',
          'plating_1',
        ],
        hold: ['missile_crate_1', 'missile_crate_1'],
      ),
    ),
  ),

  /// Mid elite: a Gor champion who has come looking for a duel. Missiles
  /// everywhere, thick plating and one drone to cover it.
  gorChampion(
    EnemyTemplate(
      'Gor champion',
      750,
      CombatLoadout(
        [
          'missiles_2',
          'laser_1',
          'fire_control_1',
          'missiles_1',
          'missiles_1',
          'quick_fuzes_1',
          'plating_2',
          'shield_1',
          'fabricator_1',
        ],
        hold: ['missile_crate_2', 'feedstock_1'],
      ),
    ),
  ),

  /// Late elite: a Tern foundry ship that lost touch with the hivemind and
  /// kept building itself bigger out of wrecks. Drones stop missiles and
  /// repair it; shields stop lasers. Teleport bombs and hellfire get in.
  unmergedFoundry(
    EnemyTemplate(
      'Unmerged foundry',
      2000,
      CombatLoadout(
        [
          'laser_2',
          'laser_2',
          'fire_control_2',
          'fabricator_2',
          'fabricator_2',
          'capacitors_1',
          'shield_2',
          'shield_capacitor_1',
          'plating_1',
        ],
        hold: ['feedstock_2', 'feedstock_2'],
      ),
    ),
  ),

  /// Nobody: the one human specially trained to kill the species of the
  /// galactic republic. A fully upgraded drone port and shields, and one
  /// weapon. Forty seconds after the fight starts he boards, and the
  /// captain is dead. The ship is already fully upgraded, so later on only
  /// its hull grows.
  nobody(
    EnemyTemplate(
      'Nobody',
      900,
      CombatLoadout(
        [
          'nobody_boarding_teleporter',
          null,
          null,
          'fabricator_3',
          null,
          null,
          'shield_3',
          null,
          null,
        ],
        hold: ['feedstock_3'],
      ),
    ),
  );

  const SpecialEnemy(this.template, {this.actsAhead = 0});
  final EnemyTemplate template;

  /// How many acts ahead of the usual enemy this ship is scaled.
  final int actsAhead;

  /// This ship at fight [round].
  EnemyTemplate at(int round) => template.forAct(brawlAct(round) + actsAhead);
}
