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
    // Shield charges to 30 at 6 s. The upgraded laser (120) fires at 4 s,
    // 8 s, ...: the shot at 8 s loses 30 to the shield.
    final r = fight(ship(['laser_2']), target(['shield_1']));
    final atEight = r.events.firstWhere((e) => e.time == 8 && e.side == 0);
    expect(atEight.kind, CombatEventKind.laserHit);
    expect(atEight.value, 90);
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
      ship(['missiles_2', 'missile_crate_1']),
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

  test('a merged fabricator builds more drones than the three it replaced', () {
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

    final three = fight(
      ship(
        ['missiles_1', 'missiles_1', 'missiles_1'],
        hold: ['missile_crate_2'],
      ),
      target(
        ['fabricator_1', 'fabricator_1', 'fabricator_1'],
        hold: ['feedstock_2'],
      ),
    ).events.where((e) => e.kind == CombatEventKind.missileIntercepted).length;
    expect(interceptions('fabricator_2', 'feedstock_2'), greaterThan(three));
    expect(
      interceptions('fabricator_2', 'feedstock_2'),
      greaterThan(interceptions('fabricator_1', 'feedstock_2')),
    );
  });

  test('a Swarm Mother puts out sixteen drones at once', () {
    final r = fight(
      ship(['laser_1']),
      target(['fabricator_3'], hold: ['feedstock_2']),
    );
    final first = r.events.firstWhere(
      (e) => e.kind == CombatEventKind.droneBuilt,
    );
    expect(first.value, 16);
  });

  test('drones out patch the hull a little every second', () {
    final hurt = Combatant(
      name: 'hurt',
      loadout: CombatLoadout.of(['fabricator_1'], hold: ['feedstock_1']),
      hull: 200,
    );
    final r = fight(hurt, target(['plating_1']));
    // One drone from the first build at 8 s, one hull a second for the
    // remaining 53 seconds.
    expect(r.hull, 200 + 53);
  });

  test('a Drone Foundry\'s drones patch twice as much', () {
    final hurt = Combatant(
      name: 'hurt',
      loadout: CombatLoadout.of(['fabricator_2'], hold: ['feedstock_1']),
      baseHull: 1000,
      hull: 200,
    );
    final r = fight(hurt, target(['plating_1']));
    // Four drones at 8 s, two hull each a second for 53 seconds.
    expect(r.hull, 200 + 4 * 2 * 53);
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
    for (final (tier, shield) in [(1, 30), (2, 140), (3, 600)]) {
      expect(equipmentById('shield_$tier').maxShield, shield);
    }
    // A super laser shot against a super shield is stopped outright.
    expect(equipmentById('laser_3').damage, lessThan(600));
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
      'missiles_1', 'quick_fuzes_1', 'missile_crate_1', //
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

  double firstShot(List<String?> topTriangle) {
    final r = fight(
      Combatant(
        name: 'me',
        loadout: CombatLoadout([...topTriangle, ...List.filled(6, null)]),
        baseHull: 100000,
      ),
      target([]),
    );
    return r.events.firstWhere((e) => e.side == 0).time;
  }

  test('charge boosts stack past half a cooldown', () {
    // Two Targeting Suites at 30% each: a 5 s laser fires every 2 s.
    expect(firstShot(['laser_1', 'fire_control_2', 'fire_control_2']), 2.0);
  });

  test('but no card fires more than once a second', () {
    // Two Ternary Directors at 45% each would leave half a second.
    expect(
      firstShot(['laser_1', 'fire_control_3', 'fire_control_3']),
      minCooldown,
    );
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

  group('merge perks', () {
    List<CombatEvent> mine(CombatResult r) =>
        r.events.where((e) => e.side == 0).toList();

    test('armour takes a little off every hit, but never more than half', () {
      int firstHit(List<String> plating) =>
          mine(fight(ship(['laser_1']), target(plating))).first.value!;
      expect(firstHit([]), 30);
      expect(firstHit(['plating_2']), 26);
      expect(firstHit(['plating_3']), 18);
      expect(firstHit(['plating_3', 'plating_3']), 15);
    });

    test('a super missile a drone stops still hits for half', () {
      // The drone is out at 8 s; the missile at 12 s goes through it.
      final r = fight(
        ship(['missiles_3']),
        target(['fabricator_1', 'feedstock_1']),
      );
      final atTwelve = mine(r).firstWhere((e) => e.time == 12);
      expect(atTwelve.kind, CombatEventKind.missileHit);
      expect(atTwelve.value, equipmentById('missiles_3').damage! ~/ 2);
    });

    test(
      'super teleport bombs bring their own charges and can\'t be jammed',
      () {
        final r = fight(ship(['teleporter_3']), target(['jammer_1']));
        expect(mine(r).first.kind, CombatEventKind.teleportHit);
      },
    );

    test('a Null Lattice sends jammed bombs home', () {
      final r = fight(
        ship(['teleporter_1', 'teleport_charges_1']),
        target(['jammer_3']),
      );
      expect(mine(r).first.kind, CombatEventKind.teleportJammed);
      final back = r.events.firstWhere(
        (e) => e.side == 1 && e.kind != CombatEventKind.jamsReady,
      );
      expect(back.kind, CombatEventKind.teleportHit);
      expect(back.value, 240);
    });

    test('a Barrier Cathedral patches the hull when the shields are full', () {
      final hurt = Combatant(
        name: 'hurt',
        loadout: CombatLoadout.of(['shield_3']),
        baseHull: 1000,
        hull: 200,
      );
      final r = fight(hurt, target([]));
      // Charges every 3.9 s: 15 times, and all but the first find the
      // shields full.
      expect(r.hull, 200 + 14 * 40);
    });

    test('capacitor rings start the fight with the shields up', () {
      final r = fight(ship(['laser_1']), target(['shield_capacitor_2']));
      expect(mine(r).first.kind, CombatEventKind.laserAbsorbed);
    });

    test('regenerating shields keep up with a basic laser', () {
      final r = fight(ship(['laser_1']), target(['shield_capacitor_3']));
      expect(
        mine(r).every((e) => e.kind == CombatEventKind.laserAbsorbed),
        isTrue,
      );
    });

    test('a living hull regrows', () {
      final hurt = Combatant(
        name: 'hurt',
        loadout: CombatLoadout.of(['metal_flesh_2']),
        hull: 200,
      );
      expect(fight(hurt, target([])).hull, 200 + 3 * 60);
    });

    test('frenzied weapons hit harder with every shot this fight', () {
      final r = fight(ship(['teeth_2']), target([]));
      expect(mine(r).take(3).map((e) => e.value), [72, 74, 76]);
    });

    test('veteran lances ramp in the fight and count their shots', () {
      final r = fight(ship(['lance_2']), target([]));
      // 40 damage, 20 more a shot from the lance, 2 more from the perk.
      expect(mine(r).take(3).map((e) => e.value), [40, 62, 84]);
      expect(r.shots.first, 10);
    });

    test('fire control makes the weapons in its triangle hit harder', () {
      int firstHit(String fireControl) =>
          mine(fight(ship(['laser_1', fireControl]), target([]))).first.value!;
      expect(firstHit('fire_control_1'), 30);
      expect(firstHit('fire_control_2'), 34);
      expect(firstHit('fire_control_3'), 42);
    });

    test('a Sky Shredder\'s shrapnel passes shields', () {
      int atSix(String flak) => mine(
        fight(ship([flak]), target(['shield_1'])),
      ).firstWhere((e) => e.time == 6).value!;
      expect(atSix('flak_2'), 4 * 10 - 30);
      expect(atSix('flak_3'), 16 * 10);
    });

    test('a Storm Engine\'s leftover hits the hull in full', () {
      int firstHit(String ion) =>
          mine(fight(ship([ion]), target([]))).first.value!;
      expect(firstHit('ion_2'), 180 ~/ 3);
      expect(firstHit('ion_3'), 720);
    });

    test('a Mass Accelerator\'s deflected slug knocks the shields out', () {
      final r = fight(ship(['rail_3']), target(['shield_1']));
      final deflected = mine(r).first;
      expect(deflected.kind, CombatEventKind.railDeflected);
      expect(r.at(deflected.time).shield[1], 0);
    });

    test('merged missile crates make every missile hit harder, from the '
        'hold', () {
      int firstHit(String crate) => mine(
        fight(ship(['missiles_1'], hold: [crate]), target([])),
      ).first.value!;
      expect(firstHit('missile_crate_1'), 45);
      expect(firstHit('missile_crate_2'), 45 * 115 ~/ 100);
      expect(firstHit('missile_crate_3'), 45 * 140 ~/ 100);
    });

    test('merging supplies never loses ammo', () {
      for (final family in ['missile_crate', 'teleport_charges', 'feedstock']) {
        final [one, three, nine] = [
          for (var t = 1; t <= 3; t++)
            equipmentById('${family}_$t').ammo.values.single,
        ];
        expect(three, greaterThanOrEqualTo(3 * one), reason: family);
        expect(nine, greaterThanOrEqualTo(3 * three), reason: family);
      }
    });

    test('merged feedstock has drones out before the first missile', () {
      final r = fight(
        ship(['missiles_1', 'missile_crate_1']),
        target(['fabricator_1', 'fabricator_1'], hold: ['feedstock_2']),
      );
      expect(r.at(0).drones[1], 2, reason: 'as many as there is room for');
      expect(mine(r).first.kind, CombatEventKind.missileIntercepted);
    });

    test('insulated hellfire burns its own ship less', () {
      int burnt(String gun) => 100000 - fight(ship([gun]), target([])).hull;
      expect(burnt('brimstone_1'), greaterThan(0));
      // Four times the damage, so four times the burn, halved.
      expect(burnt('brimstone_2'), burnt('brimstone_1') * 2);
      expect(burnt('brimstone_3'), 0);
    });
  });
}
