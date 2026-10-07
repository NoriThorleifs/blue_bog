import 'package:blue_bog/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the main launch button starts a brawl', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: BlueBogApp()));
    await tester.tap(find.text('Ál'));
    await tester.tap(find.textContaining('Launch as'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Fight 1'), findsOneWidget);
    expect(find.text('Buy'), findsOneWidget);
  });

  testWidgets(
    'story mode: launch a run, resolve the opening and hold position',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const ProviderScope(child: BlueBogApp()));
      expect(find.text('Choose your captain'), findsOneWidget);

      await tester.tap(find.text('Bhrun'));
      await tester.scrollUntilVisible(find.byType(TextField), 200);
      await tester.enterText(find.byType(TextField), '42');
      await tester.tap(find.text('Story mode: the full campaign'));
      await tester.pumpAndSettle();

      expect(find.textContaining('TURN 1'), findsOneWidget);
      expect(find.text('Captain\'s log, turn one'), findsOneWidget);

      await tester.tap(find.text('Welcome them properly'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Bhrun-Gai'), findsWidgets);
      await tester.tap(find.text('Hold position (end turn)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('TURN 2'), findsOneWidget);
    },
  );
}
