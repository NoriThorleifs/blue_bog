import 'package:blue_bog/game_engine/combat/catalog.dart';
import 'package:blue_bog/game_engine/combat/combat.dart';
import 'package:flutter_test/flutter_test.dart';

Combatant ship(
  List<String> ids, {
  int hull = 100000,
  String name = 'ship',
  List<String> hold = const [],
}) => Combatant(
  name: name,
  loadout: CombatLoadout.of(ids, hold: hold),
  baseHull: hull,
);

/// A target that never shoots back.
Combatant target(
  List<String> ids, {
  int hull = 100000,
  List<String> hold = const [],
}) => ship(ids, hull: hull, name: 'target', hold: hold);

void main() {
  test('shields absorb laser damage before the hull', () {
    // Shield charges to 30 at 6 s. The upgraded laser (90) fires at 5 s,
    // 10 s, ...: the shot at 10 s loses 30 to the shield.
    final r = fight(ship(['laser_2']), target(['shield_1']));
    final atTen = r.events.firstWhere((e) => e.time == 10 && e.side == 0);
    expect(atTen.kind, CombatEventKind.laserHit);
    expect(atTen.value, 60);
  });

  test('shields refill to the maximum from every generator, not beyond', () {
    final r = fight(ship([]), target(['shield_1', 'shield_1']));
    final charges = r.events
        .where((e) => e.kind == CombatEventKind.shieldsCharged)
        .map((e) => e.value)
        .toSet();
    expect(charges, {60});
  });

  test('missiles ignore shields', () {
    final r = fight(
      ship(['missiles_1', 'missile_crate_2']),
      target(['shield_3']),
    );
    expect(r.events.where((e) => e.side == 0).map((e) => e.kind).toSet(), {
      CombatEventKind.missileHit,
    });
  });

  test('each drone stops one missile, however big', () {
    final r = fight(
      ship(['missiles_3', 'missile_crate_1']),
      target(['fabricator_1', 'feedstock_1']),
    );
    final first = r.events.firstWhere((e) => e.side == 0);
    // The drone is built at 8 s; the first missile at 6 s gets through, the
    // one at 12 s is intercepted.
    expect(first.kind, CombatEventKind.missileHit);
    expect(
      r.events.firstWhere((e) => e.side == 0 && e.time == 12).kind,
      CombatEventKind.missileIntercepted,
    );
  });

  test(
    'a merged fabricator builds as many drones as the three it replaced',
    () {
      int interceptions(String fabricator, String feedstock) {
        final r = fight(
          ship(
            ['missiles_1', 'missiles_1', 'missiles_1'],
            hold: ['missile_crate_2'],
          ),
          target([fabricator], hold: [feedstock]),
        );
        return r.events
            .where((e) => e.kind == CombatEventKind.missileIntercepted)
            .length;
      }

      final three =
          fight(
                ship(
                  ['missiles_1', 'missiles_1', 'missiles_1'],
                  hold: ['missile_crate_2'],
                ),
                target(
                  ['fabricator_1', 'fabricator_1', 'fabricator_1'],
                  hold: ['feedstock_2'],
                ),
              ).events
              .where((e) => e.kind == CombatEventKind.missileIntercepted)
              .length;
      expect(interceptions('fabricator_2', 'feedstock_2'), three);
      expect(
        interceptions('fabricator_2', 'feedstock_2'),
        greaterThan(interceptions('fabricator_1', 'feedstock_2')),
      );
    },
  );

  test('a Swarm Mother puts out nine drones at once', () {
    final r = fight(
      ship(['laser_1']),
      target(['fabricator_3'], hold: ['feedstock_2']),
    );
    final first = r.events.firstWhere(
      (e) => e.kind == CombatEventKind.droneBuilt,
    );
    expect(first.value, 9);
  });

  test('drones out patch the hull a little every second', () {
    final hurt = Combatant(
      name: 'hurt',
      loadout: CombatLoadout.of(['fabricator_2'], hold: ['feedstock_2']),
      hull: 200,
    );
    final r = fight(hurt, target(['plating_1']));
    // Three drones from the first build at 8 s, one hull each per second
    // for the remaining 53 seconds.
    expect(r.hull, 200 + 3 * 53);
  });

  test('shield capacitors speed up shield generators in their triangle', () {
    double firstCharge(List<String?> slots) => fight(
      Combatant(
        name: 'me',
        loadout: CombatLoadout([
          ...slots,
          ...List.filled(9 - slots.length, null),
        ]),
      ),
      target([]),
    ).events.firstWhere((e) => e.kind == CombatEventKind.shieldsCharged).time;
    expect(firstCharge(['shield_1']), 6);
    expect(firstCharge(['shield_1', 'shield_capacitor_1']), closeTo(4.8, 0.05));
    expect(
      firstCharge(['shield_1', null, null, 'shield_capacitor_1']),
      6,
      reason: 'only its own triangle',
    );
  });

  test('shields grow faster than lasers as they merge', () {
    for (final (tier, shield) in [(1, 30), (2, 105), (3, 360)]) {
      expect(equipmentById('shield_$tier').maxShield, shield);
    }
    // A super laser shot against a super shield is stopped outright.
    expect(equipmentById('laser_3').damage, lessThan(360));
  });

  test('teleported bombs go through shields and drones', () {
    final r = fight(
      ship(['teleporter_1', 'teleport_charges_1']),
      target(['shield_3', 'fabricator_3', 'feedstock_3']),
    );
    final hit = r.events.firstWhere((e) => e.side == 0);
    expect(hit.kind, CombatEventKind.teleportHit);
    expect(hit.time, 24);
    expect(hit.value, 240);
  });

  test('quick-arm fuzes let small missiles fire first and soak up drones', () {
    // Triangle 0: a basic rack with fuzes. Triangle 1: an upgraded rack,
    // too big for the fuzes. The small missile now leads.
    final loadout = [
      'missiles_1', 'quick_fuzes_1', 'missile_crate_2', //
      'missiles_2', null, null,
    ];
    final r = fight(
      Combatant(
        name: 'me',
        loadout: CombatLoadout([
          ...loadout,
          ...List.filled(9 - loadout.length, null),
        ]),
        baseHull: 100000,
      ),
      target(['fabricator_1', 'feedstock_1']),
    );
    final shots = r.events.where((e) => e.side == 0).toList();
    expect(shots.first.time, lessThan(6));
    expect(shots.first.value, 45);
  });

  test('charge boosts cannot cut a cooldown below half', () {
    // Three fire controls in one triangle would be 45% each.
    final r = fight(
      Combatant(
        name: 'me',
        loadout: CombatLoadout([
          'laser_1', 'fire_control_3', 'fire_control_3', //
          ...List.filled(6, null),
        ]),
        baseHull: 100000,
      ),
      target([]),
    );
    final first = r.events.firstWhere((e) => e.side == 0);
    expect(first.time, 2.5);
  });

  test('weapons without ammo do nothing', () {
    final r = fight(ship(['missiles_1']), target([]));
    expect(r.events.every((e) => e.kind == CombatEventKind.outOfAmmo), isTrue);
    expect(r.enemyHull, 100000);
  });

  test('after a minute both ships get away', () {
    final r = fight(ship(['laser_1']), target([]));
    expect(r.outcome, CombatOutcome.escape);
    expect(r.seconds, combatTimeLimit);
  });

  test('a tractor beam holds both ships until one dies', () {
    final r = fight(
      ship(['laser_1']),
      target([], hull: 600),
      tractorBeam: true,
    );
    expect(r.outcome, CombatOutcome.win);
    expect(r.seconds, greaterThan(combatTimeLimit));
  });

  test('damage carries over: a ship can start a fight already hurt', () {
    final hurt = Combatant(
      name: 'hurt',
      loadout: CombatLoadout.of([]),
      hull: 30,
    );
    final r = fight(hurt, ship(['laser_1']));
    expect(r.outcome, CombatOutcome.loss);
    expect(r.seconds, 5);
  });

  test('every captain has at least 500 hull', () {
    expect(Combatant(name: 'x', loadout: CombatLoadout.of([])).maxHull, 500);
  });

  group('ion, flak, repair, lances and jammers', () {
    List<CombatEvent> by(CombatResult r, int side, CombatEventKind kind) => [
      for (final e in r.events)
        if (e.side == side && e.kind == kind) e,
    ];

    test(
      'an ion blast strips shields, and a third of the rest gets through',
      () {
        // At 4 s there's no shield yet: 45 / 3 = 15. At 8 s the shield (30)
        // takes 30 and 15 / 3 = 5 gets through.
        final r = fight(ship(['ion_1']), target(['shield_1']));
        final hits = by(r, 0, CombatEventKind.ionHit);
        expect(hits[0].value, 15);
        expect(hits[1].value, 5);
      },
    );

    test('flak shoots down drones, and bursts on the hull without them', () {
      final r = fight(
        ship(['flak_1']),
        target(['fabricator_1'], hold: ['feedstock_1']),
      );
      expect(by(r, 0, CombatEventKind.flakShrapnel).first.time, 4);
      expect(by(r, 0, CombatEventKind.flakHit).first.time, 8);
    });

    test('a repair bay patches hull, but not past the maximum', () {
      final r = fight(
        Combatant(
          name: 'me',
          loadout: CombatLoadout.of(['repair_1']),
          hull: 450,
        ),
        target([]),
      );
      expect(by(r, 0, CombatEventKind.repaired).map((e) => e.value), [30, 20]);
      expect(r.hull, 500);
    });

    test('a lance hits harder with every shot', () {
      final r = fight(ship(['lance_1']), target([]));
      expect(by(r, 0, CombatEventKind.laserHit).take(3).map((e) => e.value), [
        10,
        15,
        20,
      ]);
    });

    test('a rail slug lands in full on bare hull', () {
      final r = fight(ship(['rail_1']), target([]));
      final hits = by(r, 0, CombatEventKind.railHit);
      expect(hits.first.time, 9);
      expect(hits.first.value, 100);
    });

    test('any shield at all deflects a rail slug, and keeps its charge', () {
      // The shield charges at 6 s, before the slug arrives at 9 s.
      final r = fight(ship(['rail_1']), target(['shield_1']));
      expect(by(r, 0, CombatEventKind.railHit), isEmpty);
      expect(by(r, 0, CombatEventKind.railDeflected), isNotEmpty);
      expect(r.at(9).shield[1], 30);
    });

    test('an ion cannon strips the shield so the slug gets through', () {
      // Ion fires at 8 s and takes the shield to 0 just before the slug.
      final r = fight(ship(['rail_1', 'ion_1']), target(['shield_1']));
      expect(by(r, 0, CombatEventKind.railHit).first.time, 9);
    });

    test('a jammer stops teleport bombs, but not Nobody', () {
      final r = fight(
        ship(['teleporter_1', 'teleport_charges_1']),
        target(['jammer_1']),
      );
      expect(by(r, 0, CombatEventKind.teleportJammed), isNotEmpty);
      expect(by(r, 0, CombatEventKind.teleportHit), isEmpty);
      final boarded = fight(
        ship(['jammer_3', 'jammer_3']),
        ship(['nobody_boarding_teleporter']),
        tractorBeam: true,
      );
      expect(boarded.outcome, CombatOutcome.loss);
      expect(boarded.seconds, 40);
    });
  });
}
