import 'package:flutter/material.dart';

import '../deck/triforce.dart';
import 'guide_widgets.dart';

/// The guide's first half: the goal, the ship, cards and fights.
List<Widget> guideBasics() => [
  const GuideSection(
    icon: Icons.flag_outlined,
    title: 'The goal',
    initiallyExpanded: true,
    children: [
      GuideText(
        'Blue Bog is a deck-building auto-battler. You fly a ship from '
        'station to station, buying and refitting between fights. The fights '
        'play themselves out: your cards decide them.',
      ),
      GuideBullets([
        'Launch from the title screen to start a brawl. Pick a captain: each '
            'species starts with different cards and credits.',
        'At a station you buy, sell, repair and refit. When you launch, '
            'something happens on the way out, usually followed by a fight.',
        'Survive and you dock at another station. Lose your hull and the '
            'brawl is over.',
        'Make it to fight 27 and beat what is waiting there to win.',
      ]),
    ],
  ),
  GuideSection(
    icon: Icons.change_history,
    title: 'Your ship: the triforce',
    children: [
      const GuideText(
        'Every captain flies the same ship: 500 hull and nine card slots, '
        'laid out as three small triangles that make one big one. Only cards '
        'in a slot fight.',
      ),
      const GuideFigure(
        caption:
            'Top: two lasers sped up by Fire Control. Bottom left: shields '
            'and plating. Bottom right: missiles with fast fuzes, and drones.',
        child: Triforce(
          slots: [
            'laser_2',
            'laser_1',
            'fire_control_1',
            'shield_2',
            'shield_capacitor_1',
            'plating_1',
            'missiles_1',
            'quick_fuzes_1',
            'fabricator_1',
          ],
        ),
      ),
      const GuideText(
        'Where a card sits matters: boosters like Fire Control only speed up '
        'the cards in their own small triangle. A few, like the Capacitor '
        'Bank, help the whole ship. Nothing can make a card fire more than '
        'twice as fast.',
      ),
      const GuideCardRow([
        ('fire_control_1', 'Speeds up its triangle'),
        ('quick_fuzes_1', 'Speeds up missiles in its triangle'),
        ('shield_capacitor_1', 'Speeds up shields in its triangle'),
        ('capacitors_1', 'Speeds up the whole ship'),
      ]),
    ],
  ),
  const GuideSection(
    icon: Icons.style_outlined,
    title: 'Cards and merging',
    children: [
      GuideText('Cards come in a few kinds, and each works in its own place.'),
      GuideCardRow([
        ('laser_1', 'Equipment: works in a slot'),
        ('missile_crate_1', 'Supplies: work from a slot or the hold'),
        ('goods_grain', 'Commodities: trade goods'),
        ('habitat_1', 'Colony cards: work in the colony'),
      ]),
      GuideText(
        'Three copies of a card, anywhere on the ship, merge into the next '
        'tier, which is exactly as strong as the three were. Three of those '
        'merge into a super card. Merging frees slots, so a ship full of '
        'super cards is a very strong ship. Tier marks on the card show how '
        'far along it is.',
      ),
      GuideFigure(
        caption:
            'Three Lasers make Twin Lasers; three of those, a Tern Choir '
            'Lance.',
        child: GuideMergeChain('laser'),
      ),
      GuideText(
        'Unique cards, like trophies from beating elite ships, never merge.',
      ),
    ],
  ),
  const GuideSection(
    icon: Icons.bolt_outlined,
    title: 'Fights',
    children: [
      GuideText(
        'Fights are automatic. Every card fires on its own timer, and you '
        'watch the replay. Damage to your hull carries over to the next '
        'fight, so repair when you can.',
      ),
      GuideBullets([
        'Win and you scrap the enemy for credits. You may salvage some of its '
            'cards, and haulers carry cargo to plunder.',
        'If neither ship is dead after 60 seconds, both break away: no loot. '
            'Some enemies use a tractor beam, and then there is no breaking '
            'away.',
        'Before you launch, the station shows what you will meet next.',
      ]),
      GuideText(
        'Every weapon has something that stops it. A good ship covers its '
        'weaknesses and picks on the enemy\'s.',
      ),
      GuideCounter('laser_1', 'blocked by', 'shield_1', 'Shields soak lasers'),
      GuideCounter(
        'missiles_1',
        'shot down by',
        'fabricator_1',
        'Drones stop missiles, and repair your hull',
      ),
      GuideCounter(
        'teleporter_1',
        'stopped only by',
        'jammer_1',
        'Teleport bombs go through shields and drones',
      ),
      GuideCounter(
        'ion_1',
        'strips',
        'shield_1',
        'What the shields don\'t take hits the hull at a third',
      ),
      GuideCounter(
        'flak_1',
        'shoots down',
        'fabricator_1',
        'Or bursts on '
            'the hull when there are no drones',
      ),
      GuideCounter(
        'rail_1',
        'deflected by',
        'shield_1',
        'A 100-damage slug, but any shield at all stops it',
      ),
      GuideCounter(
        'lance_1',
        'grows',
        null,
        'A laser that hits harder with every shot',
      ),
      GuideText(
        'Missiles, teleport bombs and drones need ammunition. Keep the right '
        'supplies aboard, in a slot or the hold.',
      ),
      GuideCardRow([
        ('missile_crate_1', 'Missiles'),
        ('teleport_charges_1', 'Teleport charges'),
        ('feedstock_1', 'Drone feedstock'),
        ('plating_1', 'Plating: more hull'),
        ('repair_1', 'Repair Bay: heals in a fight'),
      ]),
    ],
  ),
];
