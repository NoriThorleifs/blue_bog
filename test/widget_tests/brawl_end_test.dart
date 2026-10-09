import 'package:blue_bog/components/brawl/brawl_victory.dart';
import 'package:blue_bog/components/brawl/brawl_wreckage.dart';
import 'package:blue_bog/game_engine/brawl/brawl.dart';
import 'package:blue_bog/game_engine/brawl/brawl_events.dart';
import 'package:blue_bog/game_engine/captain/species.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
