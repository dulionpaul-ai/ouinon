import '../data/base.dart';
import '../models/question.dart';
import 'jour.dart';

/// Quand une question est posée. Un jour où elle a une réponse (même
/// donnée un jour non prévu, Paul, 27/11/2026) compte toujours comme posé.
///
/// Certains jours : chaque jour coché. Tous les N jours (une tâche) : à
/// partir de son échéance ([echeance]), et chaque jour ensuite tant
/// qu'elle n'est pas faite.
bool poseeLe(Question q, DateTime jour, Reponses reponses) {
  if (q.enPause) return false;
  if (reponses.containsKey(cleJour(jour))) return true;
  if (!q.tache) return q.revientLe(jour.weekday);
  final e = echeance(q, jour, reponses);
  return e == null || !jour.isBefore(e);
}

/// Pour une tâche, vue depuis [jour] : N jours après le dernier « Fait »
/// d'avant ce jour ; sans « Fait », sa « Prochaine fois » ; nulle si ni
/// l'un ni l'autre (posée chaque jour). Un « Fait » compte s'il tombe dans
/// les N jours avant la « Prochaine fois » (faite en avance : la suite se
/// recale) ou après ; plus ancien, il est remplacé par la date choisie.
DateTime? echeance(Question q, DateTime jour, Reponses reponses) {
  final depart = q.depart;
  final limite = depart == null
      ? null
      : ajouteJours(depart, -(q.intervalle - 1));
  for (var n = 1; n <= 400; n++) {
    final d = ajouteJours(jourDe(jour), -n);
    if (limite != null && d.isBefore(limite)) break;
    if (reponses[cleJour(d)] == 0) return ajouteJours(d, q.intervalle);
  }
  return depart;
}

/// Le prochain jour où [q] est posée, à partir de [aujourdhui] compris
/// (nul : en pause, ou rien dans l'année).
DateTime? prochainJour(Question q, DateTime aujourdhui, Reponses reponses) {
  if (q.enPause) return null;
  for (var n = 0; n <= 366; n++) {
    final j = ajouteJours(jourDe(aujourdhui), n);
    if (poseeLe(q, j, reponses)) return j;
  }
  return null;
}

/// Pour une tâche pas posée [aujourdhui] : dans combien de jours elle
/// revient (nul si elle est posée, ou sans intervalle).
int? revientDans(Question q, DateTime aujourdhui, Reponses reponses) {
  if (!q.tache) return null;
  final j = prochainJour(q, aujourdhui, reponses);
  if (j == null) return null;
  final n = ecartJours(jourDe(aujourdhui), j);
  return n == 0 ? null : n;
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
  if (!q.tache) return joursFr(q.jours);
  return 'Tous les ${q.intervalle} jours';
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
