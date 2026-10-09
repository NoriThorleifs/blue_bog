import 'package:flutter/material.dart';

import '../cards/card_widgets.dart';
import '../theme.dart';

/// One topic of the guide: a heading that opens to text and pictures.
class GuideSection extends StatelessWidget {
  const GuideSection({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      leading: Icon(icon, color: Palette.gateway),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      initiallyExpanded: initiallyExpanded,
      shape: const Border(),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, child) in children.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          child,
        ],
      ],
    ),
  );
}

/// A paragraph of the guide.
class GuideText extends StatelessWidget {
  const GuideText(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.bodyMedium);
}

/// A short list of points.
class GuideBullets extends StatelessWidget {
  const GuideBullets(this.points, {super.key});
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final point in points)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: style?.copyWith(color: Palette.gateway)),
                Expanded(child: Text(point, style: style)),
              ],
            ),
          ),
      ],
    );
  }
}

/// A picture with a caption under it.
class GuideFigure extends StatelessWidget {
  const GuideFigure({
    super.key,
    required this.child,
    required this.caption,
    this.maxWidth = 360,
  });

  final Widget child;
  final String caption;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        children: [
          child,
          const SizedBox(height: 6),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Palette.muted),
          ),
        ],
      ),
    ),
  );
}

/// A card's art, as it looks in the game.
class GuideCard extends StatelessWidget {
  const GuideCard(this.id, {super.key, this.size = 72});
  final String id;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CardTile(id: id),
  );
}

/// Cards in a row, each with a few words under it.
class GuideCardRow extends StatelessWidget {
  const GuideCardRow(this.cards, {super.key});
  final List<(String id, String caption)> cards;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: Palette.muted);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (id, caption) in cards)
          SizedBox(
            width: 84,
            child: Column(
              children: [
                GuideCard(id),
                const SizedBox(height: 4),
                Text(caption, textAlign: TextAlign.center, style: style),
              ],
            ),
          ),
      ],
    );
  }
}

/// One card against what stops it: "this — is stopped by → that".
class GuideCounter extends StatelessWidget {
  const GuideCounter(
    this.attacker,
    this.verb,
    this.defender,
    this.note, {
    super.key,
  });

  final String attacker;
  final String verb;
  final String? defender;
  final String note;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        GuideCard(attacker, size: 56),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                Text(
                  verb,
                  textAlign: TextAlign.center,
                  style: text.labelMedium?.copyWith(color: Palette.gateway),
                ),
                const Icon(Icons.arrow_forward, color: Palette.muted, size: 18),
                Text(
                  note,
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: Palette.muted),
                ),
              ],
            ),
          ),
        ),
        if (defender case final id?)
          GuideCard(id, size: 56)
        else
          const SizedBox(width: 56),
      ],
    );
  }
}

/// Three copies of a card merging into the next tier, twice.
class GuideMergeChain extends StatelessWidget {
  const GuideMergeChain(this.family, {super.key});
  final String family;

  @override
  Widget build(BuildContext context) {
    Widget step(int tier) => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++) ...[
          GuideCard('${family}_$tier', size: 52),
          if (i < 2) const SizedBox(width: 4),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.arrow_forward, color: Palette.muted),
        ),
        GuideCard('${family}_${tier + 1}', size: 64),
      ],
    );
    return Column(children: [step(1), const SizedBox(height: 8), step(2)]);
  }
}
