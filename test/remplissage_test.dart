import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/models/a_faire.dart';
import 'package:ouinon/models/creneau.dart';
import 'package:ouinon/models/tache.dart';
import 'package:ouinon/utils/jour.dart';
import 'package:ouinon/utils/remplissage.dart';

void main() {
  // Vendredi 23 octobre 2026.
  final vendredi = DateTime(2026, 10, 23);
  final jeudi = DateTime(2026, 10, 22);
  AFaire a(
    int id,
    String texte,
    int duree, {
    bool important = false,
    bool urgent = false,
    DateTime? echeance,
    DateTime? creeLe,
  }) => AFaire(
    id: id,
    texte: texte,
    duree: duree,
    important: important,
    urgent: urgent,
    echeance: echeance,
    creeLe: creeLe ?? jeudi,
  );

  test('les 4 cases, et la date limite qui rend urgent', () {
    expect(
      a(1, 'A', 30, important: true, urgent: true).caseLe(jeudi),
      Case.dabord,
    );
    expect(a(1, 'A', 30, important: true).caseLe(jeudi), Case.aPlanifier);
    expect(a(1, 'A', 30, urgent: true).caseLe(jeudi), Case.viteFait);
    expect(a(1, 'A', 30).caseLe(jeudi), Case.peutEtreJamais);
    final impots = a(
      1,
      'Impôts',
      90,
      important: true,
      echeance: DateTime(2026, 10, 30),
    );
    expect(impots.caseLe(jeudi), Case.aPlanifier);
    expect(impots.caseLe(DateTime(2026, 10, 28)), Case.dabord);
  });

  test('ordre : D\'abord, À planifier, Vite fait ; jamais « Peut-être »', () {
    final ordre = ordreDePlacement([
      a(1, 'Cave', 120),
      a(2, 'Marc', 15, urgent: true),
      a(3, 'Guitare', 30, important: true, creeLe: DateTime(2026, 10, 20)),
      a(4, 'Voyage', 60, important: true, echeance: DateTime(2026, 11, 10)),
      a(5, 'Plombier', 15, important: true, urgent: true),
      a(6, 'Assurance', 60, important: true, creeLe: DateTime(2026, 10, 10)),
    ], vendredi);
    expect(
      [for (final x in ordre) x.texte],
      [
        'Plombier',
        'Voyage', // date limite d'abord
        'Assurance', // puis le plus ancien
        'Guitare',
        'Marc',
      ],
    );
  });

  test('le dernier jour d\'une date limite passe devant', () {
    final ordre = ordreDePlacement([
      a(1, 'Plombier', 15, important: true, urgent: true),
      a(2, 'Cadeau', 45, echeance: vendredi),
    ], vendredi);
    expect([for (final x in ordre) x.texte], ['Cadeau', 'Plombier']);
  });

  test('premier créneau : avec un quart d\'heure de marge', () {
    final prevues = [
      Tache(jour: vendredi, debut: 10 * 60, texte: 'Garage'),
      Tache(jour: vendredi, debut: 12 * 60, texte: 'Déjeuner'),
    ];
    // 9 h – 9 h 45 tient avant le garage ; 1 h non (marge).
    expect(premierCreneau(45, prevues, depuis: 540, finJournee: 1140), 540);
    expect(
      premierCreneau(60, prevues, depuis: 540, finJournee: 1140),
      13 * 60 + 15,
    );
    expect(premierCreneau(60, prevues, depuis: 540, finJournee: 700), isNull);
  });

  test('aujourd\'hui : pas avant le prochain quart d\'heure', () {
    expect(
      premierDebut(vendredi, 540, DateTime(2026, 10, 23, 14, 7)),
      14 * 60 + 15,
    );
    expect(premierDebut(vendredi, 540, DateTime(2026, 10, 23, 7)), 540);
    expect(premierDebut(vendredi, 540, DateTime(2026, 10, 22, 20)), 540);
  });

  test('remplir : autour des impératifs, ce qui ne rentre pas est dit', () {
    final p = remplitJournee(
      jour: vendredi,
      prevues: [Tache(jour: vendredi, debut: 10 * 60, texte: 'Garage')],
      aPlacer: [
        a(1, 'Papiers', 60, important: true),
        a(2, 'Plombier', 30, important: true, urgent: true),
        a(3, 'Cave', 120),
        a(4, 'Voyage', 180, important: true),
      ],
      debutJournee: 9 * 60,
      finJournee: 13 * 60,
    );
    expect(
      [for (final t in p.placees) (t.texte, t.debut, t.listeId)],
      [('Plombier', 540, 2), ('Papiers', 675, 1)],
    );
    expect(p.placees.first.quadrant, Case.dabord.index);
    expect([for (final x in p.horsJournee) x.texte], ['Voyage']);
  });

  test('temps libre de la journée', () {
    expect(
      tempsLibre(
        jour: vendredi,
        prevues: [
          Tache(jour: vendredi, debut: 10 * 60, texte: 'Garage'),
          Tache(
            jour: vendredi,
            debut: 11 * 60,
            texte: 'X',
            etat: Tache.pasFait,
          ),
        ],
        debutJournee: 9 * 60,
        finJournee: 19 * 60,
      ),
      9 * 60,
    );
    expect(ecartJours(jeudi, vendredi), 1);
  });

  test('remplir : contourne les créneaux fixes ; « Peut-être » si choisi', () {
    final p = remplitJournee(
      jour: vendredi,
      prevues: const [],
      aPlacer: [a(1, 'Cave', 120), a(2, 'Papiers', 60, important: true)],
      debutJournee: 9 * 60,
      finJournee: 19 * 60,
      creneaux: const [Creneau(texte: 'École', debut: 8 * 60, fin: 12 * 60)],
      avecJamais: true,
    );
    expect(
      [for (final t in p.placees) (t.texte, t.debut)],
      [('Papiers', 12 * 60 + 15), ('Cave', 13 * 60 + 30)],
    );
    expect(
      tempsLibre(
        jour: vendredi,
        prevues: const [],
        debutJournee: 9 * 60,
        finJournee: 19 * 60,
        creneaux: const [
          Creneau(texte: 'Enfants', debut: 17 * 60, fin: 23 * 60),
        ],
      ),
      8 * 60,
    );
  });
}
