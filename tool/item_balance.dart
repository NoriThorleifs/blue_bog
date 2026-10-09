// ignore_for_file: avoid_print
// Item balance: hundreds of randomly generated builds per budget fight each
// other, and every card family is scored on how much it adds to winning.
//
//   dart run tool/item_balance.dart                 # budgets 200, 500, 1000, 2000
//   dart run tool/item_balance.dart 300 1500        # your own budgets
//   dart run tool/item_balance.dart --builds 400    # more builds per budget
//
// Each captain starts with a standard 500-hull ship and a budget, may buy 0
// to 3 hull upgrades, then buys at most nine cards (one per slot, at base
// price, any tier) trying to spend everything. The rules:
//
// - Missile launchers, teleport bombs and drone fabricators always come
//   with ammo of the same tier, bought together.
// - Nothing that can't do anything in the build: boosters need something to
//   boost, Quick-Arm Fuzes need missiles small enough, a Shield Capacitor
//   needs a shield generator to boost.
// - No cargo pods: nine cards fill nine slots, so the hold would be empty.
//
// Every build fights every other build twice, once from each side, at
// full hull with the 60 s limit. A win scores 1, an escape 0.5.
//
// Item value comes from a least-squares fit of each build's score against
// how much of each family it has, in basic-card units (an upgraded card is
// 3, a super card 9). That separates a card's own effect from whatever it
// tends to be bought with. Dividing by the card's price (with its ammo)
// gives value per 100 credits, which is what over- or underpowered means.
import 'dart:math';

import 'package:blue_bog/game_engine/combat/catalog.dart';
import 'package:blue_bog/game_engine/combat/combat.dart';
import 'package:blue_bog/game_engine/combat/equipment.dart';
import 'package:blue_bog/game_engine/deck/loadout.dart';

/// Ammo bought with each launcher family, tier for tier.
const ammoFor = {
  'missiles': 'missile_crate',
  'teleporter': 'teleport_charges',
  'fabricator': 'feedstock',
};

/// Families that only change things outside a fight, or are ammo bought
/// with their launcher.
const notForSale = {
  'bunks',
  'hospital',
  'barrier',
  'tanks',
  'cargo_pod',
  'missile_crate',
  'teleport_charges',
  'feedstock',
};

/// Unique cards a brawl captain can own.
const uniques = ['hell_clock'];

/// Every family and unique card the generator can buy.
final families = [
  for (final f in [...equipmentFamilies, ...hellFamilies])
    if (!notForSale.contains(f.id)) f.id,
  ...uniques,
];

/// A purchase: one card, plus its ammo.
class Package {
  Package(this.ids);
  final List<String> ids;
  int get price => ids.fold(0, (t, id) => t + equipmentById(id).price);
  Equipment get card => equipmentById(ids.first);
}

List<Package> catalogue() => [
  for (final f in [...equipmentFamilies, ...hellFamilies])
    if (!notForSale.contains(f.id))
      for (final (t, card) in f.tiers.indexed)
        Package([
          card.id,
          if (ammoFor[f.id] case final ammo?) '${ammo}_${t + 1}',
        ]),
  for (final id in uniques) Package([id]),
];

bool _acts(Equipment e) => e.action != null && e.boost == null;

/// Whether [card] would do anything on a ship that already has [owned].
bool useful(Equipment card, Iterable<Equipment> owned) {
  if (card.tier == Tier.unique && owned.any((o) => o.id == card.id)) {
    return false;
  }
  if (card.boost case final b?) {
    bool helps(ChargeBoost b, Equipment o) =>
        _acts(o) &&
        (b.only == null || o.action.runtimeType == b.only) &&
        (b.maxDamage == null || (o.damage ?? 0) <= b.maxDamage!);
    final helped = owned.where((o) => helps(b, o)).length;
    if (b.scope == BoostScope.ship) return helped > 0;
    // A triangle booster only reaches its own small triangle, so each one
    // needs a card of its own to help, and there are only three triangles.
    final rivals = owned.where(
      (o) =>
          o.boost?.scope == BoostScope.triangle &&
          owned.any((w) => helps(o.boost!, w) && helps(b, w)),
    );
    return helped > rivals.length && rivals.length < 3;
  }
  if (card.maxShield > 0 && card.action is! ChargeShields) {
    return owned.any((o) => o.action is ChargeShields);
  }
  if (card.awakens case final tag?) {
    return owned.any((o) => _acts(o) && o.has(tag));
  }
  if (card.headStart > 0) return owned.any(_acts);
  return true;
}

