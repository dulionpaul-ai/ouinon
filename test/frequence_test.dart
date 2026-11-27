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

  test('jamais faite : posée chaque jour ; en pause : jamais', () {
    expect(poseeLe(_plantes, lundi, {}), isTrue);
    expect(poseeLe(_plantes.copie(jours: 0), lundi, {}), isFalse);
  });

  test('faite un autre jour : la suite se recale sur ce jour', () {
    // Plantes tous les 7 jours, prochaine fois dimanche 29/11.
    final plantes = _plantes.copie(
      intervalle: 7,
      depart: () => DateTime(2026, 11, 29),
    );
    expect(poseeLe(plantes, jour(4), {}), isFalse); // vendredi
    expect(poseeLe(plantes, jour(6), {}), isTrue); // dimanche
    // Arrosées vendredi 27 : plus dimanche, mais le vendredi suivant.
    final r = {'2026-11-27': 0};
    expect(poseeLe(plantes, jour(4), r), isTrue);
    expect(poseeLe(plantes, jour(6), r), isFalse);
    expect(poseeLe(plantes, jour(10), r), isFalse);
    expect(poseeLe(plantes, jour(11), r), isTrue);
    expect(prochainJour(plantes, jour(5), r), DateTime(2026, 12, 4));
    // Un « Fait » d'avant la prochaine fois choisie ne compte plus.
    final r2 = {'2026-11-20': 0};
    expect(prochainJour(plantes, lundi, r2), DateTime(2026, 11, 29));
  });

  test('certains jours : fixe, même répondue un autre jour', () {
    const hyrox = Question(
      id: 3,
      texte: 'Hyrox ?',
      reponses: ['Fait', 'Pas fait'],
      heure: 12 * 60,
      jours: 0x01,
    );
    expect(poseeLe(hyrox, jour(1), {}), isFalse); // mardi
    final r = {'2026-11-24': 0}; // faite mardi quand même
    expect(poseeLe(hyrox, jour(1), r), isTrue);
    expect(poseeLe(hyrox, jour(7), r), isTrue); // lundi suivant, toujours
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
    expect(frequenceFr(_plantes.copie(intervalle: 0)), 'Tous les jours');
  });
}
