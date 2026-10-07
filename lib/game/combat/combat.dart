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
  shieldsCharged,
  droneBuilt,
  outOfAmmo,
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
  });

  /// From the first combatant's point of view.
  final CombatOutcome outcome;
  final double seconds;
  final int hull;
  final int enemyHull;
  final List<CombatEvent> events;

  /// State after every moment something happened, starting at 0 s.
  final List<CombatSnapshot> snapshots;

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

/// Cooldowns can't be cut below this fraction, or below one second.
const minCooldownFraction = 0.5;

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
  final snapshots = [snap(0)];
  const limit = combatTimeLimit * 10;
  var tick = 0;
  while (tractorBeam || tick < limit) {
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
    if (firing.isNotEmpty) snapshots.add(snap(tick / 10));
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
  );
}

int _order(_Side side, int slot) => switch (side.gear[slot]!.action) {
  ChargeShields() || BuildDrone() => 0,
  _ => 1,
};

/// A combatant's state during a fight.
class _Side {
  _Side(Combatant c)
    : gear = [
        for (final id in c.loadout.slots) id == null ? null : equipmentById(id),
      ],
      hull = c.hull {
    final all = gear.whereType<Equipment>();
    maxShield = all.fold(0, (t, e) => t + e.maxShield);
    maxDrones = all.fold(0, (t, e) => t + e.maxDrones);
    // Supplies count from the hold too; everything else only from a slot.
    final held = c.loadout.hold
        .map(equipmentById)
        .where((e) => e.kind == CardKind.supplies);
    for (final e in [...all, ...held]) {
      e.ammo.forEach((k, v) => ammo[k] = (ammo[k] ?? 0) + v);
    }
    cooldowns = [for (var i = 0; i < 9; i++) _cooldownTicks(i)];
    timers = [...cooldowns];
  }

  final List<Equipment?> gear;
  int hull;
  int shield = 0;
  int drones = 0;
  late final int maxShield;
  late final int maxDrones;
  final ammo = <Ammo, int>{};
  late final List<int?> cooldowns;
  late final List<int?> timers;

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
    final seconds = max(
      max(1.0, base * minCooldownFraction),
      base * (100 - cut) / 100,
    );
    return (seconds * 10).round();
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
    switch (gear[slot]!.action!) {
      case FireLaser(:final damage):
        final absorbed = min(enemy.shield, damage);
        enemy.shield -= absorbed;
        enemy.hull -= damage - absorbed;
        note(
          absorbed == damage
              ? CombatEventKind.laserAbsorbed
              : CombatEventKind.laserHit,
          damage - absorbed,
        );
      case FireMissile(:final damage):
        if (!_use(Ammo.missiles)) return note(CombatEventKind.outOfAmmo);
        if (enemy.drones > 0) {
          enemy.drones--;
          note(CombatEventKind.missileIntercepted, damage);
        } else {
          enemy.hull -= damage;
          note(CombatEventKind.missileHit, damage);
        }
      case TeleportBomb(:final damage):
        if (!_use(Ammo.teleportCharges)) {
          return note(CombatEventKind.outOfAmmo);
        }
        enemy.hull -= damage;
        note(CombatEventKind.teleportHit, damage);
      case ChargeShields():
        shield = maxShield;
        note(CombatEventKind.shieldsCharged, shield);
      case BuildDrone():
        if (drones >= maxDrones) return;
        if (!_use(Ammo.droneFeedstock)) return note(CombatEventKind.outOfAmmo);
        drones++;
        note(CombatEventKind.droneBuilt, drones);
    }
  }
}
