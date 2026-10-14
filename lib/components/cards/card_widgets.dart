import 'dart:math';

import 'package:flutter/material.dart';

import '../../game_engine/combat/catalog.dart';
import '../../game_engine/combat/equipment.dart';
import '../theme.dart';
import 'card_shapes.dart';

export 'card_details.dart';
export 'card_shapes.dart';

/// Colour for a card's family, so cards of a kind read as a kind.
Color cardColour(Equipment card) => switch (card.kind) {
  CardKind.commodity => const Color(0xFFD9B98C),
  CardKind.mission => const Color(0xFFFFFFFF),
  CardKind.supplies => const Color(0xFFA7B4C2),
  CardKind.colony => switch (card) {
    Equipment(housing: > 0) => const Color(0xFFFFD25A),
    Equipment(hospital: > 0) => const Color(0xFFFF8FB8),
    Equipment(crawlspace: > 0) => const Color(0xFF5CE0C8),
    _ => const Color(0xFF8FE07A),
  },
  CardKind.equipment => switch (card.action) {
    FireLaser() => const Color(0xFF4DE1FF),
    FireMissile() => const Color(0xFFFFA24D),
    FissionMissile() => const Color(0xFFFFE9A8),
    Broadcast() => const Color(0xFFFFD27A),
    TeleportBomb() || Board() => const Color(0xFFFF4D3D),
    IonBlast() => const Color(0xFFB48CFF),
    Flak() => const Color(0xFFE6C36A),
    Repair() => const Color(0xFF5CE0C8),
    LanceShot() => const Color(0xFF9DF0FF),
    JamTeleports() => const Color(0xFFFF8F80),
    RailShot() => const Color(0xFFDCE4F0),
    Hellfire() => hellishRed,
    ChargeShields() => const Color(0xFF7FA8FF),
    BuildDrone() => const Color(0xFF5CFF8A),
    null when card.boost?.only == ChargeShields => const Color(0xFF7FA8FF),
    null when card.boost != null => const Color(0xFFFFE066),
    null when card.hellShielding > 0 => const Color(0xFFB07BFF),
    null => const Color(0xFF9FB2C8),
  },
};

/// A small card in its kind's shape (see [CardShape]): tier marks, art and
/// name.
class CardTile extends StatelessWidget {
  const CardTile({
    super.key,
    required this.id,
    this.selected = false,
    this.onTap,
    this.footer,
    this.note,
    this.dimmed = false,
    this.emptyShape = CardShape.square,
  });

  final String? id;
  final bool selected;
  final VoidCallback? onTap;

  /// A line under the name, like a price.
  final String? footer;

  /// A small muted line under the footer, like a median price.
  final String? note;

  /// For cards that do nothing where they are, like equipment in the hold.
  final bool dimmed;

  /// The outline drawn when there's no card: what usually goes there.
  final CardShape emptyShape;

