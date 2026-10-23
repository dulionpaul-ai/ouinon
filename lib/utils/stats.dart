import '../models/question.dart';
import 'jour.dart';

/// Réponses d'une question : jour (« 2026-10-22 ») → indice de la réponse
/// (0 = la meilleure).
typedef Reponses = Map<String, int>;

/// Combien de fois chaque réponse a été donnée sur une période.
class Bilan {
  /// Un compte par réponse, la meilleure d'abord.
  final List<int> comptes;

  const Bilan(this.comptes);

  int get total => comptes.fold(0, (a, b) => a + b);

  /// Part de la meilleure réponse (entre 0 et 1), nulle sans réponse.
  double? get partMeilleure => total == 0 ? null : comptes[0] / total;
}

/// Bilan des réponses entre `debut` et `fin` compris (sans `debut` : depuis
/// la première réponse).
Bilan bilan(
  Question q,
  Reponses reponses, {
  DateTime? debut,
  required DateTime fin,
}) {
  final comptes = List.filled(q.nbReponses, 0);
  final cleDebut = debut == null ? null : cleJour(debut);
  final cleFin = cleJour(fin);
  reponses.forEach((jour, choix) {
    if (cleDebut != null && jour.compareTo(cleDebut) < 0) return;
    if (jour.compareTo(cleFin) > 0) return;
    if (choix >= 0 && choix < comptes.length) comptes[choix]++;
  });
  return Bilan(comptes);
}

/// Bilan par jour de la semaine : 7 bilans, lundi d'abord.
List<Bilan> parJourSemaine(Question q, Reponses reponses) {
  final comptes = List.generate(7, (_) => List.filled(q.nbReponses, 0));
  reponses.forEach((jour, choix) {
    if (choix < 0 || choix >= q.nbReponses) return;
    comptes[jourDepuisCle(jour).weekday - 1][choix]++;
  });
  return [for (final c in comptes) Bilan(c)];
}

/// Une série : jours d'affilée avec la meilleure réponse.
class Serie {
  final int actuelle;
  final int record;

  const Serie(this.actuelle, this.record);
}

/// Série en cours et record d'une question. Seuls comptent les jours où
/// la question revient ; aujourd'hui sans réponse ne casse pas la série
/// (la journée n'est pas finie).
Serie serie(Question q, Reponses reponses, DateTime aujourdhui) {
  if (reponses.isEmpty) return const Serie(0, 0);
  final premier = reponses.keys.reduce((a, b) => a.compareTo(b) < 0 ? a : b);
  final debut = jourDepuisCle(premier);
  final auj = jourDe(aujourdhui);
  var enCours = 0, record = 0;
  for (var j = debut; !j.isAfter(auj); j = ajouteJours(j, 1)) {
    if (!q.revientLe(j.weekday)) continue;
    final choix = reponses[cleJour(j)];
    if (choix == 0) {
      enCours++;
      if (enCours > record) record = enCours;
    } else if (!(choix == null && j == auj)) {
      enCours = 0;
    }
  }
  return Serie(enCours, record);
}

/// Les lignes du bilan de la semaine (du lundi au dimanche `dimanche`),
/// pour la notification du dimanche soir, plus une ligne `enPlus` (la
/// découverte la plus forte) ; nul sans aucune réponse.
List<String>? bilanSemaine(
  List<Question> questions,
  Map<int, Reponses> reponses,
  DateTime dimanche, {
  String? enPlus,
}) {
  final fin = jourDe(dimanche);
  final lundi = lundiDe(fin);
  final lignes = <String>[];
  Question? meilleureSerie;
  var longueur = 0;
  for (final q in questions) {
    if (!q.active || q.id == null) continue;
    final r = reponses[q.id] ?? const {};
    final b = bilan(q, r, debut: lundi, fin: fin);
    if (b.total == 0) continue;
    lignes.add(
      '${q.texte} ${q.reponses[0]} : ${b.comptes[0]} '
      'jour${b.comptes[0] > 1 ? 's' : ''} sur ${b.total}',
    );
    final s = serie(q, r, fin).actuelle;
    if (s > longueur) {
      longueur = s;
      meilleureSerie = q;
    }
  }
  if (lignes.isEmpty) return null;
  if (meilleureSerie != null && longueur >= 3) {
    lignes.add(
      'Série : ${meilleureSerie.texte} ${meilleureSerie.reponses[0]}, '
      '$longueur jours d\'affilée',
    );
  }
  if (enPlus != null) lignes.add(enPlus);
  return lignes;
}
