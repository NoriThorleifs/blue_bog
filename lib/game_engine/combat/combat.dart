import 'dart:math';

import 'catalog.dart';
import 'equipment.dart';

/// One side of a fight.
class Combatant {
  Combatant({
    required this.name,
    required this.loadout,
    int baseHull = baseHull,
    int? hull,
  }) : maxHull = baseHull + _sum(loadout, (e) => e.hull),
       hull = hull ?? baseHull + _sum(loadout, (e) => e.hull);

  final String name;
  final CombatLoadout loadout;
  final int maxHull;

  /// Hull going into the fight. Damage carries over between fights.
  final int hull;

  static int _sum(CombatLoadout l, int Function(Equipment) f) => l.slots
      .whereType<String>()
      .map(equipmentById)
      .where((e) => e.kind == CardKind.equipment)
      .fold(0, (total, e) => total + f(e));
}

enum CombatOutcome { win, loss, escape }

/// Something that happened, for the combat screen to replay.
class CombatEvent {
  const CombatEvent(this.time, this.side, this.slot, this.kind, [this.value]);

  /// Seconds since the fight started.
  final double time;

  /// 0 for the first combatant, 1 for the second.
  final int side;
  final int slot;
  final CombatEventKind kind;
  final int? value;
}

enum CombatEventKind {
  laserHit,
  laserAbsorbed,
  missileHit,
  missileIntercepted,
  teleportHit,

  /// Value is the damage dealt; the firing ship takes a quarter of it.
  hellfireHit,
  shieldsCharged,
  droneBuilt,
  outOfAmmo,

  /// A boarder came aboard, and the ship is lost.
  boarded,

  /// Value is the hull damage that got past the shields.
  ionHit,

  /// Value is the drones shot down.
  flakHit,

  /// Value is the shrapnel damage to the hull.
  flakShrapnel,

  /// Value is the hull repaired.
  repaired,
  jamsReady,
  teleportJammed,

  /// Value is the damage.
  railHit,

  /// Value is the damage the shields turned away.
  railDeflected,
}

/// A finished fight, kept so the combat screen can replay it.
class FightRecord {
  const FightRecord({
    required this.enemyName,
    required this.player,
    required this.enemy,
    required this.playerMaxHull,
    required this.enemyMaxHull,
    required this.playerStartHull,
    required this.result,
    this.salvage = const [],
    this.scrapCredits = 0,
  });

  final String enemyName;
  final CombatLoadout player;
  final CombatLoadout enemy;
  final int playerMaxHull;
  final int enemyMaxHull;
  final int playerStartHull;
  final CombatResult result;

  /// Cards and credits scrapped from the enemy, if the player won.
  final List<String> salvage;
  final int scrapCredits;
}

/// Both ships' state at a moment in the fight.
class CombatSnapshot {
  const CombatSnapshot(this.time, this.hull, this.shield, this.drones);
  final double time;

  /// Indexed by side: 0 is the first combatant.
  final List<int> hull;
  final List<int> shield;
  final List<int> drones;
}

class CombatResult {
  const CombatResult({
    required this.outcome,
    required this.seconds,
    required this.hull,
    required this.enemyHull,
    required this.events,
    this.snapshots = const [],
    this.shots = const [],
  });

  /// From the first combatant's point of view.
  final CombatOutcome outcome;
  final double seconds;
  final int hull;
  final int enemyHull;
  final List<CombatEvent> events;

  /// State after every moment something happened, starting at 0 s.
  final List<CombatSnapshot> snapshots;

  /// How many times the first combatant's card in each slot fired, for
  /// cards that grow with every shot (see [Veteran]).
  final List<int> shots;

  /// The latest state at or before [time].
  CombatSnapshot at(double time) {
    var best = snapshots.first;
    for (final s in snapshots) {
      if (s.time > time) break;
      best = s;
    }
    return best;
  }
}

