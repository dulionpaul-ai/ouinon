import 'dart:math' as math;

import '../models/question.dart';
import 'jour.dart';
import 'stats.dart';

/// Courbes et découvertes automatiques (demande de Paul du 23/10/2026 :
/// « je veux que l'outil trouve les liens tout seul », avec des courbes à
/// comparer, décalées d'un jour au besoin).
///
/// Chaque réponse devient une note entre 0 (la moins bonne) et 1 (la
/// meilleure) ; une réponse du milieu vaut 0,5.

/// Note d'une réponse : 1 pour la meilleure, 0 pour la moins bonne.
double note(int choix, int nbReponses) =>
    nbReponses <= 1 ? 1 : 1 - choix / (nbReponses - 1);

/// Une note par jour, de `debut` à `fin` compris (nulle sans réponse).
List<double?> notesParJour(
  Question q,
  Reponses reponses,
  DateTime debut,
  DateTime fin,
) {
  final n = ecartJours(debut, fin) + 1;
  return [
    for (var i = 0; i < n; i++)
      switch (reponses[cleJour(ajouteJours(debut, i))]) {
        final int c => note(c, q.nbReponses),
        null => null,
      },
  ];
}

/// Moyenne glissante sur `fenetre` jours (le jour et ceux d'avant) : une
/// suite de oui / non devient une courbe lisible. Nulle sans aucune note
/// dans la fenêtre.
List<double?> moyenneGlissante(List<double?> notes, {int fenetre = 7}) {
  return [
    for (var i = 0; i < notes.length; i++)
      () {
        var somme = 0.0, nb = 0;
        for (var j = math.max(0, i - fenetre + 1); j <= i; j++) {
          final v = notes[j];
          if (v != null) {
            somme += v;
            nb++;
          }
        }
        return nb == 0 ? null : somme / nb;
      }(),
  ];
}

/// Ressemblance de deux suites de notes (corrélation de Pearson, entre −1
/// et 1), B étant regardé `decalage` jours après A. Nulle avec moins de
/// `minJours` jours communs ou si l'une ne varie pas.
({double r, int jours})? ressemblance(
  Reponses ra,
  Question a,
  Reponses rb,
  Question b,
  int decalage, {
  int minJours = minJoursCourbes,
}) {
  final xs = <double>[], ys = <double>[];
  ra.forEach((cle, choixA) {
    final cleB = cleJour(ajouteJours(jourDepuisCle(cle), decalage));
    final choixB = rb[cleB];
    if (choixB == null) return;
    xs.add(note(choixA, a.nbReponses));
    ys.add(note(choixB, b.nbReponses));
  });
  if (xs.length < minJours) return null;
  final r = pearson(xs, ys);
  return r == null ? null : (r: r, jours: xs.length);
}

/// Corrélation de Pearson ; nulle si une suite ne varie pas.
double? pearson(List<double> xs, List<double> ys) {
  final n = xs.length;
  if (n < 2) return null;
  final mx = xs.reduce((a, b) => a + b) / n;
  final my = ys.reduce((a, b) => a + b) / n;
  var sxy = 0.0, sxx = 0.0, syy = 0.0;
  for (var i = 0; i < n; i++) {
    sxy += (xs[i] - mx) * (ys[i] - my);
    sxx += (xs[i] - mx) * (xs[i] - mx);
    syy += (ys[i] - my) * (ys[i] - my);
  }
  if (sxx == 0 || syy == 0) return null;
  return sxy / math.sqrt(sxx * syy);
}

/// Jours communs minimum pour parler de ressemblance.
const minJoursCourbes = 14;

/// Ressemblance minimum (en valeur absolue) pour une découverte.
const seuilDecouverte = 0.3;

/// Décalage maximum essayé, en jours.
const decalageMax = 3;

/// Une découverte : B ressemble à A (ou à son inverse si `r` < 0),
/// `decalage` jours plus tard.
class Decouverte {
  final Question a;
  final Question b;
  final int decalage;
  final double r;
  final int jours;

  const Decouverte(this.a, this.b, this.decalage, this.r, this.jours);

  bool get inverse => r < 0;

  /// « fort » dès 0,5, sinon « net ».
  bool get fort => r.abs() >= 0.5;
}

