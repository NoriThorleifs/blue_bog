import 'package:blue_bog/game_engine/captain/species.dart';
import 'package:blue_bog/game_engine/content/content.dart';
import 'package:blue_bog/game_engine/engine.dart';
import 'package:blue_bog/game_engine/faction.dart';
import 'package:blue_bog/game_engine/galaxy/galaxy.dart';
import 'package:blue_bog/game_engine/run_state.dart';
import 'package:blue_bog/game_engine/story/keys.dart';
import 'package:blue_bog/game_engine/story/rules.dart';
import 'package:blue_bog/game_engine/story/story.dart';
import 'package:flutter_test/flutter_test.dart';

/// Content with a scripted event so engine rules can be tested in isolation.
StoryContent _content({
  List<GameEvent> events = const [],
  List<StoryBeat> beats = const [],
}) => StoryContent(
  events: [
    for (final id in ['open', 'breach', 'green', 'mutiny'])
      GameEvent(
        id: id,
        title: id,
        text: '',
        triggers: const {Trigger.queued},
        once: false,
        choices: [Choice.simple('ok', id)],
      ),
    ...events,
  ],
  beats: beats,
  openingEvent: 'open',
  hellEntryEvent: 'breach',
  codeGreenEvent: 'green',
  mutinyEvent: 'mutiny',
  actHeadlines: const {},
  endingFor: (_) => Ending.codeYellow,
);

RunState _dismiss(GameEngine e, RunState s) {
  while (s.pending != null) {
    s = s.pending!.result == null ? e.choose(s, 0) : e.acknowledge(s);
  }
  return s;
}

