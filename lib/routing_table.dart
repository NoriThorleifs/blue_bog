import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/brawl_provider.dart';
import 'providers/run_provider.dart';
import 'screens/brawl_screen.dart';
import 'screens/combat_screen.dart';
import 'screens/deck_screen.dart';
import 'screens/galaxy_map_screen.dart';
import 'screens/how_to_play_screen.dart';
import 'screens/gambling_screen.dart';
import 'screens/market_screen.dart';
import 'screens/title_screen.dart';

final routerProvider = Provider(
  (ref) => GoRouter(
    redirect: (context, state) {
      final at = state.matchedLocation;
      if (at == '/' || at == '/guide') return null;
      final playing = at.startsWith('/brawl')
          ? ref.read(brawlProvider) != null
          : ref.read(runProvider) != null;
      return playing ? null : '/';
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const TitleScreen()),
      GoRoute(
        path: '/guide',
        builder: (context, state) => const HowToPlayScreen(),
      ),
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
        path: '/brawl',
        builder: (context, state) => const BrawlScreen(),
        routes: [
          GoRoute(
            path: 'combat',
            builder: (context, state) => const CombatScreen(brawl: true),
          ),
          GoRoute(
            path: 'gambling',
            builder: (context, state) => const GamblingScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/combat',
        builder: (context, state) => const CombatScreen(),
      ),
    ],
  ),
);
