/// Jours de calendrier, sans heure. Les réponses sont rangées par jour,
/// sous la forme « 2026-10-22 ».
library;

/// Le jour (à minuit) d'une date.
DateTime jourDe(DateTime date) => DateTime(date.year, date.month, date.day);

/// [jour] décalé de [n] jours (au calendrier : juste même aux changements
/// d'heure).
DateTime ajouteJours(DateTime jour, int n) =>
    DateTime(jour.year, jour.month, jour.day + n);

/// « 2026-10-22 ».
String cleJour(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime jourDepuisCle(String cle) {
  final p = cle.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// Nombre de jours entre deux jours (b − a).
int ecartJours(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// « 7 h », « 7 h 45 » ([minutes] depuis minuit).
String heureFr(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
}

/// Initiales des jours, lundi d'abord.
const initialesJours = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

/// « lun. », « mar. »…, lundi d'abord.
const joursCourts = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];

/// « Tous les jours », « En semaine », « Le week-end », « lun., mer. »,
/// « En pause » (aucun jour).
String joursFr(int masque) {
  if (masque == 0) return 'En pause';
  if (masque == 0x7F) return 'Tous les jours';
  if (masque == 0x1F) return 'En semaine';
  if (masque == 0x60) return 'Le week-end';
  return [
    for (var i = 0; i < 7; i++)
      if (masque & (1 << i) != 0) joursCourts[i],
  ].join(', ');
}

/// « 18/11 ».
String dateCourte(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
