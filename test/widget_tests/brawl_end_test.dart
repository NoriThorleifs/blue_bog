import 'package:blue_bog/components/brawl/brawl_victory.dart';
import 'package:blue_bog/components/brawl/brawl_wreckage.dart';
import 'package:blue_bog/game_engine/brawl/brawl.dart';
import 'package:blue_bog/game_engine/brawl/brawl_events.dart';
import 'package:blue_bog/game_engine/captain/species.dart';
import 'package:blue_bog/providers/brawl_provider.dart';
import 'package:blue_bog/screens/brawl_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  transitTests();
  final won = const BrawlEngine().start(Species.tern, seed: 1).clone()
    ..round = 27
    ..fightsWon = 26
    ..flags.add(beatSatan);

  Widget host(Widget child) => ProviderScope(
    child: MaterialApp(home: Scaffold(body: child)),
  );

  testWidgets('beating Satan offers retiring or going on', (tester) async {
    await tester.pumpWidget(host(Victory(brawl: won)));
    expect(find.text('Satan is beaten'), findsOneWidget);
    expect(find.text('Retire a winner'), findsOneWidget);
    expect(find.text('Keep going'), findsOneWidget);
  });

  testWidgets('the wreckage shows what was left behind', (tester) async {
    final s = won.clone()..wreckage = ['missiles_1', 'goods_ore'];
    await tester.pumpWidget(host(WreckageBar(brawl: s)));
    expect(find.textContaining('Left in the wreckage'), findsOneWidget);
    expect(find.text('Missile Rack'), findsOneWidget);
  });
}

class _Fixed extends BrawlController {
  _Fixed(this.fixed);
  final BrawlState fixed;
  @override
  BrawlState? build() => fixed;
}

void transitTests() {
  testWidgets('news after a dock pops up once, then clears', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = const BrawlEngine().start(Species.tern, seed: 1).clone()
      ..log = [
        'Docked at Somewhere.',
        'The colony\'s businesses paid 9 credits.',
      ];
    final container = ProviderContainer(
      overrides: [brawlProvider.overrideWith(() => _Fixed(s))],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: BrawlScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('businesses paid 9'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(container.read(brawlProvider)!.log, isEmpty);
    expect(find.textContaining('businesses paid 9'), findsNothing);
  });

  testWidgets('in transit, a colony event waits before the dock', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = const BrawlEngine().start(Species.tern, seed: 1).clone()
      ..event = 'petition_gravity'
      ..inTransit = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [brawlProvider.overrideWith(() => _Fixed(s))],
        child: const MaterialApp(home: BrawlScreen()),
      ),
    );
    expect(find.text('In transit'), findsOneWidget);
    expect(find.text('A petition: gravity'), findsOneWidget);
    await tester.tap(find.text('Pay for it'));
    await tester.pumpAndSettle();
    expect(find.text('Dock'), findsOneWidget);
  });
}
