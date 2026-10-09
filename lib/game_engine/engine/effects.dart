import 'dart:collection';
import 'dart:math' show max, min;

import '../combat/catalog.dart';
import '../combat/combat.dart';
import '../combat/equipment.dart';
import '../deck/loadout.dart';
import '../galaxy/galaxy.dart';
import '../market.dart';
import '../run_state.dart';
import '../story/keys.dart';
import '../story/rules.dart';
import '../story/story.dart';
import 'turn.dart';
import 'turn_flow.dart';
import 'world_effects.dart';

/// Applies the effects of events, beats and choices to the run.
extension Effects on EngineTurn {
  void applyAll(List<Effect> effects, StringBuffer text) {
    for (final e in effects) {
      if (s.isOver) return;
      apply(e, text);
    }
  }

  void apply(Effect effect, StringBuffer text) {
    switch (effect) {
      case Fuel(:final amount):
        s.fuel = (s.fuel + amount).clamp(0, s.stats.fuelCapacity);
      case SettleDebt(:final counter):
        final debt = s.counter(counter);
        if (s.credits >= debt) {
          s.credits -= debt;
          s.counters[counter] = 0;
        }
      case Credits(:final amount):
        s.credits = max(0, s.credits + amount);
      case Hull(:final amount):
        s.hull = min(s.stats.maxHull, s.hull + amount);
        if (s.hull <= 0) {
          s.hull = 0;
          s.ending = Ending.shipDestroyed;
        }
      case Humans(:final amount):
        // Hospitals cut every loss short of the whole colony leaving.
        final cut = min(s.stats.hospital * 10, maxHospitalCut);
        final change = amount < 0 && amount > -Humans.everyone
            ? (amount * (100 - cut) / 100).round()
            : amount;
        s.humans = s.humans.copyWith(
          count: (s.humans.count + change).clamp(0, s.stats.housing),
        );
        if (s.humans.count == 0) s.flags.remove(Flag.hellbornAgentAboard);
      case Loyalty(:final amount):
        s.humans = s.humans.copyWith(loyalty: s.humans.loyalty + amount);
      case Drift(:final amount):
        s.humans = s.humans.copyWith(drift: s.humans.drift + amount);
      case SetFlag(:final flag):
        s.flags.add(flag);
      case ClearFlag(:final flag):
        s.flags.remove(flag);
      case AddCounter(:final counter, :final amount):
        addCounter(s, counter, amount);
      case Reveal(:final systemId):
        s.revealed.add(systemId);
      case Rename(:final systemId, :final name):
        s.nameOverrides[systemId] = name;
      case RestoreGateway(:final a, :final b):
        final g =
            s.galaxy.gatewayBetween(a, b) ??
            (throw ArgumentError('No gateway between $a and $b'));
        restore(g);
      case RestoreDeadGateway(:final towardAct, :final here):
        restoreDeadGateway(towardAct, here: here);
      case EnterHell(:final zone):
        enterHell(zone);
      case EscapeHell():
        escapeHell(text);
      case SetControl(:final systemId, :final faction):
        s.control[systemId] = faction;
      case Retreat():
        final back = s.previousLocation;
        if (back != null && !s.inHell) {
          s
            ..previousLocation = s.location
            ..location = back;
          log(LogKind.ship, 'Turned back to ${s.nameOf(back)}.');
        }
      case QueueEvent(:final eventId):
        s.eventQueue.add(eventId);
      case Note(text: final note):
        log(LogKind.ship, note);
      case Combat():
        combat(effect, text);
      case ResolveEnding():
        final code = content.endingFor(s);
        final next = content.codeEffects[code];
        if (next == null) {
          s.ending = code;
        } else {
          applyAll(next, text);
        }
      case Expand():
        expand(effect);
      case Breach(:final faction, :final pairs):
        breach(faction, pairs);
      case Transfer(:final from, :final to):
        for (final id in s.control.keys) {
          if (s.control[id] == from) s.control[id] = to;
        }
      case MaybeAgent(:final chance):
        if (s.humans.count > 0 && rng.chance(chance)) {
          s.flags.add(Flag.hellbornAgentAboard);
        }
      case StartDelivery():
        startDelivery(effect, text);
      case CompleteDeliveries(:final paid):
        for (final d in s.deliveries.where((d) => d.to == s.location)) {
          if (!s.loadout.remove(d.cardId) || !paid) continue;
          s.credits += d.reward;
          text.write('\n\nDelivered. Paid ${d.reward} credits.');
          log(LogKind.ship, 'Delivered cargo for ${d.reward} credits.');
        }
        s.deliveries.removeWhere((d) => d.to == s.location);
      case SellCommodity(:final markup):
        final goods = [
          for (final id in s.cards)
            if (equipmentById(id).kind == CardKind.commodity) id,
        ];
        if (goods.isEmpty) break;
        int value(String id) => commodityPrice(
          equipmentById(id),
          s.location,
          s.galaxy.seed,
          time: s.turn,
        );
        goods.sort((a, b) => value(b).compareTo(value(a)));
        final price = (value(goods.first) * markup).round();
        s.loadout.remove(goods.first);
        s.credits += price;
        text.write(
          '\n\nSold ${equipmentById(goods.first).name} for $price credits.',
        );
      case GrantCard(:final pool):
        grantCard(pool, text);
      case ClaimTagged(:final tag, :final faction):
        for (final sys in s.galaxy.systems.values) {
          if (sys.tags.contains(tag)) s.control[sys.id] = faction;
        }
      case EndRun(:final ending):
        s.ending = ending;
    }
  }

