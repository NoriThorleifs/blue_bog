import 'package:blue_bog/components/cards/card_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _details(String id) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: CardDetails(
        id: id,
        copies: 1,
        actions: [FilledButton(onPressed: () {}, child: const Text('Buy'))],
      ),
    ),
  ),
);

void main() {
  testWidgets('the arrows step through every tier of a card', (tester) async {
    await tester.pumpWidget(_details('shield_1'));
    expect(find.text('Shield Generator'), findsOneWidget);
    expect(find.text('Charges 20% faster'), findsNothing);

    await tester.tap(find.byTooltip('Tier above'));
    await tester.pump();
    expect(find.text('Shield Array'), findsOneWidget);
    expect(find.text('+140 max shield'), findsOneWidget);
    expect(find.text('Charges 20% faster'), findsOneWidget);
    expect(find.textContaining('Preview: three of yours'), findsOneWidget);
    expect(find.text('Buy'), findsOneWidget, reason: 'actions stay');

    await tester.tap(find.byTooltip('Tier above'));
    await tester.pump();
    expect(find.text('Barrier Cathedral'), findsOneWidget);
    expect(find.textContaining('nine of yours'), findsOneWidget);
    // Already at the top: the arrow does nothing.
    await tester.tap(find.byTooltip('Tier above'));
    await tester.pump();
    expect(find.text('Barrier Cathedral'), findsOneWidget);

    await tester.tap(find.byTooltip('Tier below'));
    await tester.tap(find.byTooltip('Tier below'));
    await tester.pump();
    expect(find.text('Shield Generator'), findsOneWidget);
    expect(find.textContaining('Preview'), findsNothing);
  });

  testWidgets('a swipe steps through the tiers too', (tester) async {
    await tester.pumpWidget(_details('laser_2'));
    await tester.fling(find.text('Twin Lasers'), const Offset(-300, 0), 800);
    await tester.pumpAndSettle();
    expect(find.text('Tern Choir Lance'), findsOneWidget);
    await tester.fling(
      find.text('Tern Choir Lance'),
      const Offset(300, 0),
      800,
    );
    await tester.pumpAndSettle();
    expect(find.text('Twin Lasers'), findsOneWidget);
  });

  testWidgets('cards with no tiers have no arrows', (tester) async {
    await tester.pumpWidget(_details('goods_grain'));
    expect(find.byTooltip('Tier above'), findsNothing);
    await tester.pumpWidget(_details('hell_clock'));
    expect(find.byTooltip('Tier above'), findsNothing);
  });
}
