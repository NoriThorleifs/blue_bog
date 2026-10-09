import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game_engine/brawl/brawl.dart';
import '../../providers/brawl_provider.dart';
import '../cards/card_widgets.dart';
import '../dialogs.dart';
import '../theme.dart';

/// What was left in the wreckage for want of room. Tap a card to take it
/// aboard; jettison something on the Ship tab first if there's no room.
/// Gone once the ship moves on.
class WreckageBar extends ConsumerWidget {
  const WreckageBar({super.key, required this.brawl});
  final BrawlState brawl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Palette.panel,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Left in the wreckage. Tap to take it; jettison something on '
              'the Ship tab if there\'s no room.',
              style: text.bodySmall?.copyWith(color: Palette.muted),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 64,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final (i, id) in brawl.wreckage.indexed)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: SizedBox.square(
                        dimension: 64,
                        child: CardTile(
                          id: id,
                          onTap: () => reportError(
                            context,
                            ref.read(brawlProvider.notifier).salvage(i),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