/// Pour chaque paire de questions, le décalage (de 0 à 3 jours, dans un
/// sens ou dans l'autre) où leurs notes se ressemblent le plus. Toutes les
/// paires mesurables, de la plus forte à la plus faible.
List<Decouverte> toutesLesRessemblances(
  List<Question> questions,
  Map<int, Reponses> reponses,
) {
  final liste = <Decouverte>[];
  final qs = [
    for (final q in questions)
      if (q.id != null) q,
  ];
  for (var i = 0; i < qs.length; i++) {
    for (var j = i + 1; j < qs.length; j++) {
      Decouverte? meilleure;
      // Du plus petit décalage au plus grand : à ressemblance égale, le
      // plus petit l'emporte.
      for (final d in [
        0,
        for (var k = 1; k <= decalageMax; k++) ...[k, -k],
      ]) {
        // Décalage négatif : c'est A qui suit B.
        final a = d >= 0 ? qs[i] : qs[j];
        final b = d >= 0 ? qs[j] : qs[i];
        final res = ressemblance(
          reponses[a.id] ?? const {},
          a,
          reponses[b.id] ?? const {},
          b,
          d.abs(),
        );
        if (res == null) continue;
        if (meilleure == null || res.r.abs() > meilleure.r.abs() + 0.02) {
          meilleure = Decouverte(a, b, d.abs(), res.r, res.jours);
        }
      }
      if (meilleure != null) liste.add(meilleure);
    }
  }
  liste.sort((x, y) => y.r.abs().compareTo(x.r.abs()));
  return liste;
}

/// Les découvertes : les ressemblances assez nettes pour être montrées.
List<Decouverte> decouvertes(
  List<Question> questions,
  Map<int, Reponses> reponses,
) => [
  for (final d in toutesLesRessemblances(questions, reponses))
    if (d.r.abs() >= seuilDecouverte) d,
];

/// Un point par semaine : note moyenne de A (x) et de B (y), pour le
/// nuage de points ; semaines avec au moins 3 réponses de chaque.
List<({double x, double y, DateTime lundi})> pointsParSemaine(
  Question a,
  Reponses ra,
  Question b,
  Reponses rb,
  DateTime debut,
  DateTime fin, {
  int decalage = 0,
}) {
  final points = <({double x, double y, DateTime lundi})>[];
  for (var l = lundiDe(debut); !l.isAfter(fin); l = ajouteJours(l, 7)) {
    final xs = <double>[], ys = <double>[];
    for (var i = 0; i < 7; i++) {
      final j = ajouteJours(l, i);
      final ca = ra[cleJour(j)];
      final cb = rb[cleJour(ajouteJours(j, decalage))];
      if (ca != null) xs.add(note(ca, a.nbReponses));
      if (cb != null) ys.add(note(cb, b.nbReponses));
    }
    if (xs.length >= 3 && ys.length >= 3) {
      points.add((
        x: xs.reduce((p, q) => p + q) / xs.length,
        y: ys.reduce((p, q) => p + q) / ys.length,
        lundi: l,
      ));
    }
  }
  return points;
}

/// Droite des moindres carrés (y = pente × x + origine) ; nulle si les x
/// ne varient pas.
({double pente, double origine})? droite(List<({double x, double y})> pts) {
  if (pts.length < 2) return null;
  final n = pts.length;
  final mx = pts.map((p) => p.x).reduce((a, b) => a + b) / n;
  final my = pts.map((p) => p.y).reduce((a, b) => a + b) / n;
  var sxy = 0.0, sxx = 0.0;
  for (final p in pts) {
    sxy += (p.x - mx) * (p.y - my);
    sxx += (p.x - mx) * (p.x - mx);
  }
  if (sxx == 0) return null;
  final pente = sxy / sxx;
  return (pente: pente, origine: my - pente * mx);
}

/// Texte court d'une découverte : « suit » / « va avec » / « à
/// l'inverse », et le décalage.
String phraseDecouverte(Decouverte d) {
  final quand = switch (d.decalage) {
    0 => 'le même jour',
    1 => 'avec 1 jour de décalage',
    _ => 'avec ${d.decalage} jours de décalage',
  };
  return d.inverse ? 'À l\'inverse, $quand' : 'Même courbe, $quand';
}

/// La découverte en une ligne, pour le bilan du dimanche.
String ligneBilan(Decouverte d) =>
    '${d.a.texte} et ${d.b.texte} : ${phraseDecouverte(d).toLowerCase()} '
    '(${(d.r.abs() * 100).round()} %)';
