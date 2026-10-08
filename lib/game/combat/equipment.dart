/// A label on a card that other cards can look for. The Cursed Orb, say,
/// wakes every other card tagged Hellish.
enum CardTag {
  hellish('Hellish');

  const CardTag(this.label);
  final String label;
}

/// Separates the tags a card has picked up from its id: `laser_1#hellish`
/// is a Laser that has been tagged Hellish.
const tagSeparator = '#';

/// What a piece of equipment does each time its timer runs out.
sealed class Action {
  const Action();
}

/// Blocked by shields. Needs no ammo.
class FireLaser extends Action {
  const FireLaser(this.damage);
  final int damage;
}

/// Passes through shields. Each drone stops one. Uses one missile.
class FireMissile extends Action {
  const FireMissile(this.damage);
  final int damage;
}

/// Passes through shields and drones. Uses one teleport charge.
class TeleportBomb extends Action {
  const TeleportBomb(this.damage);
  final int damage;
}

/// Hell's own weapons. Passes through shields and drones and needs no
/// ammo, but every shot burns the ship that fires it for a quarter of the
/// damage.
class Hellfire extends Action {
  const Hellfire(this.damage);
  final int damage;

  int get recoil => damage ~/ 4;
}

/// Refills shields to the ship's maximum.
class ChargeShields extends Action {
  const ChargeShields();
}

/// Hull each drone out repairs per second of a fight.
const droneRepair = 1;

/// Builds one drone, up to the ship's maximum. Uses one unit of feedstock.
class BuildDrone extends Action {
  const BuildDrone([this.count = 1]);

  /// Drones built per activation, each using one unit of feedstock. Like
  /// damage, this triples per tier, so merging three fabricators keeps
  /// their output.
  final int count;
}

enum Ammo {
  missiles('missiles'),
  teleportCharges('teleport charges'),
  droneFeedstock('drone feedstock');

  const Ammo(this.label);
  final String label;
}

enum BoostScope {
  /// The other cards in the same small triangle.
  triangle,

  /// Every other card on the ship.
  ship,
}

/// Makes other equipment charge faster.
class ChargeBoost {
  const ChargeBoost(this.scope, this.percent, {this.only, this.maxDamage});
  final BoostScope scope;

  /// Cooldown reduction, in percent.
  final int percent;

  /// If set, only equipment whose action is this type.
  final Type? only;

  /// If set, only weapons dealing at most this much damage: small missiles
  /// arm faster than big ones.
  final int? maxDamage;
}

enum Tier {
  basic('Basic'),
  upgraded('Upgraded'),
  superior('Super'),

  /// One of a kind. Never merges.
  unique('Unique');

  const Tier(this.label);
  final String label;

  Tier? get next => switch (this) {
    basic => upgraded,
    upgraded => superior,
    _ => null,
  };
}

/// What kind of card this is, which decides where it works.
enum CardKind {
  /// Works only in a slot.
  equipment,

  /// Ammunition or materials. Works from a slot or the hold.
  supplies,

  /// Trade goods. Do nothing; worth money at the right market.
  commodity,

  /// Something you've been paid to carry somewhere. Can't be sold.
  mission,
}

/// A card: equipment, supplies or a commodity.
class Equipment {
  const Equipment({
    required this.id,
    required this.name,
    required this.family,
    required this.tier,
    this.kind = CardKind.equipment,
    this.cooldown,
    this.action,
    this.hull = 0,
    this.maxShield = 0,
    this.maxDrones = 0,
    this.ammo = const {},
    this.boost,
    this.berths = 0,
    this.hospital = 0,
    this.hellShielding = 0,
    this.fuel = 0,
    this.hold = 0,
    this.price = 0,
    this.text = '',
    this.tags = const {},
    this.awakens,
    this.headStart = 0,
    this.grantsTag,
    this.shopOdds = 1,
  });

  final String id;
  final String name;
  final String family;
  final Tier tier;
  final CardKind kind;

