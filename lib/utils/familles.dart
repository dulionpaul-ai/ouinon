import '../models/question.dart';
import 'stats.dart';

/// Les familles de questions (demande de Paul du 27/10/2026) : « Sport »
/// regroupe Cardio ? et Muscu ?. Chaque question reste séparée (sa
/// notification, ses réponses), mais la famille a son propre suivi :
/// chaque jour, la somme de ses questions. Cardio et muscu faits : 2 ;
/// un seul : 1 ; aucun : 0.
///
/// Une réponse compte 1 si c'est la meilleure, 0 si c'est la moins bonne,
/// et ½ pour celle du milieu (questions à 3 réponses). Un jour sans
/// aucune réponse dans la famille ne compte pas ; une question sans
/// réponse ce jour-là compte 0.
///
/// Pour tout le reste du Suivi (anneau, courbes, liens trouvés), une
/// famille se présente comme une question : ses « réponses » vont de
/// « 2 sur 2 » (la meilleure) à « 0 sur 2 », par demi-points.
class Famille {
  final String nom;
  final List<Question> questions;

  /// La famille en question, pour les graphiques.
  final Question commeQuestion;

  /// Ses jours en « réponses » de [commeQuestion].
  final Reponses reponses;

  const Famille({
    required this.nom,
    required this.questions,
    required this.commeQuestion,
    required this.reponses,
  });
}

/// Identifiants des familles dans les graphiques : négatifs, après celui
/// du planning (-1).
const idPremiereFamille = -100;

/// Note d'une réponse : 1 (meilleure), ½ (milieu), 0 (moins bonne).
double pointsDe(int choix, int nbReponses) =>
    nbReponses <= 1 ? 1 : 1 - choix / (nbReponses - 1);

/// « 1,5 » ou « 2 ».
String points(double p) =>
    p == p.roundToDouble() ? '${p.round()}' : p.toString().replaceAll('.', ',');

/// Les familles d'au moins une question, dans l'ordre du nom.
List<Famille> familles(List<Question> questions, Map<int, Reponses> toutes) {
  final parNom = <String, List<Question>>{};
  for (final q in questions) {
    final nom = q.famille?.trim();
    if (nom == null || nom.isEmpty || q.id == null) continue;
    parNom.putIfAbsent(nom, () => []).add(q);
  }
  final noms = parNom.keys.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return [
    for (final (i, nom) in noms.indexed)
      _famille(nom, parNom[nom]!, toutes, idPremiereFamille - i),
  ];
}

Famille _famille(
  String nom,
  List<Question> qs,
  Map<int, Reponses> toutes,
  int id,
) {
  final n = qs.length;
  // Demi-points : de 2n (tout au mieux) à 0.
  final paliers = 2 * n;
  final reponses = <String, int>{};
  final jours = {for (final q in qs) ...?toutes[q.id]?.keys};
  for (final jour in jours) {
    var total = 0.0;
    for (final q in qs) {
      final c = toutes[q.id]?[jour];
      if (c != null) total += pointsDe(c, q.nbReponses);
    }
    // Indice 0 = tout au mieux (comme une meilleure réponse).
    reponses[jour] = paliers - (total * 2).round();
  }
  return Famille(
    nom: nom,
    questions: qs,
    reponses: reponses,
    commeQuestion: Question(
      id: id,
      texte: nom,
      reponses: [
        for (var i = 0; i <= paliers; i++)
          '${points((paliers - i) / 2)} sur $n',
      ],
      heure: qs.map((q) => q.heure).reduce((a, b) => a < b ? a : b),
      famille: nom,
    ),
  );
}
