import 'dart:math' as math;

import '../models/question.dart';
import '../utils/jour.dart';
import 'base.dart';

/// Réponses de test pour essayer les graphiques (demande de Paul du
/// 23/10/2026 : « rajoute plein de données, c'est une base de test »).
///
/// Une « énergie » cachée varie d'un jour à l'autre (avec un mieux le
/// week-end) ; chaque question y répond, certaines avec un jour de
/// retard, une à l'inverse : les découvertes ont de quoi trouver des
/// courbes qui se suivent. Toujours les mêmes réponses (tirage fixe).
/// Marquées « test », elles s'effacent d'un coup ; les vraies réponses ne
/// sont jamais remplacées.
List<({int questionId, DateTime jour, int choix})> genereReponsesTest(
  List<Question> questions, {
  required DateTime aujourdhui,
  int jours = 182,
  int graine = 42,
}) {
  final hasard = math.Random(graine);
  double gauss() {
    // Box-Muller.
    final u = 1 - hasard.nextDouble(), v = hasard.nextDouble();
    return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * v);
  }

  final debut = ajouteJours(jourDe(aujourdhui), -jours);
  // Énergie cachée, un jour de plus avant le début pour les retards.
  final energie = <double>[];
  var e = 0.0;
  for (var i = 0; i <= jours + 1; i++) {
    final jour = ajouteJours(debut, i - 1);
    final weekEnd = jour.weekday >= 6 ? 0.35 : 0.0;
    e = 0.72 * e + 0.55 * gauss();
    energie.add(e + weekEnd);
  }

  final actives = [
    for (final q in questions)
      if (q.id != null && q.active) q,
  ];
  final reponses = <({int questionId, DateTime jour, int choix})>[];
  for (final (rang, q) in actives.indexed) {
    // Une question sur trois suit l'énergie avec un jour de retard ; la
    // quatrième va à l'inverse ; force et penchant varient.
    final retard = rang % 3 == 1 ? 1 : 0;
    final sens = rang == 3 ? -1.0 : 1.0;
    final force = 2.4 + hasard.nextDouble() * 1.2;
    final penchant = -0.2 + hasard.nextDouble() * 0.9;
    for (var i = 0; i < jours; i++) {
      final jour = ajouteJours(debut, i);
      if (!q.revientLe(jour.weekday)) continue;
      if (hasard.nextDouble() < 0.07) continue; // quelques jours oubliés
      final x = sens * force * energie[i + 1 - retard] + penchant;
      final p = 1 / (1 + math.exp(-x)); // chance d'une bonne réponse
      final u = hasard.nextDouble();
      final int choix;
      if (q.nbReponses == 2) {
        choix = u < p ? 0 : 1;
      } else {
        final pBien = p * p, pMal = (1 - p) * (1 - p);
        choix = u < pBien ? 0 : (u < 1 - pMal ? 1 : 2);
      }
      reponses.add((questionId: q.id!, jour: jour, choix: choix));
    }
  }
  return reponses;
}

/// Ajoute six mois de réponses de test à la base. Rend le nombre ajouté.
Future<int> ajouteDonneesTest(Base base, {DateTime? maintenant}) async {
  final reponses = genereReponsesTest(
    await base.questions(),
    aujourdhui: maintenant ?? DateTime.now(),
  );
  return base.ajouteReponsesTest(reponses);
}
