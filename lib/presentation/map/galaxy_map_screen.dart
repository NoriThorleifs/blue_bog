import 'package:flutter/material.dart' hide Route;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/run_controller.dart';
import '../../app/theme.dart';
import '../../game/run_state.dart';
import '../event_overlay.dart';
import '../hud.dart';
import 'galaxy_view.dart';
import 'system_panel.dart';

class GalaxyMapScreen extends ConsumerStatefulWidget {
  const GalaxyMapScreen({super.key});

  @override
  ConsumerState<GalaxyMapScreen> createState() => _GalaxyMapScreenState();
}

class _GalaxyMapScreenState extends ConsumerState<GalaxyMapScreen> {
  final _scaffold = GlobalKey<ScaffoldState>();
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final run = ref.watch(runProvider);
    if (run == null) return const Scaffold();

    // Surface galactic news as it happens.
    ref.listen(runProvider, (before, after) {
      if (before == null || after == null) return;
      // Watch every new fight as it happens.
      if (after.lastCombat != null &&
          !identical(after.lastCombat, before.lastCombat)) {
        context.push('/combat');
      }
      final fresh = after.log.skip(before.log.length);
      final news = fresh.where(
        (e) => e.kind == LogKind.news && e.title != null,
      );
      if (news.isEmpty) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(news.map((e) => e.title).join('  ·  ')),
            action: SnackBarAction(
              label: 'Read',
              onPressed: () => _scaffold.currentState?.openEndDrawer(),
            ),
          ),
        );
    });

    final routes = ref.read(engineProvider).routesFrom(run);
    final selected = run.revealed.contains(_selected)
        ? _selected!
        : run.location;
    final panel = run.inHell
        ? HellPanel(run: run)
        : SystemPanel(run: run, systemId: selected, routes: routes);

    return Scaffold(
      key: _scaffold,
      endDrawer: LogDrawer(run: run),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Hud(
            run: run,
            onOpenLog: () => _scaffold.currentState?.openEndDrawer(),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final wide = box.maxWidth >= 900;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          run.inHell
                              ? Palette.hell.withValues(alpha: 0.35)
                              : Colors.transparent,
                          BlendMode.srcATop,
                        ),
                        child: GalaxyView(
                          run: run,
                          routes: routes,
                          selected: selected,
                          focusY: wide ? 0.5 : 0.28,
                          onSelect: (id) => setState(() => _selected = id),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12 + MediaQuery.paddingOf(context).bottom,
                      left: wide ? null : 12,
                      width: wide ? 380 : null,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: box.maxHeight * (wide ? 0.9 : 0.45),
                        ),
                        child: Card(
                          color: Theme.of(context).colorScheme.surface,
                          margin: EdgeInsets.zero,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: panel,
                          ),
                        ),
                      ),
                    ),
                    EventOverlay(run: run),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
