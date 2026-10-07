import 'galaxy.dart';

/// Lore text for a system, separate from where it ends up on the map.
class SystemProfile {
  const SystemProfile(this.name, this.description, [this.tags = const {}]);

  final String name;
  final String description;
  final Set<String> tags;
}

/// Systems that exist in every run. Text is condensed from the vault notes.
const fixedSystems = <String, SystemProfile>{
  Sys.center: SystemProfile(
    'The Center',
    'Once the Center of Interstellar Tourism, now the capital of the '
        'Republic and home of the Overseer, the last Havi anyone knows of. '
        'Four gateways ring its star. Only three of them still work.',
    {Tag.station, Tag.capital, Tag.neutral, Tag.market},
  ),
  Sys.orcha: SystemProfile(
    'Orcha Station',
    'A junction the Havi built on the route between the Center and '
        'Ghor-Dum: an unimportant planet and a station meant to keep the '
        'peace. The Republic has let the newly arrived humans set up a '
        'temporary residence here.',
    {Tag.station, Tag.humans, Tag.neutral, Tag.market},
  ),
  Sys.ghorDum: SystemProfile(
    'Ghor-Dum',
    'Homeworld of the Gor. The Havi uplifted them from the industrial age '
        'to be a standing army and never used them. They have been '
        'compensating ever since.',
    {Tag.homeworld, Tag.gor},
  ),
  Sys.bhrunGai: SystemProfile(
    'Bhrun-Gai',
    'A luscious jungle world with the galaxy\'s strangest bugs and biggest '
        'megafauna, the Bhrun among them. Their towers dominate the world by '
        'size alone.',
    {Tag.homeworld, Tag.bhrun},
  ),
  Sys.kepler: SystemProfile(
    'Kepler',
    'A Havi observation post watches a high gravity world evolve in peace. '
        'Only scientists may enter, until the end of time or until something '
        'down there reaches space. Something just arrived from out there '
        'instead.',
    {Tag.station, Tag.humans},
  ),
  Sys.neoTerra: SystemProfile(
    'Hive World',
    'A plain Havi agri-world. Its gravity, close to one G, made it too '
        'expensive to lift cargo out of and too heavy for any species to '
        'live on comfortably, so the Havi gave it to the Consumers. It is '
        'thoroughly infested and guarded by a shipbuilding gantry. Nobody '
        'wants to fly years at sublight to get here. Almost nobody.',
    {Tag.consumers},
  ),
  Sys.urGor: SystemProfile(
    'Ur-Gor',
    'The world the Gor colonised at sublight, only to be told the natives '
        'counted as people. The Gor have been belligerent about it ever '
        'since.',
    {Tag.gor, Tag.frontier},
  ),
  Sys.traeTraeTene: SystemProfile(
    'Træ Træ Tene',
    'A system cut off from the Center when the gatecrash broke the fourth '
        'gateway. Nobody in the Republic has heard from it in living memory.',
    {Tag.station},
  ),
  Sys.ulamora: SystemProfile(
    'Úlamora',
    'Water world and homeworld of the Ál, who survived by poking and '
        'prodding their way through everything.',
    {Tag.homeworld, Tag.al},
  ),
  Sys.ulaval: SystemProfile(
    'Úlaval',
    'The Ál colony, 156 light years from Úlamora and almost exactly like '
        'it. Found and settled at sublight.',
    {Tag.al, Tag.frontier},
  ),
  Sys.kyndari: SystemProfile(
    'Kyndari',
    'Once the hub of all trade and the cradle of the Unfortunates. The '
        'demons stripped it of everything they found useful during the '
        'gatecrash and left a ruin behind.',
    {Tag.ruins, Tag.unfortunate},
  ),
  Sys.elephantHq: SystemProfile(
    'Elephant Rock',
    'An asteroid in the middle of nowhere, conveniently close to a sublight '
        'trade lane. The House of the Elephant is building a spaceport on it, '
        'without asking anyone. The minefield around it trumpets at you.',
    {Tag.humans, Tag.station, Tag.frontier, Tag.market},
  ),
  Sys.sol: SystemProfile(
    'Sol',
    'The humans\' home system, the one with the "dying sun". Its '
        'coordinates were scrubbed from every human database.',
    {Tag.humans},
  ),
};

/// Named systems from the vault that may appear in a run, keyed by the act
/// they can appear in.
const loreFillers = <int, List<SystemProfile>>{
  1: [
    SystemProfile(
      'Pax Morra',
      'A quiet transit system. The humans once came pouring out of its '
          'gateway, and nobody here has forgotten.',
      {Tag.neutral},
    ),
  ],
  2: [
    SystemProfile(
      'Kyberon',
      'The forge world of the Tern. Every Tern in the old empire was '
          'assembled here, nanobot by nanobot.',
      {Tag.tern, Tag.homeworld},
    ),
    SystemProfile('Narcillia', 'Little is recorded about Narcillia.'),
  ],
  3: [
    SystemProfile(
      'Zirmai',
      'During the gatecrash the demons poured into Kyndari from the '
          'gateway to Zirmai.',
      {Tag.ruins},
    ),
    SystemProfile('Tarsíus', 'Little is recorded about Tarsíus.'),
  ],
};

/// Name parts for procedurally named systems.
const fillerNamePrefixes = [
  'Vel', 'Ost', 'Kar', 'Dra', 'Mir', 'Sel', 'Thu', 'Nym', 'Ix', 'Ora', //
  'Bel', 'Qua', 'Ren', 'Ska', 'Ulm', 'Vor', 'Hesh', 'Ga', 'Tri', 'Ond',
];
const fillerNameSuffixes = [
  'mar',
  'dun',
  'thos',
  'ira',
  'vex',
  'lune',
  'grad',
  'eon',
  'ussa',
  'rik',
  'al',
  'os',
  'ane',
  'tor',
  'ix',
  'ebb',
];

/// Descriptions for procedurally named systems.
const fillerProfiles = <SystemProfile>[
  SystemProfile(
    '',
    'A gas giant with a refuelling depot older than most species in the '
        'Republic.',
    {Tag.station},
  ),
  SystemProfile(
    '',
    'An asteroid mining belt worked by whoever is desperate enough.',
    {Tag.frontier},
  ),
  SystemProfile(
    '',
    'A Tern relay hums here, keeping the system in step with the rest of '
        'the Republic.',
    {Tag.tern, Tag.station},
  ),
  SystemProfile(
    '',
    'An agricultural moon that has spent every generation since the '
        'gatecrash bracing for a Consumer raid.',
    {Tag.frontier},
  ),
  SystemProfile(
    '',
    'A Havi waystation. The lights still work. Nobody remembers who pays '
        'for them.',
    {Tag.station, Tag.ruins},
  ),
  SystemProfile(
    '',
    'A trading post where nobody asks where the cargo came from.',
    {Tag.station, Tag.neutral},
  ),
  SystemProfile(
    '',
    'A frozen world of research outposts and very bored scientists.',
    {Tag.station},
  ),
  SystemProfile(
    '',
    'A system of scorched planets. Locals say the gatecrash came through '
        'here first. Locals say that everywhere.',
    {Tag.ruins},
  ),
];
