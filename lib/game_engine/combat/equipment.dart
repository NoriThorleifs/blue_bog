import 'dart:math';

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

/// Separates the damage a card has gained for good from the rest of its id:
/// `laser_3#hellish+42` hits 42 harder than a fresh Tern Choir Lance. See
/// [Veteran].
const growthSeparator = '+';

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
/// damage, less its [insulation] in percent.
class Hellfire extends Action {
  const Hellfire(this.damage, {this.insulation = 0});
  final int damage;
  final int insulation;

  int get recoil => recoilFor(damage);

  /// What a shot of [hit] damage burns its own ship for.
  int recoilFor(int hit) => hit ~/ 4 * (100 - insulation) ~/ 100;
}

/// Strips up to [damage] from the enemy's shields. Whatever the shields
/// don't take hits the hull at a third.
class IonBlast extends Action {
  const IonBlast(this.damage);
  final int damage;
}

/// Shoots down up to [count] enemy drones. Rounds with no drone to hit
/// burst against the hull for [shrapnel] each, which shields block.
class Flak extends Action {
  const Flak(this.count, {this.shrapnel = 10});
  final int count;
  final int shrapnel;
}

/// Patches [amount] of the ship's own hull, up to its maximum.
class Repair extends Action {
  const Repair(this.amount);
  final int amount;
}

/// A laser that hits [ramp] harder with every shot it has fired this
/// fight. Blocked by shields.
class LanceShot extends Action {
  const LanceShot(this.damage, this.ramp);
  final int damage;
  final int ramp;
}

/// Readies the ship's teleport jammers: each jam stops one incoming
/// teleport bomb. Like shields, it refills to the ship's maximum, which
/// is [count] from every jammer aboard.
class JamTeleports extends Action {
  const JamTeleports(this.count);
  final int count;
}

/// A rail slug: massive damage, but any charge at all in the enemy's
/// shields deflects it entirely, leaving the shields untouched.
class RailShot extends Action {
  const RailShot(this.damage);
  final int damage;
}

/// Teleports a boarder onto the enemy ship. Nothing stops it, and
/// nothing aboard survives it: the enemy is lost outright.
class Board extends Action {
  const Board();
}

/// Refills shields to the ship's maximum.
class ChargeShields extends Action {
  const ChargeShields();
}

/// Hull each drone out repairs per second of a fight.
const droneRepair = 1;

/// [p] without a trailing ".0".
String _percent(double p) =>
    p == p.roundToDouble() ? '${p.round()}' : p.toStringAsFixed(1);

/// Births a colony has without hospitals, in percent of the colony.
const baseBirths = 1.0;

/// Extra births each hospital level adds, in percent of the colony:
/// healthier babies, more of whom grow up.
const birthsPerHospital = 0.5;

/// The most a colony's hospitals add to its births, in percent.
const maxHospitalBirths = 4.0;

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

/// A bonus a card gains when three copies merge into it, on top of its
/// bigger numbers. Every family has its own, and its super card's are
/// stronger than its upgraded card's. Shops only sell basic cards, so these
/// are earned by merging, or taken from a wreck.
sealed class Perk {
  const Perk();

  /// What it does, for the card's details. [action] is the card's own.
  String describe(Action? action);
}

/// Charges [percent] faster. Built into the card's cooldown.
class Quicker extends Perk {
  const Quicker(this.percent);
  final int percent;

  @override
  String describe(Action? action) => 'Charges $percent% faster';
}

/// Hits [perShot] harder with every shot it has fired this fight, or for a
/// repair bay, patches [perShot] more each time.
class Frenzy extends Perk {
  const Frenzy(this.perShot);
  final int perShot;

  @override
  String describe(Action? action) => action is Repair
      ? 'Patches $perShot more every time it works this fight'
      : 'Hits $perShot harder with every shot this fight';
}

/// Hits [perShot] harder with every shot it fires, and keeps what it gains:
/// the growth is written into the card's id after each fight (see
/// [growthSeparator]) and survives merging.
class Veteran extends Perk {
  const Veteran(this.perShot);
  final int perShot;

  @override
  String describe(Action? action) =>
      'Gains $perShot damage for good with every shot';
}

/// Brings [count] of its own [ammo] to every fight. Built into the card's
/// ammo.
class Stocked extends Perk {
  const Stocked(this.ammo, this.count);
  final Ammo ammo;
  final int count;

  @override
  String describe(Action? action) =>
      'Brings $count of its own ${ammo.label} to every fight';
}

