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
    final weekend = sport.copie(jours: 0x60, redemande: () => false);
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

  test('bilan : le prochain dimanche à 20 h', () {
    // Jeudi 22 octobre → dimanche 25 à 20 h.
    expect(prochainBilan(midi), DateTime(2026, 10, 25, 20));
    // Dimanche 25 à 19 h → le soir même ; à 20 h → la semaine suivante.
    expect(
      prochainBilan(DateTime(2026, 10, 25, 19)),
      DateTime(2026, 10, 25, 20),
    );
    expect(
      prochainBilan(DateTime(2026, 10, 25, 20)),
      DateTime(2026, 11, 1, 20),
    );
  });

  group('redemander le lendemain si pas fait', () {
    // « Me raser ? » le lundi seulement.
    final raser = sport.copie(id: 3, texte: 'Me raser ?', jours: 0x01);
    final lundi = DateTime(2026, 10, 26);
    final mardi = DateTime(2026, 10, 27);
    final mercredi = DateTime(2026, 10, 28);

    test('automatique : oui sauf tous les jours', () {
      expect(raser.redemandee, isTrue);
      expect(sport.redemandee, isFalse);
      expect(raser.copie(redemande: () => false).redemandee, isFalse);
    });

    test('« Non » lundi : redemandée mardi, mercredi… jusqu\'à « Oui »', () {
      expect(jourARattraper(raser, {'2026-10-26': 1}, mardi), lundi);
      expect(jourARattraper(raser, {'2026-10-26': 1}, mercredi), lundi);
      // Pas de réponse : pareil.
      expect(jourARattraper(raser, {}, mardi), lundi);
      // « Oui » : fini.
      expect(jourARattraper(raser, {'2026-10-26': 0}, mardi), isNull);
      // Le lundi lui-même : la question normale.
      expect(jourARattraper(raser, {}, lundi), isNull);
      // Tous les jours : jamais redemandée.
      expect(jourARattraper(sport, {}, mardi), isNull);
    });

    test(
      'notifications : « (de lundi) » programmée mardi, après un « Non »',
      () {
        final plan = planifie(
          questions: [raser],
          repondues: {'3|2026-10-26'},
          maintenant: DateTime(2026, 10, 26, 22),
          reponses: {
            3: {'2026-10-26': 1},
          },
        );
        final rattrapages = [
          for (final n in plan.notifs)
            if (n.rattrapage && n.jour == lundi) n,
        ];
        expect(rattrapages.first.quand, DateTime(2026, 10, 27, 21));
        expect(rattrapages.first.jour, lundi);
        // Jusqu'au dimanche ; le lundi suivant, la question normale.
        expect(rattrapages, hasLength(6));
        expect(
          plan.notifs.map((n) => n.id).toSet(),
          hasLength(plan.notifs.length),
        );
      },
    );
  });
}
