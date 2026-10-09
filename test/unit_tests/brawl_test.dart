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
    for (var seed = 0; seed < 20; seed++) {
      expect(
        brawlEnemy(20, seed).hull,
        greaterThan(brawlEnemy(1, seed).hull * 5),
      );
    }
  });

  test('the same ship never comes up twice in a row', () {
    for (var seed = 0; seed < 50; seed++) {
      for (var r = 2; r <= 20; r++) {
        expect(brawlEnemy(r, seed).name, isNot(brawlEnemy(r - 1, seed).name));
      }
    }
  });

  test('late brawls meet more than the dreadnought', () {
    final names = {
      for (var seed = 0; seed < 20; seed++)
        for (var r = 11; r <= 30; r++) brawlEnemy(r, seed).name,
    };
    expect(names.length, brawlPools.last.length);
  });

  test('elites come up once, and only in their window', () {
    final s = engine.start(Species.gor, seed: 1);
    bool open(String id) => brawlEventsById[id]!.condition!(s);
    for (final (id, from, to) in [
      ('shakedown', 4, 5),
      ('gor_duel', 8, 10),
      ('unmerged_foundry', 11, 14),
    ]) {
      s
        ..flags.clear()
        ..round = from - 1;
      expect(open(id), isFalse);
      s.round = from;
      expect(open(id), isTrue);
      s.round = to + 1;
      expect(open(id), isFalse);
      s
        ..round = to
        ..flags.add(id);
      expect(open(id), isFalse);
    }
  });

  test('every elite fight pays a unique trophy', () {
    final elites = [
      for (final e in brawlEvents)
        for (final c in e.choices)
          for (final o in c.outcomes)
            for (final f in o.effects.whereType<Fight>())
              if (f.winCards.isNotEmpty) f,
    ];
    expect(elites, hasLength(3));
    for (final f in elites) {
      expect(f.special, isNotNull);
      for (final id in f.winCards) {
        expect(equipmentById(id).tier, Tier.unique);
      }
    }
  });

  test('Nobody boards at 40 seconds, and the captain is lost', () {
    final r = fight(
      Combatant(name: 'you', loadout: CombatLoadout.of(['shield_3'])),
      Combatant(name: 'Nobody', loadout: SpecialEnemy.nobody.template.loadout),
      tractorBeam: true,
    );
    expect(r.outcome, CombatOutcome.loss);
    expect(r.seconds, 40);
    expect(r.events.last.kind, CombatEventKind.boarded);
  });

  test('beating Nobody pays well, but his teleporter stays his', () {
    const id = 'nobody_boarding_teleporter';
    var wins = 0;
    for (var seed = 0; seed < 40; seed++) {
      final s = engine.start(Species.tern, seed: seed)
        ..round = 9
        ..event = 'nobody'
        ..loadout = (Loadout()
          ..add('teleporter_3')
          ..add('teleport_charges_3'));
      final after = engine.proceed(engine.choose(s, 1));
      if (after.lost) continue;
      wins++;
      expect(after.loadout.all, isNot(contains(id)));
      expect(after.flags, contains('nobody'));
    }
    expect(wins, greaterThan(0));
  });

  test('no event, shop or pool can hand out the boarding teleporter', () {
    const id = 'nobody_boarding_teleporter';
    for (final e in brawlEvents) {
      for (final c in e.choices) {
        for (final o in c.outcomes) {
          for (final effect in o.effects) {
            final ids = switch (effect) {
              GainCards(:final ids) => ids,
              GainRandom(:final pool) => pool,
              Fight(:final winCards) => winCards,
              _ => const <String>[],
            };
            expect(ids, isNot(contains(id)), reason: e.id);
          }
        }
      }
    }
    expect([
      for (final f in [...equipmentFamilies, ...hellFamilies])
        for (final t in f.tiers) t.id,
    ], isNot(contains(id)));
  });

  test('a shortage multiplies the price, a glut divides it', () {
    final seen = <SupplyShock>{};
    for (final id in brawlStations.keys) {
      for (var round = 1; round <= 60; round++) {
        final shock = supplyAt(id, 7, round);
        for (final goodId in ['goods_grain', 'goods_ice']) {
          final good = equipmentById(goodId);
          final usual = commodityPrice(good, id, 7);
          final now = commodityPrice(good, id, 7, time: round);
          if (shock?.goodId != goodId) {
            expect(now, usual);
          } else if (shock!.shortage) {
            expect(now, greaterThanOrEqualTo((usual * 2.4).floor()));
          } else {
            expect(now, lessThanOrEqualTo((usual * 0.46).ceil()));
          }
        }
        if (shock != null) seen.add(shock);
      }
    }
    expect(seen, SupplyShock.values.toSet());
  });

  test('supply shocks last a season, then move on', () {
    final seasons = [
      for (var round = 0; round < 90; round += supplySeason)
        supplyAt('orcha', 3, round),
    ];
    expect(seasons.toSet().length, greaterThan(1));
    for (var round = 0; round < 60; round++) {
      expect(
        supplyAt('orcha', 3, round),
        supplyAt('orcha', 3, round - round % supplySeason),
      );
    }
  });

  test('the galactic median ignores supply shocks', () {
    final grain = equipmentById('goods_grain');
    final median = medianPrice(grain, brawlStations.keys, 7);
    final prices = [
      for (final id in brawlStations.keys) commodityPrice(grain, id, 7),
    ]..sort();
    expect(median, inInclusiveRange(prices.first, prices.last));
  });

  test('a hauler\'s cargo is plundered when it is destroyed', () {
    final hauler = brawlPools[1].firstWhere((e) => e.cargo.isNotEmpty);
    expect(hauler.cargo, isNotEmpty);
    expect(hauler.forAct(3).cargo, hauler.cargo);
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

    test('the Mourner always gives the Hell Clock, and lets you go', () {
      for (var choice = 0; choice < 3; choice++) {
        var s = inHell('hell_mourner')..hull = 50;
        s = engine.proceed(engine.choose(s, choice));
        expect(s.lost, isFalse);
        expect(s.loadout.all, contains('hell_clock'));
        expect(s.inHell, isFalse);
        expect(s.docked, isTrue);
        expect(s.flags, contains(metMourner));
      }
    });

    test('with no room, the orb takes the cheapest card\'s place', () {
      final s = inHell('hell_mourner');
      while (s.loadout.add('plating_1') != null) {}
      final after = engine.choose(s, 0);
      expect(after.loadout.all, contains('hell_clock'));
    });

    test('the Mourner only turns up once', () {
      final s = inHell('hell_clocks')..flags.add(metMourner);
      final mourner = brawlEventsById['hell_mourner']!;
      expect(mourner.condition!(s), isFalse);
    });

    test('there is one Hell Clock per brawl, from either event', () {
      final mourner = brawlEventsById['hell_mourner']!;
      final found = inHell('hell_clocks')..flags.add(hasHellClock);
      expect(mourner.condition!(found), isFalse);
      expect(engine.canChoose(found, 1), isFalse, reason: 'no second clock');
      final fresh = inHell('hell_clocks');
      expect(engine.canChoose(fresh, 1), isTrue);
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
      expect(first.value, 32);
      expect(result.hull, lessThan(baseHull));
    });

    test(
      'the Cursed Orb fires every other Hellish-tagged card at the start',
      () {
        final result = fight(
          Combatant(
            name: 'a',
            loadout: CombatLoadout.of(['hell_clock', 'brimstone_1', 'laser_1']),
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
          loadout: CombatLoadout.of(['hell_clock', 'laser_1#hellish']),
        ),
        Combatant(name: 'b', loadout: CombatLoadout.of(['laser_1'])),
      );
      expect(result.events.first.time, 0);
      expect(result.events.first.kind, CombatEventKind.laserHit);
    });

    test('the Hell Clock starts every card half charged', () {
      final result = fight(
        Combatant(
          name: 'a',
          loadout: CombatLoadout.of(['hell_clock', 'laser_1']),
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
