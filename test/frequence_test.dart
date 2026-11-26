import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/models/question.dart';
import 'package:ouinon/utils/frequence.dart';
import 'package:ouinon/utils/planification.dart';

const _plantes = Question(
  id: 1,
  texte: 'Arroser les plantes ?',
  reponses: ['Fait', 'Pas fait'],
  heure: 10 * 60,
  jours: Question.tousLesJours,
  intervalle: 3,
);

void main() {
  final lundi = DateTime(2026, 11, 23);
  DateTime jour(int n) => DateTime(2026, 11, 23 + n);

  test('une tâche revient N jours après « Fait », puis chaque jour', () {
    final r = {'2026-11-23': 0};
    expect(poseeLe(_plantes, lundi, r), isTrue); // répondue ce jour-là
    expect(poseeLe(_plantes, jour(1), r), isFalse);
    expect(poseeLe(_plantes, jour(2), r), isFalse);
    expect(poseeLe(_plantes, jour(3), r), isTrue);
    // Pas faite jeudi : revient vendredi.
    final r2 = {...r, '2026-11-26': 1};
    expect(poseeLe(_plantes, jour(4), r2), isTrue);
    expect(revientDans(_plantes, jour(1), r), 2);
    expect(revientDans(_plantes, jour(3), r), isNull);
  });

  test('jamais faite : posée chaque jour coché ; en pause : jamais', () {
    expect(poseeLe(_plantes, lundi, {}), isTrue);
    final semaine = _plantes.copie(jours: 0x1F);
    expect(poseeLe(semaine, DateTime(2026, 11, 28), {}), isFalse);
    expect(poseeLe(_plantes.copie(jours: 0), lundi, {}), isFalse);
  });

  test('les notifications d\'une tâche', () {
    final plan = planifie(
      questions: [_plantes],
      reponses: {
        1: {'2026-11-23': 0},
      },
      maintenant: DateTime(2026, 11, 23, 12),
    );
    // Faite lundi : jeudi, puis chaque jour tant qu'elle n'est pas faite.
    expect(plan.notifs.first.jour, jour(3));
    expect(plan.notifs[1].jour, jour(4));
  });

  test('la semaine : les « oui » sur les questions posées', () {
    const sport = Question(
      id: 2,
      texte: 'Sport ?',
      reponses: ['Oui', 'Non'],
      heure: 21 * 60,
      jours: Question.tousLesJours,
    );
    final s = semaine(
      [sport],
      {
        2: {'2026-11-23': 0, '2026-11-24': 1},
      },
      DateTime(2026, 11, 25, 12),
    );
    // Lundi, mardi ; mercredi pas encore répondu ne compte pas.
    expect(s, (oui: 1, total: 2));
  });

  test('les fréquences en français', () {
    expect(frequenceFr(_plantes), 'Tous les 3 jours');
    expect(
      frequenceFr(_plantes.copie(jours: 0x1F)),
      'Tous les 3 jours · en semaine',
    );
    expect(frequenceFr(_plantes.copie(intervalle: 0)), 'Tous les jours');
  });
}
