import '../brawl_enemies.dart';
import '../brawl_events.dart';

/// The end of a brawl: its final bosses. Beating any of them wins.
///
/// - Satan, the hardest, comes up out of Hell for a captain with a full
///   build who kills his herald (see [fullBuild]), whenever that is.
/// - At fight [brawlFinalFight], if nobody has been beaten yet: a colony
///   that still doesn't like its captain votes to leave for the House of the
///   Elephant, and Lady Idun comes in her flagship; otherwise the Uploaded
///   flagship comes, with Shining-head aboard.
final finaleEvents = <BrawlEvent>[
  BrawlEvent(
    id: 'satan',
    title: 'Satan',
    always: true,
    condition: (s) => s.satanDue,
    text:
        'The dark goes red from end to end. Something enormous has come up '
        'out of Hell for you, built from the wrecks of the gatecrash: Havi '
        'plating, Republic guns, a hull of living metal. You killed his '
        'herald, and every demon before it was his too. Satan has come to '
        'collect, and his tractor beam has you before you can turn.',
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
  BrawlEvent(
    id: 'secession',
    title: 'The vote',
    always: true,
    condition: (s) => s.secessionDue,
    text:
        'Your humans held a vote last night, and nobody told you about it. '
        'This morning the colony\'s docking clamps let go, one after another, '
        'and the whole grid is drifting away from your ship. This '
        'relationship just isn\'t working out, the representatives say.\n\n'
        'A ship is waiting to take them in: The Matriarch, flagship of the '
        'House of the Elephant, with Lady Idun the Giantess on her bridge. '
        'Her tractor beam is already on you. The House doesn\'t leave a '
        'captain like you free to come after its people.',
    choices: [
      Choice('Go after them', [
        Outcome(
          'You burn after the colony. Lady Idun puts her flagship between '
          'you and it, and her fission missiles come up out of the bays.',
          effects: [Secede(), _idun],
        ),
      ]),
      Choice('Wish them well', [
        Outcome(
          'Lady Idun thanks you for your understanding. Then she opens fire '
          'anyway.',
          effects: [Secede(), _idun],
        ),
      ]),
    ],
  ),
  BrawlEvent(
    id: 'uploaded_flagship',
    title: 'The Ascension',
    always: true,
    condition: (s) => s.finalDue && !s.secessionDue,
    text:
        'The Uploaded took Neo Terra months ago and never said so. Every '
        'human the draft sent to fight the Consumers was taken in, and '
        'taught to hear Shining-head as a god. Now its army has come out '
        'through the Republic, and the Republic\'s fleets are wrecks behind '
        'it.\n\n'
        'Its flagship, The Ascension, comes for you, holed from bow to '
        'stern, every channel full of Shining-head\'s voice. It wants your '
        'humans. It wants everyone\'s humans. Its tractor beam has you.',
    choices: [
      Choice('Fight', [
        Outcome(
          'Its crew start singing as it comes about.',
          effects: [_ascension],
        ),
      ]),
      Choice('Answer its hail', [
        Outcome(
          'Shining-head explains, warmly and at length, that your humans '
          'will be happier with it. Your humans are listening. You cut the '
          'channel and open fire.',
          effects: [_ascension],
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

const _idun = Fight(
  special: SpecialEnemy.idunFlagship,
  tractorBeam: true,
  winCards: ['trophy_fission'],
);

const _ascension = Fight(
  special: SpecialEnemy.uploadedFlagship,
  tractorBeam: true,
  startHull: SpecialEnemy.uploadedFlagshipHull,
  winCards: ['trophy_voice_below'],
);
