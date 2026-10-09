import 'dart:io';

import 'package:blue_bog/components/cards/card_widgets.dart';
import 'package:blue_bog/game_engine/combat/catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a selected super card fits a combat-sized slot', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 36,
            height: 36,
            child: CardTile(id: 'laser_3', selected: true),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  test('every card has placeholder art', () {
    for (final card in equipmentCatalog.values) {
      expect(
        File('assets/cards/${card.family}_ai_generated.png').existsSync(),
        isTrue,
        reason: '${card.id}: run tool/generate_card_icons.py',
      );
    }
  });

  for (final (width, columns, size) in [
    (387.0, 3, 120.0),
    (700.0, 5, 120.0),
    (320.0, 3, 101.33),
  ]) {
    testWidgets('a $width px shop shows $columns columns of $size px', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: CardGrid(
                children: [
                  for (var i = 0; i < 27; i++) const CardTile(id: 'laser_1'),
                ],
              ),
            ),
          ),
        ),
      );
      final tiles = tester.getRect(find.byType(CardTile).first);
      expect(tiles.width, closeTo(size, 0.01));
      final firstRow = [
        for (var i = 0; i < 27; i++)
          if (tester.getRect(find.byType(CardTile).at(i)).top == tiles.top) i,
      ];
      expect(firstRow.length, columns);
      expect(tester.takeException(), isNull);
    });
  }
}
