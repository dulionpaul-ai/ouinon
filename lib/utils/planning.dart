import '../models/question.dart';
import '../models/tache.dart';
import 'date_fr.dart';
import 'jour.dart';
import 'stats.dart';

/// Calculs du planning (purs et testés) : rappels, part de ce qui est
/// fait, et les stats qui en sortent.

/// Les réponses d'une chose prévue dans l'appli, comme une question à
/// deux réponses (« Fait » = la meilleure, à droite). « Reporter » n'est
/// que dans la notification : dans l'appli, on change l'heure.
const reponsesTache = Question(
  texte: '',
  reponses: ['Fait', 'Pas fait'],
  heure: 0,
);

/// Identifiant du rappel du soir « Prépare ta journée de demain ».
const idRappelPlanning = 3;

/// Identifiant de la notification d'une chose prévue : négatif, pour ne
/// jamais croiser celles des questions.
int idNotifTache(int id) => -id;

/// « 18 h – 19 h ».
String plageFr(Tache t) =>
    '${heureFr(t.debut)} – ${heureFr(t.fin % (24 * 60))}';

/// « 15 min », « 1 h », « 1 h 30 ».
String dureeFr(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
}

/// Les rappels à programmer : chaque chose sans réponse, à son heure de
/// début, si elle n'est pas passée.
List<Tache> rappelsAProgrammer(List<Tache> taches, DateTime maintenant) => [
  for (final t in taches)
    if (t.id != null && t.etat == null && t.quand.isAfter(maintenant)) t,
]..sort((a, b) => a.quand.compareTo(b.quand));

/// Le prochain rappel du soir, à `heure` (minutes), strictement après
/// `maintenant`.
DateTime prochainRappelPlanning(DateTime maintenant, int heure) {
  var jour = jourDe(maintenant);
  var quand = DateTime(
    jour.year,
    jour.month,
    jour.day,
    heure ~/ 60,
    heure % 60,
  );
  if (!quand.isAfter(maintenant)) {
    jour = ajouteJours(jour, 1);
    quand = DateTime(jour.year, jour.month, jour.day, heure ~/ 60, heure % 60);
  }
  return quand;
}

/// Texte du rappel du soir : le point sur la journée, puis ce qui est
/// déjà prévu pour le lendemain.
String texteRappelPlanning(List<Tache> duJour, List<Tache> lendemain) {
  final lignes = <String>[];
  final c = compte(duJour);
  if (duJour.isNotEmpty) {
    lignes.add(
      'Aujourd\'hui : ${c.faits} fait${c.faits > 1 ? 's' : ''} sur '
      '${duJour.length}'
      '${c.sansReponse > 0 ? ', ${c.sansReponse} sans réponse' : ''}.',
    );
  }
  if (lendemain.isEmpty) {
    lignes.add('Rien de prévu demain pour l\'instant.');
  } else {
    final n = lendemain.length;
    lignes.add(
      'Demain : $n chose${n > 1 ? 's' : ''} prévue${n > 1 ? 's' : ''}, '
      'de ${heureFr(lendemain.map((t) => t.debut).reduce(_min))} '
      'à ${heureFr(lendemain.map((t) => t.fin).reduce(_max) % (24 * 60))}.',
    );
  }
  return lignes.join('\n');
}

int _min(int a, int b) => a < b ? a : b;
int _max(int a, int b) => a > b ? a : b;

/// Faits, pas faits, sans réponse.
({int faits, int pasFaits, int sansReponse}) compte(Iterable<Tache> taches) {
  var f = 0, p = 0, s = 0;
  for (final t in taches) {
    switch (t.etat) {
      case Tache.fait:
        f++;
      case Tache.pasFait:
        p++;
      default:
        s++;
    }
  }
  return (faits: f, pasFaits: p, sansReponse: s);
}

/// Part de ce qui est fait parmi ce qui a une réponse (« pas répondu »
/// ne compte pas, comme pour les questions). Nulle sans réponse.
double? partFaite(Iterable<Tache> taches) {
  final c = compte(taches);
  final total = c.faits + c.pasFaits;
  return total == 0 ? null : c.faits / total;
}

