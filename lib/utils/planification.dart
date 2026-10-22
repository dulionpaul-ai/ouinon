import '../models/question.dart';
import 'jour.dart';

/// Une notification à programmer : une question, le jour dont elle parle,
/// et le moment où elle s'affiche.
class NotifPrevue {
  final int id;
  final Question question;
  final DateTime jour;
  final DateTime quand;

  const NotifPrevue(this.id, this.question, this.jour, this.quand);
}

/// Jours programmés d'avance : au-delà, il faut une réponse ou une
/// ouverture de l'appli pour continuer (docs/plan_action.md, relecture).
const horizonJours = 14;

/// Identifiant de la notification « Ouvre Oui-Non pour continuer ».
const idRappelContinuer = 1;

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
