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

/// Cards made in Hell. Never sold at a station: they come from demon
/// wrecks and Hell's own events.
const hellFamilies = [
  EquipmentFamily(
    id: 'brimstone',
    names: ['Brandy Burner', 'Brimstone Projector', 'Hellmouth Cannon'],
    cooldown: 5,
    action: Hellfire(24),
    price: 45,
    tags: {CardTag.hellish},
  ),
  EquipmentFamily(
    id: 'teeth',
    names: ['Loose Teeth', 'Tooth Lattice', 'The Chewer\'s Grin'],
    cooldown: 3,
    action: FireLaser(14),
    price: 35,
    tags: {CardTag.hellish},
  ),
  EquipmentFamily(
    id: 'brandy_mist',
    names: ['Brandy Mist', 'Fume Bank', 'The Drowning Sea'],
    cooldown: 7,
    action: ChargeShields(),
    maxShield: 40,
    price: 40,
    tags: {CardTag.hellish},
  ),
  EquipmentFamily(
    id: 'metal_flesh',
    names: ['Metal Flesh Graft', 'Living Hull', 'Behemoth Hide'],
    hull: 140,
    price: 40,
    tags: {CardTag.hellish},
  ),
];

/// The Mourner's only gift.
const cursedOrb = Equipment(
  id: 'cursed_orb',
  name: 'Cursed Orb',
  family: 'cursed_orb',
  tier: Tier.unique,
  awakens: CardTag.hellish,
  price: 400,
  text:
      'A tiny black hole inside a greasy black stone ball. Heavier than it '
      'should be, and warm.',
);

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
    grantsTag: CardTag.hellish,
    // Rare in shops: most of it comes out of Hell.
    shopOdds: 0.1,
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

/// Cargo the captain has been paid to deliver.
const missionCargo = [
  Equipment(
    id: 'parcel_sealed',
    name: 'Sealed Crate',
    family: 'parcel_sealed',
    tier: Tier.basic,
    kind: CardKind.mission,
    text: 'Somebody paid well for nobody to ask what\'s inside.',
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
    boost: ChargeBoost(BoostScope.ship, 30),
    headStart: 0.5,
    tags: {CardTag.hellish},
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
  for (final e in missionCargo) e.id: e,
  for (final e in mournerCards) e.id: e,
  for (final family in hellFamilies)
    for (final e in family.tiers) e.id: e,
  cursedOrb.id: cursedOrb,
};

final _tagged = <String, Equipment>{};

/// A card by id. Ids with tags after [tagSeparator] are tagged copies.
Equipment equipmentById(String id) {
  if (id.contains(tagSeparator)) {
    return _tagged[id] ??= equipmentById(
      baseId(id),
    ).withTags(addedTags(id), id);
  }
  return equipmentCatalog[id] ?? (throw ArgumentError('Unknown equipment $id'));
}

/// The id without any tags the card has picked up.
String baseId(String id) => id.split(tagSeparator).first;

/// Tags a card has picked up, beyond the ones it was made with.
Set<CardTag> addedTags(String id) => {
  for (final name in id.split(tagSeparator).skip(1))
    CardTag.values.byName(name),
};

/// The id of [id] with [tags] added. Tags the card was made with aren't
/// written into the id.
String taggedId(String id, Set<CardTag> tags) {
  final added = {...addedTags(id), ...tags}
    ..removeAll(equipmentById(baseId(id)).tags);
  return [
    baseId(id),
    for (final tag in CardTag.values)
      if (added.contains(tag)) tag.name,
  ].join(tagSeparator);
}

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
