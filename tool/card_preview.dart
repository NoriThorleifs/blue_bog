// Every card at once, at shop and hold sizes and in a triforce, for
// checking card faces (names fitting their shapes, art, tier marks)
// without playing to find each card.
//
//   flutter run -d emulator-5554 -t tool/card_preview.dart
import 'package:blue_bog/components/cards/card_widgets.dart';
import 'package:blue_bog/components/deck/triforce.dart';
import 'package:blue_bog/components/theme.dart';
import 'package:blue_bog/game_engine/combat/catalog.dart';
import 'package:flutter/material.dart';

void main() => runApp(
  MaterialApp(
    theme: appTheme,
    debugShowCheckedModeBanner: false,
    home: const _CardPreview(),
  ),
);

class _CardPreview extends StatefulWidget {
  const _CardPreview();

  @override
  State<_CardPreview> createState() => _CardPreviewState();
}

class _CardPreviewState extends State<_CardPreview> {
  /// The size of a square cell: 120 is a shop, 64 a phone's hold.
  double _tile = CardGrid.tile;

  @override
  Widget build(BuildContext context) {
    final cards = equipmentCatalog.values.toList();
    final triangles = [
      for (final card in cards)
        if (CardShape.of(card) == CardShape.triangle) card.id,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text('${cards.length} cards'),
        actions: [
          SegmentedButton<double>(
            segments: const [
              ButtonSegment(value: CardGrid.tile, label: Text('Shop')),
              ButtonSegment(value: 64, label: Text('Hold')),
            ],
            selected: {_tile},
            onSelectionChanged: (s) => setState(() => _tile = s.single),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (var i = 0; i < triangles.length; i += 9)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Triforce(
                slots: [
                  for (var j = i; j < i + 9; j++)
                    j < triangles.length ? triangles[j] : null,
                ],
              ),
            ),
          Wrap(
            spacing: CardGrid.gap,
            runSpacing: CardGrid.gap,
            children: [
              for (final card in cards)
                SizedBox.square(
                  dimension: _tile,
                  child: CardTile(id: card.id, footer: '${card.price} cr'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