/// Each slot's cooldown in seconds after charge boosts, or null for passive
/// equipment and empty slots. For showing timers.
List<double?> cooldownSeconds(CombatLoadout loadout) {
  final side = _Side(Combatant(name: '', loadout: loadout));
  return [for (final c in side.cooldowns) c == null ? null : c / 10];
}

/// Fights last at most this long, unless a tractor beam holds both ships.
const combatTimeLimit = 60.0;

/// No card fires more often than this, in seconds, however many charge
/// boosts stack on it. Boosts add up with no other cap, so a teleport bomb
/// with enough of them fires every second, for as long as its charges last.
const minCooldown = 1.0;

/// Simulates a fight between [a] and [b]. Deterministic: the same ships
/// always fight the same way.
///
/// Time advances in 0.1 s ticks. On each tick every timer counts down, and
/// everything that fires on the same tick resolves together: shields and
/// drones first, then weapons.
CombatResult fight(Combatant a, Combatant b, {bool tractorBeam = false}) {
  final sides = [_Side(a), _Side(b)];
  final events = <CombatEvent>[];
  CombatSnapshot snap(double time) => CombatSnapshot(
    time,
    [for (final s in sides) max(0, s.hull)],
    [for (final s in sides) s.shield],
    [for (final s in sides) s.drones],
  );
  // Cards like the Cursed Orb wake every other card with a tag before the
  // first tick.
  final opening = [
    for (var s = 0; s < 2; s++)
      for (final slot in sides[s].awakened()) (s, slot),
  ];
  opening.sort((x, y) => _order(sides[x.$1], x.$2) - _order(sides[y.$1], y.$2));
  for (final (s, slot) in opening) {
    sides[s].fire(slot, sides[1 - s], 0, s, events);
  }
  final snapshots = [snap(0)];
  const limit = combatTimeLimit * 10;
  var tick = 0;
  while ((tractorBeam || tick < limit) && sides.every((s) => s.hull > 0)) {
    tick++;
    final firing = [
      for (var s = 0; s < 2; s++)
        for (final slot in sides[s].tick()) (s, slot),
    ];
    // Defences first, so a shield that charges this instant counts.
    firing.sort(
      (x, y) => _order(sides[x.$1], x.$2) - _order(sides[y.$1], y.$2),
    );
    for (final (s, slot) in firing) {
      sides[s].fire(slot, sides[1 - s], tick / 10, s, events);
    }
    // Every second, drones and living hulls patch the hull a little, and
    // regenerating shields recover.
    var mended = false;
    if (tick % 10 == 0) {
      for (final side in sides) {
        if (side.hull <= 0) continue;
        mended = side.mend() || mended;
      }
    }
    if (firing.isNotEmpty || mended) snapshots.add(snap(tick / 10));
    if (sides[0].hull <= 0 || sides[1].hull <= 0) break;
    if (tick > 100000) break;
  }
  final outcome = sides[1].hull <= 0 && sides[0].hull > 0
      ? CombatOutcome.win
      : sides[0].hull <= 0
      ? CombatOutcome.loss
      : CombatOutcome.escape;
  return CombatResult(
    outcome: outcome,
    seconds: tick / 10,
    hull: max(0, sides[0].hull),
    enemyHull: max(0, sides[1].hull),
    events: events,
    snapshots: [...snapshots, snap(tick / 10)],
    shots: [...sides[0].shots],
  );
}

int _order(_Side side, int slot) => switch (side.gear[slot]!.action) {
  ChargeShields() || BuildDrone() || JamTeleports() => 0,
  _ => 1,
};