/// A missile a drone stops still hits the hull for half.
class Overpenetrate extends Perk {
  const Overpenetrate();

  @override
  String describe(Action? action) =>
      'A missile a drone stops still hits for half';
}

/// Its teleport bombs can't be jammed.
class JamProof extends Perk {
  const JamProof();

  @override
  String describe(Action? action) => 'Its bombs can\'t be jammed';
}

/// When it charges shields that are already full, it patches [amount] hull
/// instead.
class Overflow extends Perk {
  const Overflow(this.amount);
  final int amount;

  @override
  String describe(Action? action) =>
      'Charging full shields patches $amount hull instead';
}

/// Each drone out repairs [extra] more hull a second.
class DronePatch extends Perk {
  const DronePatch(this.extra);
  final int extra;

  @override
  String describe(Action? action) =>
      'Every drone out repairs $extra more hull a second';
}

/// Every hit on the hull is [amount] weaker, but never less than half.
/// Armour from every card aboard adds up.
class Armour extends Perk {
  const Armour(this.amount);
  final int amount;

  @override
  String describe(Action? action) =>
      'Armour: every hit on the hull is $amount weaker, down to half';
}

/// The ship's shields start every fight full.
class StartShielded extends Perk {
  const StartShielded();

  @override
  String describe(Action? action) => 'Shields start every fight full';
}

/// Shields regenerate [perSecond] a second, up to their maximum.
class ShieldRegen extends Perk {
  const ShieldRegen(this.perSecond);
  final int perSecond;

  @override
  String describe(Action? action) => 'Shields regenerate $perSecond a second';
}

/// The ship repairs [perSecond] hull a second.
class HullRegen extends Perk {
  const HullRegen(this.perSecond);
  final int perSecond;

  @override
  String describe(Action? action) => 'Regrows $perSecond hull a second';
}

/// An ion blast's leftover hits the hull in full, not at a third.
class Overload extends Perk {
  const Overload();

  @override
  String describe(Action? action) =>
      'Leftover ion damage hits the hull in full';
}

/// [percent] of each shot passes the enemy's shields.
class PierceShields extends Perk {
  const PierceShields(this.percent);
  final int percent;

  @override
  String describe(Action? action) => percent >= 100
      ? 'Passes shields'
      : '$percent% of every shot passes shields';
}

/// A rail slug that glances off the shields knocks them out.
class ShieldBreaker extends Perk {
  const ShieldBreaker();

  @override
  String describe(Action? action) =>
      'A deflected slug knocks the enemy\'s shields out';
}

/// Teleport bombs jammed aboard this ship go off aboard the ship that sent
/// them.
class Reflect extends Perk {
  const Reflect();

  @override
  String describe(Action? action) =>
      'Jammed bombs go off aboard the ship that sent them';
}

/// Weapons in the same triangle hit [percent] harder; only those whose
/// action is [only], if set.
class DamageBoost extends Perk {
  const DamageBoost(
    this.percent, {
    this.only,
    this.scope = BoostScope.triangle,
  });
  final int percent;
  final Type? only;

  /// The cards in the same triangle, or every weapon aboard. A ship-wide
  /// boost on supplies works from the hold too.
  final BoostScope scope;

  @override
  String describe(Action? action) {
    final what = switch (only) {
      const (FireMissile) => 'Missiles',
      const (TeleportBomb) => 'Teleport bombs',
      _ => 'Weapons',
    };
    return scope == BoostScope.triangle
        ? '$what in this triangle hit $percent% harder'
        : '$what you fire hit $percent% harder';
  }
}

/// The ship starts every fight with [count] drones out, if it has room for
/// them, built in port without using any feedstock.
class StartDrones extends Perk {
  const StartDrones(this.count);
  final int count;

  @override
  String describe(Action? action) =>
      '$count drones are out when a fight starts, if there\'s room';
}

/// Every card on the ship starts each fight [fraction] charged. Built into
/// [Equipment.headStart].
class Primed extends Perk {
  const Primed(this.fraction);
  final double fraction;

  @override
  String describe(Action? action) =>
      'Every card starts each fight ${(fraction * 100).round()}% charged';
}

/// Hellfire that burns its own ship [percent] less. Built into the card's
/// [Hellfire].
class Insulated extends Perk {
  const Insulated(this.percent);
  final int percent;

  @override
  String describe(Action? action) => percent >= 100
      ? 'No longer burns your own hull'
      : 'Burns your own hull $percent% less';
}

