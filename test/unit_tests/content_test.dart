import 'package:blue_bog/game/captain/species.dart';
import 'package:blue_bog/game/content/content.dart';
import 'package:blue_bog/game/combat/combat.dart';
import 'package:blue_bog/game/deck/loadout.dart';
import 'package:blue_bog/game/engine.dart';
import 'package:blue_bog/game/faction.dart';
import 'package:blue_bog/game/galaxy/galaxy.dart';
import 'package:blue_bog/game/rng.dart';
import 'package:blue_bog/game/run_state.dart';
import 'package:blue_bog/game/story/keys.dart';
import 'package:blue_bog/game/story/rules.dart';
import 'package:blue_bog/game/story/story.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ids = {for (final e in storyContent.events) e.id};

  Iterable<Effect> flatten(Iterable<Effect> effects) sync* {
    for (final e in effects) {
      yield e;
      if (e case Combat(:final win, :final lose)) {
        yield* flatten([...win, ...lose]);
      }
    }
  }

  test('event ids are unique', () {
    expect(ids.length, storyContent.events.length);
  });

  test('every referenced event exists', () {
    final referenced = <String>{
      storyContent.openingEvent,
      storyContent.hellEntryEvent,
      storyContent.codeGreenEvent,
      storyContent.mutinyEvent,
      for (final b in storyContent.beats)
        if (b.localEvent != null) b.localEvent!.$2,
      for (final effect in [
        for (final b in storyContent.beats) ...[
          ...b.effects,
          for (final o in b.outcomes) ...o.effects,
        ],
        for (final e in storyContent.events)
          for (final c in e.choices)
            for (final o in c.outcomes) ...o.effects,
      ])
        for (final inner in flatten([effect]))
          if (inner case QueueEvent(:final eventId)) eventId,
    };
    expect(ids, containsAll(referenced));
  });

  test('every choice has at least one outcome', () {
    for (final e in storyContent.events) {
      expect(e.choices, isNotEmpty, reason: e.id);
      for (final c in e.choices) {
        expect(c.outcomes, isNotEmpty, reason: '${e.id}: ${c.label}');
      }
    }
  });

  test('there is always a repeatable event wherever you are in Hell', () {
    final base = GameEngine(storyContent).newRun(Species.tern, seed: 1);
    for (final zone in HellZone.values) {
      for (final act in [1, 2, 3]) {
        for (final pulled in [false, true]) {
          for (final humans in [0, 9]) {
            if (pulled && zone == HellZone.pipe) continue;
            final s = base.clone()
              ..hell = zone
              ..act = act
              ..humans = HumanResources(count: humans, loyalty: 50, drift: 0);
            if (pulled) s.flags.add(Flag.mournerPull);
            final options = storyContent.events.where(
              (e) =>
                  e.triggers.contains(Trigger.hell) &&
                  !e.once &&
                  (e.condition?.test(s) ?? true),
            );
            expect(
              options,
              isNotEmpty,
              reason: '$zone, act $act, pulled $pulled, $humans humans',
            );
          }
        }
      }
    }
  });

  test('caught by the black hole, only the Mourner comes', () {
    final s = GameEngine(storyContent).newRun(Species.tern, seed: 1).clone()
      ..hell = HellZone.deep
      ..act = 2
      ..flags.add(Flag.mournerPull);
    final options = storyContent.events.where(
      (e) =>
          e.triggers.contains(Trigger.hell) && (e.condition?.test(s) ?? true),
    );
    expect(options.map((e) => e.id), ['hell_mourner']);
  });

  test('random play never crashes and always finishes', () {
    final engine = GameEngine(storyContent);
    for (var seed = 0; seed < 150; seed++) {
      final bot = GameRng(seed + 99);
      var s = engine.newRun(Species.values[seed % 5], seed: seed);
      for (var step = 0; step < 3000 && !s.isOver; step++) {
        final pending = s.pending;
        if (pending != null) {
          s = pending.result != null
              ? engine.acknowledge(s)
              : engine.choose(s, bot.nextInt(engine.choicesFor(s).length));
        } else if (s.inHell) {
          s = engine.canCodeGreen(s) ? engine.codeGreen(s) : engine.pressOn(s);
        } else {
          if (engine.fuelForSale(s) > 0) s = engine.refuel(s);
          final routes = [
            for (final r in engine.routesFrom(s))
              if (engine.canTake(s, r)) r,
          ];
          s = bot.chance(0.2) || routes.isEmpty
              ? engine.hold(s)
              : engine.travel(s, bot.pick(routes).to);
        }
      }
      expect(s.isOver, isTrue, reason: 'seed $seed stalled on turn ${s.turn}');
    }
  });

  group('lore rules', () {
    // Every (text, effects) pair that can happen, including combat results.
    final results = <(String, List<Effect>)>[
      for (final b in storyContent.beats)
        for (final o in b.outcomes) (o.text, [...b.effects, ...o.effects]),
      for (final e in storyContent.events)
        for (final c in e.choices)
          for (final o in c.outcomes) ...[
            (o.text, o.effects),
            for (final effect in o.effects)
              if (effect case Combat(:final win))
                (win.whereType<Note>().map((n) => n.text).join(' '), win),
          ],
    ];

    bool sets(List<Effect> effects, String flag) =>
        effects.any((e) => e is SetFlag && e.flag == flag);

    test('only the Mourner can kill the Overseer', () {
      final kills = results.where((r) => sets(r.$2, Flag.overseerGone));
      expect(kills, isNotEmpty);
      for (final (text, _) in kills) {
        expect(text, contains('Mourner'));
      }
    });

    test('Shining-head only dies when his complex is destroyed', () {
      final kills = results.where((r) => sets(r.$2, Flag.shiningHeadDead));
      expect(kills, isNotEmpty);
      for (final (text, _) in kills) {
        expect(text, anyOf(contains('complex'), contains('Complex')));
      }
    });

    test('a Hellborn agent outing themselves to the Mourner is Code Green', () {
      final engine = GameEngine(storyContent);
      final s = engine.newRun(Species.gor, seed: 3).clone()
        ..pending = const PendingEvent('hell_mourner')
        ..hell = HellZone.deep
        ..act = 2
        ..humans = const HumanResources(count: 3, loyalty: 20, drift: 0);
      final without = engine.choicesFor(s).map((c) => c.label);
      expect(without, isNot(contains(contains('let them speak'))));

      s.flags.add(Flag.hellbornAgentAboard);
      final choices = engine.choicesFor(s);
      final speak = choices.indexWhere((c) => c.label.contains('let them'));
      expect(speak, isNot(-1));
      final after = engine.choose(s, speak);
      expect(after.inHell, isFalse);
      expect(after.has(Flag.codeGreenUsed), isTrue);
      expect(after.has(Flag.mournerLore), isTrue);
      expect(after.cards.where((c) => c.startsWith('mourner')), hasLength(1));

      // Knowing how, you can ask again. The gift is never the same twice.
      final again = engine.acknowledge(after).clone()
        ..hell = HellZone.deep
        ..pending = const PendingEvent('hell_mourner');
      final ask = engine
          .choicesFor(again)
          .indexWhere((c) => c.label.startsWith('Ask politely'));
      final second = engine.choose(again, ask);
      final gifts = second.cards.where((c) => c.startsWith('mourner'));
      expect(gifts, hasLength(2));
      expect(gifts.toSet(), hasLength(2));
    });

    test('losing every human loses any agent among them', () {
      final engine = GameEngine(storyContent);
      final s = engine.newRun(Species.tern, seed: 3).clone()
        ..flags.add(Flag.hellbornAgentAboard)
        ..pending = const PendingEvent('mutiny');
      final leave = engine
          .choicesFor(s)
          .indexWhere((c) => c.label.contains('next port'));
      expect(engine.choose(s, leave).has(Flag.hellbornAgentAboard), isFalse);
    });

    test('a captain can destroy the complex and end the Uploaded', () {
      final engine = GameEngine(storyContent);
      final s = engine.newRun(Species.gor, seed: 3).clone()
        ..location = Sys.neoTerra
        ..flags.addAll([Flag.neoTerraClaimed, Flag.uploadedFormed])
        ..control[Sys.neoTerra] = Faction.uploaded;
      final event = engine.event('deep_complex');
      expect(event.condition!.test(s), isTrue);

      // A ship strong enough to win.
      final strong = s.clone()
        ..loadout = Loadout(
          slots: [
            'laser_3',
            'laser_3',
            'shield_3',
            'plating_3',
            'bunks_1',
            'laser_3',
            null,
            null,
            null,
          ],
        )
        ..pending = const PendingEvent('deep_complex');
      final after = engine.choose(strong, 0);
      expect(after.lastCombat!.result.outcome, CombatOutcome.win);
      expect(after.has(Flag.shiningHeadDead), isTrue);
      expect(after.control[Sys.neoTerra], Faction.colonists);
      expect(after.has(Flag.overseerGone), isFalse);
    });
  });
}