  @override
  Widget build(BuildContext context) {
    final card = id == null ? null : equipmentById(id!);
    final colour = card == null ? Palette.muted : cardColour(card);
    final shape = card == null ? emptyShape : CardShape.of(card);
    return Semantics(
      button: onTap != null,
      label: card?.name ?? 'Empty',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: ShapeDecoration(
            color: card == null
                ? Colors.black.withValues(alpha: 0.3)
                : Color.lerp(Palette.space, colour, dimmed ? 0.08 : 0.22),
            shape: shape.border(
              BorderSide(
                color: selected
                    ? Colors.white
                    : colour.withValues(alpha: card == null ? 0.3 : 0.8),
                width: selected ? 2.5 : 1.2,
              ),
            ),
            shadows: [
              if (card != null && !dimmed)
                BoxShadow(
                  color: colour.withValues(alpha: 0.35),
                  blurRadius: 10,
                ),
            ],
          ),
          child: card == null
              ? const SizedBox.expand()
              : ClipPath(
                  clipper: ShapeBorderClipper(shape: shape.border()),
                  child: Opacity(
                    opacity: dimmed ? 0.55 : 1,
                    child: switch (shape) {
                      CardShape.triangle => _triangle(card, colour),
                      CardShape.square => _face(
                        card,
                        colour,
                        const EdgeInsets.all(4),
                        // Wide enough for "Maintenance" on one line.
                        labelWidth: 72,
                        artAboveName: true,
                      ),
                      // Kept clear of the circle's narrowing edges.
                      CardShape.circle => LayoutBuilder(
                        builder: (context, box) => _face(
                          card,
                          colour,
                          EdgeInsets.all(
                            min(box.maxWidth, box.maxHeight) * 0.13,
                          ),
                        ),
                      ),
                    },
                  ),
                ),
        ),
      ),
    );
  }

  /// A square or round face: tier marks on top, art behind, name at the
  /// bottom, all [inset] from the edge. The fade behind the name fills the
  /// whole shape, so it follows the outline. With [artAboveName], the art
  /// keeps to the space between the tier marks and the name rather than
  /// filling the face.
  Widget _face(
    Equipment card,
    Color colour,
    EdgeInsets inset, {
    double labelWidth = 64,
    bool artAboveName = false,
  }) => Stack(
    fit: StackFit.expand,
    children: [
      Padding(
        padding: inset,
        child: artAboveName
            ? FractionallySizedBox(
                alignment: const Alignment(0, -0.45),
                heightFactor: 0.56,
                child: CardArt(card: card),
              )
            : CardArt(card: card),
      ),
      const _Fade(),
      Padding(
        padding: inset,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Three tier marks are wider than a slot in the combat replay.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: TierMarks(card: card, colour: colour),
            ),
            Flexible(child: _label(card, colour, width: labelWidth)),
          ],
        ),
      ),
    ],
  );

  /// A triangular face: tier marks under the point, art in the middle and
  /// the name in the wide band along the base. The triangle narrows towards
  /// its point, so the band is only as wide as the triangle is at its top,
  /// and a name's top line never runs past the edges.
  Widget _triangle(Equipment card, Color colour) => LayoutBuilder(
    builder: (context, box) {
      final Size(width: side, height: h) = triangleIn(box.biggest);
      // How far down the name's band starts, as a share of the height.
      const band = 0.64;
      // The triangle's width at the band's top, less the rounded corners
      // and the border.
      final labelWidth = side * band * 0.86;
      return Center(
        child: SizedBox(
          width: side,
          height: h,
          child: Stack(
            children: [
              Positioned(
                left: side * 0.24,
                right: side * 0.24,
                top: h * 0.27,
                height: h * 0.41,
                child: CardArt(card: card),
              ),
              const Positioned.fill(child: _Fade(from: 0.55)),
              Positioned(
                left: side * 0.38,
                right: side * 0.38,
                top: h * 0.19,
                height: h * 0.09,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: TierMarks(card: card, colour: colour),
                ),
              ),
              Positioned(
                left: (side - labelWidth) / 2,
                width: labelWidth,
                top: h * band,
                bottom: h * 0.05,
                child: _label(
                  card,
                  colour,
                  // Laid out no narrower than a short word needs, then
                  // shrunk to fit a small slot.
                  width: max(labelWidth, 58),
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _label(
    Equipment card,
    Color colour, {
    double width = 64,
    int maxLines = 3,
  }) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.bottomCenter,
    child: ConstrainedBox(
      // Laid out this wide, then shrunk to fit: narrow enough that names
      // stay readable in a phone's combat triforce.
      constraints: BoxConstraints(maxWidth: width),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            card.name,
            textAlign: TextAlign.center,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              height: 1.1,
              shadows: [Shadow(blurRadius: 3)],
            ),
          ),
          if (footer != null)
            Text(
              footer!,
              style: TextStyle(
                fontSize: 10,
                height: 1.15,
                color: colour,
                fontWeight: FontWeight.w600,
                shadows: const [Shadow(blurRadius: 3)],
              ),
            ),
          if (note != null)
            Text(
              note!,
              style: const TextStyle(fontSize: 9, color: Palette.muted),
            ),
        ],
      ),
    ),
  );
}

/// A dark fade towards the bottom, to keep a card's name readable over its
/// art.
class _Fade extends StatelessWidget {
  const _Fade({this.from = 0.45});
  final double from;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [from, 1],
        colors: const [Colors.transparent, Color(0xCC000000)],
      ),
    ),
  );
}