class Build {
  Build(this.upgrades, this.loadout, this.unspent);
  final int upgrades;
  final Loadout loadout;
  final int unspent;
  double score = 0;

  int get hull => baseHull + upgrades * ShipStats.hullPerUpgrade;
  Iterable<Equipment> get cards => loadout.all.map(equipmentById);

  /// Basic-card units of each family. Ammo isn't counted: it's always
  /// bought with its launcher.
  Map<String, int> get units {
    final u = <String, int>{};
    for (final c in cards) {
      if (notForSale.contains(c.family)) continue;
      final n = c.tier == Tier.unique ? 1 : [1, 3, 9][c.tier.index];
      u[c.family] = (u[c.family] ?? 0) + n;
    }
    return u;
  }

  String describe() {
    final counts = <String, int>{};
    for (final c in cards) {
      counts[c.name] = (counts[c.name] ?? 0) + 1;
    }
    return [
      if (upgrades > 0) '+${upgrades * 100} hull',
      for (final e in counts.entries)
        e.value == 1 ? e.key : '${e.value}× ${e.key}',
    ].join(', ');
  }
}

/// A random build that tries to spend its whole budget on at most nine
/// cards.
Build generate(Random rng, int budget) {
  var credits = budget;
  var upgrades = rng.nextInt(4);
  while (upgrades > 0 && [0, 50, 150, 350][upgrades] > budget - 30) {
    upgrades--;
  }
  credits -= [0, 50, 150, 350][upgrades];
  final loadout = Loadout();
  final all = catalogue();

  // Buy cards, aiming each one at an even share of what's left.
  while (true) {
    final free = loadout.slots.where((s) => s == null).length;
    if (free == 0) break;
    final owned = loadout.all.map(equipmentById).toList();
    final options = <(Package, Loadout)>[];
    for (final p in all) {
      if (p.price > credits || !useful(p.card, owned)) continue;
      final trial = loadout.copy();
      if (p.ids.every((id) => trial.add(id) != null)) options.add((p, trial));
    }
    if (options.isEmpty) break;
    final target = credits / free;
    final weights = [
      for (final (p, _) in options)
        1 / (1 + pow((p.price - target).abs() / max(target, 1), 2)),
    ];
    final (pick, trial) = options[_weighted(rng, weights)];
    loadout
      ..slots.setAll(0, trial.slots)
      ..hold.clear();
    credits -= pick.price;
  }

  // Spend what's left upgrading cards a tier, ammo along with its launcher.
  while (true) {
    final options = <(int, List<(int, String)>, int)>[];
    for (var i = 0; i < Loadout.slotCount; i++) {
      final id = loadout.slots[i];
      if (id == null) continue;
      final card = equipmentById(id);
      final up = upgradeOf(card);
      if (up == null || notForSale.contains(card.family)) continue;
      final swaps = [(i, up.id)];
      var cost = up.price - card.price;
      if (ammoFor[card.family] case final ammo?) {
        final j = loadout.slots.indexOf('${ammo}_${card.tier.index + 1}');
        if (j >= 0) {
          final a = equipmentById(loadout.slots[j]!);
          final aUp = upgradeOf(a)!;
          swaps.add((j, aUp.id));
          cost += aUp.price - a.price;
        }
      }
      if (cost <= credits) options.add((i, swaps, cost));
    }
    if (options.isEmpty) break;
    final (_, swaps, cost) = options[rng.nextInt(options.length)];
    for (final (j, id) in swaps) {
      loadout.slots[j] = id;
    }
    credits -= cost;
  }
  arrange(loadout);
  return Build(upgrades, loadout, credits);
}

int _weighted(Random rng, List<double> w) {
  var roll = rng.nextDouble() * w.reduce((a, b) => a + b);
  for (var i = 0; i < w.length; i++) {
    roll -= w[i];
    if (roll < 0) return i;
  }
  return w.length - 1;
}

