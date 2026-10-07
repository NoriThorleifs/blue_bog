import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/run_controller.dart';
import '../../app/theme.dart';
import '../../game/combat/catalog.dart';
import '../../game/combat/equipment.dart';
import '../../game/deck/loadout.dart';
import '../../game/run_state.dart';
import '../cards/card_widgets.dart';

/// The ship's nine card slots, laid out as a triforce, plus the hold.
///
/// Tap a card to pick it up, then tap a slot or hold space to put it there.
/// Whatever was there swaps places with it.
class DeckScreen extends ConsumerStatefulWidget {
  const DeckScreen({super.key});

  @override
  ConsumerState<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends ConsumerState<DeckScreen> {
  CardSpot? _selected;

  Future<void> _tap(RunState run, CardSpot spot) async {
    final selected = _selected;
    if (selected == null) {
      if (run.loadout.at(spot) != null) setState(() => _selected = spot);
      return;
    }
    if (selected == spot) {
      setState(() => _selected = null);
      return;
    }
    setState(() => _selected = null);
    final engine = ref.read(engineProvider);
    final lost = engine.crewLostWith(
      run,
      run.loadout.copy()..move(selected, spot),
    );
    if (lost > 0 && !await confirmCrewLoss(context, lost, run.humans.count)) {
      return;
    }
    final error = ref.read(runProvider.notifier).arrange(selected, spot);
    if (error != null && mounted) showError(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final run = ref.watch(runProvider);
    if (run == null) return const Scaffold();
    final selectedId = _selected == null ? null : run.loadout.at(_selected!);
    final text = Theme.of(context).textTheme;
    final capacity = run.stats.holdCapacity;
    final holdSpaces = max(capacity, run.loadout.hold.length);

    return Scaffold(
      appBar: AppBar(title: const Text('Ship loadout')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ShipStatsBar(run: run),
            const SizedBox(height: 16),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Triforce(
                  slots: run.loadout.slots,
                  selected: _selected,
                  onTap: (spot) => _tap(run, spot),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Cargo hold (${run.loadout.hold.length}/$capacity)',
              style: text.titleMedium,
            ),
            Text(
              capacity == 0
                  ? 'No hold without a cargo pod. Cargo can sit in a slot '
                        'instead, doing nothing.'
                  : 'Supplies and commodities belong here. Equipment in the '
                        'hold does nothing. Three of a card anywhere merge.',
              style: text.bodySmall?.copyWith(color: Palette.muted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < holdSpaces; i++)
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: CardTile(
                      id: run.loadout.at(HoldSpot(i)),
                      selected: _selected == HoldSpot(i),
                      dimmed: _inertInHold(run.loadout.at(HoldSpot(i))),
                      onTap: () => _tap(run, HoldSpot(i)),
                    ),
                  ),
              ],
            ),
            if (selectedId != null) ...[
              const SizedBox(height: 16),
              CardDetails(
                id: selectedId,
                copies: run.loadout.copiesOf(selectedId),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _inertInHold(String? id) =>
      id != null && equipmentById(id).kind == CardKind.equipment;
}

/// Asks before a change that would send humans away.
Future<bool> confirmCrewLoss(BuildContext context, int lost, int total) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lose your humans?'),
        content: Text(
          lost == total
              ? 'Without accommodation, all $total humans aboard will leave '
                    'the ship.'
              : '$lost of your $total humans would have no berth, and will '
                    'leave the ship.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep them'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Let them go'),
          ),
        ],
      ),
    ) ??
    false;

void showError(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

class ShipStatsBar extends StatelessWidget {
  const ShipStatsBar({super.key, required this.run});
  final RunState run;

  @override
  Widget build(BuildContext context) {
    final stats = run.stats;
    final gear = run.loadout.slotted.where((e) => e.kind == CardKind.equipment);
    final shield = gear.fold(0, (t, e) => t + e.maxShield);
    final drones = gear.fold(0, (t, e) => t + e.maxDrones);
    Widget chip(IconData icon, String label) => Chip(
      avatar: Icon(icon, size: 16, color: Palette.muted),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        chip(Icons.shield_outlined, 'Hull ${run.hull}/${stats.maxHull}'),
        if (shield > 0) chip(Icons.blur_circular, 'Shield $shield'),
        if (drones > 0) chip(Icons.flight, 'Drones $drones'),
        chip(
          Icons.groups_outlined,
          'Berths ${run.humans.count}/${stats.berths}',
        ),
        if (stats.hospital > 0)
          chip(Icons.local_hospital_outlined, 'Hospital ${stats.hospital}'),
        if (stats.hellShielding > 0)
          chip(
            Icons.blur_on,
            'Hell shielding ${(stats.hellShielding * 100).round()}%',
          ),
        chip(
          Icons.local_gas_station_outlined,
          'Fuel ${run.fuel}/${stats.fuelCapacity}',
        ),
        chip(Icons.inventory_2_outlined, 'Hold ${stats.holdCapacity}'),
      ],
    );
  }
}

/// Nine slots: three small triangles (top, bottom left, bottom right) that
/// make one big triangle.
class Triforce extends StatelessWidget {
  const Triforce({
    super.key,
    required this.slots,
    this.selected,
    this.onTap,
    this.overlay,
  });

  final List<String?> slots;
  final CardSpot? selected;
  final ValueChanged<CardSpot>? onTap;

  /// Something to draw over each slot, like a charge timer in combat.
  final Widget Function(int slot)? overlay;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // The triangle is inset by half a tile so slots near its corners
        // stay inside the box.
        final tile = box.maxWidth * 0.145;
        final inner = Size(
          box.maxWidth - tile,
          (box.maxWidth - tile) * sqrt(3) / 2,
        );
        final inset = Offset(tile / 2, tile / 2);
        final centres = [for (final c in _slotCentres(inner)) c + inset];
        return SizedBox(
          width: box.maxWidth,
          height: inner.height + tile,
          child: Stack(
            children: [
              Positioned(
                left: inset.dx,
                top: inset.dy,
                width: inner.width,
                height: inner.height,
                child: CustomPaint(painter: _TrianglePainter()),
              ),
              for (var i = 0; i < Loadout.slotCount; i++)
                Positioned(
                  left: centres[i].dx - tile / 2,
                  top: centres[i].dy - tile / 2,
                  width: tile,
                  height: tile,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CardTile(
                        id: slots[i],
                        selected: selected == SlotSpot(i),
                        dimmed:
                            slots[i] != null &&
                            const {
                              CardKind.commodity,
                              CardKind.mission,
                            }.contains(equipmentById(slots[i]!).kind),
                        onTap: onTap == null ? null : () => onTap!(SlotSpot(i)),
                      ),
                      if (overlay != null) IgnorePointer(child: overlay!(i)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Each small triangle holds three slots, one near each of its corners.
  static List<Offset> _slotCentres(Size size) => [
    for (final triangle in _smallTriangles(size)) ...[
      for (final corner in triangle)
        Offset.lerp(_centroid(triangle), corner, 0.42)!,
    ],
  ];

  static List<List<Offset>> _smallTriangles(Size size) {
    final top = Offset(size.width / 2, 0);
    final left = Offset(0, size.height);
    final right = Offset(size.width, size.height);
    final midLeft = Offset.lerp(top, left, 0.5)!;
    final midRight = Offset.lerp(top, right, 0.5)!;
    final midBottom = Offset.lerp(left, right, 0.5)!;
    return [
      [top, midLeft, midRight],
      [midLeft, left, midBottom],
      [midRight, midBottom, right],
    ];
  }

  static Offset _centroid(List<Offset> t) => Offset(
    (t[0].dx + t[1].dx + t[2].dx) / 3,
    (t[0].dy + t[1].dy + t[2].dy) / 3,
  );
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..color = Palette.gateway.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final line = Paint()
      ..color = Palette.gateway.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final t in Triforce._smallTriangles(size)) {
      final path = Path()..addPolygon(t, true);
      canvas
        ..drawPath(
          path,
          Paint()..color = Palette.gateway.withValues(alpha: 0.05),
        )
        ..drawPath(path, glow)
        ..drawPath(path, line);
    }
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => false;
}
