import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/cards/card_widgets.dart';
import '../components/theme.dart';
import '../game_engine/brawl/brawl.dart';
import '../game_engine/captain/species.dart';
import '../game_engine/combat/catalog.dart';
import '../providers/brawl_provider.dart';
import '../providers/run_provider.dart';

class TitleScreen extends ConsumerStatefulWidget {
  const TitleScreen({super.key});

  @override
  ConsumerState<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends ConsumerState<TitleScreen> {
  Species _species = Species.tern;
  final _seed = TextEditingController();

  @override
  void dispose() {
    _seed.dispose();
    super.dispose();
  }

  void _story() {
    ref
        .read(runProvider.notifier)
        .start(_species, seed: int.tryParse(_seed.text.trim()));
    context.go('/map');
  }

  void _brawl() {
    ref
        .read(brawlProvider.notifier)
        .start(_species, seed: int.tryParse(_seed.text.trim()));
    context.go('/brawl');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      bottomNavigationBar: Material(
        color: Palette.panel,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: _brawl,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: const Icon(Icons.rocket_launch),
                  label: Text('Launch as ${_species.name} captain'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _story,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  icon: const Icon(Icons.auto_stories_outlined),
                  label: const Text('Story mode: the full campaign'),
                ),
              ],
            ),
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/galaxy_ai_generated.jpg'),
            fit: BoxFit.cover,
            opacity: 0.25,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 24),
                  Text(
                    'BLUE BOG',
                    textAlign: TextAlign.center,
                    style: text.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Find a crew. Keep a ship. Make ends meet. '
                    'Try not to be the reason the humans push the button.',
                    textAlign: TextAlign.center,
                    style: text.bodyLarge?.copyWith(color: Palette.muted),
                  ),
                  const SizedBox(height: 32),
                  Text('Choose your captain', style: text.titleLarge),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, box) => Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final species in Species.values)
                          SizedBox(
                            width: box.maxWidth < 720 ? box.maxWidth : 340,
                            child: _SpeciesCard(
                              species: species,
                              selected: species == _species,
                              onTap: () => setState(() => _species = species),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 180,
                      child: TextField(
                        controller: _seed,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Seed (optional)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeciesCard extends StatelessWidget {
  const _SpeciesCard({
    required this.species,
    required this.selected,
    required this.onTap,
  });

  final Species species;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ship = species.ship;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? Palette.gateway
              : Palette.gateway.withValues(alpha: 0.2),
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(species.name, style: text.titleLarge),
              Text(
                species.traits,
                style: text.labelMedium?.copyWith(color: Palette.muted),
              ),
              const SizedBox(height: 8),
              Text(species.blurb, style: text.bodyMedium),
              const Divider(height: 24),
              Text(ship.name, style: text.titleSmall),
              Text(
                ship.description,
                style: text.bodySmall?.copyWith(color: Palette.muted),
              ),
              const SizedBox(height: 8),
              _Stat(
                Icons.toll_outlined,
                'Credits',
                species.startingCredits + BrawlEngine.startingBonus,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final id in brawlStartingCards(species))
                    Chip(
                      label: Text(equipmentById(id).name),
                      labelStyle: text.labelSmall,
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(
                        color: cardColour(
                          equipmentById(id),
                        ).withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Palette.muted),
        const SizedBox(width: 4),
        Text('$value'),
      ],
    ),
  );
}