/// A combatant's state during a fight.
class _Side {
  _Side(Combatant c)
    : gear = [
        for (final id in c.loadout.slots) id == null ? null : equipmentById(id),
      ],
      hull = c.hull,
      maxHull = c.maxHull {
    final all = gear.whereType<Equipment>();
    maxShield = all.fold(0, (t, e) => t + e.maxShield);
    maxDrones = all.fold(0, (t, e) => t + e.maxDrones);
    maxJams = all.fold(
      0,
      (t, e) =>
          t +
          (e.action is JamTeleports ? (e.action! as JamTeleports).count : 0),
    );
    // Supplies count from the hold too; everything else only from a slot.
    final held = c.loadout.hold
        .map(equipmentById)
        .where((e) => e.kind == CardKind.supplies);
    for (final e in [...all, ...held]) {
      e.ammo.forEach((k, v) => ammo[k] = (ammo[k] ?? 0) + v);
    }
    // Supplies' perks work from the hold as well as a slot.
    final perks = [
      for (final e in [...all, ...held]) ...e.perks,
    ];
    int total<T extends Perk>(int Function(T) f) =>
        perks.whereType<T>().fold(0, (t, p) => t + f(p));
    armour = total<Armour>((p) => p.amount);
    shieldRegen = total<ShieldRegen>((p) => p.perSecond);
    hullRegen = total<HullRegen>((p) => p.perSecond);
    droneRate = droneRepair + total<DronePatch>((p) => p.extra);
    reflector = [
      for (var i = 0; i < 9; i++)
        if (gear[i]?.perk<Reflect>() != null) i,
    ].firstOrNull;
    if (perks.any((p) => p is StartShielded)) shield = maxShield;
    drones = min(maxDrones, total<StartDrones>((p) => p.count));
    shipBoosts = [
      for (final p in perks)
        if (p is DamageBoost && p.scope == BoostScope.ship) p,
    ];
    cooldowns = [for (var i = 0; i < 9; i++) _cooldownTicks(i)];
    boosts = [for (var i = 0; i < 9; i++) _damageBoost(i)];
    final headStart = all.fold(0.0, (t, e) => max(t, e.headStart));
    timers = [
      for (final c in cooldowns)
        c == null ? null : max(1, (c * (1 - headStart)).round()),
    ];
  }

  /// Slots that fire at the very start: every card with a tag that
  /// another slotted card [Equipment.awakens].
  List<int> awakened() => [
    for (var i = 0; i < 9; i++)
      if (gear[i] case final e? when e.action != null)
        if (_awakeners(i).any(e.has)) i,
  ];

  /// Tags woken by every slotted card except the one in [slot].
  Iterable<CardTag> _awakeners(int slot) => [
    for (var j = 0; j < 9; j++)
      if (j != slot)
        if (gear[j]?.awakens case final tag?) tag,
  ];

  final List<Equipment?> gear;
  int hull;
  final int maxHull;
  int shield = 0;
  int drones = 0;
  int jams = 0;
  late final int maxJams;

  /// Shots fired from each slot this fight, for lances and every card
  /// that grows with each shot.
  final shots = List.filled(9, 0);
  late final int maxShield;
  late final int maxDrones;
  final ammo = <Ammo, int>{};
  late final List<int?> cooldowns;
  late final List<int?> timers;

  /// Taken off every hit on the hull, down to half. See [Armour].
  late final int armour;
  late final int shieldRegen;
  late final int hullRegen;

  /// Hull each drone out repairs a second.
  late final int droneRate;

  /// The slot of a jammer that sends jammed bombs back, if any.
  late final int? reflector;

  /// How much harder, in percent, each slot's weapon hits for the cards
  /// around it. See [DamageBoost].
  late final List<int> boosts;

  /// Damage boosts that reach every weapon aboard.
  late final List<DamageBoost> shipBoosts;

  /// Cooldown in ticks after every charge boost that reaches this slot.
  int? _cooldownTicks(int slot) {
    final e = gear[slot];
    final base = e?.cooldown;
    if (e == null || base == null || e.action == null) return null;
    var cut = 0;
    for (var j = 0; j < 9; j++) {
      final boost = gear[j]?.boost;
      if (j == slot || boost == null) continue;
      if (boost.scope == BoostScope.triangle && j ~/ 3 != slot ~/ 3) continue;
      if (boost.only != null && e.action.runtimeType != boost.only) continue;
      if (boost.maxDamage != null && (e.damage ?? 0) > boost.maxDamage!) {
        continue;
      }
      cut += boost.percent;
    }
    final seconds = max(minCooldown, base * (100 - cut) / 100);
    return (seconds * 10).round();
  }

