import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/models/question.dart';
import 'package:ouinon/utils/familles.dart';

/// Les familles (règle de Paul du 27/10/2026) : cardio et muscu faits = 2,
/// un seul = 1, aucun = 0.
void main() {
  const cardio = Question(
    id: 1,
    texte: 'Cardio ?',
    reponses: ['Oui', 'Non'],
    heure: 1260,
    famille: 'Sport',
  );
  const muscu = Question(
    id: 2,
    texte: 'Muscu ?',
    reponses: ['Oui', 'Non'],
    heure: 1260,
    famille: 'Sport',
  );
  const sommeil = Question(
    id: 3,
    texte: 'Sommeil ?',
    reponses: ['Bien', 'Moyen', 'Mal'],
    heure: 540,
  );

  test('cardio + muscu : 2, un seul : 1, aucun : 0', () {
    final fs = familles(
      [cardio, muscu, sommeil],
      {
        1: {'2026-10-20': 0, '2026-10-21': 0, '2026-10-22': 1},
        2: {'2026-10-20': 0, '2026-10-21': 1, '2026-10-22': 1},
      },
    );
    expect(fs, hasLength(1));
    final sport = fs.single;
    expect(sport.nom, 'Sport');
    expect(sport.questions, [cardio, muscu]);
    final r = sport.commeQuestion.reponses;
    expect(r.first, '2 sur 2');
    expect(r.last, '0 sur 2');
    expect(r[sport.reponses['2026-10-20']!], '2 sur 2');
    expect(r[sport.reponses['2026-10-21']!], '1 sur 2');
    expect(r[sport.reponses['2026-10-22']!], '0 sur 2');
  });

  test('une réponse du milieu compte ½ ; une question sans réponse, 0', () {
    const forme = Question(
      id: 4,
      texte: 'Forme ?',
      reponses: ['Bien', 'Moyen', 'Mal'],
      heure: 1260,
      famille: 'Corps',
    );
    const eau = Question(
      id: 5,
      texte: 'Eau ?',
      reponses: ['Oui', 'Non'],
      heure: 1260,
      famille: 'Corps',
    );
    final corps = familles(
      [forme, eau],
      {
        4: {'2026-10-20': 1},
        5: {'2026-10-21': 0},
      },
    ).single;
    final r = corps.commeQuestion.reponses;
    expect(r[corps.reponses['2026-10-20']!], '0,5 sur 2');
    expect(r[corps.reponses['2026-10-21']!], '1 sur 2');
    // Un jour sans aucune réponse dans la famille ne compte pas.
    expect(corps.reponses.containsKey('2026-10-22'), isFalse);
  });
}
