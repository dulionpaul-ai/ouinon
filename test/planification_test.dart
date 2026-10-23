import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/data/notifications.dart';
import 'package:ouinon/models/question.dart';
import 'package:ouinon/utils/planification.dart';

void main() {
  const sport = Question(
    id: 1,
    texte: 'Sport ?',
    reponses: ['Oui', 'Non'],
    heure: 21 * 60,
  );
  const sommeil = Question(
    id: 2,
    texte: 'Sommeil ?',
    reponses: ['8 h et +', '6 à 8 h', 'Moins de 6 h'],
    heure: 9 * 60,
  );
  // Jeudi 22 octobre 2026, 12 h.
  final midi = DateTime(2026, 10, 22, 12);

  test('chaque question à son heure, 14 jours, sans les heures passées', () {
    final plan = planifie(
      questions: [sport, sommeil],
      repondues: {},
      maintenant: midi,
    );
    // Sommeil de 9 h déjà passé aujourd'hui : 14 sport + 13 sommeil.
    expect(plan.notifs, hasLength(27));
    expect(plan.notifs.first.question, sport);
    expect(plan.notifs.first.quand, DateTime(2026, 10, 22, 21));
    expect(plan.notifs[1].quand, DateTime(2026, 10, 23, 9));
    expect(plan.notifs.map((n) => n.id).toSet(), hasLength(27));
    // Rappel « continuer » le lendemain du 14e jour, à 9 h.
    expect(plan.rappelContinuer, DateTime(2026, 11, 5, 9));
  });

  test('les jours déjà répondus sont sautés', () {
    final plan = planifie(
      questions: [sport],
      repondues: {'1|2026-10-22', '1|2026-10-24'},
      maintenant: midi,
    );
    final jours = plan.notifs.map((n) => n.jour.day).toList();
    expect(jours.take(3), [23, 25, 26]);
  });

  test('seulement les jours choisis, rien pour une question en pause', () {
    final weekend = sport.copie(jours: 0x60);
    final pause = sommeil.copie(active: false);
    final plan = planifie(
      questions: [weekend, pause],
      repondues: {},
      maintenant: midi,
    );
    expect(plan.notifs.every((n) => n.quand.weekday >= 6), isTrue);
    expect(plan.notifs, hasLength(4));
  });

  test('beaucoup de questions : moins de jours programmés (iPhone)', () {
    final questions = [
      for (var i = 1; i <= 10; i++) sport.copie(id: i, heure: 20 * 60 + i),
    ];
    final plan = planifie(
      questions: questions,
      repondues: {},
      maintenant: midi,
      maxNotifs: 63,
    );
    expect(plan.notifs.length, lessThanOrEqualTo(63));
    expect(plan.notifs, hasLength(60));
    expect(plan.rappelContinuer, DateTime(2026, 10, 28, 20, 1));
  });

  test('aucune question active : rien à programmer', () {
    final plan = planifie(
      questions: [sport.copie(active: false)],
      repondues: {},
      maintenant: midi,
    );
    expect(plan.notifs, isEmpty);
    expect(plan.rappelContinuer, isNull);
  });

  test('identifiant : la question et le jour', () {
    expect(
      idNotification(3, DateTime(2026, 10, 22)),
      isNot(idNotification(3, DateTime(2026, 10, 23))),
    );
    expect(
      idNotification(3, DateTime(2026, 10, 22)),
      isNot(idNotification(4, DateTime(2026, 10, 22))),
    );
    expect(idNotification(1, DateTime(2026, 10, 22)), isNot(idRappelContinuer));
  });

  test('moment envoyé à Android : même instant, en temps universel', () {
    final local = DateTime(2026, 10, 24, 7, 1);
    final envoye = instantProgramme(local);
    // « Etc/UTC » : nom reconnu tel quel par Android (ZoneId).
    expect(envoye.location.name, 'Etc/UTC');
    expect(envoye.isAtSameMomentAs(local), isTrue);
    // Changement d'heure (25/10/2026) : toujours le même instant.
    final apres = DateTime(2026, 10, 26, 7, 1);
    expect(instantProgramme(apres).isAtSameMomentAs(apres), isTrue);
  });
}
