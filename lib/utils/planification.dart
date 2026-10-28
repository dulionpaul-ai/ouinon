import '../models/question.dart';
import 'jour.dart';
import 'stats.dart';

/// Une notification à programmer : une question, le jour dont elle parle,
/// et le moment où elle s'affiche.
class NotifPrevue {
  final int id;
  final Question question;
  final DateTime jour;
  final DateTime quand;

  /// Redemandée un jour après [jour], parce que pas faite (« Me raser ?
  /// (de lundi) »).
  final bool rattrapage;

  const NotifPrevue(
    this.id,
    this.question,
    this.jour,
    this.quand, {
    this.rattrapage = false,
  });

  /// Temps d'affichage : jusqu'à la suivante de la même question, qui la
  /// remplace (Paul, 27/10/2026) ; une journée au plus pour une question
  /// redemandée le lendemain (la suivante prend sa place).
  Duration get duree {
    final jusqua = prochaineFois(question, quand).difference(quand);
    if (!question.redemandee) return jusqua;
    return jusqua < const Duration(days: 1) ? jusqua : const Duration(days: 1);
  }
}

/// Le dernier jour prévu de [q] strictement avant [jour] (6 jours avant
/// au plus), ou nul.
DateTime? jourPrevuAvant(Question q, DateTime jour) {
  for (var n = 1; n <= 6; n++) {
    final d = ajouteJours(jourDe(jour), -n);
    if (q.revientLe(d.weekday)) return d;
  }
  return null;
}

/// Le jour en retard que [q] redemande le [jour] (Paul, 28/10/2026), ou
/// nul : une question redemandée ([Question.redemandee]) qui ne revient
/// pas ce jour-là, dont le dernier jour prévu attend encore : pas de
/// réponse, ou la moins bonne (« Me raser ? » le lundi, « Non » : elle
/// revient mardi, puis mercredi… jusqu'à « Oui » ou au lundi suivant).
DateTime? jourARattraper(Question q, Reponses reponses, DateTime jour) {
  if (!q.active || q.jours == 0 || !q.redemandee) return null;
  if (q.revientLe(jour.weekday)) return null;
  final d = jourPrevuAvant(q, jour);
  if (d == null) return null;
  final r = reponses[cleJour(d)];
  return r == null || r == q.nbReponses - 1 ? d : null;
}

/// La prochaine fois que la question est posée, strictement après
/// [apres] (dans les 7 jours qui suivent, à son heure).
DateTime prochaineFois(Question q, DateTime apres) {
  final jour = jourDe(apres);
  for (var n = 0; n <= 7; n++) {
    final j = ajouteJours(jour, n);
    final quand = DateTime(j.year, j.month, j.day, q.heure ~/ 60, q.heure % 60);
    if (q.revientLe(j.weekday) && quand.isAfter(apres)) return quand;
  }
  return apres.add(const Duration(days: 7));
}

/// Jours programmés d'avance : au-delà, il faut une réponse ou une
/// ouverture de l'appli pour continuer (docs/plan_action.md, relecture).
const horizonJours = 14;

/// Identifiant de la notification « Ouvre Ouinon pour continuer ».
const idRappelContinuer = 1;

/// Identifiant du bilan du dimanche soir.
const idBilanDimanche = 2;

/// Heure du bilan du dimanche (en minutes) : 20 h.
const heureBilan = 20 * 60;

/// Le prochain dimanche à 20 h, strictement après `maintenant`.
DateTime prochainBilan(DateTime maintenant) {
  final aujourdhui = jourDe(maintenant);
  var jour = ajouteJours(
    aujourdhui,
    (DateTime.sunday - aujourdhui.weekday) % 7,
  );
  var quand = DateTime(jour.year, jour.month, jour.day, heureBilan ~/ 60);
  if (!quand.isAfter(maintenant)) {
    jour = ajouteJours(jour, 7);
    quand = DateTime(jour.year, jour.month, jour.day, heureBilan ~/ 60);
  }
  return quand;
}

/// Identifiant d'une notification : la question et le jour, pour la
/// retrouver (et l'effacer) quand on répond dans l'appli.
int idNotification(int questionId, DateTime jour) =>
    questionId * 100000 + ecartJours(DateTime(2020), jour) % 100000;

/// Ce qu'il faut programmer à partir de `maintenant` : chaque question
/// active, à son heure, ses jours, pour les jours à venir, sauf les jours
/// déjà répondus (`repondues` : « id|2026-10-22 »). Le nombre de jours
/// est réduit s'il y a beaucoup de questions (`maxNotifs` : limite du
/// téléphone, 64 sur iPhone).
({List<NotifPrevue> notifs, DateTime? rappelContinuer}) planifie({
  required List<Question> questions,
  required Set<String> repondues,
  required DateTime maintenant,
  int maxNotifs = 400,
  Map<int, Reponses> reponses = const {},
}) {
  final actives = [
    for (final q in questions)
      if (q.active && q.id != null && q.jours != 0) q,
  ];
  if (actives.isEmpty) return (notifs: const [], rappelContinuer: null);
  final horizon = (maxNotifs ~/ actives.length).clamp(1, horizonJours);
  final aujourdhui = jourDe(maintenant);
  final notifs = <NotifPrevue>[];
  for (var n = 0; n < horizon; n++) {
    final jour = ajouteJours(aujourdhui, n);
    for (final q in actives) {
      if (!q.revientLe(jour.weekday)) continue;
      if (repondues.contains('${q.id}|${cleJour(jour)}')) continue;
      final quand = DateTime(
        jour.year,
        jour.month,
        jour.day,
        q.heure ~/ 60,
        q.heure % 60,
      );
      if (!quand.isAfter(maintenant)) continue;
      notifs.add(NotifPrevue(idNotification(q.id!, jour), q, jour, quand));
    }
    // Les questions pas faites, redemandées les jours suivants (en
    // supposant qu'elles restent sans réponse : une réponse reprogramme
    // tout).
    for (final q in actives) {
      final enRetard = jourARattraper(q, reponses[q.id] ?? const {}, jour);
      if (enRetard == null) continue;
      final quand = DateTime(
        jour.year,
        jour.month,
        jour.day,
        q.heure ~/ 60,
        q.heure % 60,
      );
      if (!quand.isAfter(maintenant)) continue;
      notifs.add(
        NotifPrevue(
          idNotification(q.id!, jour),
          q,
          enRetard,
          quand,
          rattrapage: true,
        ),
      );
    }
  }
  notifs.sort((a, b) => a.quand.compareTo(b.quand));
  // Le lendemain du dernier jour programmé, à l'heure de la première
  // question : si rien n'a bougé d'ici là, on invite à rouvrir l'appli.
  final fin = ajouteJours(aujourdhui, horizon);
  final premiere = actives.map((q) => q.heure).reduce((a, b) => a < b ? a : b);
  final rappel = DateTime(
    fin.year,
    fin.month,
    fin.day,
    premiere ~/ 60,
    premiere % 60,
  );
  return (notifs: notifs, rappelContinuer: rappel);
}
