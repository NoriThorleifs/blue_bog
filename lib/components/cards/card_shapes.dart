import 'dart:math';

import 'package:flutter/material.dart';

import '../../game_engine/combat/equipment.dart';
import '../../game_engine/deck/loadout.dart';

/// Height over side of an equilateral triangle.
final triangleHeight = sqrt(3) / 2;

/// The base and height of a triangular card in [box]: as big as fits, and
/// filling the box's height, from equilateral (in a triforce slot) up to as
/// tall as it is wide (in a square grid cell, so it stands as tall as the
/// square and round cards beside it).
Size triangleIn(Size box) {
  final side = min(box.width, box.height / triangleHeight);
  return Size(side, min(box.height, side));
}

/// The outline of a card, which says what kind of card it is: the ship's
/// equipment is triangular, to fit the triforce; the humans build in
/// squares; cargo is round.
enum CardShape {
  triangle,
  square,
  circle;

  static CardShape of(Equipment card) => switch (card.kind) {
    CardKind.equipment || CardKind.supplies => triangle,
    CardKind.colony => square,
    CardKind.commodity || CardKind.mission => circle,
  };

  /// The shape an empty [spot] shows: what usually goes there.
  static CardShape forSpot(CardSpot spot) => switch (spot) {
    SlotSpot() || CargoSpot() => triangle,
    ColonySpot() => square,
    HoldSpot() => circle,
  };

  OutlinedBorder border([BorderSide side = BorderSide.none]) => switch (this) {
    triangle => TriangleBorder(side: side),
    square => RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: side,
    ),
    circle => CircleBorder(side: side),
  };
}

/// A triangle, point up, as big as fits in the box (see [triangleIn]) and
/// centred in it, with its corners rounded off.
class TriangleBorder extends OutlinedBorder {
  const TriangleBorder({super.side});

  /// The triangle's corners in [rect]: top, bottom right, bottom left.
  static List<Offset> corners(Rect rect) {
    final Size(width: side, height: h) = triangleIn(rect.size);
    final c = rect.center;
    return [
      Offset(c.dx, c.dy - h / 2),
      Offset(c.dx + side / 2, c.dy + h / 2),
      Offset(c.dx - side / 2, c.dy + h / 2),
    ];
  }

  static Path pathIn(Rect rect) {
    final pts = corners(rect);
    final r = (pts[1].dx - pts[2].dx) * 0.07;
    final path = Path();
    for (var i = 0; i < 3; i++) {
      final prev = pts[(i + 2) % 3];
      final at = pts[i];
      final next = pts[(i + 1) % 3];
      // Cut each corner [r] back along both edges, and curve across it.
      final into = at + (prev - at) / (prev - at).distance * r;
      final out = at + (next - at) / (next - at).distance * r;
      if (i == 0) {
        path.moveTo(into.dx, into.dy);
      } else {
        path.lineTo(into.dx, into.dy);
      }
      path.quadraticBezierTo(at.dx, at.dy, out.dx, out.dy);
    }
    return path..close();
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => pathIn(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      pathIn(rect.deflate(side.strokeInset));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawPath(
      pathIn(rect.deflate(side.width / 2)),
      side.toPaint()..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  TriangleBorder scale(double t) => TriangleBorder(side: side.scale(t));

  @override
  TriangleBorder copyWith({BorderSide? side}) =>
      TriangleBorder(side: side ?? this.side);

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) => a is TriangleBorder
      ? TriangleBorder(side: BorderSide.lerp(a.side, side, t))
      : super.lerpFrom(a, t);

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) => b is TriangleBorder
      ? TriangleBorder(side: BorderSide.lerp(side, b.side, t))
      : super.lerpTo(b, t);
}