  /// The damage boost from the other cards in [slot]'s triangle, and from
  /// ship-wide boosts.
  int _damageBoost(int slot) {
    final e = gear[slot];
    if (e == null || e.damage == null) return 0;
    bool fits(DamageBoost p) =>
        p.only == null || e.action.runtimeType == p.only;
    var boost = 0;
    for (var j = slot ~/ 3 * 3; j < slot ~/ 3 * 3 + 3; j++) {
      if (j == slot) continue;
      for (final p in gear[j]?.perks ?? const <Perk>[]) {
        if (p is DamageBoost && p.scope == BoostScope.triangle && fits(p)) {
          boost += p.percent;
        }
      }
    }
    for (final p in shipBoosts) {
      if (fits(p)) boost += p.percent;
    }
    return boost;
  }

  /// What a shot of [base] from [slot] amounts to, with what the card has
  /// gained this fight and the boosts around it. Counts the shot.
  int _power(int slot, int base) {
    final e = gear[slot]!;
    final ramp =
        e.perks.whereType<Frenzy>().fold(0, (t, p) => t + p.perShot) +
        e.perks.whereType<Veteran>().fold(0, (t, p) => t + p.perShot);
    final hit = (base + ramp * shots[slot]) * (100 + boosts[slot]) ~/ 100;
    shots[slot]++;
    return hit;
  }

  /// Takes [amount] of hull damage from the enemy, less [armour], and
  /// returns what got through.
  int _hurt(int amount) {
    if (amount <= 0) return 0;
    final taken = max(amount - armour, (amount + 1) ~/ 2);
    hull -= taken;
    return taken;
  }

  /// Patches [amount] hull, up to the maximum, and returns what it patched.
  int _patch(int amount) {
    final patched = max(0, min(amount, maxHull - hull));
    hull += patched;
    return patched;
  }

  /// A second's worth of drone repairs, regrowing hull and regenerating
  /// shields. Returns whether anything changed.
  bool mend() {
    final patched = _patch(drones * droneRate + hullRegen);
    final before = shield;
    shield = min(maxShield, shield + shieldRegen);
    return patched > 0 || shield != before;
  }

  /// Counts every timer down one tick and returns the slots that fire.
  List<int> tick() {
    final fired = <int>[];
    for (var i = 0; i < 9; i++) {
      final t = timers[i];
      if (t == null) continue;
      if (t <= 1) {
        fired.add(i);
        timers[i] = cooldowns[i];
      } else {
        timers[i] = t - 1;
      }
    }
    return fired;
  }

  bool _use(Ammo kind) {
    final left = ammo[kind] ?? 0;
    if (left <= 0) return false;
    ammo[kind] = left - 1;
    return true;
  }

