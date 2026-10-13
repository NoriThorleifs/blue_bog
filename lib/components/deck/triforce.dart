import 'package:flutter/material.dart';

import '../../game_engine/combat/catalog.dart';
import '../../game_engine/combat/equipment.dart';
import '../../game_engine/deck/loadout.dart';
import '../cards/card_widgets.dart';
import '../theme.dart';

/// A card in a slot or the hold, optionally draggable to another spot.
/// Empty, it shows the outline of what usually goes there.
class SpotTile extends StatelessWidget {
  const SpotTile({
    super.key,
    required this.spot,
    required this.id,
    this.selected = false,
    this.dimmed = false,
    this.onTap,
    this.onDrop,
    this.glowing = false,
    this.footer,
    this.note,
  });

  final CardSpot spot;
  final String? id;
  final bool selected;
  final bool dimmed;
  final ValueChanged<CardSpot>? onTap;
  final void Function(CardSpot from, CardSpot to)? onDrop;

  /// Pulses to show the card can be picked.
  final bool glowing;

  /// See [CardTile.footer] and [CardTile.note].
  final String? footer;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final empty = CardShape.forSpot(spot);
    Widget tile({bool hovered = false}) {
      final card = CardTile(
        id: id,
        selected: selected || hovered,
        dimmed: dimmed,
        footer: footer,
        note: note,
        emptyShape: empty,
        // Empty spots take taps only where cards move by tapping, not by
        // dragging.
        onTap: onTap == null || (id == null && onDrop != null)
            ? null
            : () => onTap!(spot),
      );
      if (!glowing) return card;
      return GlowPulse(
        shape: id == null ? empty : CardShape.of(equipmentById(id!)),
        child: card,
      );
    }

    final drop = onDrop;
    if (drop == null) return tile();
    return DragTarget<CardSpot>(
      onWillAcceptWithDetails: (details) => details.data != spot,
      onAcceptWithDetails: (details) => drop(details.data, spot),
      builder: (context, hovering, _) => id == null
          ? tile(hovered: hovering.isNotEmpty)
          : LayoutBuilder(
              builder: (context, box) => Draggable<CardSpot>(
                data: spot,
                feedback: SizedBox(
                  width: box.maxWidth * 1.15,
                  height: box.maxHeight * 1.15,
                  child: Material(
                    type: MaterialType.transparency,
                    child: CardTile(id: id, selected: true),
                  ),
                ),
                childWhenDragging: CardTile(id: null, emptyShape: empty),
                child: tile(hovered: hovering.isNotEmpty),
              ),
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
        final geo = TriforceGeometry(box.maxWidth);
        // A small gap between each card and the lines around it, keeping
        // each slot's box equilateral so its card is too.
        final gap = geo.side * 0.012;
        return SizedBox(
          width: geo.width,
          height: geo.height,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _TrianglePainter(geo)),
              ),
              for (var i = 0; i < Loadout.slotCount; i++)
                Positioned.fromRect(
                  rect: Rect.fromCenter(
                    center: geo.slotRects[i].center,
                    width: geo.slotRects[i].width - 2 * gap,
                    height: geo.slotRects[i].height - 2 * gap * triangleHeight,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      SpotTile(
                        spot: SlotSpot(i),
                        id: slots[i],
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

  /// Where each slot's centre sits in a triforce [width] wide, so effects
  /// can be drawn over it.
  static List<Offset> slotCentres(double width) =>
      TriforceGeometry(width).slotCentres;
}

/// Where everything in a [Triforce] [width] wide sits.
///
/// The big triangle splits into three small ones, and each small one into
/// four smaller still: the three at its corners are its slots, point up
/// like the triangular cards that fill them, and the one in the middle,
/// upside down, stays empty.
class TriforceGeometry {
  TriforceGeometry(this.width);
  final double width;

  /// Room around the big triangle for its glow.
  double get margin => width * 0.02;

  /// The big triangle's side.
  double get side => width - 2 * margin;

  double get height => side * triangleHeight + 2 * margin;

  /// Height over width, for fitting a triforce into a box.
  static double get aspect => 0.96 * triangleHeight + 0.04;

  Offset get top => Offset(width / 2, margin);
  Offset get left => Offset(margin, margin + side * triangleHeight);
  Offset get right => Offset(width - margin, margin + side * triangleHeight);

  /// Top, bottom left and bottom right, each as its top, bottom left and
  /// bottom right corners.
  List<List<Offset>> get smallTriangles => _split([top, left, right]);

  /// The nine slots' triangles, in slot order.
  late final List<List<Offset>> slotTriangles = [
    for (final t in smallTriangles) ..._split(t),
  ];

  /// Each slot's bounding box, which its card fills.
  late final List<Rect> slotRects = [
    for (final t in slotTriangles)
      Rect.fromLTRB(t[1].dx, t[0].dy, t[2].dx, t[1].dy),
  ];

  late final List<Offset> slotCentres = [
    for (final t in slotTriangles) (t[0] + t[1] + t[2]) / 3,
  ];

  /// The three corner triangles of [t] (top, bottom left, bottom right).
  static List<List<Offset>> _split(List<Offset> t) {
    final [a, b, c] = t;
    final ab = Offset.lerp(a, b, 0.5)!;
    final ac = Offset.lerp(a, c, 0.5)!;
    final bc = Offset.lerp(b, c, 0.5)!;
    return [
      [a, ab, ac],
      [ab, b, bc],
      [ac, bc, c],
    ];
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter(this.geo);
  final TriforceGeometry geo;

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
    for (final t in geo.smallTriangles) {
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
  bool shouldRepaint(_TrianglePainter old) => old.geo.width != geo.width;
}
