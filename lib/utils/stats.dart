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

/// Bilan semaine par semaine (lundi → dimanche), des `nbSemaines`
/// dernières semaines jusqu'à celle de `aujourdhui`, la plus ancienne
/// d'abord.
List<Bilan> evolution(
  Question q,
  Reponses reponses, {
  required DateTime aujourdhui,
  int nbSemaines = 12,
}) {
  final lundi = lundiDe(aujourdhui);
  return [
    for (var s = nbSemaines - 1; s >= 0; s--)
      bilan(
        q,
        reponses,
        debut: ajouteJours(lundi, -7 * s),
        fin: ajouteJours(lundi, -7 * s + 6),
      ),
  ];
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

/// Seuils des croisements (choix de Paul : dès 7 jours communs ; garde-fous
/// de la relecture du plan contre les faux liens).
const minJoursCommuns = 7;
const minJoursParCote = 3;
const ecartMin = 0.20;

/// Un croisement entre deux questions : quand A a sa meilleure réponse,
/// B a-t-il plus (ou moins) souvent la sienne ? `decalage` = 1 : B est
/// regardé le lendemain de A.
class Lien {
  final Question a;
  final Question b;
  final int decalage;

  /// Part de la meilleure réponse de B les jours où A a la sienne…
  final double avec;
  final int joursAvec;

  /// … et les autres jours.
  final double sans;
  final int joursSans;

  const Lien({
    required this.a,
    required this.b,
    required this.decalage,
    required this.avec,
    required this.joursAvec,
    required this.sans,
    required this.joursSans,
  });

  double get ecart => (avec - sans).abs();
  int get jours => joursAvec + joursSans;
}

/// Les croisements nets entre questions, du plus net au moins net. Même
/// jour : un seul sens par paire (le plus net). Lendemain : A un jour, B le
/// jour suivant.
List<Lien> liens(List<Question> questions, Map<int, Reponses> reponses) {
  final trouves = <Lien>[];
  final avecId = [
    for (final q in questions)
      if (q.id != null) q,
  ];
  for (var i = 0; i < avecId.length; i++) {
    for (var j = 0; j < avecId.length; j++) {
      if (i == j) continue;
      final a = avecId[i];
      final b = avecId[j];
      for (final decalage in const [0, 1]) {
        if (decalage == 0 && j < i) continue;
        final candidats = [
          _lien(a, b, decalage, reponses[a.id] ?? {}, reponses[b.id] ?? {}),
          if (decalage == 0)
            _lien(b, a, 0, reponses[b.id] ?? {}, reponses[a.id] ?? {}),
        ].whereType<Lien>().toList();
        if (candidats.isEmpty) continue;
        candidats.sort((x, y) => y.ecart.compareTo(x.ecart));
        trouves.add(candidats.first);
      }
    }
  }
  trouves.sort((x, y) {
    final e = y.ecart.compareTo(x.ecart);
    return e != 0 ? e : y.jours.compareTo(x.jours);
  });
  return trouves;
}

Lien? _lien(Question a, Question b, int decalage, Reponses ra, Reponses rb) {
  var joursAvec = 0, meilleurAvec = 0, joursSans = 0, meilleurSans = 0;
  ra.forEach((cle, choixA) {
    final cleB = decalage == 0
        ? cle
        : cleJour(ajouteJours(jourDepuisCle(cle), decalage));
    final choixB = rb[cleB];
    if (choixB == null) return;
    if (choixA == 0) {
      joursAvec++;
      if (choixB == 0) meilleurAvec++;
    } else {
      joursSans++;
      if (choixB == 0) meilleurSans++;
    }
  });
  if (joursAvec + joursSans < minJoursCommuns) return null;
  if (joursAvec < minJoursParCote || joursSans < minJoursParCote) return null;
  final lien = Lien(
    a: a,
    b: b,
    decalage: decalage,
    avec: meilleurAvec / joursAvec,
    joursAvec: joursAvec,
    sans: meilleurSans / joursSans,
    joursSans: joursSans,
  );
  return lien.ecart >= ecartMin ? lien : null;
}

/// « 7 fois sur 10 ».
String foisSurDix(double part) => '${(part * 10).round()} fois sur 10';

/// La phrase d'un croisement, sans jamais parler de cause.
String phraseLien(Lien l) {
  final a = '« ${l.a.texte} ${l.a.reponses[0]} »';
  final b = '« ${l.b.texte} ${l.b.reponses[0]} »';
  final quand = l.decalage == 0 ? 'Les jours avec $a' : 'Le lendemain de $a';
  final autres = l.decalage == 0 ? 'les autres jours' : 'sinon';
  return '$quand : $b ${foisSurDix(l.avec)}, '
      'contre ${foisSurDix(l.sans)} $autres.';
}
