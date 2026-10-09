import '../brawl_enemies.dart';
import '../brawl_event_model.dart';

/// The end of a brawl: Satan comes for the captain at fight
/// [brawlFinalFight], wherever they are. Beating him wins the brawl.
final finaleEvents = <BrawlEvent>[
  BrawlEvent(
    id: 'satan',
    title: 'Satan',
    always: true,
    condition: (s) => s.satanDue,
    text:
        'The dark goes red from end to end. Something enormous has come up '
        'out of Hell for you, built from the wrecks of the gatecrash: Havi '
        'plating, Republic guns, a hull of living metal. Every demon you '
        'have killed was his. Satan has come to collect, and his tractor '
        'beam has you before you can turn.',
    choices: [
      Choice('Fight', [
        Outcome('There is no running from this one.', effects: [_satan]),
      ]),
      Choice('Hail him', [
        Outcome(
          'He laughs. It sounds like a hull tearing. Then he opens fire.',
          effects: [_satan],
        ),
      ]),
    ],
  ),
];

const _satan = Fight(
  special: SpecialEnemy.satan,
  tractorBeam: true,
  winCards: ['trophy_broken_seal'],
);