/// Les choses prévues rangées par jour (« 2026-10-22 »).
Map<String, List<Tache>> parJour(Iterable<Tache> taches) {
  final jours = <String, List<Tache>>{};
  for (final t in taches) {
    (jours[cleJour(t.jour)] ??= []).add(t);
  }
  return jours;
}

/// Le planning vu comme une question de plus, pour les courbes, les
/// découvertes et le comparateur : chaque jour devient une note de 0 à
/// 1 (la part faite), arrondie au dixième (11 « réponses », 0 = tout
/// fait).
const idPlanning = -1;
final questionPlanning = Question(
  id: idPlanning,
  texte: 'Planning',
  reponses: [for (var i = 0; i <= 10; i++) '${100 - i * 10} %'],
  heure: 0,
);

/// Les jours du planning en « réponses » de `questionPlanning`.
Reponses reponsesPlanning(Iterable<Tache> taches) => {
  for (final MapEntry(:key, :value) in parJour(taches).entries)
    if (partFaite(value) case final p?) key: ((1 - p) * 10).round(),
};

/// Moments de la journée : le matin (avant midi), l'après-midi (avant
/// 18 h), le soir.
const moments = ['Matin', 'Après-midi', 'Soir'];

int moment(Tache t) => t.debut < 12 * 60
    ? 0
    : t.debut < 18 * 60
    ? 1
    : 2;

/// Part faite selon le moment de la journée.
List<double?> partParMoment(Iterable<Tache> taches) => [
  for (var m = 0; m < 3; m++) partFaite(taches.where((t) => moment(t) == m)),
];

/// Part faite selon le jour de la semaine (lundi d'abord).
List<double?> partParJourSemaine(Iterable<Tache> taches) => [
  for (var j = 1; j <= 7; j++)
    partFaite(taches.where((t) => t.jour.weekday == j)),
];

/// Heures prévues au-delà desquelles le nuage « Charge » plafonne.
const heuresMaxCharge = 8;

/// Un point par jour : heures prévues (x, de 0 à `heuresMaxCharge` h
/// ramené entre 0 et 1) et part faite (y).
List<({double x, double y, DateTime lundi})> pointsCharge(
  Iterable<Tache> taches,
) => [
  for (final liste in parJour(taches).values)
    if (partFaite(liste) case final p?)
      (
        x: (liste.fold(0, (s, t) => s + t.duree) / 60 / heuresMaxCharge).clamp(
          0.0,
          1.0,
        ),
        y: p,
        lundi: liste.first.jour,
      ),
];

/// Ce qui est le plus souvent reporté (au moins 2 fois en tout).
List<({String texte, int fois})> plusReportees(
  Iterable<Tache> taches, {
  int nombre = 3,
}) {
  final fois = <String, int>{};
  for (final t in taches) {
    if (t.reports > 0) fois[t.texte] = (fois[t.texte] ?? 0) + t.reports;
  }
  final liste =
      [
        for (final MapEntry(:key, :value) in fois.entries)
          if (value >= 2) (texte: key, fois: value),
      ]..sort(
        (a, b) => b.fois != a.fois
            ? b.fois.compareTo(a.fois)
            : a.texte.compareTo(b.texte),
      );
  return liste.take(nombre).toList();
}

/// Les autres choses du même jour dont l'horaire croise celui de `t`.
List<Tache> chevauchements(Tache t, Iterable<Tache> memeJour) => [
  for (final autre in memeJour)
    if (autre.id != t.id && autre.debut < t.fin && t.debut < autre.fin) autre,
];

/// Ligne du bilan du dimanche : la semaine du planning (lundi →
/// `dimanche`). Nulle sans réponse.
String? ligneBilanPlanning(Iterable<Tache> taches, DateTime dimanche) {
  final lundi = ajouteJours(jourDe(dimanche), -6);
  final semaine = taches.where(
    (t) => !t.jour.isBefore(lundi) && !t.jour.isAfter(jourDe(dimanche)),
  );
  final c = compte(semaine);
  final total = c.faits + c.pasFaits;
  if (total == 0) return null;
  return 'Planning : ${c.faits} fait${c.faits > 1 ? 's' : ''} sur $total';
}