/// At each station, [percent] more of the colony's free housing fills with
/// humans signing on (a third as much where humans don't live).
class SignOn extends Perk {
  const SignOn(this.percent);
  final int percent;

  @override
  String describe(Action? action) =>
      'More humans sign on at stations: +$percent% of the free housing';
}

/// The colony's loyalty rises by [amount] every time the ship docks.
class Morale extends Perk {
  const Morale(this.amount);
  final int amount;

  @override
  String describe(Action? action) => '+$amount loyalty every time you dock';
}

/// The humans patch the hull up to [percent] of its maximum, not the usual
/// 75%. The best one aboard counts.
class PatchCap extends Perk {
  const PatchCap(this.percent);
  final int percent;

  @override
  String describe(Action? action) =>
      'Your humans patch the hull up to $percent%, not 75%';
}

/// Pays [credits] on docking at a station, however few humans are aboard.
class FlatIncome extends Perk {
  const FlatIncome(this.credits);
  final int credits;

  @override
  String describe(Action? action) =>
      'Pays $credits cr on docking at a station, however few humans';
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

  /// Part of the human colony. Works only in the colony grid, never in a
  /// fight.
  colony,
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
    this.housing = 0,
    this.hospital = 0,
    this.crawlspace = 0,
    this.dividend = 0,
    this.gamble = false,
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
    this.perks = const [],
    this.grown = 0,
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

  /// Humans the colony has room for. Take housing away and the humans
  /// without a home leave.
  final int housing;

  /// Each level adds [birthsPerHospital] to the colony's births, up to
  /// [maxHospitalBirths]. In story mode it also slowly raises loyalty.
  final int hospital;

  /// Hull the humans in the walls patch every turn.
  final int crawlspace;

  /// Credits per hundred humans aboard, paid on docking at a station.
  final int dividend;

  /// Whether the [dividend] is a gamble: anywhere from nothing to three
  /// times as much.
  final bool gamble;

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

  /// Bonuses from merging, beyond the bigger numbers. See [Perk].
  final List<Perk> perks;

  /// Damage gained for good in fights, already counted in [action]. See
  /// [Veteran].
  final int grown;

  bool has(CardTag tag) => tags.contains(tag);

  /// The first perk of type [T], if the card has one.
  T? perk<T extends Perk>() => perks.whereType<T>().firstOrNull;

  /// A cargo pod: it goes in the cargo bay slot, and only works there.
  bool get isCargoBay => hold > 0;

  /// This card with [extra] tags as well, under the id [taggedId].
  Equipment withTags(Set<CardTag> extra, String taggedId) =>
      _copy(id: taggedId, tags: {...tags, ...extra});

  /// This card after gaining [extra] damage for good in fights, under the
  /// id [grownId].
  Equipment withGrowth(int extra, String grownId) => _copy(
    id: grownId,
    action: action == null ? null : plusDamage(action!, extra),
    grown: grown + extra,
  );

