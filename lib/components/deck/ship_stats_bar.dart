import 'package:flutter/material.dart';

import '../../game_engine/combat/equipment.dart';
import '../../game_engine/run_state.dart';
import '../theme.dart';

class ShipStatsBar extends StatelessWidget {
  const ShipStatsBar({super.key, required this.run});
  final RunState run;

  @override
  Widget build(BuildContext context) {
    final stats = run.stats;
    final gear = run.loadout.slotted.where((e) => e.kind == CardKind.equipment);
    final shield = gear.fold(0, (t, e) => t + e.maxShield);
    final drones = gear.fold(0, (t, e) => t + e.maxDrones);
    Widget chip(IconData icon, String label) => Chip(
      avatar: Icon(icon, size: 16, color: Palette.muted),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        chip(Icons.shield_outlined, 'Hull ${run.hull}/${stats.maxHull}'),
        if (shield > 0) chip(Icons.blur_circular, 'Shield $shield'),
        if (drones > 0) chip(Icons.flight, 'Drones $drones'),
        chip(
          Icons.groups_outlined,
          'Berths ${run.humans.count}/${stats.berths}',
        ),
        if (stats.hospital > 0)
          chip(Icons.local_hospital_outlined, 'Hospital ${stats.hospital}'),
        if (stats.hellShielding > 0)
          chip(
            Icons.blur_on,
            'Hell shielding ${(stats.hellShielding * 100).round()}%',
          ),
        chip(
          Icons.local_gas_station_outlined,
          'Fuel ${run.fuel}/${stats.fuelCapacity}',
        ),
        chip(Icons.inventory_2_outlined, 'Hold ${stats.holdCapacity}'),
      ],
    );
  }
}
