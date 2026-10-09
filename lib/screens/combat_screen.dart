import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/combat/battle_effects.dart';
import '../components/combat/combat_log.dart';
import '../components/combat/combat_top_bar.dart';
import '../components/combat/ship_panel.dart';
import '../components/theme.dart';
import '../functions/battle_sounds.dart';
import '../functions/sound.dart';
import '../game_engine/combat/catalog.dart';
import '../game_engine/combat/combat.dart';
import '../game_engine/combat/equipment.dart';
import '../providers/brawl_provider.dart';
import '../providers/run_provider.dart';

/// Replays the most recent fight.
///
/// The fight is already decided (combat is deterministic); this shows it
/// happening: both ships' cards charging and firing, hull, shields and
/// drones, and a running log.
class CombatScreen extends ConsumerStatefulWidget {
  const CombatScreen({super.key, this.brawl = false, this.record});

  /// Replays the brawl's last fight instead of the run's.
  final bool brawl;

  /// A fight to replay instead of either, for previews.
  final FightRecord? record;

  @override
  ConsumerState<CombatScreen> createState() => _CombatScreenState();
}

class _CombatScreenState extends ConsumerState<CombatScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _time = 0;
  int _speed = 2;

  /// The fight's sounds, and how far through them playback has got.
  FightRecord? _cuedFor;
  List<Cue> _cues = const [];
  double _cuedTo = -1;

  /// Pans shots left and right when the ships are side by side.
  bool _wide = false;

  /// For the effects layer to find both ships on screen.
  final _layer = GlobalKey();
  final _triforces = [GlobalKey(), GlobalKey()];

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
    final end = record.result.seconds + outroSeconds;
    setState(() => _time = min(end, _time + dt * _speed));
    _playCues(record);
    if (_time >= end) _ticker.stop();
  }

  /// Plays every sound the clock has passed since the last frame.
  void _playCues(FightRecord record) {
    if (!identical(record, _cuedFor)) {
      _cuedFor = record;
      _cues = battleCues(record);
    }
    var played = 0;
    for (final c in _cues) {
      if (c.time <= _cuedTo) continue;
      if (c.time > _time) break;
      // A handful a frame is plenty; the rest would only be noise.
      if (played++ >= 6) break;
      final pan = !_wide || c.side == null ? 0.0 : (c.side == 0 ? -0.35 : 0.35);
      SoundBoard.instance.play(c.sfx, volume: c.volume, pan: pan);
    }
    _cuedTo = _time;
  }

  FightRecord? _record({bool watch = false}) {
    if (widget.record case final record?) return record;
    final brawl = widget.brawl;
    return switch (watch) {
      true when brawl => ref.watch(brawlProvider)?.lastCombat,
      true => ref.watch(runProvider)?.lastCombat,
      false when brawl => ref.read(brawlProvider)?.lastCombat,
      false => ref.read(runProvider)?.lastCombat,
    };
  }

  /// Jumps to the end of the fight, leaving the outro to play.
  void _skip(FightRecord record) => setState(() {
    // Skipped sounds stay skipped, but the ending still plays.
    _cuedTo = max(_cuedTo, record.result.seconds - 1e-6);
    _time = max(_time, record.result.seconds);
  });

  @override
  Widget build(BuildContext context) {
    final record = _record(watch: true);
    if (record == null) return const Scaffold();
    final result = record.result;
    final now = result.at(min(_time, result.seconds));
    final done = _time >= result.seconds;
    final maxShield = [
      _maxShield(record.player.slots),
      _maxShield(record.enemy.slots),
    ];

    Widget ship(int side) => ShipPanel(
      triforceKey: _triforces[side],
      maxShield: maxShield[side],
      name: side == 0 ? 'Your ship' : record.enemyName,
      slots: side == 0 ? record.player.slots : record.enemy.slots,
      side: side,
      hull: now.hull[side],
      maxHull: side == 0 ? record.playerMaxHull : record.enemyMaxHull,
      shield: now.shield[side],
      drones: now.drones[side],
      time: _time,
      events: result.events,
    );
    final bar = CombatTopBar(
      time: min(_time, result.seconds),
      end: result.seconds,
      done: done,
      speed: _speed,
      onSpeed: (speed) => setState(() => _speed = speed),
      onSkip: () => _skip(record),
    );
    final log = CombatLog(record: record, time: _time);
    final finish = done
        ? Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
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
            ),
          )
        : const SizedBox.shrink();

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            // Too short to lay out at all: scroll rather than overflow.
            _wide = box.maxWidth >= 720 && box.maxWidth > box.maxHeight;
            const minHeight = 420.0;
            final short = box.maxHeight < minHeight;
            final fit = short ? box.copyWith(maxHeight: minHeight) : box;
            // Shots fly between the ships, so the effects go over
            // everything.
            final battle = Stack(
              children: [
                _layout(fit, ship, bar, log, finish),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      key: _layer,
                      painter: BattleEffects(
                        record: record,
                        time: _time,
                        layer: _layer,
                        triforces: _triforces,
                        maxShield: maxShield,
                      ),
                    ),
                  ),
                ),
              ],
            );
            return short
                ? SingleChildScrollView(
                    child: SizedBox(height: minHeight, child: battle),
                  )
                : battle;
          },
        ),
      ),
    );
  }

  /// Both ships, the clock and the log, arranged for the space.
  static Widget _layout(
    BoxConstraints box,
    Widget Function(int side) ship,
    Widget bar,
    Widget log,
    Widget finish,
  ) {
    // Side by side when there's room, facing each other across the
    // gap the shots will fly through; stacked on a phone.
    final wide = box.maxWidth >= 720 && box.maxWidth > box.maxHeight;
    if (wide) {
      return Column(
        children: [
          bar,
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: ship(0)),
                SizedBox(width: min(160, box.maxWidth * 0.08)),
                Expanded(child: ship(1)),
              ],
            ),
          ),
          SizedBox(height: (box.maxHeight * 0.16).clamp(80, 160), child: log),
          finish,
        ],
      );
    }
    return Column(
      children: [
        Expanded(child: ship(1)),
        bar,
        SizedBox(height: (box.maxHeight * 0.14).clamp(64, 140), child: log),
        Expanded(child: ship(0)),
        finish,
      ],
    );
  }
}

int _maxShield(List<String?> slots) => [
  for (final id in slots)
    if (id != null) equipmentById(id),
].where((e) => e.kind == CardKind.equipment).fold(0, (t, e) => t + e.maxShield);