  Equipment _copy({
    required String id,
    Set<CardTag>? tags,
    Action? action,
    int? grown,
  }) => Equipment(
    id: id,
    name: name,
    family: family,
    tier: tier,
    kind: kind,
    cooldown: cooldown,
    action: action ?? this.action,
    hull: hull,
    maxShield: maxShield,
    maxDrones: maxDrones,
    ammo: ammo,
    boost: boost,
    housing: housing,
    hospital: hospital,
    crawlspace: crawlspace,
    dividend: dividend,
    gamble: gamble,
    hellShielding: hellShielding,
    fuel: fuel,
    hold: hold,
    price: price,
    text: text,
    tags: tags ?? this.tags,
    awakens: awakens,
    headStart: headStart,
    grantsTag: grantsTag,
    shopOdds: shopOdds,
    perks: perks,
    grown: grown ?? this.grown,
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
    Hellfire(:final damage) ||
    IonBlast(:final damage) ||
    LanceShot(:final damage) ||
    RailShot(:final damage) => damage,
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
        Board() => 'Boards the enemy$every. Nobody aboard survives it',
        IonBlast(:final damage) =>
          'Ion blast$every: strips $damage shield. Leftover hits the hull '
              '${perk<Overload>() == null ? 'at a third' : 'in full'}',
        Flak(count: 1, :final shrapnel) =>
          'Flak$every: shoots down a drone, or $shrapnel shrapnel damage',
        Flak(:final count, :final shrapnel) =>
          'Flak$every: shoots down $count drones, each miss $shrapnel '
              'shrapnel damage',
        Repair(:final amount) => 'Repairs $amount hull$every',
        RailShot(:final damage) =>
          'Rail slug: $damage damage$every. Any shield at all deflects it',
        LanceShot(:final damage, :final ramp) =>
          'Lance: $damage damage$every, $ramp more each shot',
        JamTeleports(count: 1) => 'Readies a teleport jam$every',
        JamTeleports(:final count) => 'Readies $count teleport jams$every',
        null => '',
      },
      if (hull != 0) '+$hull hull',
      if (maxShield != 0) '+$maxShield max shield',
      if (maxDrones != 0) '+$maxDrones max drones',
      if (action is BuildDrone)
        'Each drone out repairs $droneRepair hull a second',
      if (grown != 0) '+$grown damage earned in fights, for good',
      // Ammo a perk brings, and a perk's head start, are its own lines.
      for (final e in ammo.entries)
        if (!perks.any((p) => p is Stocked && p.ammo == e.key))
          '${e.value} ${e.key.label} per fight',
      if (boost case final b?)
        '${switch (b.only) {
              const (FireMissile) => 'Missiles',
              const (ChargeShields) => 'Shield generators',
              _ => b.scope == BoostScope.triangle ? 'Cards' : 'Every other card',
            }}'
            '${b.maxDamage != null ? ' of ${b.maxDamage} damage or less' : ''}'
            '${b.scope == BoostScope.triangle ? ' in this triangle' : ''}'
            ' charge ${b.percent}% faster',
      if (housing != 0) 'Houses $housing humans',
      if (hospital != 0)
        'More babies born and grown: +${_percent(min(hospital * birthsPerHospital, maxHospitalBirths))}% '
            'of the colony',
      if (crawlspace != 0) 'Patches $crawlspace hull a turn',
      if (dividend != 0)
        gamble
            ? 'Pays 0 to ${dividend * 3} cr per 100 humans on docking at a '
                  'station'
            : 'Pays $dividend cr per 100 humans on docking at a station',
      if (hellShielding != 0)
        '+${(hellShielding * 100).round()}% Hell shielding',
      if (fuel != 0) '+$fuel fuel capacity',
      if (hold != 0) '+$hold cargo hold',
      if (headStart != 0 && perk<Primed>() == null)
        'Every card starts each fight ${(headStart * 100).round()}% charged',
      if (awakens case final tag?)
        'At the start of each fight, every other ${tag.label} card fires '
            'once',
      if (grantsTag case final tag?)
        'Use it on a card to tag that card ${tag.label}. Used up',
    ].where((line) => line.isNotEmpty).toList();
  }

  /// What the card gained from merging, one line per perk. See [Perk].
  List<String> describePerks() => [for (final p in perks) p.describe(action)];

  static String _secs(double s) =>
      s == s.roundToDouble() ? '${s.round()} s' : '$s s';
}

/// How much bigger a card's numbers are at each tier: an upgraded card
/// has four times a basic card's damage, hull or ammo, a super card
/// sixteen times, so merging three cards is worth more than the three.
const mergeScale = [1, 4, 16];

/// The tier scale for cards whose numbers would break the economy if they
/// grew faster than the cards merged into them (the colony, the cargo
/// hold), or that no fight could use more of (supplies). Their merge bonus
/// is all in their [EquipmentFamily.perks].
const flatScale = [1, 3, 9];

