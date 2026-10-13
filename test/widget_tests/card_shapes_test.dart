import 'package:blue_bog/components/cards/card_widgets.dart';
import 'package:blue_bog/components/deck/cargo_hold.dart';
import 'package:blue_bog/components/deck/triforce.dart';
import 'package:blue_bog/game_engine/combat/catalog.dart';
import 'package:blue_bog/game_engine/deck/loadout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a card\'s shape says what kind of card it is', () {
    CardShape shape(String id) => CardShape.of(equipmentById(id));
    expect(shape('laser_1'), CardShape.triangle);
    expect(shape('missile_crate_1'), CardShape.triangle);
    expect(shape('habitat_1'), CardShape.square);
    expect(shape('goods_grain'), CardShape.circle);
    expect(shape('parcel_sealed'), CardShape.circle);
  });

  test('every slot is a corner of its small triangle, inside the big one', () {
    final geo = TriforceGeometry(360);
    expect(geo.slotRects, hasLength(Loadout.slotCount));
    final box = Rect.fromLTWH(0, 0, geo.width, geo.height);
    for (final (i, rect) in geo.slotRects.indexed) {
      expect(
        box.contains(rect.topLeft) && box.contains(rect.bottomRight),
        isTrue,
        reason: 'slot $i',
      );
      // Each slot is a quarter of the big triangle's side.
      expect(rect.width, closeTo(geo.side / 4, 0.01));
    }
    // Slots 0–2 are the top triangle: its top, bottom left, bottom right.
    expect(geo.slotRects[0].top, closeTo(geo.margin, 0.01));
    expect(geo.slotRects[1].left, lessThan(geo.slotRects[2].left));
  });

  for (final shape in CardShape.values) {
    testWidgets('a ${shape.name} card fits a combat-sized slot', (
      tester,
    ) async {
      final id = switch (shape) {
        CardShape.triangle => 'laser_3',
        CardShape.square => 'habitat_3',
        CardShape.circle => 'goods_relics',
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 36,
              height: 32,
              child: CardTile(id: id, selected: true, footer: '99 cr'),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  test('a triangle stands as tall as a square in a square box', () {
    expect(triangleIn(const Size(120, 120)), const Size(120, 120));
    // A triforce slot's box keeps the triangle equilateral.
    final slot = triangleIn(Size(80, 80 * triangleHeight));
    expect(slot.height / slot.width, closeTo(triangleHeight, 1e-9));
    // A wide box never makes it squatter than equilateral.
    final wide = triangleIn(const Size(200, 50));
    expect(wide.height / wide.width, closeTo(triangleHeight, 1e-9));
  });

  // The name's lines once ran past the triangle's sloping sides, cutting
  // off their first and last letters.
  final triangles = {
    for (final card in equipmentCatalog.values)
      if (CardShape.of(card) == CardShape.triangle) card.name: card.id,
  };
  for (final size in [
    const Size(120, 120), // a shop square
    const Size(64, 64), // a hold space
    Size(84, 84 * triangleHeight), // a triforce slot on a phone
  ]) {
    testWidgets('every triangular card\'s name stays inside it at $size', (
      tester,
    ) async {
      for (final MapEntry(key: name, value: id) in triangles.entries) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox.fromSize(
                size: size,
                child: CardTile(id: id, footer: '999 cr'),
              ),
            ),
          ),
        );
        final rect = tester.getRect(find.byType(CardTile));
        final outline = TriangleBorder.pathIn(rect);
        final paragraph = tester.renderObject<RenderParagraph>(find.text(name));
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: name.length),
        );
        for (final box in boxes) {
          for (final corner in [
            Offset(box.left, box.top),
            Offset(box.right, box.top),
          ]) {
            final at = paragraph.localToGlobal(corner);
            expect(outline.contains(at), isTrue, reason: '$name at $at');
          }
        }
      }
    });
  }

  testWidgets('a full hold on a phone gets five columns, not two', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final loadout = Loadout(cargo: 'cargo_pod_3');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: CargoHold(
              loadout: loadout,
              tile: (spot) => CardTile(
                id: loadout.at(spot),
                emptyShape: CardShape.forSpot(spot),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final tiles = find.byType(CardTile);
    // The cargo bay, then 27 hold spaces.
    expect(tiles, findsNWidgets(28));
    final rowOne = {
      for (var i = 1; i < 28; i++)
        if (tester.getTopLeft(tiles.at(i)).dy ==
            tester.getTopLeft(tiles.at(1)).dy)
          i,
    };
    expect(rowOne.length, greaterThanOrEqualTo(CargoHold.minColumns));
  });
}
