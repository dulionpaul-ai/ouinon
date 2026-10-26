import '../models/tache.dart';
import 'date_fr.dart';
import 'planning.dart';

/// Les deux toi (idée de Paul du 26/10/2026, d'après la série
/// « Severance ») : le soir, celui qui décide prépare le lendemain ; le
/// jour, celui qui exécute suit le plan. Ils ne se croisent pas : ils se
/// laissent des mots, et un compte rendu en fin de journée.
enum Moi {
  /// Le soir : on décide de demain (ambre).
  decideur,

  /// Le jour : on exécute le plan (terminal sobre).
  executant,

  /// Les deux toi ne sont pas encore actifs (intro pas vue) : style
  /// habituel.
  repos,
}

/// `minutes` (depuis minuit) est-il dans la plage ? Une plage peut passer
/// minuit.
bool dansPlage(int minutes, ({int debut, int fin}) plage) {
  final d = plage.debut, f = plage.fin;
  if (d == f) return false;
  return d < f ? minutes >= d && minutes < f : minutes >= d || minutes < f;
}

/// Qui est là à `maintenant` (anneau toujours plein, 26/10/2026) :
/// l'Exécutant pendant la journée, le Décideur tout le reste du temps.
Moi moiA(DateTime maintenant, {required ({int debut, int fin}) jour}) {
  final m = maintenant.hour * 60 + maintenant.minute;
  return dansPlage(m, jour) ? Moi.executant : Moi.decideur;
}

/// La chose en cours à `minutes`, sinon la prochaine sans réponse ; nulle
/// s'il n'y a plus rien à faire.
({Tache tache, bool enCours})? enCours(List<Tache> taches, int minutes) {
  final restantes = [
    for (final t in taches)
      if (t.etat == null && t.fin > minutes) t,
  ]..sort((a, b) => a.debut.compareTo(b.debut));
  if (restantes.isEmpty) return null;
  final t = restantes.first;
  return (tache: t, enCours: t.debut <= minutes);
}

/// « 4 choses, 4 h 15 ».
String resumeJournee(List<Tache> taches) {
  final n = taches.length;
  final duree = taches.fold(0, (s, t) => s + t.duree);
  return '$n chose${n > 1 ? 's' : ''}, ${dureeFr(duree)}';
}

/// Texte de la notification du matin : ce que le toi du soir a prévu.
/// Nul s'il n'a rien prévu.
String? texteMatin(List<Tache> taches, String? mot) {
  if (taches.isEmpty) return null;
  final premiere = taches.map((t) => t.debut).reduce((a, b) => a < b ? a : b);
  return [
    'Prévu hier soir : ${resumeJournee(taches)}. '
        'Première à ${heureFr(premiere)}.',
    if (mot != null) '« $mot »',
  ].join('\n');
}

/// « 3 sur 4 » : choses faites sur choses prévues.
String scoreJournee(List<Tache> taches) =>
    '${compte(taches).faits} sur ${taches.length}';

/// Texte de la notification de fin de journée (le compte rendu). Nul si
/// rien n'était prévu.
String? texteRapport(List<Tache> taches) {
  if (taches.isEmpty) return null;
  return '${scoreJournee(taches)} de ce que tu avais prévu. '
      'Un mot pour ton toi du soir ?';
}
