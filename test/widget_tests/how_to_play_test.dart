import 'package:blue_bog/screens/how_to_play_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('every section of the guide opens cleanly on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: HowToPlayScreen()));
    final titles = [
      'The goal',
      'Your ship: the triforce',
      'Cards and merging',
      'Fights',
      'Stations and trade',
      'Cargo bay, hold and wreckage',
      'The human colony',
      'Hell',
      'Elites, Nobody and the end',
      'Story mode',
    ];
    for (final title in titles.skip(1)) {
      await tester.scrollUntilVisible(find.text(title), 300);
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('Satan himself'), findsOneWidget);
  });
}