  void fire(
    int slot,
    _Side enemy,
    double time,
    int side,
    List<CombatEvent> log,
  ) {
    void note(CombatEventKind kind, [int? value]) =>
        log.add(CombatEvent(time, side, slot, kind, value));
    final card = gear[slot]!;
    final pierce = card.perks.whereType<PierceShields>().fold(
      0,
      (t, p) => t + p.percent,
    );

    /// A hit that shields soak up, all but the share that pierces them.
    /// Returns what reached the hull.
    int beam(int hit) {
      final absorbed = min(enemy.shield, hit - hit * min(100, pierce) ~/ 100);
      enemy.shield -= absorbed;
      return enemy._hurt(hit - absorbed);
    }

    switch (card.action!) {
      case FireLaser(:final damage):
        final taken = beam(_power(slot, damage));
        note(
          taken == 0 ? CombatEventKind.laserAbsorbed : CombatEventKind.laserHit,
          taken,
        );
      case FireMissile(:final damage):
        if (!_use(Ammo.missiles)) return note(CombatEventKind.outOfAmmo);
        final hit = _power(slot, damage);
        if (enemy.drones > 0) {
          enemy.drones--;
          if (card.perk<Overpenetrate>() == null) {
            return note(CombatEventKind.missileIntercepted, hit);
          }
          note(CombatEventKind.missileHit, enemy._hurt(hit ~/ 2));
        } else {
          note(CombatEventKind.missileHit, enemy._hurt(hit));
        }
      case TeleportBomb(:final damage):
        if (!_use(Ammo.teleportCharges)) {
          return note(CombatEventKind.outOfAmmo);
        }
        final hit = _power(slot, damage);
        if (enemy.jams > 0 && card.perk<JamProof>() == null) {
          enemy.jams--;
          note(CombatEventKind.teleportJammed, hit);
          // A reflecting jammer sends the bomb home.
          if (enemy.reflector case final back?) {
            log.add(
              CombatEvent(
                time,
                1 - side,
                back,
                CombatEventKind.teleportHit,
                _hurt(hit),
              ),
            );
          }
          return;
        }
        note(CombatEventKind.teleportHit, enemy._hurt(hit));
      case IonBlast(:final damage):
        final hit = _power(slot, damage);
        final stripped = min(enemy.shield, hit);
        enemy.shield -= stripped;
        final leftover = hit - stripped;
        final through = card.perk<Overload>() == null
            ? leftover ~/ 3
            : leftover;
        note(CombatEventKind.ionHit, enemy._hurt(through));
      case Flak(:final count, :final shrapnel):
        final downed = min(enemy.drones, count);
        enemy.drones -= downed;
        if (downed > 0) note(CombatEventKind.flakHit, downed);
        if (downed < count) {
          note(CombatEventKind.flakShrapnel, beam((count - downed) * shrapnel));
        }
      case RailShot(:final damage):
        if (enemy.shield > 0) {
          if (card.perk<ShieldBreaker>() != null) enemy.shield = 0;
          return note(CombatEventKind.railDeflected, damage);
        }
        note(CombatEventKind.railHit, enemy._hurt(_power(slot, damage)));
      case Repair(:final amount):
        final patched = _patch(_power(slot, amount));
        if (patched <= 0) return;
        note(CombatEventKind.repaired, patched);
      case LanceShot(:final damage, :final ramp):
        final taken = beam(_power(slot, damage + ramp * shots[slot]));
        note(
          taken == 0 ? CombatEventKind.laserAbsorbed : CombatEventKind.laserHit,
          taken,
        );
      case JamTeleports():
        if (jams >= maxJams) return;
        jams = maxJams;
        note(CombatEventKind.jamsReady, jams);
      case Hellfire():
        final hellfire = card.action! as Hellfire;
        final hit = _power(slot, hellfire.damage);
        hull -= hellfire.recoilFor(hit);
        note(CombatEventKind.hellfireHit, enemy._hurt(hit));
      case Board():
        enemy.hull = 0;
        note(CombatEventKind.boarded);
      case ChargeShields():
        final full = shield >= maxShield;
        shield = maxShield;
        note(CombatEventKind.shieldsCharged, shield);
        // A generator with nothing to refill patches the hull instead.
        final overflow = card.perk<Overflow>();
        if (full && overflow != null) {
          final patched = _patch(overflow.amount);
          if (patched > 0) note(CombatEventKind.repaired, patched);
        }
      case BuildDrone(:final count):
        if (drones >= maxDrones) return;
        var built = 0;
        while (built < count &&
            drones < maxDrones &&
            _use(Ammo.droneFeedstock)) {
          drones++;
          built++;
        }
        if (built == 0) return note(CombatEventKind.outOfAmmo);
        note(CombatEventKind.droneBuilt, drones);
    }
  }
}
