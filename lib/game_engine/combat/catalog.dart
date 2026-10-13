import 'equipment.dart';

export 'enemies.dart';

/// Starting numbers from `Combat and economy plan.md`. Tune with
/// `dart run tool/combat_balance.dart`.
const equipmentFamilies = [
  // Weapons and defences --------------------------------------------------
  EquipmentFamily(
    id: 'laser',
    names: ['Laser', 'Twin Lasers', 'Tern Choir Lance'],
    cooldown: 5,
    action: FireLaser(30),
    perks: [
      [Quicker(20)],
      [Quicker(40), Veteran(3)],
    ],
  ),
  EquipmentFamily(
    id: 'missiles',
    names: ['Missile Rack', 'Missile Battery', 'Rip and Tear Array'],
    cooldown: 6,
    action: FireMissile(45),
    perks: [
      [Stocked(Ammo.missiles, 6)],
      [Stocked(Ammo.missiles, 24), Overpenetrate()],
    ],
  ),
  EquipmentFamily(
    id: 'teleporter',
    names: ['Teleport Bomb', 'Teleport Barrage', 'Satan\'s Last Stand'],
    cooldown: 24,
    action: TeleportBomb(240),
    price: 60,
    // Already the strongest weapon for its price: its numbers only triple.
    scale: flatScale,
    perks: [
      [Stocked(Ammo.teleportCharges, 1)],
      [Stocked(Ammo.teleportCharges, 3), JamProof()],
    ],
  ),
  EquipmentFamily(
    id: 'shield',
    names: ['Shield Generator', 'Shield Array', 'Barrier Cathedral'],
    cooldown: 6,
    action: ChargeShields(),
    maxShield: 30,
    // Shields grow faster per tier than other cards, so lasers that
    // dominate early hit a wall later on.
    maxShieldTiers: [30, 140, 600],
    perks: [
      [Quicker(20)],
      [Quicker(35), Overflow(40)],
    ],
  ),
  EquipmentFamily(
    id: 'fabricator',
    names: ['Drone Fabricator', 'Drone Foundry', 'Swarm Mother'],
    cooldown: 8,
    action: BuildDrone(),
    maxDrones: 1,
    perks: [
      [DronePatch(1)],
      [DronePatch(2), Stocked(Ammo.droneFeedstock, 16)],
    ],
  ),
  EquipmentFamily(
    id: 'plating',
    names: ['Hull Plating', 'Ablative Plating', 'Triplex Lattice Hull'],
    hull: 100,
    perks: [
      [Armour(4)],
      [Armour(12)],
    ],
  ),
  EquipmentFamily(
    id: 'shield_capacitor',
    names: ['Shield Capacitor', 'Capacitor Ring', 'Halo Reservoir'],
    maxShield: 15,
    boostScope: BoostScope.triangle,
    boostPercents: [20, 30, 40],
    boostOnly: ChargeShields,
    perks: [
      [StartShielded()],
      [StartShielded(), ShieldRegen(6)],
    ],
  ),

  EquipmentFamily(
    id: 'ion',
    names: ['Ion Cannon', 'Ion Driver', 'Storm Engine'],
    cooldown: 4,
    action: IonBlast(45),
    perks: [
      [Quicker(25)],
      [Quicker(25), Overload()],
    ],
  ),
  EquipmentFamily(
    id: 'flak',
    names: ['Flak Battery', 'Flak Curtain', 'Sky Shredder'],
    cooldown: 4,
    action: Flak(1),
    perks: [
      [Quicker(25)],
      [Quicker(25), PierceShields(100)],
    ],
  ),
  EquipmentFamily(
    id: 'repair',
    names: ['Repair Bay', 'Nanite Welders', 'Phoenix Foundry'],
    cooldown: 8,
    action: Repair(30),
    price: 35,
    perks: [
      [Frenzy(10)],
      [Frenzy(40), Quicker(25)],
    ],
  ),
  EquipmentFamily(
    id: 'lance',
    names: ['Plasma Lance', 'Plasma Spear', 'Sunspear'],
    cooldown: 6,
    action: LanceShot(10, 5),
    perks: [
      [Veteran(2)],
      [Veteran(6), PierceShields(25)],
    ],
  ),
  EquipmentFamily(
    id: 'rail',
    names: ['Rail Cannon', 'Rail Driver', 'Mass Accelerator'],
    cooldown: 9,
    action: RailShot(100),
    price: 45,
    perks: [
      [Quicker(20)],
      [Quicker(20), ShieldBreaker()],
    ],
  ),
  EquipmentFamily(
    id: 'jammer',
    names: ['Teleport Jammer', 'Phase Anchor', 'Null Lattice'],
    cooldown: 6,
    action: JamTeleports(1),
    price: 20,
    perks: [
      [Quicker(30)],
      [Quicker(30), Reflect()],
    ],
  ),

  // Synergy ---------------------------------------------------------------
  EquipmentFamily(
    id: 'fire_control',
    names: ['Fire Control', 'Targeting Suite', 'Ternary Fire Director'],
    boostScope: BoostScope.triangle,
    boostPercents: [15, 30, 45],
    perks: [
      [DamageBoost(15)],
      [DamageBoost(40)],
    ],
  ),
  EquipmentFamily(
    id: 'capacitors',
    names: ['Capacitor Bank', 'Overclocked Bus', 'Havi Heart'],
    boostScope: BoostScope.ship,
    boostPercents: [5, 10, 15],
    perks: [
      [Primed(0.15)],
      [Primed(0.35)],
    ],
  ),
  EquipmentFamily(
    id: 'quick_fuzes',
    names: ['Quick-Arm Fuzes', 'Hair Triggers', 'Instant Ordnance'],
    boostScope: BoostScope.triangle,
    boostPercents: [30, 45, 60],
    boostOnly: FireMissile,
    boostMaxDamage: 60,
    perks: [
      [DamageBoost(20, only: FireMissile)],
      [DamageBoost(50, only: FireMissile)],
    ],
  ),

  // Ship systems ----------------------------------------------------------
  EquipmentFamily(
    id: 'cargo_pod',
    names: ['Cargo Pod', 'Cargo Bay', 'Bulk Hold'],
    hold: 3,
    price: 20,
    scale: flatScale,
  ),
  EquipmentFamily(
    id: 'barrier',
    names: ['Barrier Liner', 'Pipe Hugger', 'Demon-Proof Hull'],
    hellShielding: 0.05,
    scale: flatScale,
  ),
  EquipmentFamily(
    id: 'tanks',
    names: ['Drop Tank', 'Fuel Bladder', 'Fuel Rat Special'],
    fuel: 3,
    price: 20,
    scale: flatScale,
  ),

  // The human colony: works only in the colony grid -----------------------
  EquipmentFamily(
    id: 'habitat',
    names: ['Habitat Block', 'Habitat Tower', 'Habitat Arcology'],
    kind: CardKind.colony,
    housing: 100,
    price: 20,
    scale: flatScale,
    perks: [
      [SignOn(10)],
      [SignOn(25)],
    ],
  ),
  EquipmentFamily(
    id: 'hospital',
    names: ['Clinic', 'Human Hospital', 'Hospital Deck'],
    kind: CardKind.colony,
    hospital: 1,
    scale: flatScale,
    perks: [
      [Morale(1)],
      [Morale(3)],
    ],
  ),
  EquipmentFamily(
    id: 'crawlspace',
    names: ['Crawlspace Crews', 'Maintenance Guild', 'Hull Keepers'],
    kind: CardKind.colony,
    crawlspace: 10,
    scale: flatScale,
    perks: [
      [PatchCap(85)],
      [PatchCap(100)],
    ],
  ),
  EquipmentFamily(
    id: 'shop',
    names: ['Corner Shop', 'Market Hall', 'Shopping Deck'],
    kind: CardKind.colony,
    dividend: 1,
    scale: flatScale,
    perks: [
      [FlatIncome(15)],
      [FlatIncome(60)],
    ],
  ),
  EquipmentFamily(
    id: 'casino',
    names: ['Card Room', 'Casino', 'Grand Casino'],
    kind: CardKind.colony,
    dividend: 1,
    gamble: true,
    scale: flatScale,
    perks: [
      [SignOn(5)],
      [SignOn(10), FlatIncome(25)],
    ],
  ),
  EquipmentFamily(
    id: 'brothel',
    names: ['Two-Sided Brothel', 'Two-Sided House', 'Two-Sided Palace'],
    kind: CardKind.colony,
    dividend: 2,
    price: 60,
    scale: flatScale,
    perks: [
      [Morale(1)],
      [Morale(2), SignOn(10)],
    ],
  ),

  // Supplies: work from the hold --------------------------------------------
  EquipmentFamily(
    id: 'missile_crate',
    names: ['Missile Crate', 'Missile Pallet', 'Missile Hold'],
    kind: CardKind.supplies,
    ammo: {Ammo.missiles: 9},
    price: 15,
    // No fight uses more than a few dozen missiles: the merge bonus is in
    // the perks, not the count.
    scale: flatScale,
    perks: [
      [DamageBoost(15, only: FireMissile, scope: BoostScope.ship)],
      [DamageBoost(40, only: FireMissile, scope: BoostScope.ship)],
    ],
  ),
  EquipmentFamily(
    id: 'teleport_charges',
    names: ['Teleport Charges', 'Charge Case', 'Charge Vault'],
    kind: CardKind.supplies,
    ammo: {Ammo.teleportCharges: 2},
    price: 40,
    scale: flatScale,
    perks: [
      [DamageBoost(10, only: TeleportBomb, scope: BoostScope.ship)],
      [DamageBoost(25, only: TeleportBomb, scope: BoostScope.ship)],
    ],
  ),
  EquipmentFamily(
    id: 'feedstock',
    names: ['Drone Feedstock', 'Feedstock Drum', 'Feedstock Silo'],
    kind: CardKind.supplies,
    ammo: {Ammo.droneFeedstock: 9},
    price: 15,
    scale: flatScale,
    perks: [
      [StartDrones(3)],
      [StartDrones(9), DronePatch(1)],
    ],
  ),
];

