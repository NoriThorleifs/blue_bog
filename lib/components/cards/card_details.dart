import 'package:flutter/material.dart';

import '../../game_engine/combat/catalog.dart';
import '../../game_engine/combat/equipment.dart';
import '../theme.dart';
import 'card_widgets.dart';

/// Everything about one card. Arrows on either side of the name (or a
/// swipe) step through the card's tiers, so the captain can see what
/// merging it would make, and what it was made from. The [actions] always
/// act on the card itself, whichever tier is showing.
class CardDetails extends StatefulWidget {
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
  State<CardDetails> createState() => _CardDetailsState();
}

class _CardDetailsState extends State<CardDetails> {
  /// The tier showing, as an index into [tiersOf].
  late int _shown = _own;

  Equipment get _card => equipmentById(widget.id);

  /// The card's own place among its tiers.
  int get _own => tiersOf(_card).indexOf(_card);

  @override
  void didUpdateWidget(CardDetails old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) _shown = _own;
  }

  void _step(int by, int count) {
    final next = _shown + by;
    if (next < 0 || next >= count) return;
    setState(() => _shown = next);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: Palette.muted);
    final tiers = tiersOf(_card);
    final own = _own;
    final upgrade = upgradeOf(_card);

    /// Everything about the tier at [index], under the arrows.
    Widget body(int index) {
      final shown = tiers[index];
      final preview = index != own;
      final where = switch (shown.kind) {
        CardKind.equipment when shown.isCargoBay => 'Works in the cargo bay.',
        CardKind.equipment => 'Works in a slot.',
        CardKind.supplies => 'Works from a slot or the hold.',
        CardKind.commodity => 'Trade goods. Worth more at some markets.',
        CardKind.mission =>
          'Cargo you\'ve been paid to deliver. Can\'t be sold.',
        CardKind.colony => 'Works in the colony grid. Never fights.',
      };
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (preview) ...[
            const SizedBox(height: 6),
            Text(switch (index - own) {
              1 => 'Preview: three of yours merge into this.',
              2 => 'Preview: nine of yours merge into this.',
              _ => 'Preview: three of these merge into the next tier.',
            }, style: muted),
          ],
          if (shown.tags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (final tag in shown.tags)
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
          for (final line in shown.describe()) Text(line),
          for (final line in shown.describePerks()) PerkLine(line),
          Text(where, style: muted),
          if (shown.text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              shown.text,
              style: text.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
          if (!preview && widget.median != null) ...[
            const SizedBox(height: 6),
            Text('Galactic median price: ${widget.median} cr'),
          ],
          if (!preview && upgrade != null && widget.copies != null) ...[
            const SizedBox(height: 6),
            Text(
              'You have ${widget.copies} of 3. Three merge into '
              '${upgrade.name}.',
              style: muted,
            ),
          ],
        ],
      );
    }

    return Card(
      child: GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v.abs() > 200) _step(v < 0 ? 1 : -1, tiers.length);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TierHeader(
                card: tiers[_shown],
                tiers: tiers.length,
                shown: _shown,
                own: own,
                onStep: (by) => _step(by, tiers.length),
              ),
              // As tall as the tallest tier, so the arrows stay put while
              // the captain steps through them.
              IndexedStack(
                index: _shown,
                children: [for (var i = 0; i < tiers.length; i++) body(i)],
              ),
              if (widget.actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: widget.actions),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The name and tier of the card showing, between arrows that step to the
/// tier below and above, with a dot for each tier.
class _TierHeader extends StatelessWidget {
  const _TierHeader({
    required this.card,
    required this.tiers,
    required this.shown,
    required this.own,
    required this.onStep,
  });

  final Equipment card;
  final int tiers;
  final int shown;

  /// The tier of the card actually tapped.
  final int own;
  final void Function(int by) onStep;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colour = cardColour(card);
    final label = Text(switch (card.kind) {
      CardKind.commodity => 'Commodity',
      CardKind.mission => 'Mission cargo',
      _ => card.tier.label,
    }, style: text.labelMedium?.copyWith(color: colour));
    final title = Text(card.name, style: text.titleLarge);
    if (tiers < 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [title, label],
      );
    }
    Widget arrow(IconData icon, int by, String tooltip) {
      final enabled = shown + by >= 0 && shown + by < tiers;
      return IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        color: colour,
        disabledColor: Palette.muted.withValues(alpha: 0.3),
        onPressed: enabled ? () => onStep(by) : null,
      );
    }

    return Row(
      children: [
        arrow(Icons.chevron_left, -1, 'Tier below'),
        Expanded(
          child: Column(
            children: [
              title,
              label,
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < tiers; i++)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == shown ? colour : Colors.transparent,
                        // The card's own tier keeps a ring when another
                        // tier is showing.
                        border: Border.all(
                          color: i == own ? colour : Palette.muted,
                          width: i == own ? 1.5 : 1,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        arrow(Icons.chevron_right, 1, 'Tier above'),
      ],
    );
  }
}

/// A bonus the card gained from merging (see [Perk]), marked with a gold
/// star.
class PerkLine extends StatelessWidget {
  const PerkLine(this.text, {super.key});
  final String text;

  static const gold = Color(0xFFFFD25A);

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(top: 2, right: 4),
        child: Icon(Icons.star, size: 14, color: gold),
      ),
      Expanded(
        child: Text(text, style: const TextStyle(color: gold)),
      ),
    ],
  );
}
