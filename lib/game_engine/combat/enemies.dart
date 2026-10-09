import 'catalog.dart';

/// An enemy ship: its hull before equipment, and its loadout.
class EnemyTemplate {
  const EnemyTemplate(
    this.name,
    this.hull,
    this.loadout, {
    this.cargo = const [],
  });
  final String name;
  final int hull;
  final CombatLoadout loadout;

  /// Commodities aboard, taken as plunder if the ship is destroyed.
  final List<String> cargo;

  /// The same ship in a later act.
  ///
  /// Interim scaling until missions and trading give the player a real
  /// income: act 2 doubles the hull, act 3 triples it and moves every card
  /// up a tier. The plan's target is ×3 per act.
  EnemyTemplate forAct(int act, {String? name}) {
    if (act <= 1) {
      return EnemyTemplate(name ?? this.name, hull, loadout, cargo: cargo);
    }
    final tiersUp = act >= 3 ? 1 : 0;
    String up(String id) {
      final e = equipmentById(id);
      if (!e.merges) return id;
      final tier = (e.tier.index + tiersUp).clamp(0, 2);
      return '${e.family}_${tier + 1}';
    }

    return EnemyTemplate(
      name ?? this.name,
      hull * act,
      CombatLoadout(
        [for (final id in loadout.slots) id == null ? null : up(id)],
        hold: [for (final id in loadout.hold) up(id)],
      ),
      cargo: cargo,
    );
  }
}

/// Act 1 enemy tiers, weakest first.
final act1Enemies = [
  EnemyTemplate('Scout', 200, CombatLoadout.of(['laser_1'])),
  EnemyTemplate('Raider', 300, CombatLoadout.of(['laser_1', 'shield_1'])),
  EnemyTemplate(
    'Pirate',
    350,
    CombatLoadout.of(['laser_1', 'missiles_1'], hold: ['missile_crate_1']),
  ),
  EnemyTemplate(
    'Gunship',
    500,
    CombatLoadout.of(['laser_1', 'laser_1', 'shield_1']),
  ),
  EnemyTemplate(
    'Elite',
    750,
    CombatLoadout.of(
      ['missiles_1', 'missiles_1', 'laser_1', 'fabricator_1', 'shield_1'],
      hold: ['missile_crate_1', 'feedstock_1'],
    ),
  ),
  EnemyTemplate(
    'Dreadnought',
    1200,
    CombatLoadout.of(
      [
        'laser_2',
        'missiles_1',
        'missiles_1',
        'shield_1',
        'shield_1',
        'fabricator_1',
        'plating_1',
      ],
      hold: ['missile_crate_2', 'feedstock_1'],
    ),
  ),
];

/// Demons, weakest first. Only met in Hell.
final demons = [
  EnemyTemplate(
    'Tooth swarm',
    300,
    CombatLoadout.of(['teeth_1', 'teeth_1', 'teeth_1']),
  ),
  EnemyTemplate(
    'Brandy leech',
    450,
    CombatLoadout.of([
      'brimstone_1',
      'brimstone_1',
      'brandy_mist_1',
      'metal_flesh_1',
    ]),
  ),
  EnemyTemplate(
    'Metal-flesh behemoth',
    800,
    CombatLoadout.of([
      'brimstone_1',
      'brimstone_1',
      'teeth_2',
      'metal_flesh_1',
      'metal_flesh_1',
    ]),
  ),
  EnemyTemplate(
    'Herald of a demon lord',
    1200,
    CombatLoadout.of([
      'brimstone_2',
      'teeth_2',
      'teeth_1',
      'brandy_mist_2',
      'metal_flesh_2',
    ]),
  ),
];

/// The enemy for a story fight of a given strength. Story events rate
/// fights roughly 5 (a scout) to 14 (an elite), with anything above that a
/// dreadnought.
EnemyTemplate enemyFor(String name, int strength, int act) {
  final index = switch (strength) {
    <= 5 => 0,
    6 => 1,
    7 => 2,
    <= 9 => 3,
    <= 13 => 4,
    _ => 5,
  };
  return act1Enemies[index].forAct(act, name: name);
}
