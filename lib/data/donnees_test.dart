import 'dart:math' as math;

import '../models/question.dart';
import '../models/tache.dart';
import '../utils/jour.dart';
import 'base.dart';

/// Réponses de test pour essayer les graphiques (demande de Paul du
/// 23/10/2026 : « rajoute plein de données, c'est une base de test »).
///
/// Une « énergie » cachée varie d'un jour à l'autre (avec un mieux le
/// week-end) ; chaque question y répond, certaines avec un jour de
/// retard, une à l'inverse : les découvertes ont de quoi trouver des
/// courbes qui se suivent. Le planning inventé la suit aussi (et se tient
/// moins bien les jours chargés et le soir). Toujours les mêmes données
/// (tirage fixe). Marquées « test », elles s'effacent d'un coup ; les
/// vraies réponses ne sont jamais remplacées.
List<({int questionId, DateTime jour, int choix})> genereReponsesTest(
  List<Question> questions, {
  required DateTime aujourdhui,
  int jours = 182,
  int graine = 42,
}) {
  final hasard = math.Random(graine + 1);
  final debut = ajouteJours(jourDe(aujourdhui), -jours);
  final energie = _energie(debut, jours, graine);

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

/// Tirage gaussien (Box-Muller).
double _gauss(math.Random hasard) {
  final u = 1 - hasard.nextDouble(), v = hasard.nextDouble();
  return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * v);
}

/// Énergie cachée de chaque jour depuis `debut`, avec un jour de plus
/// avant le début (pour les retards) : indice `i + 1` pour le jour `i`.
List<double> _energie(DateTime debut, int jours, int graine) {
  final hasard = math.Random(graine);
  final energie = <double>[];
  var e = 0.0;
  for (var i = 0; i <= jours + 1; i++) {
    final jour = ajouteJours(debut, i - 1);
    final weekEnd = jour.weekday >= 6 ? 0.35 : 0.0;
    e = 0.72 * e + 0.55 * _gauss(hasard);
    energie.add(e + weekEnd);
  }
  return energie;
}

/// Choses à prévoir du planning de test : texte, durée, heures possibles,
/// et un penchant (les papiers se reportent plus que le sport).
const _choses = [
  ('Courir', 45, [7, 18], 0.3),
  ('Courses', 60, [10, 17, 18], 0.4),
  ('Appeler maman', 15, [12, 19], 0.6),
  ('Ménage', 60, [10, 14], -0.2),
  ('Banque', 30, [9, 14], -0.6),
  ('Lessive', 30, [8, 19], 0.2),
  ('Lire', 30, [21, 22], 0.1),
  ('Garage', 60, [9, 17], -0.3),
  ('Mails', 30, [9, 11], 0.5),
  ('Préparer le dîner', 60, [19], 0.7),
  ('Papiers', 60, [14, 20], -0.9),
  ('Vélo', 90, [10, 16], 0.2),
  ('Bricolage', 120, [14, 15], -0.4),
];

/// Planning de test des `jours` jours passés (pas aujourd'hui).
List<Tache> genereTachesTest({
  required DateTime aujourdhui,
  int jours = 182,
  int graine = 42,
}) {
  final hasard = math.Random(graine + 2);
  final debut = ajouteJours(jourDe(aujourdhui), -jours);
  final energie = _energie(debut, jours, graine);
  final taches = <Tache>[];
  for (var i = 0; i < jours; i++) {
    final jour = ajouteJours(debut, i);
    if (hasard.nextDouble() < 0.08) continue; // jours sans planning
    final nombre = 2 + hasard.nextInt(5);
    final choisies = [..._choses]..shuffle(hasard);
    final du = <Tache>[];
    for (final (texte, duree, heures, _) in choisies.take(nombre)) {
      final debutMin =
          heures[hasard.nextInt(heures.length)] * 60 +
          (hasard.nextBool() ? 30 : 0);
      du.add(Tache(jour: jour, debut: debutMin, duree: duree, texte: texte));
    }
    final heures = du.fold(0, (s, t) => s + t.duree) / 60;
    for (final t in du) {
      final penchant = _choses.firstWhere((c) => c.$1 == t.texte).$4;
      final x =
          1.6 * energie[i + 1] +
          0.9 +
          penchant -
          0.35 * (heures - 3) -
          (t.debut >= 18 * 60 ? 0.5 : 0) +
          (t.debut < 12 * 60 ? 0.3 : 0);
      final p = 1 / (1 + math.exp(-x));
      final u = hasard.nextDouble();
      final int? etat = u < p
          ? Tache.fait
          : hasard.nextDouble() < 0.85
          ? Tache.pasFait
          : null;
      final reports = switch (etat) {
        Tache.fait => hasard.nextDouble() < 0.15 ? 1 : 0,
        Tache.pasFait => hasard.nextDouble() < 0.4 ? 1 + hasard.nextInt(3) : 0,
        _ => 0,
      };
      taches.add(
        Tache(
          jour: jour,
          debut: t.debut,
          duree: t.duree,
          texte: t.texte,
          etat: etat,
          reports: reports,
          test: true,
        ),
      );
    }
  }
  return taches;
}

/// Ajoute six mois de réponses et de planning de test à la base. Rend le
/// nombre ajouté.
Future<int> ajouteDonneesTest(Base base, {DateTime? maintenant}) async {
  final aujourdhui = maintenant ?? DateTime.now();
  final reponses = genereReponsesTest(
    await base.questions(),
    aujourdhui: aujourdhui,
  );
  return await base.ajouteReponsesTest(reponses) +
      await base.ajouteTachesTest(genereTachesTest(aujourdhui: aujourdhui));
}
