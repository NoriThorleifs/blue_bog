import 'galaxy/galaxy.dart';

/// Powers that can control a system. Colours are ARGB so the domain layer
/// stays free of Flutter.
///
/// Major factions hold territory and can expand. Minor factions hold little
/// or none, but have ships and will fight you if you're their enemy. Every
/// human faction, major or minor, follows the captain of the Promethius as
/// the de facto leader of humanity, which is what keeps them pulling in
/// roughly the same direction.
enum Faction {
  republic('The Galactic Republic', 'the Overseer', 0xFF7FA8FF, major: true),
  colonists(
    'The colonist humans',
    'the captain of the Promethius',
    0xFFFFC84A,
    major: true,
  ),
  uploaded('The Uploaded', 'Shining-head', 0xFF2BE0B0, major: true),
  solarHumans('The Solar humans', 'the Earth Council', 0xFFFF8F2E, major: true),
  hellborn('The Hellborn', 'General Grönigen', 0xFFE0263A, major: true),
  demons('The demons', 'nobody', 0xFF9B1BFF, major: true),
  ternCollective(
    'The Tern Collective',
    'the hivemind',
    0xFFB4B9C8,
    major: true,
  ),

  /// Systems cut off since the gatecrash and not yet part of anything.
  unaligned('Unaligned', 'nobody in particular', 0xFFC58BFF, major: true),
  ruins('Nobody', 'nobody', 0xFF6E6470, major: true),

  houseOfTheElephant(
    'The House of the Elephant',
    'Lady Idun the Giantess',
    0xFF9C8B7A,
    major: false,
  ),
  fuelRats('The Fuel Rats', 'the guild', 0xFFE8D24A, major: false),
  pirates(
    'Human pirates',
    'whoever won the last vote',
    0xFF8A8A8A,
    major: false,
  );

  const Faction(this.label, this.leader, this.argb, {required this.major});
  final String label;
  final String leader;
  final int argb;
  final bool major;
}

/// Who controls each system when a run starts.
Map<String, Faction> initialControl(Galaxy galaxy) => {
  for (final s in galaxy.systems.values) s.id: _initialFaction(s),
};

Faction _initialFaction(StarSystem s) => switch (s.id) {
  Sys.kepler => Faction.colonists,
  Sys.sol => Faction.solarHumans,
  Sys.neoTerra => Faction.ruins,
  Sys.elephantHq => Faction.houseOfTheElephant,
  _ => switch (s.act) {
    1 => Faction.republic,
    2 => Faction.unaligned,
    _ => Faction.ruins,
  },
};
