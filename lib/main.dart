import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/run_controller.dart';
import 'app/theme.dart';
import 'presentation/combat/combat_screen.dart';
import 'presentation/deck/deck_screen.dart';
import 'presentation/map/galaxy_map_screen.dart';
import 'presentation/market/market_screen.dart';
import 'presentation/title_screen.dart';

void main() => runApp(const ProviderScope(child: BlueBogApp()));

final routerProvider = Provider(
  (ref) => GoRouter(
    redirect: (context, state) =>
        state.matchedLocation != '/' && ref.read(runProvider) == null
        ? '/'
        : null,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const TitleScreen()),
      GoRoute(
        path: '/map',
        builder: (context, state) => const GalaxyMapScreen(),
      ),
      GoRoute(path: '/deck', builder: (context, state) => const DeckScreen()),
      GoRoute(
        path: '/market',
        builder: (context, state) => const MarketScreen(),
      ),
      GoRoute(
        path: '/combat',
        builder: (context, state) => const CombatScreen(),
      ),
    ],
  ),
);

class BlueBogApp extends ConsumerWidget {
  const BlueBogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Blue Bog',
    debugShowCheckedModeBanner: false,
    theme: appTheme,
    routerConfig: ref.watch(routerProvider),
  );
}