/// A line of equipment in three tiers. Shops sell only the basic tier, so
/// the others come from merging three of the tier below, or from wrecks.
/// Each tier is stronger than the three cards merged into it: its numbers
/// grow by [scale], and it gains [perks].
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
    this.housing = 0,
    this.hospital = 0,
    this.crawlspace = 0,
    this.dividend = 0,
    this.gamble = false,
    this.hellShielding = 0,
    this.fuel = 0,
    this.hold = 0,
    this.price = 30,
    this.tags = const {},
    this.maxShieldTiers,
    this.scale = mergeScale,
    this.perks = const [[], []],
  });

  final String id;
  final List<String> names;
  final CardKind kind;
  final double? cooldown;

  /// The basic tier's action. Its numbers grow by [scale].
  final Action? action;
  final int hull;
  final int maxShield;
  final int maxDrones;
  final Map<Ammo, int> ammo;

  /// Charge boosts don't grow by [scale]; they get their own list.
  final List<int>? boostPercents;
  final BoostScope? boostScope;
  final Type? boostOnly;
  final int? boostMaxDamage;
  final int housing;
  final int hospital;
  final int crawlspace;
  final int dividend;
  final bool gamble;
  final double hellShielding;
  final int fuel;
  final int hold;

  /// The basic card's price. Higher tiers cost what the cards merged into
  /// them did: three or nine times as much.
  final int price;
  final Set<CardTag> tags;

  /// Max shield per tier, where it doesn't simply follow [scale].
  final List<int>? maxShieldTiers;

  /// How much the numbers grow at each tier: [mergeScale] or [flatScale].
  final List<int> scale;

  /// What the upgraded card and the super card gain from merging, beyond
  /// their numbers. The super card's list is complete, not added to the
  /// upgraded card's.
  final List<List<Perk>> perks;

  List<Equipment> get tiers => [
    for (final tier in [Tier.basic, Tier.upgraded, Tier.superior]) _at(tier),
  ];

  Equipment _at(Tier tier) {
    final x = scale[tier.index];
    final gained = tier == Tier.basic ? const <Perk>[] : perks[tier.index - 1];
    final faster = gained.whereType<Quicker>().fold(0, (t, p) => t + p.percent);
    final insulation = gained.whereType<Insulated>().fold(
      0,
      (t, p) => t + p.percent,
    );
    return Equipment(
      id: '${id}_${tier.index + 1}',
      name: names[tier.index],
      family: id,
      tier: tier,
      kind: kind,
      // To a tenth of a second, the fight's tick.
      cooldown: cooldown == null
          ? null
          : (cooldown! * (100 - faster) / 10).round() / 10,
      action: switch (action) {
        Hellfire(:final damage) => Hellfire(damage * x, insulation: insulation),
        final Action a => scaleAction(a, x),
        null => null,
      },
      hull: hull * x,
      maxShield: maxShieldTiers?[tier.index] ?? maxShield * x,
      maxDrones: maxDrones * x,
      ammo: {
        for (final e in ammo.entries) e.key: e.value * x,
        for (final p in gained.whereType<Stocked>()) p.ammo: p.count,
      },
      boost: boostPercents == null
          ? null
          : ChargeBoost(
              boostScope!,
              boostPercents![tier.index],
              only: boostOnly,
              maxDamage: boostMaxDamage == null ? null : boostMaxDamage! * x,
            ),
      housing: housing * x,
      hospital: hospital * x,
      crawlspace: crawlspace * x,
      dividend: dividend * x,
      gamble: gamble,
      hellShielding: hellShielding * x,
      fuel: fuel * x,
      hold: hold * x,
      price: price * [1, 3, 9][tier.index],
      tags: tags,
      headStart: gained.whereType<Primed>().fold(
        0.0,
        (t, p) => max(t, p.fraction),
      ),
      perks: gained,
    );
  }
}

/// [action] with its numbers multiplied by [x].
Action scaleAction(Action action, int x) => switch (action) {
  FireLaser(:final damage) => FireLaser(damage * x),
  FireMissile(:final damage) => FireMissile(damage * x),
  TeleportBomb(:final damage) => TeleportBomb(damage * x),
  Hellfire(:final damage, :final insulation) => Hellfire(
    damage * x,
    insulation: insulation,
  ),
  BuildDrone(:final count) => BuildDrone(count * x),
  IonBlast(:final damage) => IonBlast(damage * x),
  Flak(:final count, :final shrapnel) => Flak(count * x, shrapnel: shrapnel),
  Repair(:final amount) => Repair(amount * x),
  RailShot(:final damage) => RailShot(damage * x),
  LanceShot(:final damage, :final ramp) => LanceShot(damage * x, ramp * x),
  JamTeleports(:final count) => JamTeleports(count * x),
  final other => other,
};

/// [action] hitting [extra] harder, for weapons; anything else unchanged.
Action plusDamage(Action action, int extra) => switch (action) {
  FireLaser(:final damage) => FireLaser(damage + extra),
  FireMissile(:final damage) => FireMissile(damage + extra),
  TeleportBomb(:final damage) => TeleportBomb(damage + extra),
  Hellfire(:final damage, :final insulation) => Hellfire(
    damage + extra,
    insulation: insulation,
  ),
  IonBlast(:final damage) => IonBlast(damage + extra),
  RailShot(:final damage) => RailShot(damage + extra),
  LanceShot(:final damage, :final ramp) => LanceShot(damage + extra, ramp),
  final other => other,
};
