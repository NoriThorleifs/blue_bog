import 'package:blue_bog/presentation/node_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:blue_bog/presentation/home_screen.dart';

final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'node/:nodeId',
          builder: (context, state) => NodeScreen(
            nodeId: state.pathParameters['nodeId']!,
          ),
        ),
      ],
    ),
  ],
);