/// A card's placeholder art from `assets/cards/`, one image per family.
/// Made by `tool/generate_card_icons.py`.
class CardArt extends StatelessWidget {
  const CardArt({super.key, required this.card});
  final Equipment card;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/cards/${card.family}_ai_generated.png',
    fit: BoxFit.contain,
    filterQuality: FilterQuality.medium,
    errorBuilder: (context, error, stack) => const SizedBox.shrink(),
  );
}

/// One triangle per tier; a star for unique cards; a crate for cargo; a
/// flame for cards tagged Hellish.
class TierMarks extends StatelessWidget {
  const TierMarks({super.key, required this.card, required this.colour});
  final Equipment card;
  final Color colour;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ...switch (card) {
        Equipment(kind: CardKind.commodity) => [
          Icon(Icons.inventory_2_outlined, size: 12, color: colour),
        ],
        Equipment(kind: CardKind.mission) => [
          Icon(Icons.local_shipping_outlined, size: 12, color: colour),
        ],
        Equipment(tier: Tier.unique) => [
          Icon(Icons.auto_awesome, size: 12, color: colour),
        ],
        // Humans build in squares, not triangles.
        Equipment(kind: CardKind.colony) => [
          for (var i = 0; i <= card.tier.index; i++)
            Icon(Icons.crop_square, size: 10, color: colour),
        ],
        _ => [
          for (var i = 0; i <= card.tier.index; i++)
            Icon(Icons.change_history, size: 10, color: colour),
        ],
      },
      if (card.has(CardTag.hellish))
        const Icon(Icons.local_fire_department, size: 11, color: hellishRed),
    ],
  );
}

/// Marks cards tagged Hellish.
const hellishRed = Color(0xFFFF3D7F);

/// A slow pulsing glow around [child], to show it can be picked.
class GlowPulse extends StatefulWidget {
  const GlowPulse({
    super.key,
    required this.child,
    this.shape = CardShape.square,
  });
  final Widget child;

  /// The outline to glow around.
  final CardShape shape;

  @override
  State<GlowPulse> createState() => _GlowPulseState();
}

class _GlowPulseState extends State<GlowPulse>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pulse,
    child: widget.child,
    builder: (context, child) {
      final t = Curves.easeInOut.transform(_pulse.value);
      return DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: ShapeDecoration(
          shape: widget.shape.border(
            BorderSide(
              color: Colors.white.withValues(alpha: 0.125 + 0.3 * t),
              width: 2,
            ),
          ),
          shadows: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.05 + 0.175 * t),
              blurRadius: 6 + 10 * t,
              spreadRadius: 1 + 2 * t,
            ),
          ],
        ),
        child: child,
      );
    },
  );
}

/// Cards laid out in a grid of fixed-size squares. A wider screen gets more
/// columns rather than bigger squares. Below three columns' worth of width
/// the squares shrink instead, so a narrow phone still gets three.
class CardGrid extends StatelessWidget {
  const CardGrid({super.key, required this.children});
  final List<Widget> children;

  /// A shop square, in logical pixels.
  static const tile = 120.0;
  static const gap = 8.0;
  static const minColumns = 3;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final columns = max(
        minColumns,
        ((box.maxWidth + gap) / (tile + gap)).floor(),
      );
      final size = min(tile, (box.maxWidth - gap * (columns - 1)) / columns);
      return Center(
        child: SizedBox(
          width: columns * size + gap * (columns - 1),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final child in children)
                SizedBox.square(dimension: size, child: child),
            ],
          ),
        ),
      );
    },
  );
}
