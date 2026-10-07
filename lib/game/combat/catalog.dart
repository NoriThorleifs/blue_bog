import 'equipment.dart';

/// Starting numbers from `Combat and economy plan.md`. Tune with
/// `dart run tool/combat_balance.dart`.
const equipmentFamilies = [
  // Weapons and defences --------------------------------------------------
  EquipmentFamily(
    id: 'laser',
    names: ['Laser', 'Twin Lasers', 'Tern Choir Lance'],
    cooldown: 5,
    action: FireLaser(30),
  ),
  EquipmentFamily(
    id: 'missiles',
    names: ['Missile Rack', 'Missile Battery', 'Rip and Tear Array'],
    cooldown: 6,
    action: FireMissile(45),
  ),
  EquipmentFamily(
    id: 'teleporter',
    names: ['Teleport Bomb', 'Teleport Barrage', 'Satan\'s Last Stand'],
    cooldown: 24,
    action: TeleportBomb(240),
    price: 60,
  ),
  EquipmentFamily(
    id: 'shield',
    names: ['Shield Generator', 'Shield Array', 'Barrier Cathedral'],
    cooldown: 6,
    action: ChargeShields(),
    maxShield: 30,
  ),
  EquipmentFamily(
    id: 'fabricator',
    names: ['Drone Fabricator', 'Drone Foundry', 'Swarm Mother'],
    cooldown: 8,
    action: BuildDrone(),
    maxDrones: 1,
  ),
  EquipmentFamily(
    id: 'plating',
    names: ['Hull Plating', 'Ablative Plating', 'Triplex Lattice Hull'],
    hull: 100,
  ),
  EquipmentFamily(
    id: 'shield_capacitor',
    names: ['Shield Capacitor', 'Capacitor Ring', 'Halo Reservoir'],
    maxShield: 30,
  ),

  // Synergy ---------------------------------------------------------------
  EquipmentFamily(
    id: 'fire_control',
    names: ['Fire Control', 'Targeting Suite', 'Ternary Fire Director'],
    boostScope: BoostScope.triangle,
    boostPercents: [15, 30, 45],
  ),
  EquipmentFamily(
    id: 'capacitors',
    names: ['Capacitor Bank', 'Overclocked Bus', 'Havi Heart'],
    boostScope: BoostScope.ship,
    boostPercents: [5, 10, 15],
  ),
  EquipmentFamily(
    id: 'quick_fuzes',
    names: ['Quick-Arm Fuzes', 'Hair Triggers', 'Instant Ordnance'],
    boostScope: BoostScope.triangle,
    boostPercents: [30, 45, 60],
    boostOnly: FireMissile,
    boostMaxDamage: 60,
  ),

  // Ship systems ----------------------------------------------------------
  EquipmentFamily(
    id: 'bunks',
    names: ['Bunk Module', 'Habitat Ring', 'Spinning Asteroid Habitat'],
    berths: 3,
    price: 20,
  ),
  EquipmentFamily(
    id: 'cargo_pod',
    names: ['Cargo Pod', 'Cargo Bay', 'Bulk Hold'],
    hold: 3,
    price: 20,
  ),
  EquipmentFamily(
    id: 'hospital',
    names: ['Sick Bay', 'Human Hospital', 'Hospital Ship'],
    hospital: 1,
  ),
  EquipmentFamily(
    id: 'barrier',
    names: ['Barrier Liner', 'Pipe Hugger', 'Demon-Proof Hull'],
    hellShielding: 0.05,
  ),
  EquipmentFamily(
    id: 'tanks',
    names: ['Drop Tank', 'Fuel Bladder', 'Fuel Rat Special'],
    fuel: 3,
    price: 20,
  ),

  // Supplies: work from the hold --------------------------------------------
  EquipmentFamily(
    id: 'missile_crate',
    names: ['Missile Crate', 'Missile Pallet', 'Missile Hold'],
    kind: CardKind.supplies,
    ammo: {Ammo.missiles: 9},
    price: 15,
  ),
  EquipmentFamily(
    id: 'teleport_charges',
    names: ['Teleport Charges', 'Charge Case', 'Charge Vault'],
    kind: CardKind.supplies,
    ammo: {Ammo.teleportCharges: 2},
    price: 40,
  ),
  EquipmentFamily(
    id: 'feedstock',
    names: ['Drone Feedstock', 'Feedstock Drum', 'Feedstock Silo'],
    kind: CardKind.supplies,
    ammo: {Ammo.droneFeedstock: 9},
    price: 15,
  ),
];

