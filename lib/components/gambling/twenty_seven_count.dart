import 'package:flutter/material.dart';

import '../../functions/three_thirds/ternary_number_translator.dart';
import '../../game_engine/gambling/twenty_seven.dart';
import 'twenty_seven_colours.dart';

/// The count in ternary words, as the dealer calls it.
class CountPanel extends StatelessWidget {
  const CountPanel({super.key, required this.game});
  final TwentySeven? game;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final g = game;
    final count = g?.count ?? 0;
    final (colour, verdict) = switch (g?.status) {
      null => (SeaColours.foam, 'Place your stake'),
      CountStatus.counting => (
        SeaColours.aqua,
        'Counting… stake ${g!.stake} cr',
      ),
      CountStatus.holy => (
        SeaColours.gold,
        'Holy 2! Walk away or keep counting?',
      ),
      CountStatus.bust when count > holyGoal => (
        SeaColours.bust,
        'Past 27. You lose ${g!.stake} cr.',
      ),
      CountStatus.bust => (SeaColours.bust, 'Bust! You lose ${g!.stake} cr.'),
      CountStatus.walked => (
        SeaColours.gold,
        'You walk away with ${g!.payout} cr.',
      ),
      CountStatus.won => (
        SeaColours.gold,
        'TWENTY-SEVEN! You win ${g!.payout} cr!',
      ),
    };
    final glowing = colour != SeaColours.aqua && colour != SeaColours.foam;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: colour),
      duration: const Duration(milliseconds: 400),
      builder: (context, c, _) => CountStone(
        padding: 16,
        tint: c,
        glow: glowing ? c : null,
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(
                  scale: Tween(begin: 0.7, end: 1.0).animate(
                    CurvedAnimation(parent: a, curve: Curves.easeOutBack),
                  ),
                  child: child,
                ),
              ),
              child: Column(
                key: ValueKey(count),
                children: [
                  Text(
                    intToTernaryString(count),
                    textAlign: TextAlign.center,
                    style: text.headlineSmall?.copyWith(
                      color: c!,
                      shadows: [if (glowing) Shadow(color: c, blurRadius: 16)],
                    ),
                  ),
                  Text('$count', style: text.titleMedium),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(verdict, textAlign: TextAlign.center, style: text.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// A slab of stone standing in the pool, like the tiles: a dry top face, a
/// sliver of its side above the waterline and a shadow on the floor.
/// Opaque, so text stays readable over the water, and painted once: nothing
/// on it moves with the water.
class CountStone extends StatelessWidget {
  const CountStone({
    super.key,
    required this.child,
    this.padding = 12,
    this.tint,
    this.glow,
  });
  final Widget child;
  final double padding;

  /// Colours the face and edge, for the count's verdicts.
  final Color? tint;

  /// A halo round the slab, for the verdicts worth shouting about.
  final Color? glow;

  /// How much of the slab's side shows below its face.
  static const thick = 7.0;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _StonePainter(tint: tint, glow: glow),
    child: Padding(
      padding: EdgeInsets.fromLTRB(padding, padding, padding, padding + thick),
      child: child,
    ),
  );
}

class _StonePainter extends CustomPainter {
  _StonePainter({this.tint, this.glow});
  final Color? tint;
  final Color? glow;

  @override
  void paint(Canvas canvas, Size size) {
    const thick = CountStone.thick;
    const waterline = thick * 0.35;
    final face = tint == null
        ? SeaColours.stone
        : Color.lerp(SeaColours.stone, tint, 0.12)!;
    final side = Color.lerp(face, Colors.black, 0.45)!;
    final slab = RRect.fromRectAndRadius(
      Offset.zero & Size(size.width, size.height - thick),
      const Radius.circular(16),
    );
    RRect sunk(double dy) => slab.shift(Offset(0, dy));

    // Flat layers stand in for blurs throughout: the water under them
    // moves, so a blur would be worked out again every frame.
    // Fine steps of a pixel or so, from a wide faint rim in to a dark core,
    // read as a soft edge.
    final shadow = slab.shift(const Offset(thick * 0.8, thick * 1.6));
    for (var i = 0; i < 6; i++) {
      canvas.drawRRect(
        shadow.inflate(6.0 - i * 1.6),
        Paint()..color = SeaColours.floorShadow.withValues(alpha: 0.09),
      );
    }
    if (glow case final g?) {
      for (final grow in [12.0, 8.0, 4.0]) {
        canvas.drawRRect(
          slab.inflate(grow),
          Paint()..color = g.withValues(alpha: 0.09),
        );
      }
    }
    // The side: under water up to the waterline, dry above it, with a
    // bright meniscus where the surface meets it.
    canvas
      ..drawRRect(sunk(thick), Paint()..color = side)
      ..drawRRect(
        sunk(thick),
        Paint()..color = SeaColours.aqua.withValues(alpha: 0.35),
      )
      ..drawRRect(sunk(waterline), Paint()..color = side)
      ..drawRRect(
        sunk(waterline),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = SeaColours.foam.withValues(alpha: 0.5),
      )
      ..drawRRect(
        slab,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(face, Colors.white, 0.12)!, face],
          ).createShader(slab.outerRect),
      )
      ..drawRRect(
        slab.deflate(0.75),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color =
              tint?.withValues(alpha: 0.8) ??
              Color.lerp(face, Colors.white, 0.3)!,
      );
  }

  @override
  bool shouldRepaint(_StonePainter old) => old.tint != tint || old.glow != glow;
}

/// A heading that sits straight on the water.
class CountLabel extends StatelessWidget {
  const CountLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.titleMedium?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      shadows: const [
        Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(0, 1)),
      ],
    ),
  );
}
