import '../data/base.dart';
import '../models/question.dart';
import 'frequence.dart';
import 'jour.dart';

/// Le bilan des 7 derniers jours, à coller dans la conversation avec le
/// coach : pour chaque question, le compte de la meilleure réponse et la
/// réponse jour par jour (« – » : pas de réponse).
String bilan(
  List<Question> questions,
  Map<int, Reponses> reponses,
  DateTime aujourdhui,
) {
  final fin = jourDe(aujourdhui);
  final debut = ajouteJours(fin, -6);
  final lignes = <String>[
    'Bilan Ouinon du ${dateCourte(debut)} au ${dateCourte(fin)}',
  ];
  for (final q in questions) {
    if (q.enPause) continue;
    final r = reponses[q.id] ?? const {};
    final jours = <String>[];
    var meilleure = 0, total = 0;
    for (var n = 0; n < 7; n++) {
      final j = ajouteJours(debut, n);
      if (!poseeLe(q, j, r)) continue;
      final c = r[cleJour(j)];
      total++;
      if (c == 0) meilleure++;
      jours.add(
        '${joursCourts[j.weekday - 1]} ${c == null ? '–' : q.reponses[c]}',
      );
    }
    if (total == 0) continue;
    lignes.add(
      '${q.texte} ${q.reponses.first} $meilleure/$total · ${jours.join(', ')}',
    );
  }
  return lignes.join('\n');
}
