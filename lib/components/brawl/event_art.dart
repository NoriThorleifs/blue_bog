import 'package:flutter/material.dart';

import '../../game_engine/brawl/brawl.dart';
import '../theme.dart';

/// Every event's backdrop, and where each picture's subject sits, so a
/// phone's narrow crop keeps it. The pictures are placeholders from
/// `tool/generate_event_art.py`, in the same order.
const eventArt = <String, Alignment>{
  'chewer': Alignment(0.2, 0),
  'toll': Alignment.center,
  'wreck': Alignment.center,
  'neo_terra': Alignment.center,
  'smuggler': Alignment(-0.2, 0),
  'leak': Alignment.center,
  'quiet_lane': Alignment.center,
  'convoy': Alignment.center,
  'shakedown': Alignment.center,
  'gor_duel': Alignment(-0.45, 0),
  'unmerged_foundry': Alignment.center,
  'nobody': Alignment.center,
  'nobody_abandoned': Alignment.center,
  'gift_boarders': Alignment.center,
  'wrong_warp': Alignment.center,
  'neo_terra_war': Alignment(0.85, 0),
  'veterans_home': Alignment(-0.3, 0),
  'the_helmet': Alignment.center,
  'petition_rifles': Alignment.center,
  'petition_gravity': Alignment.center,
  'petition_wreck': Alignment(0.1, 0),
  'hell_headcount': Alignment.center,
  'red_eyes': Alignment.center,
  'wrong_warp_offer': Alignment.center,
  'colony_strike': Alignment.center,
  'kepler_refused': Alignment(0.2, 0),
  'elephant_crate': Alignment.center,
  'gor_colony_mutiny': Alignment.center,
  'tern_colony_stays': Alignment.center,
  'gift_spares': Alignment.center,
  'gift_double_shift': Alignment.center,
  'gift_collection': Alignment.center,
  'gift_ammunition': Alignment.center,
  'gift_shipwrights': Alignment.center,
  'hell_flesh': Alignment.center,
  'hell_hunter': Alignment.center,
  'hell_swarm': Alignment.center,
  'hell_still': Alignment.center,
  'hell_clocks': Alignment.center,
  'hell_barrier': Alignment.center,
  'hell_herald': Alignment.center,
  'hell_mourner': Alignment(0, 0.3),
  'satan': Alignment.center,
  'secession': Alignment(0.1, 0),
  'uploaded_flagship': Alignment(0.2, 0),
};

/// The brawl screen's background: tinted red in Hell.
Color brawlBackground(BuildContext context, BrawlState brawl) => brawl.inHell
    ? Color.lerp(Palette.space, Palette.hell, 0.12)!
    : Theme.of(context).scaffoldBackgroundColor;

/// [child] over the event's picture, if it has one: the picture fills the
/// top of the screen and fades into [background], and [child] scrolls over
/// it. [child] is told how far down to start so the picture shows first.
class EventBackdrop extends StatelessWidget {
  const EventBackdrop({
    super.key,
    required this.eventId,
    required this.background,
    required this.child,
  });

  final String eventId;
  final Color background;
  final Widget Function(double top) child;

  @override
  Widget build(BuildContext context) {
    final focus = eventArt[eventId];
    if (focus == null) return child(0);
    return LayoutBuilder(
      builder: (context, box) {
        // Landscape screens get a shorter strip, so the text still fits.
        final height =
            box.maxHeight * (box.maxWidth > box.maxHeight ? 0.45 : 0.5);
        return Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: height,
              child: Image.asset(
                'assets/events/${eventId}_ai_generated.jpg',
                fit: BoxFit.cover,
                alignment: focus,
                errorBuilder: (context, error, stack) => const SizedBox(),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: height + 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.55, 1],
                    colors: [
                      background.withValues(alpha: 0),
                      background.withValues(alpha: 0.35),
                      background,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(child: child(height * 0.62)),
          ],
        );
      },
    );
  }
}