/// Cards made in Hell. Never sold at a station: they come from demon
/// wrecks and Hell's own events. Stronger for their price than anything
/// sold at a station, since getting them means going to Hell.
const hellFamilies = [
  EquipmentFamily(
    id: 'brimstone',
    names: ['Brandy Burner', 'Brimstone Projector', 'Hellmouth Cannon'],
    cooldown: 5,
    action: Hellfire(32),
    price: 45,
    tags: {CardTag.hellish},
    perks: [
      [Insulated(50)],
      [Insulated(100)],
    ],
  ),
  EquipmentFamily(
    id: 'teeth',
    names: ['Loose Teeth', 'Tooth Lattice', 'The Chewer\'s Grin'],
    cooldown: 2.5,
    action: FireLaser(18),
    price: 35,
    tags: {CardTag.hellish},
    perks: [
      [Frenzy(2)],
      [Frenzy(6), Veteran(1)],
    ],
  ),
  EquipmentFamily(
    id: 'brandy_mist',
    names: ['Brandy Mist', 'Fume Bank', 'The Drowning Sea'],
    cooldown: 6,
    action: ChargeShields(),
    maxShield: 50,
    maxShieldTiers: [50, 230, 1000],
    price: 40,
    tags: {CardTag.hellish},
    perks: [
      [ShieldRegen(4)],
      [ShieldRegen(15)],
    ],
  ),
  EquipmentFamily(
    id: 'metal_flesh',
    names: ['Metal Flesh Graft', 'Living Hull', 'Behemoth Hide'],
    hull: 180,
    price: 40,
    tags: {CardTag.hellish},
    perks: [
      [HullRegen(3)],
      [HullRegen(10)],
    ],
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
    price: 15,
    text: 'Cheap, until somewhere runs out of it.',
  ),
  Equipment(
    id: 'goods_ice',
    name: 'Water Ice',
    family: 'goods_ice',
    tier: Tier.basic,
    kind: CardKind.commodity,
    price: 12,
    text: 'Worth its weight in credits wherever the taps have run dry.',
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

/// Hell's great prize: from the Mourner, or found ticking in the murk.
/// One per brawl.
const hellClock = Equipment(
  id: 'hell_clock',
  name: 'Hell Clock',
  family: 'hell_clock',
  tier: Tier.unique,
  boost: ChargeBoost(BoostScope.ship, 30),
  headStart: 0.5,
  awakens: CardTag.hellish,
  tags: {CardTag.hellish},
  price: 400,
  text:
      'A brass clock ticking backwards, set into a greasy black stone ball '
      'with a tiny black hole at its heart. Everything happens a little '
      'before it should.',
);

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
  hellClock,
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

/// Trophies taken from the elites that only events send against a brawl
/// captain, one elite for each stage of the game.
const eliteTrophies = [
  Equipment(
    id: 'trophy_last_vote',
    name: 'The Last Vote\'s Battery',
    family: 'trophy_last_vote',
    tier: Tier.unique,
    cooldown: 3,
    action: FireMissile(45),
    ammo: {Ammo.missiles: 12},
    price: 150,
    text: 'Fires twice as fast as a Missile Rack and brings its own missiles.',
  ),
  Equipment(
    id: 'trophy_champions_bulwark',
    name: 'Champion\'s Bulwark',
    family: 'trophy_champions_bulwark',
    tier: Tier.unique,
    cooldown: 6,
    action: ChargeShields(),
    maxShield: 75,
    hull: 200,
    price: 250,
    text: 'A Gor duelling shield, and the armour plate it hangs from.',
  ),
  Equipment(
    id: 'trophy_nanoforge',
    name: 'Unmerged Nanoforge',
    family: 'trophy_nanoforge',
    tier: Tier.unique,
    cooldown: 6,
    action: BuildDrone(3),
    maxDrones: 6,
    ammo: {Ammo.droneFeedstock: 18},
    price: 400,
    text:
        'Tern nanobots that no longer answer to anyone. They build, and feed themselves.',
  ),
];

/// The trophy for beating Satan at the end of a brawl.
const satanTrophy = Equipment(
  id: 'trophy_broken_seal',
  name: 'The Broken Seal',
  family: 'trophy_broken_seal',
  tier: Tier.unique,
  cooldown: 3,
  action: Hellfire(240),
  hull: 300,
  price: 600,
  tags: {CardTag.hellish},
  text:
      'The seal Satan broke at Kyndari to start the gatecrash, rebuilt into '
      'a gun. He wants it back.',
);

/// Nobody's only weapon. Never salvaged: nobody else could use it.
const boardingTeleporter = Equipment(
  id: 'nobody_boarding_teleporter',
  name: 'Boarding Teleporter',
  family: 'nobody_boarding_teleporter',
  tier: Tier.unique,
  cooldown: 40,
  action: Board(),
  text: 'It takes a long time to charge. It only has to carry one man.',
);

final equipmentCatalog = <String, Equipment>{
  for (final family in equipmentFamilies)
    for (final e in family.tiers) e.id: e,
  for (final e in commodities) e.id: e,
  for (final e in missionCargo) e.id: e,
  for (final e in mournerCards) e.id: e,
  for (final e in eliteTrophies) e.id: e,
  satanTrophy.id: satanTrophy,
  boardingTeleporter.id: boardingTeleporter,
  for (final family in hellFamilies)
    for (final e in family.tiers) e.id: e,
};

final _variants = <String, Equipment>{};

/// A card by id. Ids with tags after [tagSeparator] are tagged copies, and
/// ids with a number after [growthSeparator] have grown in fights.
Equipment equipmentById(String id) {
  if (id.contains(tagSeparator) || id.contains(growthSeparator)) {
    return _variants[id] ??= () {
      final card = equipmentById(baseId(id));
      final tags = addedTags(id);
      final tagged = tags.isEmpty ? card : card.withTags(tags, id);
      final grown = grownBy(id);
      return grown == 0 ? tagged : tagged.withGrowth(grown, id);
    }();
  }
  return equipmentCatalog[id] ?? (throw ArgumentError('Unknown equipment $id'));
}

/// The id without its growth.
String _ungrown(String id) => id.split(growthSeparator).first;

/// The id without any tags the card has picked up, or growth.
String baseId(String id) => _ungrown(id).split(tagSeparator).first;

/// Tags a card has picked up, beyond the ones it was made with.
Set<CardTag> addedTags(String id) => {
  for (final name in _ungrown(id).split(tagSeparator).skip(1))
    CardTag.values.byName(name),
};

/// Damage a card has gained for good in fights. See [Veteran].
int grownBy(String id) {
  final parts = id.split(growthSeparator);
  return parts.length < 2 ? 0 : int.parse(parts[1]);
}

/// The id of [id] after gaining [extra] damage for good.
String grownId(String id, int extra) {
  final total = grownBy(id) + extra;
  return total == 0 ? _ungrown(id) : '${_ungrown(id)}$growthSeparator$total';
}

/// The id of [id] with [tags] added. Tags the card was made with aren't
/// written into the id. Growth is kept.
String taggedId(String id, Set<CardTag> tags) {
  final added = {...addedTags(id), ...tags}
    ..removeAll(equipmentById(baseId(id)).tags);
  final tagged = [
    baseId(id),
    for (final tag in CardTag.values)
      if (added.contains(tag)) tag.name,
  ].join(tagSeparator);
  return grownId(tagged, grownBy(id));
}

/// The upgraded version of a card, if it has one.
Equipment? upgradeOf(Equipment e) {
  final next = e.tier.next;
  return next == null || !e.merges
      ? null
      : equipmentCatalog['${e.family}_${next.index + 1}'];
}

/// Every tier of [card]'s family, basic first, with [card] itself at its
/// own tier; just [card] if it has no tiers (commodities, mission cargo,
/// unique cards).
List<Equipment> tiersOf(Equipment card) {
  if (card.tier == Tier.unique ||
      card.kind == CardKind.commodity ||
      card.kind == CardKind.mission) {
    return [card];
  }
  final tiers = [
    for (var t = 1; t <= 3; t++) equipmentCatalog['${card.family}_$t'],
  ];
  if (tiers.contains(null)) return [card];
  return [
    for (final (i, tier) in tiers.indexed) i == card.tier.index ? card : tier!,
  ];
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
