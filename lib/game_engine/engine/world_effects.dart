import 'dart:math' show max;

import '../faction.dart';
import '../galaxy/galaxy.dart';
import '../run_state.dart';
import '../story/keys.dart';
import '../story/rules.dart';
import 'turn.dart';

/// Effects on the galaxy: borders, gateways and acts.
extension WorldEffects on EngineTurn {
  void expand(Expand e) {
    final before = Map.of(s.control);
    final taken = <String>{};
    for (final g in s.galaxy.gateways) {
      if (!e.throughDeadGateways && !s.isGatewayActive(g)) continue;
      for (final (from, to) in [(g.a, g.b), (g.b, g.a)]) {
        if (before[from] != e.faction || before[to] == e.faction) continue;
        if (e.only != null && before[to] != e.only) continue;
        if (taken.contains(to) || !rng.chance(e.chance)) continue;
        taken.add(to);
        s.control[to] = e.faction;
      }
    }
    if (taken.isNotEmpty) {
      log(
        LogKind.news,
        '${taken.map(s.nameOf).join(', ')} ${e.verb} ${e.faction.label}.',
        title: 'Borders shift',
      );
    }
  }

  void breach(Faction faction, int pairs) {
    final gates = rng.shuffled(s.galaxy.gateways).take(pairs);
    for (final g in gates) {
      s.activeGateways.add(g.key);
      s.control[g.a] = faction;
      s.control[g.b] = faction;
      s.revealed.addAll([g.a, g.b]);
    }
    log(
      LogKind.news,
      'The barrier gave way in the gateways between '
      '${gates.map((g) => '${s.nameOf(g.a)} and ${s.nameOf(g.b)}').join('; ')}.',
      title: 'Gatecrash',
    );
  }

  void restore(Gateway g) {
    if (!s.activeGateways.add(g.key)) return;
    s.revealed.addAll([g.a, g.b]);
    log(
      LogKind.news,
      'The gateway between ${s.nameOf(g.a)} and ${s.nameOf(g.b)} is open '
      'for the first time since the gatecrash.',
      title: 'Gateway restored',
    );
    checkActs();
  }

  void restoreDeadGateway(int? towardAct, {required bool here}) {
    final network = gatewayNetwork(s);
    final candidates = s.galaxy.gateways.where((g) {
      final inA = network.contains(g.a);
      final inB = network.contains(g.b);
      if (s.isGatewayActive(g) || (!inA && !inB)) return false;
      if (here) return g.touches(s.location);
      final farAct = max(s.galaxy[g.a].act, s.galaxy[g.b].act);
      return towardAct == null ? farAct <= s.act : farAct == towardAct;
    });
    final pick = candidates.isEmpty ? null : rng.pick(candidates.toList());
    if (pick != null) restore(pick);
  }

  /// Acts follow the gateway network: act 2 when Træ Træ Tene joins it,
  /// act 3 when Kyndari does.
  void checkActs() {
    final network = gatewayNetwork(s);
    if (s.act < 2 && network.contains(Sys.traeTraeTene)) startAct(2);
    if (s.act < 3 && network.contains(Sys.kyndari)) startAct(3);
  }

  void startAct(int act) {
    s
      ..act = act
      ..actStartedTurn = s.turn;
    for (final sys in s.galaxy.systems.values) {
      if (sys.act == act) s.revealed.add(sys.id);
    }
    if (act == 3) s.flags.add(Flag.kyndariRevealed);
    final (title, text) = content.actHeadlines[act] ?? ('Act $act', '');
    log(LogKind.news, text, title: title);
  }
}
