import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/brawl_controller.dart';
import '../../app/run_controller.dart';
import '../../app/sound.dart';
import '../../app/theme.dart';
import '../../game/combat/catalog.dart';
import '../../game/combat/combat.dart';
import '../../game/combat/equipment.dart';
import '../cards/card_widgets.dart';
import 'battle_effects.dart';
import 'battle_sounds.dart';
import '../deck/deck_screen.dart';

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

    Widget ship(int side) => _ShipPanel(
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
    final bar = _TopBar(
      time: min(_time, result.seconds),
      end: result.seconds,
      done: done,
      speed: _speed,
      onSpeed: (speed) => setState(() => _speed = speed),
      onSkip: () => _skip(record),
    );
    final log = _Log(record: record, time: _time);
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

/// The fight's clock, how far through the time limit it is, and the
/// playback controls.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.time,
    required this.end,
    required this.done,
    required this.speed,
    required this.onSpeed,
    required this.onSkip,
  });
  final double time;
  final double end;
  final bool done;
  final int speed;
  final ValueChanged<int> onSpeed;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                '${time.toStringAsFixed(1)} s',
                style: text.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                ' / ${combatTimeLimit.round()} s',
                style: text.labelLarge?.copyWith(color: Palette.muted),
              ),
              const Spacer(),
              if (!done) ...[
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('1×')),
                    ButtonSegment(value: 2, label: Text('2×')),
                    ButtonSegment(value: 4, label: Text('4×')),
                  ],
                  selected: {speed},
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  onSelectionChanged: (s) => onSpeed(s.first),
                ),
                IconButton(
                  tooltip: 'Skip to the end',
                  onPressed: onSkip,
                  icon: const Icon(Icons.skip_next),
                ),
              ],
              ValueListenableBuilder(
                valueListenable: SoundBoard.instance.muted,
                builder: (context, muted, _) => IconButton(
                  tooltip: muted ? 'Sound on' : 'Sound off',
                  onPressed: () => SoundBoard.instance.muted.value = !muted,
                  icon: Icon(muted ? Icons.volume_off : Icons.volume_up),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: min(1, time / combatTimeLimit),
              minHeight: 3,
              color: Palette.muted,
              backgroundColor: Colors.white10,
            ),
          ),
        ],
      ),
    );
  }
}

/// One ship: its name, hull, shield and drones, and its triforce as large
/// as the space allows.
class _ShipPanel extends StatelessWidget {
  const _ShipPanel({
    required this.triforceKey,
    required this.maxShield,
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

  final GlobalKey triforceKey;
  final int maxShield;
  final String name;
  final List<String?> slots;
  final int side;
  final int hull;
  final int maxHull;
  final int shield;
  final int drones;
  final double time;
  final List<CombatEvent> events;

  /// Hits that land for at least this share of the hull shake the ship.
  static const _heavy = 0.04;

  static const _shieldColour = Color(0xFF7FA8FF);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cooldowns = cooldownSeconds(CombatLoadout(slots));
    final gear = [
      for (final id in slots)
        if (id != null) equipmentById(id),
    ].where((e) => e.kind == CardKind.equipment);
    final maxDrones = gear.fold(0, (t, e) => t + e.maxDrones);
    // A card flashes as its shot leaves, which for missiles is a little
    // before the moment they land.
    final flashing = {
      for (final e in events)
        if (e.side == side)
          if (time - (e.time - launchLead(e.kind)) case final age
              when age >= 0 && age < 0.35)
            e.slot,
    };
    var shake = Offset.zero;
    for (final e in events) {
      final age = time - e.time;
      if (e.side == side || age < 0 || age > 0.3) continue;
      if ((e.value ?? 0) < maxHull * _heavy || !_hurts(e.kind)) continue;
      final fade = 1 - age / 0.3;
      shake = Offset(sin(age * 90) * 7 * fade, cos(age * 70) * 3 * fade);
    }
    final accent = side == 0 ? Palette.gateway : const Color(0xFFFFB3A8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: text.titleMedium?.copyWith(color: accent),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (maxDrones > 0)
                      _Stat(
                        icon: Icons.flight,
                        colour: Palette.codeGreen,
                        label: '$drones / $maxDrones',
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                _Bar(
                  value: hull,
                  max: maxHull,
                  height: 16,
                  colour: hull < maxHull / 4 ? Palette.hell : Palette.codeGreen,
                  label: '$hull / $maxHull hull',
                ),
                if (maxShield > 0) ...[
                  const SizedBox(height: 4),
                  _Bar(
                    value: shield,
                    max: maxShield,
                    height: 14,
                    colour: _shieldColour,
                    label: '$shield / $maxShield shield',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Transform.translate(
              offset: shake,
              child: _FitTriforce(
                triforceKey: triforceKey,
                slots: slots,
                overlay: (slot) => _Charge(
                  id: slots[slot],
                  cooldown: cooldowns[slot],
                  time: time,
                  flash: flashing.contains(slot),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static bool _hurts(CombatEventKind kind) => const {
    CombatEventKind.laserHit,
    CombatEventKind.missileHit,
    CombatEventKind.teleportHit,
    CombatEventKind.hellfireHit,
    CombatEventKind.ionHit,
    CombatEventKind.flakShrapnel,
    CombatEventKind.railHit,
  }.contains(kind);
}

/// A labelled meter, with its numbers written inside it.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.max,
    required this.height,
    required this.colour,
    required this.label,
  });
  final int value;
  final int max;
  final double height;
  final Color colour;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.white12),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: max == 0 ? 0 : (value / max).clamp(0, 1),
            child: ColoredBox(color: colour.withValues(alpha: 0.85)),
          ),
          Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                height: 1,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                shadows: [Shadow(blurRadius: 3)],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.colour, required this.label});
  final IconData icon;
  final Color colour;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: colour),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.labelLarge),
    ],
  );
}