  /// Seconds between activations. Null for passive equipment.
  final double? cooldown;
  final Action? action;

  final int hull;
  final int maxShield;
  final int maxDrones;

  /// Ammunition this card carries into each fight.
  final Map<Ammo, int> ammo;
  final ChargeBoost? boost;

  /// Human berths. Accommodation cards: remove them all and the humans go.
  final int berths;

  /// Each level saves one human from every loss, and slowly raises loyalty.
  final int hospital;

  /// Lowers the odds of falling into Hell and the damage taken there.
  final double hellShielding;
  final int fuel;

  /// Cargo hold spaces. Ships have none without cargo pods.
  final int hold;

  /// Base price in credits. Equipment sells for half.
  final int price;

  /// Flavour, or rules that aren't modelled yet.
  final String text;

  /// Labels other cards can look for, like [CardTag.hellish].
  final Set<CardTag> tags;

  /// At the start of every fight, every other card with this tag fires
  /// once.
  final CardTag? awakens;

  /// Every card on the ship starts each fight this far charged, 0 to 1.
  final double headStart;

  /// Can be used up to give another card this tag.
  final CardTag? grantsTag;

  /// How likely a shop is to stock this commodity, relative to the others.
  final double shopOdds;

  bool has(CardTag tag) => tags.contains(tag);

  /// This card with [extra] tags as well, under the id [taggedId].
  Equipment withTags(Set<CardTag> extra, String taggedId) => Equipment(
    id: taggedId,
    name: name,
    family: family,
    tier: tier,
    kind: kind,
    cooldown: cooldown,
    action: action,
    hull: hull,
    maxShield: maxShield,
    maxDrones: maxDrones,
    ammo: ammo,
    boost: boost,
    berths: berths,
    hospital: hospital,
    hellShielding: hellShielding,
    fuel: fuel,
    hold: hold,
    price: price,
    text: text,
    tags: {...tags, ...extra},
    awakens: awakens,
    headStart: headStart,
    grantsTag: grantsTag,
    shopOdds: shopOdds,
  );

  /// Whether [tag] can be given to this card: only equipment and supplies
  /// take tags, and only once.
  bool canTake(CardTag tag) =>
      !has(tag) && (kind == CardKind.equipment || kind == CardKind.supplies);

  bool get merges =>
      tier.next != null &&
      kind != CardKind.commodity &&
      kind != CardKind.mission;

  int? get damage => switch (action) {
    FireLaser(:final damage) ||
    FireMissile(:final damage) ||
    TeleportBomb(:final damage) ||
    Hellfire(:final damage) => damage,
    _ => null,
  };

  /// What this card does, one line per effect, for the UI.
  List<String> describe() {
    final every = cooldown == null ? '' : ' every ${_secs(cooldown!)}';
    return [
      switch (action) {
        FireLaser(:final damage) => 'Laser: $damage damage$every',
        FireMissile(:final damage) => 'Missile: $damage damage$every',
        TeleportBomb(:final damage) => 'Teleport bomb: $damage damage$every',
        Hellfire(:final damage, :final recoil) =>
          'Hellfire: $damage damage$every, through shields and drones. '
              'Burns your own hull for $recoil',
        ChargeShields() => 'Charges shields$every',
        BuildDrone(count: 1) => 'Builds a drone$every',
        BuildDrone(:final count) => 'Builds $count drones$every',
        null => '',
      },
      if (hull != 0) '+$hull hull',
      if (maxShield != 0) '+$maxShield max shield',
      if (maxDrones != 0) '+$maxDrones max drones',
      if (action is BuildDrone)
        'Each drone out repairs $droneRepair hull a second',
      for (final e in ammo.entries) '${e.value} ${e.key.label} per fight',
      if (boost case final b?)
        '${switch (b.only) {
              const (FireMissile) => 'Missiles',
              const (ChargeShields) => 'Shield generators',
              _ => b.scope == BoostScope.triangle ? 'Cards' : 'Every other card',
            }}'
            '${b.maxDamage != null ? ' of ${b.maxDamage} damage or less' : ''}'
            '${b.scope == BoostScope.triangle ? ' in this triangle' : ''}'
            ' charge ${b.percent}% faster',
      if (berths != 0) '+$berths human berths',
      if (hospital != 0) '+$hospital hospital',
      if (hellShielding != 0)
        '+${(hellShielding * 100).round()}% Hell shielding',
      if (fuel != 0) '+$fuel fuel capacity',
      if (hold != 0) '+$hold cargo hold',
      if (headStart != 0)
        'Every card starts each fight ${(headStart * 100).round()}% charged',
      if (awakens case final tag?)
        'At the start of each fight, every other ${tag.label} card fires '
            'once',
      if (grantsTag case final tag?)
        'Use it on a card to tag that card ${tag.label}. Used up',
    ].where((line) => line.isNotEmpty).toList();
  }

  static String _secs(double s) =>
      s == s.roundToDouble() ? '${s.round()} s' : '$s s';
}

