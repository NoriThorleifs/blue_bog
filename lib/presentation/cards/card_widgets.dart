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
    TeleportBomb() => const Color(0xFFFF4D3D),
    ChargeShields() => const Color(0xFF7FA8FF),
    BuildDrone() => const Color(0xFF5CFF8A),
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
    this.dimmed = false,
  });

  final String? id;
  final bool selected;
  final VoidCallback? onTap;

  /// A line under the name, like a price.
  final String? footer;

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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TierMarks(card: card, colour: colour),
                      const SizedBox(height: 2),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 80),
                            child: Text(
                              card.name,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              style: const TextStyle(fontSize: 11, height: 1.1),
                            ),
                          ),
                        ),
                      ),
                      if (footer != null)
                        Text(
                          footer!,
                          style: TextStyle(
                            fontSize: 10,
                            color: colour,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// One triangle per tier; a star for unique cards; a crate for cargo.
class TierMarks extends StatelessWidget {
  const TierMarks({super.key, required this.card, required this.colour});
  final Equipment card;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    if (card.kind == CardKind.commodity) {
      return Icon(Icons.inventory_2_outlined, size: 12, color: colour);
    }
    if (card.kind == CardKind.mission) {
      return Icon(Icons.local_shipping_outlined, size: 12, color: colour);
    }
    if (card.tier == Tier.unique) {
      return Icon(Icons.auto_awesome, size: 12, color: colour);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i <= card.tier.index; i++)
          Icon(Icons.change_history, size: 10, color: colour),
      ],
    );
  }
}

/// Everything about one card.
class CardDetails extends StatelessWidget {
  const CardDetails({
    super.key,
    required this.id,
    this.copies,
    this.actions = const [],
  });

  final String id;

  /// How many the captain owns, for merge progress.
  final int? copies;
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