/// The triforce as big as fits in both directions. Its height is a fixed
/// fraction of its width, so a short, wide space would otherwise squash it.
class _FitTriforce extends StatelessWidget {
  const _FitTriforce({
    required this.triforceKey,
    required this.slots,
    required this.overlay,
  });
  final GlobalKey triforceKey;
  final List<String?> slots;
  final Widget Function(int slot) overlay;

  /// Height over width of a [Triforce], tiles included.
  static const _aspect = 0.855 * 0.8660 + 0.145;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final width = min(min(box.maxWidth, box.maxHeight / _aspect), 600.0);
      return Center(
        child: SizedBox(
          key: triforceKey,
          width: width,
          child: Triforce(slots: slots, overlay: overlay),
        ),
      );
    },
  );
}

/// A slot's charge bar, in the card's colour, and a flash when it fires.
class _Charge extends StatelessWidget {
  const _Charge({
    required this.id,
    required this.cooldown,
    required this.time,
    this.flash = false,
  });
  final String? id;
  final double? cooldown;
  final double time;
  final bool flash;

  @override
  Widget build(BuildContext context) {
    final c = cooldown;
    final colour = id == null
        ? Palette.gateway
        : cardColour(equipmentById(id!));
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
              // Along the bottom edge, under the card's name.
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 1.5),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (time % c) / c,
                  minHeight: 3,
                  color: colour,
                  backgroundColor: Colors.black54,
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
          CombatEventKind.droneBuilt => '$who: drones out: ${e.value}',
          CombatEventKind.outOfAmmo => '$who: $card is out of ammunition',
          CombatEventKind.ionHit =>
            '$who: $card strips shields${e.value! > 0 ? ' and hits for ${e.value}' : ''}',
          CombatEventKind.flakHit =>
            '$who: $card shoots down ${e.value} '
                '${e.value == 1 ? 'drone' : 'drones'}',
          CombatEventKind.flakShrapnel =>
            e.value == 0
                ? '$who: $card shrapnel is stopped by shields'
                : '$who: $card shrapnel hits for ${e.value}',
          CombatEventKind.repaired => '$who: $card patches ${e.value} hull',
          CombatEventKind.jamsReady => '$who: teleport jams ready: ${e.value}',
          CombatEventKind.teleportJammed =>
            '$who: $card is jammed and goes off harmlessly',
          CombatEventKind.railHit => '$who: $card slams home for ${e.value}',
          CombatEventKind.railDeflected =>
            '$who: $card glances off the shields',
          CombatEventKind.boarded =>
            '$who: $card fires. Nobody is aboard ${e.side == 0 ? record.enemyName : 'your ship'}',
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