/// Puts each triangle booster in a small triangle with cards it helps.
void arrange(Loadout l) {
  final cards = l.slots.whereType<String>().toList();
  bool isBooster(String id) =>
      equipmentById(id).boost?.scope == BoostScope.triangle;
  bool helps(String booster, String card) {
    final b = equipmentById(booster).boost!;
    final c = equipmentById(card);
    return _acts(c) &&
        (b.only == null || c.action.runtimeType == b.only) &&
        (b.maxDamage == null || (c.damage ?? 0) <= b.maxDamage!);
  }

  final boosters = cards.where(isBooster).toList();
  final rest = cards.where((c) => !isBooster(c)).toList();
  final slots = List<String?>.filled(Loadout.slotCount, null);
  for (var t = 0; t < 3 && boosters.isNotEmpty; t++) {
    final b = boosters.removeAt(0);
    slots[t * 3] = b;
    for (var k = 1; k < 3; k++) {
      final i = rest.indexWhere((c) => helps(b, c));
      if (i >= 0) slots[t * 3 + k] = rest.removeAt(i);
    }
  }
  final leftovers = [...boosters, ...rest];
  for (var i = 0; i < slots.length && leftovers.isNotEmpty; i++) {
    slots[i] ??= leftovers.removeAt(0);
  }
  l.slots.setAll(0, slots);
}

double play(Build a, Build b) {
  var points = 0.0;
  for (final aFirst in [true, false]) {
    final ca = Combatant(
      name: 'a',
      loadout: a.loadout.forCombat,
      baseHull: a.hull,
    );
    final cb = Combatant(
      name: 'b',
      loadout: b.loadout.forCombat,
      baseHull: b.hull,
    );
    final r = aFirst ? fight(ca, cb) : fight(cb, ca);
    points += switch (r.outcome) {
      CombatOutcome.escape => 0.5,
      CombatOutcome.win => aFirst ? 1 : 0,
      CombatOutcome.loss => aFirst ? 0 : 1,
    };
  }
  return points / 2;
}

/// Least squares with a little ridge, by Gaussian elimination.
List<double> fit(List<List<double>> x, List<double> y, {double ridge = 0.5}) {
  final n = x.first.length;
  final a = List.generate(n, (_) => List.filled(n + 1, 0.0));
  for (var r = 0; r < x.length; r++) {
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        a[i][j] += x[r][i] * x[r][j];
      }
      a[i][n] += x[r][i] * y[r];
    }
  }
  for (var i = 1; i < n; i++) {
    a[i][i] += ridge; // Not on the intercept.
  }
  for (var c = 0; c < n; c++) {
    var p = c;
    for (var r = c + 1; r < n; r++) {
      if (a[r][c].abs() > a[p][c].abs()) p = r;
    }
    final t = a[c];
    a[c] = a[p];
    a[p] = t;
    if (a[c][c].abs() < 1e-12) continue;
    for (var r = 0; r < n; r++) {
      if (r == c) continue;
      final f = a[r][c] / a[c][c];
      for (var k = c; k <= n; k++) {
        a[r][k] -= f * a[c][k];
      }
    }
  }
  return [
    for (var i = 0; i < n; i++) a[i][i].abs() < 1e-12 ? 0 : a[i][n] / a[i][i],
  ];
}

/// Price of one basic unit of a family, with its ammo.
int unitPrice(String family) {
  if (uniques.contains(family)) return equipmentById(family).price;
  final card = equipmentById('${family}_1');
  final ammo = ammoFor[family];
  return card.price + (ammo == null ? 0 : equipmentById('${ammo}_1').price);
}

String nameOf(String family) => uniques.contains(family)
    ? equipmentById(family).name
    : equipmentById('${family}_1').name;

String pct(double x) => '${(x * 100).round()}%';