void main() {
  group('new run', () {
    final engine = GameEngine(storyContent);

    test('starts each species at its home system', () {
      for (final species in Species.values) {
        final s = engine.newRun(species, seed: 3);
        expect(s.location, species.home);
        expect(s.humans.count, species.startingHumans);
        expect(s.flags, containsAll(Flag.history));
      }
    });

    test('opens with the opening event', () {
      final s = engine.newRun(Species.tern, seed: 3);
      expect(s.pending?.eventId, 'opening');
      expect(engine.canAct(s), isFalse);
    });

    test('reveals act 1 except Neo Terra, plus Træ Træ Tene', () {
      final s = engine.newRun(Species.tern, seed: 3);
      expect(s.revealed, isNot(contains(Sys.neoTerra)));
      expect(s.revealed, isNot(contains(Sys.elephantHq)));
      expect(s.revealed, containsAll([Sys.urGor, Sys.traeTraeTene]));
      expect(s.revealed, isNot(contains(Sys.ulamora)));
      expect(s.revealed, isNot(contains(Sys.sol)));
    });
  });

  group('travel', () {
    final engine = GameEngine(_content());

    test('a gateway jump ends the turn and moves the ship', () {
      var s = _dismiss(engine, engine.newRun(Species.gor, seed: 5));
      final route = engine.routesFrom(s).firstWhere((r) => !r.isSublight);
      s = _dismiss(engine, engine.travel(s, route.to));
      expect(s.turn, 2);
      expect(s.location == route.to || s.inHell, isTrue);
    });

    test('sublight takes several turns', () {
      var s = _dismiss(engine, engine.newRun(Species.gor, seed: 5));
      final lane = s.galaxy.laneBetween(Sys.ghorDum, Sys.urGor)!;
      s = _dismiss(engine, engine.travel(s, Sys.urGor));
      expect(s.location, Sys.urGor);
      expect(s.turn, 1 + lane.turns);
    });

    test('hidden systems and unconnected systems are unreachable', () {
      final s = _dismiss(engine, engine.newRun(Species.al, seed: 5));
      expect(s.location, Sys.orcha);
      expect(
        engine.routesFrom(s).map((r) => r.to),
        isNot(contains(Sys.neoTerra)),
      );
      expect(() => engine.travel(s, Sys.kepler), throwsA(isA<IllegalMove>()));
    });

    test('cannot travel while an event is pending', () {
      final s = engine.newRun(Species.al, seed: 5);
      expect(() => engine.travel(s, Sys.center), throwsA(isA<IllegalMove>()));
    });

    test('does not mutate the state it was given', () {
      final before = _dismiss(engine, engine.newRun(Species.tern, seed: 9));
      final turn = before.turn;
      final log = before.log.length;
      engine.hold(before);
      expect(before.turn, turn);
      expect(before.log.length, log);
    });
  });

  group('hell', () {
    final engine = GameEngine(
      _content(
        events: [
          const GameEvent(
            id: 'escape',
            title: 'escape',
            text: '',
            triggers: {Trigger.hell},
            once: false,
            choices: [
              Choice(
                'out',
                outcomes: [
                  Outcome('', effects: [EscapeHell()]),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    RunState inHell(int seed, {int act = 1}) {
      final s = _dismiss(
        engine,
        engine.newRun(Species.tern, seed: seed),
      ).clone();
      s
        ..hell = HellZone.pipe
        ..act = act;
      return s;
    }

    test('escaping in act 1 always lands in the act 1 network', () {
      for (var seed = 0; seed < 60; seed++) {
        var s = engine.pressOn(inHell(seed));
        s = _dismiss(engine, s);
        expect(s.inHell, isFalse);
        expect(s.galaxy[s.location].act, 1, reason: 'seed $seed');
        expect(engine.routesFrom(s), isNotEmpty);
      }
    });

    test('Hell damages the hull every turn', () {
      final s = inHell(1);
      final after = engine.pressOn(s);
      expect(after.hull, lessThan(s.hull));
    });

    test('Code Green needs Hell and a strong bond with the humans', () {
      final s = inHell(2)
        ..humans = const HumanResources(count: 18, loyalty: 90, drift: 0);
      expect(engine.canCodeGreen(s), isTrue);
      expect(engine.codeGreen(s).pending?.eventId, 'green');

      final weak = s.clone()
        ..humans = const HumanResources(count: 18, loyalty: 30, drift: 0);
      expect(engine.canCodeGreen(weak), isFalse);

      final outside = s.clone()..hell = null;
      expect(engine.canCodeGreen(outside), isFalse);

      final used = s.clone()..flags.add(Flag.codeGreenUsed);
      expect(engine.canCodeGreen(used), isFalse);
    });
  });

  group('humans', () {
    final engine = GameEngine(_content());

    test('a mutiny is queued when loyalty collapses', () {
      final s = _dismiss(engine, engine.newRun(Species.gor, seed: 1)).clone()
        ..humans = const HumanResources(count: 5, loyalty: 5, drift: 0);
      expect(engine.hold(s).pending?.eventId, 'mutiny');
    });

    test('no humans, no mutiny', () {
      final s = _dismiss(engine, engine.newRun(Species.gor, seed: 1)).clone()
        ..humans = const HumanResources(count: 0, loyalty: 0, drift: 0);
      expect(engine.hold(s).pending, isNull);
    });

    test('bond saturates at a full crew', () {
      const small = HumanResources(count: 9, loyalty: 80, drift: 0);
      const full = HumanResources(count: 18, loyalty: 80, drift: 0);
      const huge = HumanResources(count: 27, loyalty: 80, drift: 0);
      expect(small.bond, 40);
      expect(full.bond, 80);
      expect(huge.bond, 80);
    });

    test('bondWeight shifts outcome odds toward the humans', () {
      final eng = GameEngine(
        _content(
          events: [
            GameEvent(
              id: 'coin',
              title: 'coin',
              text: '',
              triggers: const {Trigger.queued},
              once: false,
              choices: [
                Choice(
                  'flip',
                  outcomes: [
                    Outcome('human', bondWeight: 4, effects: [SetFlag('h')]),
                    Outcome('other', effects: [SetFlag('o')]),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
      int humanWins(int loyalty) {
        var wins = 0;
        for (var seed = 0; seed < 300; seed++) {
          final s = _dismiss(eng, eng.newRun(Species.tern, seed: seed)).clone()
            ..humans = HumanResources(count: 18, loyalty: loyalty, drift: 0)
            ..pending = const PendingEvent('coin');
          final after = eng.choose(s, 0);
          if (after.has('h')) wins++;
        }
        return wins;
      }

      expect(humanWins(100), greaterThan(humanWins(0) + 60));
    });
  });

  group('story beats', () {
    test('deadlines force a beat to fire', () {
      final engine = GameEngine(
        _content(
          beats: [
            const StoryBeat(
              id: 'late',
              headline: 'late',
              condition: TurnAtLeast(1),
              chance: 0,
              deadline: 3,
              effects: [SetFlag('fired')],
            ),
          ],
        ),
      );
      var s = _dismiss(engine, engine.newRun(Species.bhrun, seed: 1));
      for (var i = 0; i < 3; i++) {
        expect(s.has('fired'), isFalse);
        s = _dismiss(engine, engine.hold(s));
      }
      s = _dismiss(engine, engine.hold(s));
      expect(s.has('fired'), isTrue);
    });

    test('restoring the Træ Træ Tene gateway starts act 2', () {
      final engine = GameEngine(
        _content(
          beats: [
            const StoryBeat(
              id: 'open',
              headline: 'open',
              condition: TurnAtLeast(2),
              chance: 1,
              effects: [RestoreGateway(Sys.center, Sys.traeTraeTene)],
            ),
          ],
        ),
      );
      var s = _dismiss(engine, engine.newRun(Species.tern, seed: 4));
      s = _dismiss(engine, engine.hold(s));
      expect(s.act, 2);
      expect(s.revealed, contains(Sys.ulamora));
      expect(engine.routesFrom(s).map((r) => r.to), contains(Sys.traeTraeTene));
    });

    test('opening a bridge to Kyndari starts act 3 and reveals Sol', () {
      final engine = GameEngine(
        _content(
          beats: [
            const StoryBeat(
              id: 'open',
              headline: 'open',
              condition: TurnAtLeast(2),
              chance: 1,
              effects: [
                RestoreGateway(Sys.center, Sys.traeTraeTene),
                RestoreDeadGateway(towardAct: 3),
              ],
            ),
          ],
        ),
      );
      for (var seed = 0; seed < 40; seed++) {
        var s = _dismiss(engine, engine.newRun(Species.tern, seed: seed));
        s = _dismiss(engine, engine.hold(s));
        expect(s.act, 3, reason: 'seed $seed');
        expect(s.revealed, containsAll([Sys.kyndari, Sys.sol]));
        expect(s.has(Flag.kyndariRevealed), isTrue);
      }
    });
  });

  group('endings', () {
    final s = GameEngine(storyContent).newRun(Species.tern, seed: 1);

    test('eviction from Kepler means Code Red', () {
      final evicted = s.clone()
        ..flags.addAll([Flag.keplerEvicted, Flag.humansGrantedPlanet])
        ..counters[Counter.republicStance] = 50;
      expect(endingFor(evicted), Ending.codeRed);
    });

    test('Code Blue needs a planet and the Republic\'s trust', () {
      final trusted = s.clone()..counters[Counter.republicStance] = 40;
      expect(endingFor(trusted), Ending.codeYellow);
      trusted.flags.add(Flag.humansGrantedPlanet);
      expect(endingFor(trusted), Ending.codeBlue);
    });

    test('a hostile Republic means Code Red', () {
      final hostile = s.clone()..counters[Counter.republicStance] = -40;
      expect(endingFor(hostile), Ending.codeRed);
    });
  });

  group('factions', () {
    RunState after(List<Effect> effects, {int seed = 4}) {
      final engine = GameEngine(
        _content(
          beats: [
            StoryBeat(
              id: 'go',
              headline: 'go',
              condition: const TurnAtLeast(2),
              chance: 1,
              effects: effects,
            ),
          ],
        ),
      );
      final s = _dismiss(engine, engine.newRun(Species.tern, seed: seed));
      return _dismiss(engine, engine.hold(s));
    }

    test('everyone starts in their lore faction', () {
      final s = GameEngine(storyContent).newRun(Species.tern, seed: 2);
      expect(s.control[Sys.center], Faction.republic);
      expect(s.control[Sys.kepler], Faction.colonists);
      expect(s.control[Sys.sol], Faction.solarHumans);
      expect(s.control[Sys.elephantHq], Faction.houseOfTheElephant);
      expect(s.control[Sys.ulamora], Faction.unaligned);
      expect(s.control[Sys.kyndari], Faction.ruins);
    });

    test('expansion takes gateway neighbours, one hop per turn', () {
      final s = after([
        const SetControl(Sys.center, Faction.hellborn),
        const Expand(Faction.hellborn, chance: 1),
      ]);
      final neighbours = {
        for (final g in s.galaxy.gatewaysOf(Sys.center))
          if (s.isGatewayActive(g)) g.other(Sys.center),
      };
      final held = s.control.entries
          .where((e) => e.value == Faction.hellborn)
          .map((e) => e.key)
          .toSet();
      expect(held, {Sys.center, ...neighbours});
    });

    test('only restricts what can be taken', () {
      final s = after([
        const SetControl(Sys.center, Faction.hellborn),
        const Expand(Faction.hellborn, chance: 1, only: Faction.unaligned),
      ]);
      expect(
        s.control.values.where((f) => f == Faction.hellborn),
        hasLength(1),
      );
    });

    test('a breach hands both ends of gateways to the attacker', () {
      final s = after([const Breach(Faction.demons, 3)]);
      final held = s.control.values.where((f) => f == Faction.demons).length;
      expect(held, inInclusiveRange(2, 6));
    });

    test('a war-starting code keeps the run going', () {
      final engine = GameEngine(storyContent);
      final s = _dismiss(engine, engine.newRun(Species.tern, seed: 1)).clone()
        ..counters[Counter.republicStance] = -60
        ..pending = const PendingEvent('the_code');
      final next = engine.choose(s, 0);
      expect(next.isOver, isFalse);
      expect(next.has(Flag.warRed), isTrue);
      expect(next.control[Sys.kyndari], Faction.hellborn);
    });
  });
}
