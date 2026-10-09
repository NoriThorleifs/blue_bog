import 'dart:math';

import 'package:flutter/material.dart';

import '../../game_engine/combat/catalog.dart';
import '../../game_engine/combat/equipment.dart';
import '../../game_engine/deck/loadout.dart';
import '../cards/card_widgets.dart';
import '../theme.dart';

/// A card in a slot or the hold, optionally draggable to another spot.
class SpotTile extends StatelessWidget {
  const SpotTile({
    super.key,
    required this.spot,
    required this.id,
    required this.size,
    this.selected = false,
    this.dimmed = false,
    this.onTap,
    this.onDrop,
    this.glowing = false,
  });

  final CardSpot spot;
  final String? id;
  final double size;
  final bool selected;
  final bool dimmed;
  final ValueChanged<CardSpot>? onTap;
  final void Function(CardSpot from, CardSpot to)? onDrop;

  /// Pulses to show the card can be picked.
  final bool glowing;

  @override
  Widget build(BuildContext context) {
    Widget tile({bool hovered = false}) {
      final card = CardTile(
        id: id,
        selected: selected || hovered,
        dimmed: dimmed,
        // Empty spots take taps only where cards move by tapping, not by
        // dragging.
        onTap: onTap == null || (id == null && onDrop != null)
            ? null
            : () => onTap!(spot),
      );
      return glowing ? GlowPulse(child: card) : card;
    }

    final drop = onDrop;
    if (drop == null) return tile();
    return DragTarget<CardSpot>(
      onWillAcceptWithDetails: (details) => details.data != spot,
      onAcceptWithDetails: (details) => drop(details.data, spot),
      builder: (context, hovering, _) => id == null
          ? tile(hovered: hovering.isNotEmpty)
          : Draggable<CardSpot>(
              data: spot,
              feedback: SizedBox.square(
                dimension: size * 1.15,
                child: Material(
                  type: MaterialType.transparency,
                  child: CardTile(id: id, selected: true),
                ),
              ),
              childWhenDragging: const CardTile(id: null),
              child: tile(hovered: hovering.isNotEmpty),
            ),
    );
  }
}

/// Whether a card does nothing in a combat slot: cargo, or a spare cargo
/// pod waiting to merge.
bool _inert(String id) {
  final card = equipmentById(id);
  return card.isCargoBay ||
      !const {CardKind.equipment, CardKind.supplies}.contains(card.kind);
}

/// Nine slots: three small triangles (top, bottom left, bottom right) that
/// make one big triangle.
class Triforce extends StatelessWidget {
  const Triforce({
    super.key,
    required this.slots,
    this.selected,
    this.onTap,
    this.onDrop,
    this.glowing = const {},
    this.overlay,
  });

  final List<String?> slots;
  final CardSpot? selected;
  final ValueChanged<CardSpot>? onTap;

  /// If set, cards can be dragged between spots: called with where the
  /// card came from and where it was dropped.
  final void Function(CardSpot from, CardSpot to)? onDrop;

  /// Slots to highlight with a pulsing glow.
  final Set<CardSpot> glowing;

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
        final centres = slotCentres(box.maxWidth);
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
                      SpotTile(
                        spot: SlotSpot(i),
                        id: slots[i],
                        size: tile,
                        selected: selected == SlotSpot(i),
                        dimmed: slots[i] != null && _inert(slots[i]!),
                        onTap: onTap,
                        onDrop: onDrop,
                        glowing: glowing.contains(SlotSpot(i)),
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
  /// Where each slot's centre sits in a triforce [width] wide, so effects
  /// can be drawn over it.
  static List<Offset> slotCentres(double width) {
    final tile = width * 0.145;
    final inner = Size(width - tile, (width - tile) * sqrt(3) / 2);
    return [
      for (final c in _slotCentres(inner)) c + Offset(tile / 2, tile / 2),
    ];
  }

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
