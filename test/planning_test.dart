import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/data/donnees_test.dart';
import 'package:ouinon/data/preferences.dart';
import 'package:ouinon/models/tache.dart';
import 'package:ouinon/utils/jour.dart';
import 'package:ouinon/utils/planning.dart';

void main() {
  // Jeudi 22 octobre 2026.
  final jeudi = DateTime(2026, 10, 22);
  Tache tache(
    int id,
    String texte,
    int heure, {
    int duree = 60,
    int? etat,
    int reports = 0,
    DateTime? jour,
  }) => Tache(
    id: id,
    jour: jour ?? jeudi,
    debut: heure,
    duree: duree,
    texte: texte,
    etat: etat,
    reports: reports,
  );

  test('textes : horaire et durée', () {
    expect(plageFr(tache(1, 'Garage', 18 * 60)), '18 h – 19 h');
    expect(plageFr(tache(1, 'Lire', 23 * 60 + 30)), '23 h 30 – 0 h 30');
    expect(dureeFr(15), '15 min');
    expect(dureeFr(60), '1 h');
    expect(dureeFr(90), '1 h 30');
  });

  test('rappels : début et fin, sans réponse, pas passés', () {
    final midi = DateTime(2026, 10, 22, 12);
    final taches = [
      tache(1, 'Courses', 10 * 60), // passée
      tache(2, 'Garage', 18 * 60),
      tache(3, 'Banque', 14 * 60, etat: Tache.fait), // déjà répondue
      tache(4, 'Mails', 11 * 60 + 30), // commencée : reste la fin
    ];
    final rappels = rappelsAProgrammer(taches, midi);
    expect(
      [for (final r in rappels) (r.tache.id, r.fin, r.question)],
      [(4, true, true), (2, false, false), (2, true, true)],
    );
    expect(rappels[1].quand, DateTime(2026, 10, 22, 18));
    expect(rappels[2].quand, DateTime(2026, 10, 22, 19));
    // Une seule notification : elle porte les trois boutons.
    final debut = rappelsAProgrammer(taches, midi, mode: NotifsPlanning.debut);
    expect([for (final r in debut) (r.tache.id, r.question)], [(2, true)]);
    final fin = rappelsAProgrammer(taches, midi, mode: NotifsPlanning.fin);
    expect([for (final r in fin) r.tache.id], [4, 2]);
    // Identifiants négatifs : jamais ceux des questions.
    expect([idNotifDebut(2), idNotifFin(2)], [-4, -5]);
  });

  test('rappel du soir : le prochain, et son texte', () {
    expect(
      prochainRappelPlanning(DateTime(2026, 10, 22, 12), 21 * 60 + 30),
      DateTime(2026, 10, 22, 21, 30),
    );
    expect(
      prochainRappelPlanning(DateTime(2026, 10, 22, 22), 21 * 60 + 30),
      DateTime(2026, 10, 23, 21, 30),
    );
    final texte = texteRappelPlanning(
      [
        tache(1, 'Courses', 10 * 60, etat: Tache.fait),
        tache(2, 'Garage', 18 * 60),
        tache(3, 'Banque', 14 * 60, etat: Tache.pasFait),
      ],
      [tache(4, 'Courir', 7 * 60), tache(5, 'Lire', 21 * 60, duree: 30)],
    );
    expect(
      texte,
      'Aujourd\'hui : 1 fait sur 3, 1 sans réponse.\n'
      'Demain : 2 choses placées, de 7 h à 21 h 30.',
    );
    expect(
      texteRappelPlanning([], [], aPlacer: 3, enFond: 9),
      '3 choses choisies à placer.',
    );
    expect(
      texteRappelPlanning([], [], enFond: 9),
      'Rien de choisi pour demain : 9 choses en fond.',
    );
    expect(
      texteRappelPlanning([], []),
      'Rien de prévu demain pour l\'instant.',
    );
  });

  test('part faite : « pas répondu » ne compte pas', () {
    final jour = [
      tache(1, 'A', 9 * 60, etat: Tache.fait),
      tache(2, 'B', 10 * 60, etat: Tache.fait),
      tache(3, 'C', 11 * 60, etat: Tache.pasFait),
      tache(4, 'D', 12 * 60),
    ];
    expect(partFaite(jour), closeTo(2 / 3, 1e-9));
    expect(partFaite([tache(5, 'E', 9 * 60)]), isNull);
    // En « réponses » de 0 à 10 (0 = tout fait), arrondies.
    final veille = ajouteJours(jeudi, -1);
    expect(
      reponsesPlanning([
        ...jour,
        tache(6, 'F', 9 * 60, etat: Tache.fait, jour: veille),
        tache(7, 'G', 9 * 60, jour: ajouteJours(jeudi, -2)),
      ]),
      {cleJour(jeudi): 3, cleJour(veille): 0},
    );
  });

  test('selon le moment, le jour, la charge', () {
    final taches = [
      tache(1, 'A', 8 * 60, etat: Tache.fait),
      tache(2, 'B', 13 * 60, etat: Tache.pasFait),
      tache(3, 'C', 19 * 60, etat: Tache.pasFait),
      tache(4, 'D', 20 * 60, etat: Tache.fait),
    ];
    expect(partParMoment(taches), [1.0, 0.0, 0.5]);
    final parJour = partParJourSemaine(taches);
    expect(parJour[3], 0.5); // jeudi
    expect(parJour[0], isNull);
    final points = pointsCharge(taches);
    expect(points, hasLength(1));
    expect(points.first.x, 0.5); // 4 h prévues sur 8
    expect(points.first.y, 0.5);
  });

  test('le plus reporté, et les horaires qui se croisent', () {
    final taches = [
      tache(1, 'Papiers', 14 * 60, reports: 2),
      tache(2, 'Papiers', 14 * 60, reports: 1, jour: DateTime(2026, 10, 21)),
      tache(3, 'Banque', 9 * 60, reports: 1),
      tache(4, 'Courir', 7 * 60, reports: 3),
    ];
    expect(plusReportees(taches), [
      (texte: 'Courir', fois: 3),
      (texte: 'Papiers', fois: 3),
    ]);
    final garage = tache(5, 'Garage', 18 * 60);
    final memeJour = [
      garage,
      tache(6, 'Courses', 17 * 60 + 30),
      tache(7, 'Lire', 19 * 60),
    ];
    expect([for (final t in chevauchements(garage, memeJour)) t.id], [6]);
  });

  test('bilan du dimanche : la semaine du planning', () {
    final dimanche = DateTime(2026, 10, 25);
    expect(
      ligneBilanPlanning([
        tache(1, 'A', 9 * 60, etat: Tache.fait),
        tache(2, 'B', 9 * 60, etat: Tache.fait),
        tache(3, 'C', 9 * 60, etat: Tache.pasFait),
        tache(4, 'D', 9 * 60),
        tache(5, 'E', 9 * 60, etat: Tache.fait, jour: DateTime(2026, 10, 18)),
      ], dimanche),
      'Planning : 2 faits sur 3',
    );
    expect(ligneBilanPlanning([], dimanche), isNull);
  });

  test('planning de test : 6 mois passés, toujours le même', () {
    final a = genereTachesTest(aujourdhui: jeudi);
    final b = genereTachesTest(aujourdhui: jeudi);
    expect(a.length, b.length);
    expect(a.length, greaterThan(400));
    expect(a.every((t) => t.test && t.jour.isBefore(jeudi)), isTrue);
    expect(
      [for (final t in a.take(20)) t.etat],
      [for (final t in b.take(20)) t.etat],
    );
    // Des faits, des pas faits, quelques sans réponse, des reports.
    final c = compte(a);
    expect(c.faits, greaterThan(c.pasFaits));
    expect(c.sansReponse, greaterThan(0));
    expect(plusReportees(a), isNotEmpty);
  });
}
