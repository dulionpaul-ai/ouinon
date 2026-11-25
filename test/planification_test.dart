import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/models/question.dart';
import 'package:ouinon/utils/bilan.dart';
import 'package:ouinon/utils/planification.dart';

const _sport = Question(
  id: 1,
  texte: 'Sport ?',
  reponses: ['Oui', 'Non'],
  heure: 21 * 60,
  jours: Question.tousLesJours,
);

void main() {
  // Mercredi 25/11/2026, midi.
  final midi = DateTime(2026, 11, 25, 12);

  test('chaque jour à son heure, 14 jours d\'avance', () {
    final plan = planifie(questions: [_sport], reponses: {}, maintenant: midi);
    expect(plan.notifs, hasLength(14));
    expect(plan.notifs.first.quand, DateTime(2026, 11, 25, 21));
    expect(plan.notifs.first.duree, const Duration(days: 1));
    expect(plan.rappelContinuer, DateTime(2026, 12, 9, 21));
  });

  test('ni l\'heure passée, ni les jours répondus, ni la pause', () {
    final tard = DateTime(2026, 11, 25, 22);
    final plan = planifie(
      questions: [_sport, _sport.copie(id: 2, jours: 0)],
      reponses: {
        1: {'2026-11-26': 0},
      },
      maintenant: tard,
    );
    expect(plan.notifs.first.jour, DateTime(2026, 11, 27));
    expect(plan.notifs.every((n) => n.question.id == 1), isTrue);
    expect(plan.notifs, hasLength(12));
  });

  test('seulement les jours choisis ; reste affichée jusqu\'à la suivante', () {
    final lundi = _sport.copie(jours: 0x01);
    final plan = planifie(questions: [lundi], reponses: {}, maintenant: midi);
    expect(plan.notifs.map((n) => n.jour.weekday).toSet(), {1});
    expect(plan.notifs.first.duree, const Duration(days: 7));
  });

  test('moins de jours d\'avance s\'il y a beaucoup de questions', () {
    final plan = planifie(
      questions: [for (var i = 1; i <= 10; i++) _sport.copie(id: i)],
      reponses: {},
      maintenant: midi,
      maxNotifs: 63,
    );
    expect(plan.notifs.length, lessThanOrEqualTo(63));
  });

  test('rien à programmer sans question active', () {
    final plan = planifie(questions: [], reponses: {}, maintenant: midi);
    expect(plan.notifs, isEmpty);
    expect(plan.rappelContinuer, isNull);
  });

  test('le bilan des 7 derniers jours', () {
    final texte = bilan(
      [
        _sport,
        _sport.copie(id: 2, texte: 'Hyrox ?', jours: 0x01),
        _sport.copie(id: 3, texte: 'Vieux ?', jours: 0),
      ],
      {
        1: {'2026-11-25': 0, '2026-11-24': 1, '2026-11-19': 0},
        2: {'2026-11-23': 0},
      },
      midi,
    );
    expect(
      texte,
      'Bilan Ouinon du 19/11 au 25/11\n'
      'Sport ? Oui 2/7 · jeu. Oui, ven. –, sam. –, dim. –, lun. –, '
      'mar. Non, mer. Oui\n'
      'Hyrox ? Oui 1/1 · lun. Oui',
    );
  });
}