  void enterHell(HellZone zone) {
    if (!s.inHell) {
      s.hellTurns = 0;
      addCounter(s, Counter.hellbornAwareness, 1);
    }
    s.hell = zone;
  }

  void escapeHell(StringBuffer text) {
    if (!s.inHell) return;
    // In act 1 Hell only lets you out into the act 1 network.
    final exits = s.galaxy.systems.values
        .where(
          (sys) =>
              sys.act <= s.act &&
              s.galaxy.gatewaysOf(sys.id).any(s.isGatewayActive),
        )
        .toList();
    final exit = rng.pick(exits);
    s.flags.remove(Flag.mournerPull);
    s
      ..hell = null
      ..location = exit.id
      ..visited.add(exit.id)
      ..revealed.add(exit.id);
    text.write(
      '\n\nThe ship tumbles out of a gateway at ${s.nameOf(exit.id)}.',
    );
    log(
      LogKind.ship,
      'Escaped Hell at ${s.nameOf(exit.id)} '
      'after ${s.hellTurns} turns.',
    );
    trigger(Trigger.hellExit, min(0.75, 0.15 * s.hellTurns));
  }

  /// A real fight against an enemy built from the event's strength rating
  /// and the act. Winning scraps the enemy. At the time limit both ships get
  /// away: no loot, and the event's "lose" effects apply (without their old
  /// hull damage, since the fight already did that). Losing ends the run.
  void combat(Combat c, StringBuffer text) {
    final enemy = enemyFor(c.enemy, c.strength, s.act);
    final upgrades = s.counter(Counter.hullUpgrades);
    final player = Combatant(
      name: 'you',
      loadout: s.loadout.forCombat,
      baseHull: baseHull + upgrades * ShipStats.hullPerUpgrade,
      hull: s.hull,
    );
    final foe = Combatant(
      name: enemy.name,
      loadout: enemy.loadout,
      baseHull: enemy.hull,
    );
    final result = fight(player, foe, tractorBeam: c.tractorBeam);
    s.hull = result.hull;

    final salvage = <String>[];
    var scrap = 0;
    switch (result.outcome) {
      case CombatOutcome.win:
        scrap = foe.maxHull ~/ 10;
        for (final id in enemy.loadout.slots.whereType<String>()) {
          if (rng.chance(0.25)) salvage.add(id);
        }
        text.write(
          '\n\nYou destroyed ${enemy.name} in ${result.seconds.round()} s '
          'and scrapped it for $scrap credits',
        );
        s.credits += scrap;
        final kept = <String>[];
        for (final id in salvage) {
          final merges = s.loadout.add(id);
          if (merges == null) continue;
          kept.add(equipmentById(id).name);
          for (final m in merges) {
            text.write(' $m');
          }
        }
        text.write(kept.isEmpty ? '.' : ', plus ${kept.join(', ')}.');
        applyAll(c.win, text);
      case CombatOutcome.escape:
        text.write(
          '\n\nAfter a minute neither ship could finish the other, and you '
          'broke away. No salvage, and ${enemy.name} will remember you.',
        );
        applyAll([
          for (final e in c.lose)
            if (e is! Hull) e,
        ], text);
      case CombatOutcome.loss:
        text.write('\n\n${enemy.name} destroyed your ship.');
        s.ending = Ending.shipDestroyed;
    }
    s.lastCombat = FightRecord(
      enemyName: enemy.name,
      player: player.loadout,
      enemy: enemy.loadout,
      playerMaxHull: player.maxHull,
      enemyMaxHull: foe.maxHull,
      playerStartHull: player.hull,
      result: result,
      salvage: salvage,
      scrapCredits: scrap,
    );
  }

