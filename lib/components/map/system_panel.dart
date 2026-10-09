import 'package:flutter/material.dart' hide Route;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../game_engine/engine.dart';
import '../../game_engine/faction.dart';
import '../../game_engine/galaxy/galaxy.dart';
import '../../game_engine/run_state.dart';
import '../../providers/run_provider.dart';
import '../theme.dart';

/// Details and actions for the selected system.
class SystemPanel extends ConsumerWidget {
  const SystemPanel({
    super.key,
    required this.run,
    required this.systemId,
    required this.routes,
  });

  final RunState run;
  final String systemId;
  final List<Route> routes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final controller = ref.read(runProvider.notifier);
    final system = run.galaxy[systemId];
    final here = systemId == run.location;
    final route = routes.where((r) => r.to == systemId).firstOrNull;
    final engine = ref.read(engineProvider);
    final enabled = engine.canAct(run);
    final forSale = engine.fuelForSale(run);
    final station = system.tags.contains(Tag.station);

    final status = here
        ? 'You are here'
        : route == null
        ? 'No route from ${run.nameOf(run.location)}'
        : route.isSublight
        ? 'Sublight burn: ${route.turns} turns, ${route.fuel} fuel'
        : 'One gateway jump, ${route.fuel} fuel';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(run.nameOf(systemId), style: text.titleLarge),
        const SizedBox(height: 2),
        Text(
          status,
          style: text.labelLarge?.copyWith(
            color: here
                ? Palette.gateway
                : route == null
                ? Palette.muted
                : route.isSublight
                ? Palette.sublight
                : Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        if (system.tags.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in system.tags)
                Chip(
                  label: Text(tag),
                  visualDensity: VisualDensity.compact,
                  labelStyle: text.labelSmall,
                ),
            ],
          ),
        const SizedBox(height: 8),
        _HeldBy(faction: run.control[systemId]),
        const SizedBox(height: 8),
        Text(system.description, style: text.bodyMedium),
        const SizedBox(height: 16),
        if (here) ...[
          FilledButton.icon(
            onPressed: enabled ? controller.hold : null,
            icon: Icon(
              station ? Icons.handyman_outlined : Icons.hourglass_bottom,
            ),
            label: Text(
              station ? 'Odd jobs (end turn)' : 'Hold position (end turn)',
            ),
          ),
          if (station)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Docked: +6 credits per turn.',
                style: text.bodySmall?.copyWith(color: Palette.muted),
              ),
            ),
          if (forSale > 0) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: controller.refuel,
              icon: const Icon(Icons.local_gas_station_outlined),
              label: Text(
                'Refuel +$forSale '
                '(${forSale * GameEngine.fuelPrice} credits)',
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (system.tags.contains(Tag.market) ||
                  system.tags.contains(Tag.tradingPost))
                FilledButton.tonalIcon(
                  onPressed: enabled ? () => context.push('/market') : null,
                  icon: const Icon(Icons.storefront_outlined),
                  label: Text(
                    system.tags.contains(Tag.market)
                        ? 'Market & shipyard'
                        : 'Trading post',
                  ),
                ),
              const _ComingSoon(Icons.assignment_outlined, 'Missions'),
            ],
          ),
        ] else if (route != null)
          FilledButton.icon(
            onPressed: enabled && engine.canTake(run, route)
                ? () => controller.travel(systemId)
                : null,
            style: route.isSublight
                ? FilledButton.styleFrom(backgroundColor: Palette.sublight)
                : null,
            icon: Icon(
              route.isSublight ? Icons.timelapse : Icons.blur_circular,
            ),
            label: Text(
              !engine.canTake(run, route)
                  ? 'Not enough fuel (needs ${route.fuel})'
                  : route.isSublight
                  ? 'Burn for ${run.nameOf(systemId)} (${route.turns} turns)'
                  : 'Jump to ${run.nameOf(systemId)}',
            ),
          ),
      ],
    );
  }
}

/// Shown instead of the system panel while the ship is in Hell.
class HellPanel extends ConsumerWidget {
  const HellPanel({super.key, required this.run});
  final RunState run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final engine = ref.read(engineProvider);
    final controller = ref.read(runProvider.notifier);
    final inPipe = run.hell == HellZone.pipe;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hell', style: text.titleLarge?.copyWith(color: Palette.hell)),
        Text(
          inPipe ? 'Inside a torn gateway pipe' : 'Outside the pipes',
          style: text.labelLarge?.copyWith(color: Palette.hell),
        ),
        const SizedBox(height: 8),
        Text(
          inPipe
              ? 'The barrier glows faintly around you. Somewhere along it '
                    'is a way out. The clocks aboard no longer agree.'
              : 'Open Hell. Metallic flesh, alcoholic seas, and things that '
                    'notice you. Nobody comes out here on purpose, except for '
                    'what is out here.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          '${run.hellTurns} turns in Hell. The hull takes damage every turn.',
          style: text.bodySmall?.copyWith(color: Palette.muted),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: engine.canAct(run) ? controller.pressOn : null,
          style: FilledButton.styleFrom(backgroundColor: Palette.hell),
          icon: const Icon(Icons.local_fire_department),
          label: const Text('Press on (end turn)'),
        ),
        if (engine.canCodeGreen(run)) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: controller.codeGreen,
            style: OutlinedButton.styleFrom(
              foregroundColor: Palette.codeGreen,
              side: const BorderSide(color: Palette.codeGreen),
            ),
            icon: const Icon(Icons.cell_tower),
            label: const Text('The humans are asking for the comms array'),
          ),
        ],
      ],
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Coming with the deck builder',
    child: OutlinedButton.icon(
      onPressed: null,
      icon: Icon(icon, size: 18),
      label: Text(label),
    ),
  );
}

class _HeldBy extends StatelessWidget {
  const _HeldBy({required this.faction});
  final Faction? faction;

  @override
  Widget build(BuildContext context) {
    final f = faction;
    if (f == null) return const SizedBox.shrink();
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: Color(f.argb),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            f == Faction.ruins
                ? 'Held by nobody'
                : '${f.label}, led by ${f.leader}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ],
    );
  }
}
