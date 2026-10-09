import 'dart:math' show min;

import '../galaxy/galaxy.dart';
import '../run_state.dart';
import '../story/keys.dart';
import '../story/rules.dart';
import '../story/story.dart';
import 'effects.dart';
import 'turn.dart';

/// Between turns: arrivals, random events, wages, crew and story beats.
extension TurnFlow on EngineTurn {
  void arrive() {
    final firstVisit = s.visited.add(s.location);
    openMarket(s, rng);
    s.revealed.add(s.location);
    for (final g in s.galaxy.gatewaysOf(s.location)) {
      if (s.isGatewayActive(g)) s.revealed.add(g.other(s.location));
    }
    trigger(Trigger.arrival, firstVisit ? 0.8 : 0.55);
  }

  /// Queues an `always` event for [trigger] if one applies. Otherwise, with
  /// probability [chance], a random one.
  void trigger(Trigger trigger, double chance) {
    bool eligible(GameEvent e) =>
        e.triggers.contains(trigger) &&
        !(e.once && s.seenEvents.contains(e.id)) &&
        (e.condition?.test(s) ?? true);
    final guard = content.events.where((e) => e.always && eligible(e));
    if (guard.isNotEmpty) {
      s.eventQueue.add(guard.first.id);
      return;
    }
    if (s.eventQueue.isNotEmpty || !rng.chance(chance)) return;
    final pick = rng.weighted(
      content.events.where(
        (e) =>
            !e.always &&
            e.triggers.contains(trigger) &&
            !(e.once && s.seenEvents.contains(e.id)) &&
            (e.condition?.test(s) ?? true),
      ),
      (e) => eventWeight(s, e.weight, e.bondWeight),
    );
    if (pick != null) s.eventQueue.add(pick.id);
  }

  void endTurn() {
    s.turn++;
    payCrew();
    quietHumanInfluence();
    if (s.inHell) {
      s.hellTurns++;
      final base = s.hell == HellZone.deep ? 45 : 15;
      final damage = (base * (1 - s.stats.hellShielding)).ceil();
      apply(Hull(-damage), StringBuffer());
    }
    patchAndCrew();
    runBeats();
    if (s.humans.count > 0 &&
        s.humans.loyalty < 10 &&
        s.pending?.eventId != content.mutinyEvent &&
        !s.eventQueue.contains(content.mutinyEvent)) {
      s.eventQueue.insert(0, content.mutinyEvent);
    }
  }

  /// Between turns the humans patch the ship, though never past 75% of its
  /// hull, and empty berths slowly fill: faster where humans live, and the
  /// better the humans aboard think of you.
  void patchAndCrew() {
    final stats = s.stats;
    final patchTo = (stats.maxHull * 0.75).floor();
    if (s.hull < patchTo && s.humans.count > 0) {
      s.hull = min(patchTo, s.hull + 2 * s.humans.count);
    }
    if (s.inHell) return;
    final free = stats.berths - s.humans.count;
    if (free <= 0) return;
    final odds =
        (0.05 + 0.25 * s.humans.loyalty / 100) *
        (s.here.tags.contains(Tag.humans) ? 1 : 0.33);
    var joined = 0;
    for (var i = 0; i < free; i++) {
      if (rng.chance(odds)) joined++;
    }
    if (joined > 0) {
      apply(Humans(joined), StringBuffer());
      apply(const MaybeAgent(0.15), StringBuffer());
      log(
        LogKind.ship,
        joined == 1 ? 'A human signed on.' : '$joined humans signed on.',
      );
    }
  }

  void payCrew() {
    final wages = 1 + s.humans.count ~/ 3;
    if (s.credits >= wages) {
      s.credits -= wages;
    } else {
      s.credits = 0;
      s.humans = s.humans.copyWith(loyalty: s.humans.loyalty - 5);
      log(LogKind.ship, 'Could not make payroll. The humans noticed.');
    }
  }

  /// The hidden part of HR: a well-bonded crew changes the galaxy a little
  /// every few turns, in a direction set by whose culture is winning aboard.
  void quietHumanInfluence() {
    if (s.turn % 3 != 0) return;
    // A hospital aboard is noticed.
    final care = min(s.stats.hospital, 5);
    if (care > 0 && s.humans.count > 0) {
      s.humans = s.humans.copyWith(loyalty: s.humans.loyalty + care);
    }
    if (s.humans.bond < 50) return;
    if (s.humans.drift <= -30) addCounter(s, Counter.republicStance, 1);
    if (s.humans.drift >= 30) addCounter(s, Counter.hellbornAwareness, 1);
  }

  void runBeats() {
    for (final beat in content.beats) {
      if (s.isOver) return;
      final fired = s.beatsFired[beat.id] ?? 0;
      if (fired > 0 && !beat.repeatable) continue;
      if (!beat.condition.test(s)) {
        s.beatsWaiting.remove(beat.id);
        continue;
      }
      final waited = s.turn - s.beatsWaiting.putIfAbsent(beat.id, () => s.turn);
      if (waited < beat.delay) continue;
      final overdue = beat.deadline != null && waited >= beat.deadline!;
      final chance = beat.modifiers.fold(
        beat.chance,
        (p, m) => m.$1.test(s) ? p * m.$2 : p,
      );
      if (overdue || rng.chance(chance)) fireBeat(beat);
    }
  }

  void fireBeat(StoryBeat beat) {
    s.beatsFired[beat.id] = (s.beatsFired[beat.id] ?? 0) + 1;
    s.beatsWaiting.remove(beat.id);
    final outcome = rng.weighted(
      beat.outcomes.where((o) => o.condition?.test(s) ?? true),
      (o) => eventWeight(s, o.weight, o.bondWeight),
    );
    log(LogKind.news, s.format(outcome?.text ?? ''), title: beat.headline);
    applyAll([...beat.effects, ...?outcome?.effects], StringBuffer());
    final local = beat.localEvent;
    if (local != null && local.$1.test(s)) s.eventQueue.add(local.$2);
  }
}
