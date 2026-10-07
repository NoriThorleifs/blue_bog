import 'package:blue_bog/game/captain/species.dart';
import 'package:blue_bog/game/combat/catalog.dart';
import 'package:blue_bog/game/combat/equipment.dart';
import 'package:blue_bog/game/content/content.dart';
import 'package:blue_bog/game/deck/loadout.dart';
import 'package:blue_bog/game/engine.dart';
import 'package:blue_bog/game/galaxy/galaxy.dart';
import 'package:blue_bog/game/market.dart';
import 'package:blue_bog/game/rng.dart';
import 'package:blue_bog/game/run_state.dart';
import 'package:blue_bog/game/story/keys.dart';
import 'package:blue_bog/game/story/rules.dart';
import 'package:flutter_test/flutter_test.dart';

final engine = GameEngine(storyContent);

RunState _dismiss(RunState s) {
  while (s.pending != null) {
    s = s.pending!.result == null ? engine.choose(s, 0) : engine.acknowledge(s);
  }
  return s;
}

/// A fresh Ál run, docked at Orcha Station (which always has a market).
RunState _atOrcha() =>
    _dismiss(engine.newRun(Species.al, seed: 5)).clone()..credits = 500;

void main() {
  group('merging', () {
    test('one is a card, two are two cards, three merge into an upgrade', () {
      final l = Loadout();
      l.add('laser_1');
      l.add('laser_1');
      expect(l.all, ['laser_1', 'laser_1']);
      final log = l.add('laser_1');
      expect(l.all, ['laser_2']);
      expect(log, ['Three Laser merged into Twin Lasers.']);
    });

    test('nine basics chain into one super card worth nine', () {
      final l = Loadout();
      for (var i = 0; i < 9; i++) {
        l.add('plating_1');
      }
      expect(l.all, ['plating_3']);
      expect(equipmentById('plating_3').tier, Tier.superior);
      expect(equipmentById('plating_3').hull, 900);
    });

    test('commodities never merge', () {
      final l = Loadout();
      for (var i = 0; i < 3; i++) {
        l.add('goods_grain');
      }
      expect(l.all, ['goods_grain', 'goods_grain', 'goods_grain']);
    });

    test('without a hold, cargo has to take a slot', () {
      final l = Loadout();
      expect(l.holdCapacity, 0);
      l.add('missile_crate_1');
      expect(l.slots.first, 'missile_crate_1');
      l.add('cargo_pod_1');
      expect(l.holdCapacity, 3);
      l.add('goods_ore');
      expect(l.hold, ['goods_ore']);
    });
  });

  group('the ship', () {
    test('every captain gets 500 hull, and plating adds to it', () {
      expect(ShipStats.of(Loadout()).maxHull, 500);
      final plated = Loadout(slots: ['plating_2', ...List.filled(8, null)]);
      expect(ShipStats.of(plated).maxHull, 800);
      expect(ShipStats.of(plated, hullUpgrades: 2).maxHull, 1000);
    });

    test('equipment in the hold does nothing', () {
      final l = Loadout(
        slots: ['cargo_pod_1', ...List.filled(8, null)],
        hold: ['plating_1'],
      );
      expect(ShipStats.of(l).maxHull, 500);
    });

    test('every species starts with berths for its humans and a cargo pod', () {
      for (final species in Species.values) {
        final s = engine.newRun(species, seed: 1);
        expect(s.stats.berths, greaterThanOrEqualTo(s.humans.count));
        expect(s.stats.holdCapacity, greaterThan(0));
        expect(s.hull, 500 + s.loadout.slotted.fold(0, (t, e) => t + e.hull));
      }
    });

    test('taking out accommodation sends the humans away', () {
      final s = _atOrcha();
      final count = s.humans.count;
      final loadout = s.loadout.copy();
      for (var i = 0; i < 9; i++) {
        if (loadout.slots[i]?.startsWith('bunks') ?? false) {
          loadout.slots[i] = null;
        }
      }
      expect(engine.crewLostWith(s, loadout), count);

      var after = s;
      for (var i = 0; i < 9; i++) {
        if (s.loadout.slots[i]?.startsWith('bunks') ?? false) {
          after = engine.sell(after, SlotSpot(i));
        }
      }
      expect(after.humans.count, 0);
    });
  });

  group('markets', () {
    test('Orcha Station and the Center always have one', () {
      for (var seed = 0; seed < 20; seed++) {
        final g = engine.newRun(Species.tern, seed: seed).galaxy;
        expect(g[Sys.orcha].tags, contains(Tag.market));
        expect(g[Sys.center].tags, contains(Tag.market));
      }
    });

    test('other stations may have a market or a trading post', () {
      var markets = 0, posts = 0;
      for (var seed = 0; seed < 30; seed++) {
        final g = engine.newRun(Species.tern, seed: seed).galaxy;
        for (final sys in g.systems.values) {
          if (sys.id == Sys.orcha || sys.id == Sys.center) continue;
          if (sys.tags.contains(Tag.market)) markets++;
          if (sys.tags.contains(Tag.tradingPost)) posts++;
        }
      }
      expect(markets, greaterThan(0));
      expect(posts, greaterThan(markets));
    });

    test('a trading post deals only in supplies and commodities', () {
      final s = _atOrcha()
        ..market = Market.roll(Sys.orcha, GameRng(1), 1, tradingPost: true);
      expect(s.market!.offers, hasLength(Market.tradingPostSize));
      for (final o in s.market!.offers) {
        expect(equipmentById(o.cardId).kind, isNot(CardKind.equipment));
      }
      final laser = s.loadout.slots.indexOf('laser_1');
      expect(
        () => engine.sell(s, SlotSpot(laser)),
        throwsA(isA<IllegalMove>()),
      );
      expect(engine.repairCost(s..hull = 100), isNull);
      expect(engine.hullUpgradeCost(s), isNull);
      final feedstock = s.loadout.hold.indexOf('feedstock_1');
      expect(
        engine.sell(s, HoldSpot(feedstock)).credits,
        greaterThan(s.credits),
      );
    });

    test('a market rolls 27 offers per visit', () {
      final s = _atOrcha();
      expect(s.market, isNotNull);
      expect(s.market!.offers, hasLength(Market.size));
    });

    test('buying takes credits and puts the card on the ship', () {
      final s = _atOrcha();
      final offer = s.market!.offers.indexWhere(
        (o) => equipmentById(o.cardId).kind == CardKind.commodity,
      );
      final o = s.market!.offers[offer];
      final after = engine.buy(s, offer);
      expect(after.credits, s.credits - o.price);
      expect(after.cards, contains(o.cardId));
      expect(after.market!.offers[offer].sold, isTrue);
      expect(() => engine.buy(after, offer), throwsA(isA<IllegalMove>()));
    });

    test('equipment sells for half its value', () {
      final s = _atOrcha();
      final laser = s.loadout.slots.indexOf('laser_1');
      final after = engine.sell(s, SlotSpot(laser));
      expect(after.credits, s.credits + 15);
    });

    test(
      'selling the last pod drops the one crate in the hold into its slot',
      () {
        final s = _atOrcha();
        final pod = s.loadout.slots.indexOf('cargo_pod_1');
        expect(s.loadout.hold, ['feedstock_1']);
        final after = engine.sell(s, SlotSpot(pod));
        expect(after.loadout.slots[pod], 'feedstock_1');
        expect(after.loadout.hold, isEmpty);
        expect(after.credits, s.credits + 10);
      },
    );

    test(
      'selling a pod is still refused if more than one card would spill',
      () {
        final s = _atOrcha();
        s.loadout.hold.add('goods_grain');
        final pod = s.loadout.slots.indexOf('cargo_pod_1');
        expect(
          () => engine.sell(s, SlotSpot(pod)),
          throwsA(isA<IllegalMove>()),
        );
      },
    );

    test('commodity prices differ between markets but not between visits', () {
      final grain = equipmentById('goods_grain');
      final prices = {
        for (final id in ['a', 'b', 'c', 'd', 'e', 'f'])
          commodityPrice(grain, id, 1),
      };
      expect(prices.length, greaterThan(2));
      expect(commodityPrice(grain, 'a', 1), commodityPrice(grain, 'a', 1));
    });

    test('rerolling costs a little more each time', () {
      var s = _atOrcha();
      final first = s.market!.offers.map((o) => o.cardId).toList();
      s = engine.rerollMarket(s);
      expect(s.credits, 495);
      expect(s.market!.offers.map((o) => o.cardId), isNot(first));
      s = engine.rerollMarket(s);
      expect(s.credits, 485);
    });

    test('the shipyard repairs hull and sells upgrades at rising prices', () {
      var s = _atOrcha()..hull = 100;
      final cost = engine.repairCost(s)!;
      s = engine.repair(s);
      expect(s.hull, s.stats.maxHull);
      expect(s.credits, 500 - cost);

      s = s.clone()..credits = 1000;
      s = engine.upgradeHull(s);
      expect(s.stats.maxHull, greaterThanOrEqualTo(600));
      expect(s.credits, 950);
      s = engine.upgradeHull(s);
      expect(s.credits, 850);
    });
  });

  group('combat in the story', () {
    test('a story fight is a real fight, recorded for the replay', () {
      final s = _atOrcha()..pending = const PendingEvent('consumer_scouts');
      final after = engine.choose(s, 0);
      final fight = after.lastCombat;
      expect(fight, isNotNull);
      expect(fight!.result.events, isNotEmpty);
      expect(after.hull, fight.result.hull);
    });

    test('humans patch the hull between turns, but only to 75%', () {
      final s = _atOrcha()..hull = 100;
      final after = _dismiss(engine.hold(s));
      expect(after.hull, greaterThan(100));
      final patched = s.clone()..hull = (s.stats.maxHull * 0.75).floor();
      expect(_dismiss(engine.hold(patched)).hull, patched.hull);
    });

    test('empty berths fill up over time', () {
      var s = _atOrcha()
        ..humans = const HumanResources(count: 0, loyalty: 90, drift: 0);
      for (var i = 0; i < 10; i++) {
        s = _dismiss(engine.hold(s.clone()..credits = 500));
      }
      expect(s.humans.count, greaterThan(0));
    });
  });

  group('fuel', () {
    test('jumps burn fuel, and an empty tank grounds you', () {
      var s = _dismiss(engine.newRun(Species.gor, seed: 5));
      final route = engine.routesFrom(s).firstWhere((r) => !r.isSublight);
      expect(engine.travel(s, route.to).fuel, s.fuel - 1);
      s = s.clone()..fuel = 0;
      expect(() => engine.travel(s, route.to), throwsA(isA<IllegalMove>()));
    });

    test('a Fuel Rats tab comes due, and not paying has consequences', () {
      var s = _dismiss(engine.newRun(Species.gor, seed: 5)).clone()
        ..counters[Counter.fuelRatsDebt] = 70
        ..credits = 0;
      var collected = false;
      for (var i = 0; i < 8 && !collected; i++) {
        s = engine.hold(s);
        collected = s.pending?.eventId == 'fuel_rats_collect';
        s = _dismiss(s);
      }
      expect(collected, isTrue);
      expect(s.counter(Counter.fuelRatsDebt), 0);
      expect(s.has(Flag.fuelRatsEnemy), isTrue);
    });

    test('stranded with nobody to call, you can still get moving', () {
      final s = _dismiss(engine.newRun(Species.gor, seed: 5)).clone()
        ..fuel = 0
        ..credits = 0
        ..flags.add(Flag.fuelRatsEnemy);
      expect(const FuelBelow(1).test(s), isTrue);
      expect(
        engine.hold(s).pending?.eventId,
        anyOf('stranded_alone', 'mutiny'),
      );
    });
  });

  group('courier jobs', () {
    // Tern start at the Center, one jump from Orcha Station.
    RunState courierAtCenter(int seed) =>
        _dismiss(engine.newRun(Species.tern, seed: seed)).clone()
          ..pending = const PendingEvent('courier_job');

    test('before the raid, the crate nearly always goes to Orcha', () {
      var toOrcha = 0;
      for (var seed = 0; seed < 40; seed++) {
        final s = engine.choose(courierAtCenter(seed), 0);
        expect(s.deliveries, hasLength(1));
        expect(s.cards, contains('parcel_sealed'));
        if (s.deliveries.single.to == Sys.orcha) toOrcha++;
      }
      expect(toOrcha, greaterThan(32));
    });

    test('after the raid, it goes anywhere nearby', () {
      var toOrcha = 0;
      for (var seed = 0; seed < 40; seed++) {
        final start = courierAtCenter(seed)..flags.add(Flag.orchaRaid);
        if (engine.choose(start, 0).deliveries.single.to == Sys.orcha) {
          toOrcha++;
        }
      }
      expect(toOrcha, lessThan(32));
    });

    test('delivering pays, and mission cargo cannot be sold', () {
      var s = engine.acknowledge(engine.choose(courierAtCenter(1), 0));
      final to = s.deliveries.single.to;
      final market = Market.roll(Sys.orcha, GameRng(1), 1);
      expect(market.buys(equipmentById('parcel_sealed')), isFalse);

      s = s.clone()
        ..location = to
        ..pending = const PendingEvent('parcel_delivered');
      final credits = s.credits;
      final after = engine.choose(s, 0);
      expect(after.credits, credits + 45);
      expect(after.cards, isNot(contains('parcel_sealed')));
      expect(after.deliveries, isEmpty);
    });

    test('opening the crate to find eggs loses the fee', () {
      var s = engine.acknowledge(engine.choose(courierAtCenter(1), 0));
      s = s.clone()..location = s.deliveries.single.to;
      for (var seed = 0; seed < 30; seed++) {
        final attempt = s.clone()
          ..rngState = seed
          ..pending = const PendingEvent('parcel_delivered');
        final after = engine.choose(attempt, 1);
        if (after.eventQueue.contains('roach_hatchling')) {
          expect(after.credits, s.credits);
          expect(after.deliveries, isEmpty);
          return;
        }
      }
      fail('never found eggs');
    });
  });
}