void main(List<String> args) {
  var count = 300;
  final budgets = <int>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--builds') {
      count = int.parse(args[++i]);
    } else {
      budgets.add(int.parse(args[i]));
    }
  }
  if (budgets.isEmpty) budgets.addAll([200, 500, 1000, 2000]);

  final summary = <String, Map<int, double>>{};
  for (final budget in budgets) {
    final rng = Random(budget);
    final builds = [for (var i = 0; i < count; i++) generate(rng, budget)];
    for (var i = 0; i < builds.length; i++) {
      for (var j = i + 1; j < builds.length; j++) {
        final s = play(builds[i], builds[j]);
        builds[i].score += s;
        builds[j].score += 1 - s;
      }
    }
    for (final b in builds) {
      b.score /= builds.length - 1;
    }

    final present = [
      for (final f in families)
        if (builds.any((b) => b.units.containsKey(f))) f,
    ];
    final x = [
      for (final b in builds)
        [
          1.0,
          b.upgrades.toDouble(),
          for (final f in present) (b.units[f] ?? 0).toDouble(),
        ],
    ];
    final coef = fit(x, [for (final b in builds) b.score]);
    final unspent = builds.fold(0, (t, b) => t + b.unspent) / builds.length;

    print(
      '\n=== Budget $budget cr: $count random builds, each fights all '
      'the others twice. Average left unspent: ${unspent.round()} cr ===\n',
    );
    print(
      '${'Card'.padRight(26)}${'in builds'.padLeft(10)}'
      '${'score with'.padLeft(12)}${'without'.padLeft(9)}'
      '${'per unit'.padLeft(10)}${'per 100 cr'.padLeft(12)}',
    );
    final rows = <(String, double)>[];
    for (final (k, f) in present.indexed) {
      final has = builds.where((b) => b.units.containsKey(f)).toList();
      final hasnt = builds.where((b) => !b.units.containsKey(f)).toList();
      double avg(List<Build> l) =>
          l.isEmpty ? 0 : l.fold(0.0, (t, b) => t + b.score) / l.length;
      final perUnit = coef[k + 2];
      final per100 = perUnit / unitPrice(f) * 100;
      rows.add((f, per100));
      summary.putIfAbsent(f, () => {})[budget] = per100;
      print(
        '${nameOf(f).padRight(26)}${pct(has.length / builds.length).padLeft(10)}'
        '${pct(avg(has)).padLeft(12)}${pct(avg(hasnt)).padLeft(9)}'
        '${(perUnit * 100).toStringAsFixed(1).padLeft(10)}'
        '${(per100 * 100).toStringAsFixed(1).padLeft(12)}',
      );
    }
    final hullCoef = coef[1];
    print(
      '${'Hull upgrade (+100)'.padRight(26)}'
      '${pct(builds.where((b) => b.upgrades > 0).length / builds.length).padLeft(10)}'
      '${''.padLeft(21)}${(hullCoef * 100).toStringAsFixed(1).padLeft(10)}'
      '${'(50→400 cr)'.padLeft(12)}',
    );
    summary.putIfAbsent('hull', () => {})[budget] = hullCoef;

    final ranked = builds.toList()..sort((a, b) => b.score.compareTo(a.score));
    print('\nBest builds:');
    for (final b in ranked.take(3)) {
      print('  ${pct(b.score).padLeft(4)}  ${b.describe()}');
    }
    print('Worst build:');
    print('  ${pct(ranked.last.score).padLeft(4)}  ${ranked.last.describe()}');
  }

  print(
    '\n=== Value per 100 cr across budgets (score points; 0 = no help) ===\n',
  );
  print(
    '${'Card'.padRight(26)}${budgets.map((b) => '$b cr'.padLeft(9)).join()}',
  );
  final order = summary.keys.where((k) => k != 'hull').toList()
    ..sort((a, b) {
      double mean(String f) {
        final v = summary[f]!.values;
        return v.reduce((x, y) => x + y) / v.length;
      }

      return mean(b).compareTo(mean(a));
    });
  for (final f in order) {
    print(
      nameOf(f).padRight(26) +
          [
            for (final b in budgets)
              (summary[f]![b] == null
                      ? '-'
                      : (summary[f]![b]! * 100).toStringAsFixed(1))
                  .padLeft(9),
          ].join(),
    );
  }
  print(
    '\nPer unit is score points per basic card (an upgraded card is 3 '
    'units). Per 100 cr divides by the card\'s price with its ammo. Cards '
    'far above the rest are overpowered for their price, cards near zero '
    'or below are underpowered.',
  );
}
