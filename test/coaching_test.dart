import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/data/coaching.dart';
import 'package:ouinon/models/a_faire.dart';
import 'package:ouinon/models/tache.dart';

import 'outils.dart';

/// Le coaching : la cible du coucher avance de 30 minutes chaque lundi,
/// de 0 h 30 (semaine du 2/11/2026) jusqu'à 23 h.
void main() {
  test('cible du coucher, semaine après semaine', () {
    expect(cibleCoucher(DateTime(2026, 11, 5)), 24 * 60 + 30);
    expect(cibleCoucher(DateTime(2026, 11, 9)), 24 * 60);
    expect(cibleCoucher(DateTime(2026, 11, 16)), 23 * 60 + 30);
    expect(cibleCoucher(DateTime(2026, 11, 23)), 23 * 60);
    expect(cibleCoucher(DateTime(2027, 1, 4)), 23 * 60);
    expect(cibleCoucher(DateTime(2026, 10, 22)), 24 * 60 + 30);
  });

  test('la notification du coucher rappelle la cible de la veille', () {
    final coucher = questionsCoaching.firstWhere(
      (q) => q.texte == texteCoucher,
    );
    // Lundi 9/11 au matin : la nuit de dimanche, cible encore 0 h 30.
    expect(detailNotification(coucher, DateTime(2026, 11, 9)), contains('30'));
    expect(
      detailNotification(questionsCoaching.first, DateTime(2026, 11, 9)),
      isNull,
    );
  });

  test(
    'tout envoyer au coach : questions, réponses, to-do, planning',
    () async {
      final base = await ouvreBase();
      final jeudi = DateTime(2026, 10, 22);
      await base.repond(1, jeudi, 0);
      await base.enregistreAFaire(
        AFaire(texte: 'Stop Pub', duree: 15, creeLe: jeudi),
      );
      await base.enregistreTache(
        Tache(jour: jeudi, debut: 9 * 60, texte: 'Mails', etat: Tache.fait),
      );
      final texte = await exportComplet(base, DateTime(2026, 11, 5));
      expect(texte, contains('QUESTIONS'));
      expect(texte, contains('Sommeil ?'));
      expect(texte, contains('22/10/26 8 h et +'));
      expect(texte, contains('Stop Pub · 15 min'));
      expect(texte, contains('22/10/26 9 h Mails (60 min) : fait'));
    },
  );
}
