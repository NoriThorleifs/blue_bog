import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../game/combat/catalog.dart';
import '../../game/combat/equipment.dart';

/// Colour for a card's family, so cards of a kind read as a kind.
Color cardColour(Equipment card) => switch (card.kind) {
  CardKind.commodity => const Color(0xFFD9B98C),
  CardKind.mission => const Color(0xFFFFFFFF),
  CardKind.supplies => const Color(0xFFA7B4C2),
  CardKind.equipment => switch (card.action) {
    FireLaser() => const Color(0xFF4DE1FF),
    FireMissile() => const Color(0xFFFFA24D),
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
    null when card.berths > 0 => const Color(0xFFFFD25A),
    null when card.hospital > 0 => const Color(0xFFFF8FB8),
    null when card.hellShielding > 0 => const Color(0xFFB07BFF),
    null => const Color(0xFF9FB2C8),
  },
};

/// A small square card: tier marks and name.
class CardTile extends StatelessWidget {
  const CardTile({
    super.key,
    required this.id,
    this.selected = false,
    this.onTap,
    this.footer,
    this.note,
    this.dimmed = false,
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

  @override
  Widget build(BuildContext context) {
    final card = id == null ? null : equipmentById(id!);
    final colour = card == null ? Palette.muted : cardColour(card);
    return Semantics(
      button: onTap != null,
      label: card?.name ?? 'Empty',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: card == null
                ? Colors.black.withValues(alpha: 0.3)
                : Color.lerp(Palette.space, colour, dimmed ? 0.08 : 0.22),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? Colors.white
                  : colour.withValues(alpha: card == null ? 0.3 : 0.8),
              width: selected ? 2.5 : 1.2,
            ),
            boxShadow: [
              if (card != null && !dimmed)
                BoxShadow(
                  color: colour.withValues(alpha: 0.35),
                  blurRadius: 10,
                ),
            ],
          ),
          child: card == null
              ? const SizedBox.expand()
              : Opacity(
                  opacity: dimmed ? 0.55 : 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CardArt(card: card),
                      // A dark fade at the bottom keeps the name readable
                      // over the art.
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.45, 1],
                            colors: [Colors.transparent, Color(0xCC000000)],
                          ),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Three tier marks are wider than a slot in the
                          // combat replay.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: TierMarks(card: card, colour: colour),
                          ),
                          Flexible(child: _label(card, colour)),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _label(Equipment card, Color colour) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.bottomCenter,
    child: ConstrainedBox(
      // Laid out this wide, then shrunk to fit: narrow enough that names
      // stay readable in a phone's combat triforce.
      constraints: const BoxConstraints(maxWidth: 64),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            card.name,
            textAlign: TextAlign.center,
            maxLines: 3,
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

/// Everything about one card.
class CardDetails extends StatelessWidget {
  const CardDetails({
    super.key,
    required this.id,
    this.copies,
    this.median,
    this.actions = const [],
  });

  final String id;

  /// How many the captain owns, for merge progress.
  final int? copies;

  /// What the card usually costs across the galaxy.
  final int? median;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final card = equipmentById(id);
    final upgrade = upgradeOf(card);
    final where = switch (card.kind) {
      CardKind.equipment => 'Works in a slot.',
      CardKind.supplies => 'Works from a slot or the hold.',
      CardKind.commodity => 'Trade goods. Worth more at some markets.',
      CardKind.mission => 'Cargo you\'ve been paid to deliver. Can\'t be sold.',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(card.name, style: text.titleLarge),
            Text(switch (card.kind) {
              CardKind.commodity => 'Commodity',
              CardKind.mission => 'Mission cargo',
              _ => card.tier.label,
            }, style: text.labelMedium?.copyWith(color: cardColour(card))),
            if (card.tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  for (final tag in card.tags)
                    Chip(
                      avatar: const Icon(
                        Icons.sell_outlined,
                        size: 14,
                        color: hellishRed,
                      ),
                      label: Text(tag.label),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            for (final line in card.describe()) Text(line),
            Text(where, style: text.bodySmall?.copyWith(color: Palette.muted)),
            if (card.text.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                card.text,
                style: text.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            if (median != null) ...[
              const SizedBox(height: 6),
              Text('Galactic median price: $median cr'),
            ],
            if (upgrade != null && copies != null) ...[
              const SizedBox(height: 6),
              Text(
                'You have $copies of 3. Three merge into ${upgrade.name}.',
                style: text.bodySmall?.copyWith(color: Palette.muted),
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

/// A slow pulsing glow around [child], to show it can be picked.
class GlowPulse extends StatefulWidget {
  const GlowPulse({super.key, required this.child});
  final Widget child;

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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.125 + 0.3 * t),
            width: 2,
          ),
          boxShadow: [
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
