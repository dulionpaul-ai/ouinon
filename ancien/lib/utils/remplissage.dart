import '../models/a_faire.dart';
import '../models/creneau.dart';
import '../models/tache.dart';
import 'jour.dart';

/// « Remplir ma journée » (idée de Paul du 24/10/2026 : « je remplis mes
/// impératifs de demain et je laisse l'appli pré-remplir le reste ») :
/// première version, simple et prévisible, à améliorer avec lui.
///
/// Les impératifs, les créneaux fixes et ce qui est déjà prévu restent où
/// ils sont. Les choses du bac (choisies pour ce jour) sont posées dans
/// les trous, entre le début et la fin de la
/// journée choisis dans les Réglages, avec un quart d'heure de marge
/// autour de chaque chose : d'abord ce dont c'est le dernier jour (date
/// limite atteinte), puis « D'abord », « À planifier », « Vite fait » ;
/// dans une case, la date limite la plus proche, puis la plus ancienne.
/// « Peut-être jamais » n'est placé que s'il a été choisi pour ce jour
/// (`avecJamais`). Les horaires tombent au quart d'heure.

/// Marge laissée avant et après chaque chose, en minutes.
const margePlanning = 15;

/// Pas des horaires proposés, en minutes.
const pasPlanning = 15;

/// Ordre de placement des choses de la liste.
List<AFaire> ordreDePlacement(
  Iterable<AFaire> liste,
  DateTime jour, {
  bool avecJamais = false,
}) {
  final aPlacer = [
    for (final a in liste)
      if (!a.faite && (avecJamais || a.caseLe(jour) != Case.peutEtreJamais)) a,
  ];
  int cle(DateTime? d) => d == null ? 1 << 30 : ecartJours(DateTime(2020), d);
  bool dernierJour(AFaire a) =>
      a.echeance != null && !a.echeance!.isAfter(jourDe(jour));
  aPlacer.sort((x, y) {
    final d = (dernierJour(x) ? 0 : 1).compareTo(dernierJour(y) ? 0 : 1);
    if (d != 0) return d;
    final c = x.caseLe(jour).index.compareTo(y.caseLe(jour).index);
    if (c != 0) return c;
    final e = cle(x.echeance).compareTo(cle(y.echeance));
    if (e != 0) return e;
    return x.creeLe.compareTo(y.creeLe);
  });
  return aPlacer;
}

/// Premier moment de la journée où l'on peut commencer à placer :
/// le début de journée, ou (aujourd'hui) le prochain quart d'heure.
int premierDebut(DateTime jour, int debutJournee, DateTime? maintenant) {
  if (maintenant == null || jourDe(maintenant) != jourDe(jour)) {
    return debutJournee;
  }
  final m = maintenant.hour * 60 + maintenant.minute;
  final prochain = ((m + pasPlanning - 1) ~/ pasPlanning) * pasPlanning;
  return prochain > debutJournee ? prochain : debutJournee;
}

/// Premier créneau libre de `duree` minutes (début en minutes), ou nul
/// s'il n'y en a pas avant la fin de journée.
int? premierCreneau(
  int duree,
  Iterable<Tache> prevues, {
  required int depuis,
  required int finJournee,
}) {
  for (var s = depuis; s + duree <= finJournee; s += pasPlanning) {
    final libre = prevues.every(
      (t) => s + duree <= t.debut - margePlanning || s >= t.fin + margePlanning,
    );
    if (libre) return s;
  }
  return null;
}

/// Un créneau fixe vu comme une chose prévue (pour savoir où c'est pris).
Tache occupation(Creneau c, DateTime jour) =>
    Tache(jour: jourDe(jour), debut: c.debut, duree: c.duree, texte: c.texte);

/// La proposition pour `jour` : les choses placées, et celles qui ne
/// rentrent pas.
({List<Tache> placees, List<AFaire> horsJournee}) remplitJournee({
  required DateTime jour,
  required List<Tache> prevues,
  required Iterable<AFaire> aPlacer,
  required int debutJournee,
  required int finJournee,
  DateTime? maintenant,
  List<Creneau> creneaux = const [],
  bool avecJamais = false,
}) {
  final depuis = premierDebut(jour, debutJournee, maintenant);
  final occupe = [
    for (final t in prevues)
      if (t.etat != Tache.pasFait) t,
    for (final c in creneaux) occupation(c, jour),
  ];
  final placees = <Tache>[];
  final horsJournee = <AFaire>[];
  for (final a in ordreDePlacement(aPlacer, jour, avecJamais: avecJamais)) {
    final debut = premierCreneau(
      a.duree,
      occupe,
      depuis: depuis,
      finJournee: finJournee,
    );
    if (debut == null) {
      horsJournee.add(a);
      continue;
    }
    final t = Tache(
      jour: jourDe(jour),
      debut: debut,
      duree: a.duree,
      texte: a.texte,
      listeId: a.id,
      quadrant: a.caseLe(jour).index,
    );
    placees.add(t);
    occupe.add(t);
  }
  placees.sort((x, y) => x.debut.compareTo(y.debut));
  return (placees: placees, horsJournee: horsJournee);
}

/// Temps libre de la journée (minutes), entre le premier début possible
/// et la fin de journée, hors ce qui est déjà prévu.
int tempsLibre({
  required DateTime jour,
  required List<Tache> prevues,
  required int debutJournee,
  required int finJournee,
  DateTime? maintenant,
  List<Creneau> creneaux = const [],
}) {
  final depuis = premierDebut(jour, debutJournee, maintenant);
  var libre = 0;
  for (var m = depuis; m < finJournee; m++) {
    if (prevues.every(
          (t) => t.etat == Tache.pasFait || m < t.debut || m >= t.fin,
        ) &&
        creneaux.every((c) => m < c.debut || m >= c.fin)) {
      libre++;
    }
  }
  return libre;
}
