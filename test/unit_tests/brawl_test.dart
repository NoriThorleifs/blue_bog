import 'package:blue_bog/game/brawl/brawl.dart';
import 'package:blue_bog/game/brawl/brawl_events.dart';
import 'package:blue_bog/game/captain/species.dart';
import 'package:blue_bog/game/combat/catalog.dart';
import 'package:blue_bog/game/combat/combat.dart';
import 'package:blue_bog/game/combat/equipment.dart';
import 'package:blue_bog/game/deck/loadout.dart';
import 'package:blue_bog/game/engine.dart' show IllegalMove;
import 'package:blue_bog/game/market.dart';
import 'package:flutter_test/flutter_test.dart';

const engine = BrawlEngine();

void main() {
  test('no human or map-only cards in a brawl', () {
    for (final species in Species.values) {
      final s = engine.start(species, seed: 3);
      for (final id in [
        ...s.loadout.all,
        for (final o in s.market.offers) o.cardId,
      ]) {
        expect(
          brawlExcludedFamilies,
          isNot(contains(equipmentById(id).family)),
          reason: '${species.name}: $id',
        );
      }
    }
  });

  test('every brawl station is a full market', () {
    final s = engine.start(Species.tern, seed: 1);
    expect(s.market.tradingPost, isFalse);
    expect(s.market.offers, hasLength(Market.size));
  });

  test('the median price sits between the cheapest and dearest station', () {
    final s = engine.start(Species.tern, seed: 7);
    final grain = equipmentById('goods_grain');
    final prices = [
      for (final id in brawlStations.keys) commodityPrice(grain, id, s.seed),
    ];
    final median = engine.median(s, grain.id);
    expect(
      median,
      greaterThanOrEqualTo(prices.reduce((a, b) => a < b ? a : b)),
    );
    expect(median, lessThanOrEqualTo(prices.reduce((a, b) => a > b ? a : b)));
    expect(engine.median(s, 'laser_1'), equipmentById('laser_1').price);
  });

  test('leaving a station brings an event, then a dock', () {
    for (var seed = 0; seed < 40; seed++) {
      final s = engine.start(Species.tern, seed: seed);
      final out = engine.launch(s);
      expect(out.currentEvent, isNotNull);
      expect(out.docked, isFalse);
      expect(() => engine.buy(out, 0), throwsA(isA<IllegalMove>()));
      final chosen = engine.choose(out, _staysOut(out));
      expect(chosen.result, isNotNull);
      final docked = engine.proceed(chosen);
      expect(docked.docked, isTrue);
      expect(docked.round, 2);
      expect(docked.station, isNot(s.station));
      expect(s.round, 1, reason: 'the old state is untouched');
    }
  });

  test('selling the last pod keeps the one crate aboard', () {
    final s = engine.start(Species.al, seed: 4);
    final pod = s.loadout.slots.indexOf('cargo_pod_1');
    expect(s.loadout.hold, ['feedstock_1']);
    final after = engine.sell(s, SlotSpot(pod));
    expect(after.loadout.slots[pod], 'feedstock_1');
  });

  test('the enemies keep getting harder', () {
    var last = 0;
    for (var r = 1; r <= 20; r++) {
      final hull = brawlEnemy(r).hull;
      expect(hull, greaterThanOrEqualTo(last));
      last = hull;
    }
  });

  test('salvage merged after a fight leaves the replay as it was', () {
    var s = engine.start(Species.tern, seed: 0);
    for (var seed = 0; seed < 200; seed++) {
      s = _fightOnce(engine.start(Species.tern, seed: seed));
      if (s.lastCombat?.salvage.isNotEmpty ?? false) break;
    }
    final record = s.lastCombat!;
    expect(record.salvage, isNotEmpty);
    for (final e in record.result.events) {
      final slots = e.side == 0 ? record.player.slots : record.enemy.slots;
      expect(slots[e.slot], isNotNull);
    }
  });

  group('Hell', () {
    BrawlState inHell(String event, {int turns = 2}) =>
        engine.start(Species.tern, seed: 9).clone()
          ..inHell = true
          ..hellTurns = turns
          ..event = event;

    test('the chewer\'s bite is a way in, and Hell has no shipyard', () {
      var s = engine.start(Species.tern, seed: 1).clone()..event = 'chewer';
      s = engine.choose(s, 1);
      expect(s.inHell, isTrue);
      expect(s.plannedFight, isNull);
      s = engine.proceed(s..hull = 300);
      expect(s.hellTurns, 1);
      expect(s.hull, 300 - BrawlEngine.hellCorrosion);
      expect(s.currentEvent!.hell, isTrue);
      expect(engine.repairCost(s), isNull);
      expect(() => engine.reroll(s), throwsA(isA<IllegalMove>()));
    });

    test('the Mourner always gives the Cursed Orb, and lets you go', () {
      for (var choice = 0; choice < 3; choice++) {
        var s = inHell('hell_mourner')..hull = 50;
        s = engine.proceed(engine.choose(s, choice));
        expect(s.lost, isFalse);
        expect(s.loadout.all, contains('cursed_orb'));
        expect(s.inHell, isFalse);
        expect(s.docked, isTrue);
        expect(s.flags, contains(metMourner));
      }
    });

    test('with no room, the orb takes the cheapest card\'s place', () {
      final s = inHell('hell_mourner');
      while (s.loadout.add('plating_1') != null) {}
      final after = engine.choose(s, 0);
      expect(after.loadout.all, contains('cursed_orb'));
    });

    test('the Mourner only turns up once', () {
      final s = inHell('hell_clocks')..flags.add(metMourner);
      final mourner = brawlEventsById['hell_mourner']!;
      expect(mourner.condition!(s), isFalse);
    });
  });

  group('tags', () {
    test('Hell Brandy can be used to tag a card Hellish, and is used up', () {
      final l = Loadout()
        ..add('laser_1')
        ..add('cargo_pod_1')
        ..add('goods_brandy');
      expect(l.hold, ['goods_brandy']);
      expect(l.use(const HoldSpot(0), const SlotSpot(0)), isTrue);
      expect(l.slots[0], 'laser_1#hellish');
      expect(l.hold, isEmpty);
      final card = equipmentById('laser_1#hellish');
      expect(card.has(CardTag.hellish), isTrue);
      expect(card.name, 'Laser');
      expect(card.damage, 30);
    });

    test('a card can\'t take the same tag twice', () {
      final l = Loadout()
        ..add('brimstone_1')
        ..add('cargo_pod_1')
        ..add('goods_brandy');
      expect(l.canUse(const HoldSpot(0), const SlotSpot(0)), isFalse);
    });

    test('Hell Brandy is rare in shops', () {
      var shops = 0;
      var withBrandy = 0;
      for (var seed = 0; seed < 400; seed++) {
        final s = engine.start(Species.tern, seed: seed);
        shops++;
        if (s.market.offers.any((o) => o.cardId == 'goods_brandy')) {
          withBrandy++;
        }
      }
      // About one shop in eight, against two in three for an ordinary good.
      expect(withBrandy / shops, inInclusiveRange(0.05, 0.25));
    });

    test('Hell Brandy still sells like any commodity', () {
      final brandy = equipmentById('goods_brandy');
      expect(brandy.kind, CardKind.commodity);
      expect(brandy.grantsTag, CardTag.hellish);
    });

    test('a tagged copy merges with plain ones, and keeps the tag', () {
      final l = Loadout()
        ..add('laser_1#hellish')
        ..add('laser_1');
      expect(l.copiesOf('laser_1'), 2);
      l.add('laser_1');
      expect(l.all, ['laser_2#hellish']);
    });

    test('Hell cards are never sold at stations', () {
      for (var seed = 0; seed < 50; seed++) {
        final s = engine.start(Species.gor, seed: seed);
        for (final offer in s.market.offers) {
          expect(equipmentById(offer.cardId).has(CardTag.hellish), isFalse);
        }
      }
    });

    test('hellfire goes through shields but burns the shooter', () {
      final result = fight(
        Combatant(name: 'a', loadout: CombatLoadout.of(['brimstone_1'])),
        Combatant(name: 'b', loadout: CombatLoadout.of(['shield_1'])),
      );
      final first = result.events.firstWhere(
        (e) => e.kind == CombatEventKind.hellfireHit,
      );
      expect(first.value, 24);
      expect(result.hull, lessThan(baseHull));
    });

    test(
      'the Cursed Orb fires every other Hellish-tagged card at the start',
      () {
        final result = fight(
          Combatant(
            name: 'a',
            loadout: CombatLoadout.of(['cursed_orb', 'brimstone_1', 'laser_1']),
          ),
          Combatant(name: 'b', loadout: CombatLoadout.of(['laser_1'])),
        );
        final opening = result.events.where((e) => e.time == 0).toList();
        expect(opening, hasLength(1));
        expect(opening.single.kind, CombatEventKind.hellfireHit);
        final plain = result.events.where((e) => e.time == 0 && e.slot == 2);
        expect(plain, isEmpty, reason: 'the plain laser waits its turn');
      },
    );

    test('a Laser tagged Hellish fires at the start with the orb', () {
      final result = fight(
        Combatant(
          name: 'a',
          loadout: CombatLoadout.of(['cursed_orb', 'laser_1#hellish']),
        ),
        Combatant(name: 'b', loadout: CombatLoadout.of(['laser_1'])),
      );
      expect(result.events.first.time, 0);
      expect(result.events.first.kind, CombatEventKind.laserHit);
    });

    test('the Backwards Clock starts every card half charged', () {
      final result = fight(
        Combatant(
          name: 'a',
          loadout: CombatLoadout.of(['mourner_backwards_clock', 'laser_1']),
        ),
        Combatant(name: 'b', loadout: CombatLoadout.of(['plating_1'])),
      );
      final firstShot = result.events.firstWhere((e) => e.side == 0);
      // 5 s laser, 30% faster, then half charged: 1.75 s.
      expect(firstShot.time, closeTo(1.8, 0.1));
    });
  });
}

/// Launches and takes a choice that stays out of Hell.
BrawlState _fightOnce(BrawlState s) {
  final out = engine.launch(s);
  return engine.proceed(engine.choose(out, _staysOut(out)));
}

/// The first choice the captain can make that can't lead into Hell.
int _staysOut(BrawlState s) {
  final choices = s.currentEvent!.choices;
  return [
    for (var i = 0; i < choices.length; i++)
      if (engine.canChoose(s, i) &&
          !choices[i].outcomes.any((o) => o.effects.any((e) => e is EnterHell)))
        i,
  ].first;
}
