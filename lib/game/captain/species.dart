import '../galaxy/galaxy.dart';

/// A species' starting ship. Every captain flies the same hull with the
/// same nine slots; ships differ only in the cards they start with.
class ShipClass {
  const ShipClass({
    required this.name,
    required this.description,
    required this.startingCards,
    this.startingHold = const [],
  });

  final String name;
  final String description;

  /// Card ids slotted when a run starts.
  final List<String> startingCards;

  /// Card ids in the hold when a run starts.
  final List<String> startingHold;
}

/// The playable species. Humans, Hellborn and Havi are not playable.
enum Species {
  tern(
    name: 'Tern',
    traits: 'Mechanical, hive-minded, calculating',
    blurb:
        'Nanobot beings built by the Havi as the distributed computer of '
        'their empire. Now the glue holding the Republic together.',
    home: Sys.center,
    humansLikeThem: 2,
    theyLikeHumans: 2,
    startingHumans: 9,
    startingCredits: 120,
    ship: ShipClass(
      name: 'Relay-class Calculator',
      description: 'Self-repairing nanobot hull. Counts everything in threes.',
      startingCards: [
        'laser_1',
        'laser_1',
        'shield_1',
        'bunks_2',
        'cargo_pod_1',
      ],
      startingHold: [],
    ),
  ),
  al(
    name: 'Ál',
    traits: 'Curious, horny, aquatic',
    blurb:
        'Tentacled explorers from Úlamora who have survived by poking and '
        'prodding their way through everything.',
    home: Sys.orcha,
    humansLikeThem: 1,
    theyLikeHumans: 2,
    startingHumans: 6,
    startingCredits: 150,
    ship: ShipClass(
      name: 'Tidecaller Survey Tank',
      description:
          'Mostly water by volume. Excellent sensors, '
          'questionable ethics board.',
      startingCards: [
        'laser_1',
        'laser_1',
        'fabricator_1',
        'bunks_1',
        'bunks_1',
        'cargo_pod_1',
        'hospital_1',
      ],
      startingHold: ['feedstock_1'],
    ),
  ),
  bhrun(
    name: 'Bhrun',
    traits: 'Slow, passive, unimportant',
    blurb:
        'Megafauna from the jungles of Bhrun-Gai. Nobody cares about them, '
        'and they have not noticed.',
    home: Sys.bhrunGai,
    humansLikeThem: 1,
    theyLikeHumans: 0,
    startingHumans: 6,
    startingCredits: 90,
    ship: ShipClass(
      name: 'Grazer Bulk Hauler',
      description:
          'Enormous, slow, and built to carry far more than it '
          'needs to.',
      startingCards: [
        'laser_1',
        'missiles_1',
        'plating_1',
        'plating_1',
        'bunks_1',
        'bunks_1',
        'cargo_pod_1',
      ],
      startingHold: ['missile_crate_1'],
    ),
  ),
  gor(
    name: 'Gor',
    traits: 'Pride, honour, aggression',
    blurb:
        'Uplifted by the Havi to be an army that never got a war. '
        'Belligerent and proud of it.',
    home: Sys.ghorDum,
    humansLikeThem: -2,
    theyLikeHumans: -1,
    startingHumans: 3,
    startingCredits: 100,
    ship: ShipClass(
      name: 'Warbound Frigate',
      description: 'Was supposed to be demilitarised. Still has the guns.',
      startingCards: [
        'missiles_1',
        'missiles_1',
        'plating_1',
        'bunks_1',
        'cargo_pod_1',
      ],
      startingHold: ['missile_crate_1'],
    ),
  ),
  unfortunate(
    name: 'Unfortunate',
    traits: 'Mechanical, mysterious, sneaky',
    blurb:
        'Machine beings whose cradle world Kyndari fell in the gatecrash. '
        'They know more about the gateways than they will ever admit, and '
        'they would rather the humans did not look at them too closely.',
    home: Sys.center,
    humansLikeThem: -1,
    theyLikeHumans: -1,
    startingHumans: 3,
    startingCredits: 140,
    ship: ShipClass(
      name: 'Quiet Pilgrim',
      description:
          'Unregistered modifications. Strangely comfortable in a '
          'gateway pipe.',
      startingCards: [
        'laser_1',
        'teleporter_1',
        'shield_1',
        'bunks_1',
        'cargo_pod_1',
        'barrier_1',
      ],
      startingHold: ['teleport_charges_1'],
    ),
  );

  const Species({
    required this.name,
    required this.traits,
    required this.blurb,
    required this.home,
    required this.humansLikeThem,
    required this.theyLikeHumans,
    required this.startingHumans,
    required this.startingCredits,
    required this.ship,
  });

  final String name;
  final String traits;
  final String blurb;

  /// System the captain starts in.
  final String home;

  /// -2 to 2. How humans feel about this species. Moves starting loyalty.
  final int humansLikeThem;

  /// -2 to 2. How this species feels about humans. Moves the captain's
  /// starting culture drift.
  final int theyLikeHumans;
  final int startingHumans;
  final int startingCredits;
  final ShipClass ship;
}
