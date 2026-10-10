import 'package:flutter/material.dart';

import '../../game_engine/deck/loadout.dart';
import '../cards/card_widgets.dart';
import '../deck/cargo_hold.dart';
import '../deck/colony_grid.dart';
import 'guide_widgets.dart';

/// The guide's second half: stations, cargo, the colony, Hell, the end,
/// and story mode.
List<Widget> guideWorld() => [
  const GuideSection(
    icon: Icons.storefront_outlined,
    title: 'Stations and trade',
    children: [
      GuideBullets([
        'Buy: each station stocks its own cards. Every price shows the '
            'galactic median under it, so you can tell a bargain. Reroll the '
            'stock for a few credits, more each time.',
        'Sell: anything sells for about half its price; commodities sell for '
            'whatever this station pays for them, which differs from station '
            'to station.',
        'Shipyard: repairs cost 1 credit per 5 hull. Hull upgrades add 100 '
            'maximum hull for good, each costing twice the last.',
      ]),
      GuideText(
        'Watch for supply shocks. A famine or drought makes a station pay '
        'several times the going rate for grain or water ice until the '
        'season ends; a bumper harvest or ice glut sells them for almost '
        'nothing. Buy low, sell high.',
      ),
      GuideCardRow([
        ('goods_grain', 'Grain'),
        ('goods_ice', 'Water ice'),
        ('goods_ore', 'Ore'),
        ('goods_medicine', 'Medicine'),
      ]),
      GuideText(
        'LETS GO GAMBLING! The human stations run roulette. Everywhere else '
        'runs 27, the Ál counting game: take tiles to count up in threes '
        'without going one over a multiple of three, walk away at 9, or go '
        'all the way to 27 for the big payout.',
      ),
    ],
  ),
  GuideSection(
    icon: Icons.inventory_2_outlined,
    title: 'Cargo bay, hold and wreckage',
    children: [
      const GuideText(
        'The hold starts with no room at all. A cargo pod in the cargo bay, '
        'a slot of its own outside the triforce, opens it up. Spare pods '
        'wait in the hold until three merge into a bigger one.',
      ),
      GuideFigure(
        caption: 'A Cargo Pod in the cargo bay gives three hold spaces.',
        child: CargoHold(loadout: _hold, tile: _tile(_hold)),
      ),
      const GuideText(
        'If a fight or an event gives you a card with no room for it, it '
        'waits in the wreckage at the top of the screen until you move on. '
        'Open a card on the Ship tab and jettison it to make room, then tap '
        'the wreckage to take what you want.',
      ),
    ],
  ),
  GuideSection(
    icon: Icons.groups_outlined,
    title: 'The human colony',
    children: [
      const GuideText(
        'The Republic asked each species to elect one captain to take a '
        'colony of humans aboard, and yours chose you. Hundreds of them live '
        'in a colony docked to your ship, laid out in a square grid of its '
        'own. Colony cards work only there, and they never fight.',
      ),
      GuideFigure(
        caption:
            'A Habitat Tower houses the colony; the rest help it, and '
            'you.',
        maxWidth: 320,
        child: ColonyGrid(
          humans: 240,
          housing: 300,
          tile: _tile(
            Loadout(
              colony: [
                'habitat_2',
                'hospital_1',
                'crawlspace_1',
                'shop_1',
                'casino_1',
                'brothel_1',
                null,
                null,
                null,
              ],
            ),
          ),
        ),
      ),
      const GuideCardRow([
        ('habitat_1', 'Houses 100 humans'),
        ('hospital_1', 'Cuts the colony\'s losses'),
        ('crawlspace_1', 'Patches hull between fights'),
        ('shop_1', 'Pays on docking'),
        ('casino_1', 'Pays on docking, a gamble'),
        ('brothel_1', 'Pays more on docking'),
      ]),
      const GuideBullets([
        'You pay the humans nothing. The colony makes ends meet on its own.',
        'It grows on its own too: children are born aboard, and adults move '
            'in at stations, more where humans live and the more they like '
            'you.',
        'The humans patch your hull between fights, though never past three '
            'quarters of it.',
        'The shops, casinos and brothels pay so much per hundred humans every '
            'time you dock, so a bigger colony pays more.',
        'Selling housing is the only way to make humans leave: the ones '
            'without a home go.',
      ]),
      const GuideText(
        'Between a fight and the next dock you are in transit, and now and '
        'then the colony needs its captain: a petition from its '
        'representatives, news from the other elected captains, veterans '
        'coming home. The humans govern themselves, but it is your ship and '
        'you have the final say. How you answer moves how much they like '
        'you. A colony that likes you grows faster; one that stops liking '
        'you altogether stops patching your hull.',
      ),
      const GuideText(
        'Look after them and they look after you. A Content colony now and '
        'then builds you a copy of one of your cards, patches your hull past '
        'the usual limit or takes up a collection. A Devoted one loads your '
        'launchers, sends a boarding party ahead to hole your next enemy, or '
        'reinforces your hull for good. Their mood shows on the Ship tab.',
      ),
      const GuideText(
        'Once the humans go to war for Neo Terra, a universal draft takes a '
        'few of your humans at every dock. Children are still born aboard and '
        'new humans still move in, and after a while the veterans start '
        'coming home.',
      ),
    ],
  ),
  const GuideSection(
    icon: Icons.local_fire_department_outlined,
    title: 'Hell',
    children: [
      GuideText(
        'Sometimes something chews on the pipe as you leave a station. A '
        'captain mad enough can dive through the bite into Hell. There are no '
        'stations there and no shipyard; Hell\'s sea eats 25 hull every turn, '
        'and the demons are tough. Look for a way out.',
      ),
      GuideText(
        'What you find there is worth it: Hell\'s own cards, stronger for '
        'their price than anything a station sells, and Hell Brandy.',
      ),
      GuideCardRow([
        (
          'brimstone_1',
          'Hellfire: through shields and drones, burns you a '
              'little',
        ),
        ('teeth_1', 'Fast, cheap bites'),
        ('brandy_mist_1', 'Shields'),
        ('metal_flesh_1', 'Living hull'),
        ('goods_brandy', 'Hell Brandy'),
      ]),
      GuideBullets([
        'Hell Brandy sells well, or use it on a card (Ship tab: tap it, Use, '
            'tap a glowing card) to make that card Hellish.',
        'Hellish cards work with Hell\'s rarest prize, the Hell Clock: '
            'everything starts half charged, and every other Hellish card '
            'fires the moment a fight begins. There is one per brawl, if '
            'you can find it.',
        'Hell\'s clocks don\'t agree with ours. When you get out, the galaxy '
            'may be a few fights older or younger than you left it.',
        'Some things in Hell are better asked than fought.',
      ]),
      GuideCardRow([('hell_clock', 'The Hell Clock')]),
    ],
  ),
  const GuideSection(
    icon: Icons.military_tech_outlined,
    title: 'Elites, Nobody and the end',
    children: [
      GuideText(
        'Three elite ships each turn up once, and only during their stretch '
        'of the brawl. Miss the window and they\'re gone. Each one pays a '
        'unique trophy.',
      ),
      GuideCardRow([
        ('trophy_last_vote', 'The Last Vote, fights 4–5'),
        ('trophy_champions_bulwark', 'A Gor champion, fights 8–10'),
        ('trophy_nanoforge', 'The Unmerged foundry, fights 11–14'),
      ]),
      GuideText(
        'From fight 9, Nobody may come for you, once. He is the one human '
        'trained to kill the species of the Republic. Forty seconds into the '
        'fight his teleporter boards your ship, and you are dead. Run for it, '
        'or kill him first.',
      ),
      GuideCardRow([('nobody_boarding_teleporter', 'Nobody\'s teleporter')]),
      GuideText(
        'At fight 27, Satan himself comes for you, wherever you are, with a '
        'tractor beam. Beat him and you win the brawl, and his Broken Seal '
        'is yours. Then retire a winner, or keep going for score against '
        'ships that get harder every fight, until one of them gets you.',
      ),
      GuideCardRow([('trophy_broken_seal', 'The Broken Seal')]),
    ],
  ),
  const GuideSection(
    icon: Icons.public,
    title: 'Story mode',
    children: [
      GuideText(
        'Story mode is the full campaign, on a map of the galaxy. It uses the '
        'same ship, cards, fights and colony.',
      ),
      GuideBullets([
        'Each turn you jump through a gateway (1 fuel), take a slow sublight '
            'lane (2 fuel), or hold position. Run dry somewhere without fuel '
            'for sale and the Fuel Rats come, at a price.',
        'The galaxy\'s history moves on around you in three acts, and '
            'events and news react to what you do.',
        'Your humans\' mood shows next to their number. Keep them happy: '
            'how they feel about you changes what happens, and a mutinous '
            'colony is a real danger.',
        'Every gateway jump has a small chance of dropping you into Hell.',
        'The story ends when the humans send their code. What the code says '
            'depends on how the galaxy has treated them, and on you.',
      ]),
    ],
  ),
];

final _hold = Loadout(
  cargo: 'cargo_pod_1',
  hold: ['missile_crate_1', 'goods_grain'],
);

/// A non-interactive tile builder showing [loadout]'s cards.
Widget Function(CardSpot) _tile(Loadout loadout) =>
    (spot) => CardTile(id: loadout.at(spot));
