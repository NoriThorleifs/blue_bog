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
    // Drones patch the hull a little every second.
    var repaired = false;
    if (tick % 10 == 0) {
      for (final side in sides) {
        if (side.drones > 0 && side.hull > 0 && side.hull < side.maxHull) {
          side.hull = min(side.maxHull, side.hull + side.drones * droneRepair);
          repaired = true;
        }
      }
    }
    if (firing.isNotEmpty || repaired) snapshots.add(snap(tick / 10));
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
    cooldowns = [for (var i = 0; i < 9; i++) _cooldownTicks(i)];
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

  /// Shots fired from each slot this fight, for lances.
  final shots = List.filled(9, 0);
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
    final seconds = max(minCooldown, base * (100 - cut) / 100);
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
        if (enemy.jams > 0) {
          enemy.jams--;
          return note(CombatEventKind.teleportJammed, damage);
        }
        enemy.hull -= damage;
        note(CombatEventKind.teleportHit, damage);
      case IonBlast(:final damage):
        final stripped = min(enemy.shield, damage);
        enemy.shield -= stripped;
        final through = (damage - stripped) ~/ 3;
        enemy.hull -= through;
        note(CombatEventKind.ionHit, through);
      case Flak(:final count, :final shrapnel):
        final downed = min(enemy.drones, count);
        enemy.drones -= downed;
        if (downed > 0) note(CombatEventKind.flakHit, downed);
        if (downed < count) {
          final burst = (count - downed) * shrapnel;
          final absorbed = min(enemy.shield, burst);
          enemy.shield -= absorbed;
          enemy.hull -= burst - absorbed;
          note(CombatEventKind.flakShrapnel, burst - absorbed);
        }
      case RailShot(:final damage):
        if (enemy.shield > 0) {
          return note(CombatEventKind.railDeflected, damage);
        }
        enemy.hull -= damage;
        note(CombatEventKind.railHit, damage);
      case Repair(:final amount):
        final patched = min(amount, maxHull - hull);
        if (patched <= 0) return;
        hull += patched;
        note(CombatEventKind.repaired, patched);
      case LanceShot(:final damage, :final ramp):
        final hit = damage + ramp * shots[slot]++;
        final absorbed = min(enemy.shield, hit);
        enemy.shield -= absorbed;
        enemy.hull -= hit - absorbed;
        note(
          absorbed == hit
              ? CombatEventKind.laserAbsorbed
              : CombatEventKind.laserHit,
          hit - absorbed,
        );
      case JamTeleports():
        if (jams >= maxJams) return;
        jams = maxJams;
        note(CombatEventKind.jamsReady, jams);
      case Hellfire(:final damage, :final recoil):
        enemy.hull -= damage;
        hull -= recoil;
        note(CombatEventKind.hellfireHit, damage);
      case Board():
        enemy.hull = 0;
        note(CombatEventKind.boarded);
      case ChargeShields():
        shield = maxShield;
        note(CombatEventKind.shieldsCharged, shield);
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