/// A line of equipment in three tiers. Each tier is worth exactly three of
/// the tier below, so merging frees slots rather than adding power.
class EquipmentFamily {
  const EquipmentFamily({
    required this.id,
    required this.names,
    this.kind = CardKind.equipment,
    this.cooldown,
    this.action,
    this.hull = 0,
    this.maxShield = 0,
    this.maxDrones = 0,
    this.ammo = const {},
    this.boostPercents,
    this.boostScope,
    this.boostOnly,
    this.boostMaxDamage,
    this.berths = 0,
    this.hospital = 0,
    this.hellShielding = 0,
    this.fuel = 0,
    this.hold = 0,
    this.price = 30,
    this.tags = const {},
    this.maxShieldTiers,
  });

  final String id;
  final List<String> names;
  final CardKind kind;
  final double? cooldown;

  /// The basic tier's action. Damage scales ×3 per tier.
  final Action? action;
  final int hull;
  final int maxShield;
  final int maxDrones;
  final Map<Ammo, int> ammo;

  /// Charge boosts don't triple per tier; they get their own list.
  final List<int>? boostPercents;
  final BoostScope? boostScope;
  final Type? boostOnly;
  final int? boostMaxDamage;
  final int berths;
  final int hospital;
  final double hellShielding;
  final int fuel;
  final int hold;
  final int price;
  final Set<CardTag> tags;

  /// Max shield per tier, where it doesn't simply triple.
  final List<int>? maxShieldTiers;

  List<Equipment> get tiers => [
    for (final tier in [Tier.basic, Tier.upgraded, Tier.superior])
      _at(tier, [1, 3, 9][tier.index]),
  ];

  Equipment _at(Tier tier, int x) => Equipment(
    id: '${id}_${tier.index + 1}',
    name: names[tier.index],
    family: id,
    tier: tier,
    kind: kind,
    cooldown: cooldown,
    action: switch (action) {
      FireLaser(:final damage) => FireLaser(damage * x),
      FireMissile(:final damage) => FireMissile(damage * x),
      TeleportBomb(:final damage) => TeleportBomb(damage * x),
      Hellfire(:final damage) => Hellfire(damage * x),
      BuildDrone(:final count) => BuildDrone(count * x),
      final other => other,
    },
    hull: hull * x,
    maxShield: maxShieldTiers?[tier.index] ?? maxShield * x,
    maxDrones: maxDrones * x,
    ammo: {for (final e in ammo.entries) e.key: e.value * x},
    boost: boostPercents == null
        ? null
        : ChargeBoost(
            boostScope!,
            boostPercents![tier.index],
            only: boostOnly,
            maxDamage: boostMaxDamage == null ? null : boostMaxDamage! * x,
          ),
    berths: berths * x,
    hospital: hospital * x,
    hellShielding: hellShielding * x,
    fuel: fuel * x,
    hold: hold * x,
    price: price * x,
    tags: tags,
  );
}
