import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/brawl_controller.dart';
import '../../app/run_controller.dart';
import '../../app/theme.dart';
import '../../game/combat/catalog.dart';
import '../../game/combat/combat.dart';
import '../deck/deck_screen.dart';

/// Replays the most recent fight.
///
/// The fight is already decided (combat is deterministic); this shows it
/// happening: both ships' cards charging and firing, hull, shields and
/// drones, and a running log.
class CombatScreen extends ConsumerStatefulWidget {
  const CombatScreen({super.key, this.brawl = false});

  /// Replays the brawl's last fight instead of the run's.
  final bool brawl;

  @override
  ConsumerState<CombatScreen> createState() => _CombatScreenState();
}

class _CombatScreenState extends ConsumerState<CombatScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _time = 0;
  int _speed = 2;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final record = _record();
    if (record == null) return;
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    setState(() => _time = min(record.result.seconds, _time + dt * _speed));
    if (_time >= record.result.seconds) _ticker.stop();
  }

  FightRecord? _record({bool watch = false}) {
    final brawl = widget.brawl;
    return switch (watch) {
      true when brawl => ref.watch(brawlProvider)?.lastCombat,
      true => ref.watch(runProvider)?.lastCombat,
      false when brawl => ref.read(brawlProvider)?.lastCombat,
      false => ref.read(runProvider)?.lastCombat,
    };
  }

  void _skip(FightRecord record) {
    _ticker.stop();
    setState(() => _time = record.result.seconds);
  }

  @override
  Widget build(BuildContext context) {
    final record = _record(watch: true);
    if (record == null) return const Scaffold();
    final result = record.result;
    final now = result.at(_time);
    final done = _time >= result.seconds;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ShipPanel(
              name: record.enemyName,
              slots: record.enemy.slots,
              side: 1,
              hull: now.hull[1],
              maxHull: record.enemyMaxHull,
              shield: now.shield[1],
              drones: now.drones[1],
              time: _time,
              events: result.events,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '${_time.toStringAsFixed(1)} s / '
                    '${combatTimeLimit.round()} s',
                    style: text.labelLarge,
                  ),
                  const Spacer(),
                  if (!done) ...[
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 1, label: Text('1×')),
                        ButtonSegment(value: 2, label: Text('2×')),
                        ButtonSegment(value: 4, label: Text('4×')),
                      ],
                      selected: {_speed},
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      onSelectionChanged: (s) =>
                          setState(() => _speed = s.first),
                    ),
                    IconButton(
                      tooltip: 'Skip to the end',
                      onPressed: () => _skip(record),
                      icon: const Icon(Icons.skip_next),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: _Log(record: record, time: _time),
            ),
            _ShipPanel(
              name: 'Your ship',
              slots: record.player.slots,
              side: 0,
              hull: now.hull[0],
              maxHull: record.playerMaxHull,
              shield: now.shield[0],
              drones: now.drones[0],
              time: _time,
              events: result.events,
            ),
            if (done)
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: switch (result.outcome) {
                      CombatOutcome.win => Palette.codeGreen,
                      CombatOutcome.loss => Palette.hell,
                      CombatOutcome.escape => Palette.sublight,
                    },
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(switch (result.outcome) {
                    CombatOutcome.win =>
                      'Victory. Scrap it for ${record.scrapCredits} credits',
                    CombatOutcome.loss => 'Your ship is lost',
                    CombatOutcome.escape => 'Both ships break away',
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShipPanel extends StatelessWidget {
  const _ShipPanel({
    required this.name,
    required this.slots,
    required this.side,
    required this.hull,
    required this.maxHull,
    required this.shield,
    required this.drones,
    required this.time,
    required this.events,
  });

  final String name;
  final List<String?> slots;
  final int side;
  final int hull;
  final int maxHull;
  final int shield;
  final int drones;
  final double time;
  final List<CombatEvent> events;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cooldowns = cooldownSeconds(CombatLoadout(slots));
    final flashing = {
      for (final e in events)
        if (e.side == side && e.time <= time && time - e.time < 0.35) e.slot,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              Text(name, style: text.titleMedium),
              const Spacer(),
              if (shield > 0) ...[
                const Icon(
                  Icons.blur_circular,
                  size: 16,
                  color: Color(0xFF7FA8FF),
                ),
                Text(' $shield  '),
              ],
              if (drones > 0) ...[
                const Icon(Icons.flight, size: 16, color: Palette.codeGreen),
                Text(' $drones'),
              ],
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: maxHull == 0 ? 0 : hull / maxHull,
              minHeight: 10,
              color: hull < maxHull / 4 ? Palette.hell : Palette.codeGreen,
              backgroundColor: Colors.white12,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text('$hull / $maxHull hull', style: text.labelSmall),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250),
            child: Triforce(
              slots: slots,
              overlay: (slot) => _Charge(
                cooldown: cooldowns[slot],
                time: time,
                flash: flashing.contains(slot),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A slot's charge bar, and a flash when it fires.
class _Charge extends StatelessWidget {
  const _Charge({
    required this.cooldown,
    required this.time,
    this.flash = false,
  });
  final double? cooldown;
  final double time;
  final bool flash;

  @override
  Widget build(BuildContext context) {
    final c = cooldown;
    return Stack(
      children: [
        if (flash)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
        if (c != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: LinearProgressIndicator(
                value: (time % c) / c,
                minHeight: 3,
                color: Palette.gateway,
                backgroundColor: Colors.white10,
              ),
            ),
          ),
      ],
    );
  }
}

class _Log extends StatelessWidget {
  const _Log({required this.record, required this.time});
  final FightRecord record;
  final double time;

  @override
  Widget build(BuildContext context) {
    final shown = record.result.events
        .where((e) => e.time <= time)
        .toList()
        .reversed
        .take(30)
        .toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: shown.length,
      itemBuilder: (context, i) {
        final e = shown[i];
        final who = e.side == 0 ? 'You' : record.enemyName;
        final slots = e.side == 0 ? record.player.slots : record.enemy.slots;
        final card = equipmentById(slots[e.slot]!).name;
        final line = switch (e.kind) {
          CombatEventKind.laserHit => '$who: $card hits for ${e.value}',
          CombatEventKind.laserAbsorbed => '$who: $card is stopped by shields',
          CombatEventKind.missileHit => '$who: $card hits for ${e.value}',
          CombatEventKind.missileIntercepted =>
            '$who: $card is shot down by a drone',
          CombatEventKind.teleportHit =>
            '$who: $card goes off inside the hull for ${e.value}',
          CombatEventKind.hellfireHit =>
            '$who: $card burns through for ${e.value}, and scorches its own '
                'hull',
          CombatEventKind.shieldsCharged => '$who: shields at ${e.value}',
          CombatEventKind.droneBuilt => '$who: drone launched',
          CombatEventKind.outOfAmmo => '$who: $card is out of ammunition',
        };
        return Opacity(
          opacity: max(0.35, 1 - i * 0.08),
          child: Text(
            '${e.time.toStringAsFixed(1)}  $line',
            style: TextStyle(
              fontSize: 12,
              color: e.side == 0 ? Palette.gateway : const Color(0xFFFFB3A8),
            ),
          ),
        );
      },
    );
  }
}
