import '../data/base.dart';
import '../models/question.dart';
import 'jour.dart';

/// Quand une question est posée.
///
/// Sans intervalle : chaque jour coché. Avec un intervalle de N jours (une
/// tâche : arroser les plantes, changer les draps) : un jour coché sans
/// meilleure réponse (« Fait ») dans les N − 1 jours d'avant. Elle revient
/// donc N jours après avoir été faite, puis chaque jour coché tant qu'elle
/// ne l'est pas. Un jour déjà répondu reste toujours posé.
bool poseeLe(Question q, DateTime jour, Reponses reponses) {
  if (q.enPause || !q.revientLe(jour.weekday)) return false;
  if (q.intervalle < 2) return true;
  if (reponses.containsKey(cleJour(jour))) return true;
  for (var n = 1; n < q.intervalle; n++) {
    if (reponses[cleJour(ajouteJours(jour, -n))] == 0) return false;
  }
  return true;
}

/// Pour une tâche pas posée [aujourdhui] : dans combien de jours elle
/// revient (nul si elle est posée, ou sans intervalle).
int? revientDans(Question q, DateTime aujourdhui, Reponses reponses) {
  if (q.enPause || q.intervalle < 2) return null;
  for (var n = 0; n <= q.intervalle + 7; n++) {
    if (poseeLe(q, ajouteJours(aujourdhui, n), reponses)) {
      return n == 0 ? null : n;
    }
  }
  return null;
}

/// La semaine en cours (du lundi à [aujourdhui]) : les meilleures réponses
/// (« oui ») sur les questions posées. Aujourd'hui ne compte que ce qui
/// est déjà répondu.
({int oui, int total}) semaine(
  List<Question> questions,
  Map<int, Reponses> reponses,
  DateTime aujourdhui,
) {
  final fin = jourDe(aujourdhui);
  final lundi = ajouteJours(fin, -(fin.weekday - 1));
  var oui = 0, total = 0;
  for (final q in questions) {
    final r = reponses[q.id] ?? const {};
    for (var j = lundi; !j.isAfter(fin); j = ajouteJours(j, 1)) {
      if (!poseeLe(q, j, r)) continue;
      final c = r[cleJour(j)];
      if (j == fin && c == null) continue;
      total++;
      if (c == 0) oui++;
    }
  }
  return (oui: oui, total: total);
}

/// « Tous les jours », « lun., mer. », « Tous les 5 jours », « Tous les
/// 5 jours · en semaine »…
String frequenceFr(Question q) {
  if (q.enPause) return 'En pause';
  if (q.intervalle < 2) return joursFr(q.jours);
  final base = 'Tous les ${q.intervalle} jours';
  return q.jours == Question.tousLesJours
      ? base
      : '$base · ${joursFr(q.jours).toLowerCase()}';
}

/// La série en cours : les jours posés d'affilée avec la meilleure
/// réponse, jusqu'à [aujourdhui] (pas encore répondu aujourd'hui : la
/// série d'hier tient toujours). Les jours où elle n'est pas posée ne
/// cassent pas la série.
int serie(Question q, DateTime aujourdhui, Reponses reponses) {
  var n = 0;
  for (var d = 0; d < 400; d++) {
    final j = ajouteJours(jourDe(aujourdhui), -d);
    if (!poseeLe(q, j, reponses)) continue;
    final c = reponses[cleJour(j)];
    if (d == 0 && c == null) continue;
    if (c != 0) break;
    n++;
  }
  return n;
}

/// Les 7 derniers jours d'une question, aujourd'hui en dernier : l'indice
/// de la réponse, −1 si posée sans réponse, nul si pas posée.
List<int?> septJours(Question q, DateTime aujourdhui, Reponses reponses) => [
  for (var n = 6; n >= 0; n--)
    () {
      final j = ajouteJours(jourDe(aujourdhui), -n);
      if (!poseeLe(q, j, reponses)) return null;
      return reponses[cleJour(j)] ?? -1;
    }(),
];

/// Pour une tâche : depuis combien de jours elle a été faite (meilleure
/// réponse) avant [jour] ; nul si jamais.
int? faitIlYA(Question q, DateTime jour, Reponses reponses) {
  for (var n = 1; n <= 366; n++) {
    if (reponses[cleJour(ajouteJours(jourDe(jour), -n))] == 0) return n;
  }
  return null;
}

/// Le texte sous la question dans la notification : le « pourquoi » de
/// Paul ; pour une tâche sans pourquoi, depuis quand elle est faite.
String? texteNotif(Question q, DateTime jour, Reponses reponses) {
  if (q.pourquoi.isNotEmpty) return q.pourquoi;
  if (q.intervalle < 2) return null;
  final n = faitIlYA(q, jour, reponses);
  if (n == null) return null;
  return n == 1 ? 'Faite hier.' : 'Faite il y a $n jours.';
}
