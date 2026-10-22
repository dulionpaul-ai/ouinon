/// Jours de calendrier, sans heure. Les réponses sont rangées par jour
/// sous la forme « 2026-10-22 ».
library;

/// Le jour (à minuit) d'une date.
DateTime jourDe(DateTime date) => DateTime(date.year, date.month, date.day);

/// `jour` décalé de `n` jours (calcul au calendrier : juste même aux
/// changements d'heure).
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

/// Lundi de la semaine de `date`.
DateTime lundiDe(DateTime date) =>
    ajouteJours(jourDe(date), -(date.weekday - 1));

/// Nombre de jours entre deux jours (b − a).
int ecartJours(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