/// Trade goods. Each card is one crate; prices vary from market to market.
const commodities = [
  Equipment(
    id: 'goods_grain',
    name: 'Grain',
    family: 'goods_grain',
    tier: Tier.basic,
    kind: CardKind.commodity,
    price: 10,
  ),
  Equipment(
    id: 'goods_ice',
    name: 'Water Ice',
    family: 'goods_ice',
    tier: Tier.basic,
    kind: CardKind.commodity,
    price: 8,
  ),
  Equipment(
    id: 'goods_ore',
    name: 'Ore',
    family: 'goods_ore',
    tier: Tier.basic,
    kind: CardKind.commodity,
    price: 14,
  ),
  Equipment(
    id: 'goods_chitin',
    name: 'Consumer Chitin',
    family: 'goods_chitin',
    tier: Tier.basic,
    kind: CardKind.commodity,
    price: 22,
    text: 'Hard as armour, if you can stand the smell.',
  ),
  Equipment(
    id: 'goods_medicine',
    name: 'Medicine',
    family: 'goods_medicine',
    tier: Tier.basic,
    kind: CardKind.commodity,
    price: 30,
  ),
  Equipment(
    id: 'goods_nanopaste',
    name: 'Nanobot Paste',
    family: 'goods_nanopaste',
    tier: Tier.basic,
    kind: CardKind.commodity,
    price: 45,
    text: 'The Tern find this distasteful. Everyone else pays well for it.',
  ),
  Equipment(
    id: 'goods_brandy',
    name: 'Hell Brandy',
    family: 'goods_brandy',
    tier: Tier.basic,
    kind: CardKind.commodity,
    price: 60,
    text: 'Distilled from things that live in Hell. Do not ask which.',
  ),
  Equipment(
    id: 'goods_relics',
    name: 'Havi Relics',
    family: 'goods_relics',
    tier: Tier.basic,
    kind: CardKind.commodity,
    price: 90,
  ),
];

/// Unique cards the Mourner grants to those who ask it politely.
const mournerCards = [
  Equipment(
    id: 'mourner_event_horizon',
    name: 'Event Horizon',
    family: 'mourner_event_horizon',
    tier: Tier.unique,
    cooldown: 6,
    action: FireLaser(150),
    price: 400,
    text: 'Light that has given up on escaping.',
  ),
  Equipment(
    id: 'mourner_unfallen_world',
    name: 'The World That Never Falls',
    family: 'mourner_unfallen_world',
    tier: Tier.unique,
    hull: 600,
    price: 400,
    text: 'Always pulled back from the edge.',
  ),
  Equipment(
    id: 'mourner_polite_request',
    name: 'A Polite Request',
    family: 'mourner_polite_request',
    tier: Tier.unique,
    cooldown: 6,
    action: ChargeShields(),
    maxShield: 150,
    price: 400,
    text: 'Most things will leave you alone if you ask nicely.',
  ),
  Equipment(
    id: 'mourner_backwards_clock',
    name: 'The Backwards Clock',
    family: 'mourner_backwards_clock',
    tier: Tier.unique,
    boost: ChargeBoost(BoostScope.ship, 20),
    price: 400,
    text: 'Everything happens a little before it should.',
  ),
  Equipment(
    id: 'mourner_grief_engine',
    name: 'Grief Engine',
    family: 'mourner_grief_engine',
    tier: Tier.unique,
    cooldown: 15,
    action: TeleportBomb(300),
    ammo: {Ammo.teleportCharges: 3},
    price: 400,
    text: 'Feeds itself.',
  ),
];

final equipmentCatalog = <String, Equipment>{
  for (final family in equipmentFamilies)
    for (final e in family.tiers) e.id: e,
  for (final e in commodities) e.id: e,
  for (final e in mournerCards) e.id: e,
};

Equipment equipmentById(String id) =>
    equipmentCatalog[id] ?? (throw ArgumentError('Unknown equipment $id'));

/// The upgraded version of a card, if it has one.
Equipment? upgradeOf(Equipment e) {
  final next = e.tier.next;
  return next == null || !e.merges
      ? null
      : equipmentCatalog['${e.family}_${next.index + 1}'];
}

/// Basic equipment found as salvage or sold in shops.
final basicEquipment = [for (final f in equipmentFamilies) f.tiers.first];

/// Every captain flies this much hull before any equipment.
const baseHull = 500;

/// A ship as it enters combat: nine slots (0–2 top triangle, 3–5 bottom
/// left, 6–8 bottom right) and a hold whose supplies also count.
class CombatLoadout {
  const CombatLoadout(this.slots, {this.hold = const []});
  final List<String?> slots;
  final List<String> hold;

  static CombatLoadout of(List<String> ids, {List<String> hold = const []}) =>
      CombatLoadout([...ids, ...List.filled(9 - ids.length, null)], hold: hold);
}

/// An enemy ship: its hull before equipment, and its loadout.
class EnemyTemplate {
  const EnemyTemplate(this.name, this.hull, this.loadout);
  final String name;
  final int hull;
  final CombatLoadout loadout;

  /// The same ship in a later act.
  ///
  /// Interim scaling until missions and trading give the player a real
  /// income: act 2 doubles the hull, act 3 triples it and moves every card
  /// up a tier. The plan's target is ×3 per act.
  EnemyTemplate forAct(int act, {String? name}) {
    if (act <= 1) return EnemyTemplate(name ?? this.name, hull, loadout);
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