  void startDelivery(StartDelivery d, StringBuffer text) {
    // Known stations within two working jumps.
    final reach = <String, int>{s.location: 0};
    final queue = Queue.of([s.location]);
    while (queue.isNotEmpty) {
      final id = queue.removeFirst();
      if (reach[id]! >= 2) continue;
      for (final g in s.galaxy.gatewaysOf(id)) {
        final next = g.other(id);
        if (s.isGatewayActive(g) && !reach.containsKey(next)) {
          reach[next] = reach[id]! + 1;
          queue.add(next);
        }
      }
    }
    final options = [
      for (final id in reach.keys)
        if (id != s.location &&
            s.revealed.contains(id) &&
            s.galaxy[id].tags.contains(Tag.station))
          id,
    ];
    final favoured = d.prefer != null && (d.preferWhen?.test(s) ?? true);
    final to = rng.weighted(
      options,
      (id) => favoured && id == d.prefer ? 12.0 : 1.0,
    );
    if (to == null) {
      text.write('\n\nThere\'s nowhere nearby to take it, so you pass.');
      return;
    }
    if (s.loadout.add(d.cardId) == null) {
      text.write('\n\nThere\'s no room aboard for it, so you pass.');
      return;
    }
    s.deliveries.add(Delivery(d.cardId, to, d.reward));
    text.write(
      '\n\nDeliver the ${equipmentById(d.cardId).name} to '
      '${s.nameOf(to)} for ${d.reward} credits.',
    );
    log(LogKind.ship, 'Took on cargo for ${s.nameOf(to)}.');
  }

  void grantCard(String pool, StringBuffer text) {
    final options = switch (pool) {
      'salvage' => basicEquipment,
      'commodity' => commodities,
      'supplies' => [
        for (final e in basicEquipment)
          if (e.kind == CardKind.supplies) e,
      ],
      _ when equipmentCatalog.containsKey(pool) => [equipmentById(pool)],
      'mourner' => [
        for (final c in mournerCards)
          if (!s.cards.contains(c.id)) c,
      ],
      _ => throw ArgumentError('Unknown card pool $pool'),
    };
    if (options.isEmpty) return;
    final card = rng.pick(options);
    final merges = s.loadout.add(card.id);
    if (merges == null) {
      text.write('\n\nFound ${card.name}, but there was no room for it.');
      return;
    }
    text.write('\n\nNew card: ${card.name}.');
    log(LogKind.ship, 'Got the card ${card.name}.');
    for (final m in merges) {
      text.write(' $m');
      log(LogKind.ship, m);
    }
  }
}
