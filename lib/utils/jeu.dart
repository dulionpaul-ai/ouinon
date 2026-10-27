import 'dart:math' as math;

import '../models/tache.dart';
import 'jour.dart';
import 'stats.dart';

/// Le jeu « Synchro » (docs/jeu.md, validé par Paul le 27/10/2026),
/// étape 1 : les points et les niveaux.
///
/// Les points ne sont pas stockés : ils se recalculent à partir de
/// l'historique (choses faites, réponses, soirées planifiées). Rien ne
/// peut donc se perdre ni se dérégler, et le passé compte déjà. On ne perd
/// jamais de points.

/// Points d'une chose faite, selon sa durée.
int pointsDuree(int minutes) => minutes <= 15
    ? 10
    : minutes <= 30
    ? 15
    : minutes <= 60
    ? 25
    : 35;

/// Bonus d'une chose venue de la case « D'abord ».
const bonusDabord = 5;

/// Une réponse à une question, quelle qu'elle soit.
const pointsReponse = 3;

/// Une soirée où l'on a validé le plan du lendemain.
const pointsPlan = 15;

/// Points d'une chose faite (sa durée, et « D'abord »).
int pointsChose(Tache t) =>
    pointsDuree(t.duree) + (t.quadrant == 0 ? bonusDabord : 0);

/// Bonus de synchro d'une journée : la part de ce qui était prévu et qui
/// a été fait.
int bonusSynchro(double part) => part >= 1
    ? 50
    : part >= 0.75
    ? 20
    : part >= 0.5
    ? 10
    : 0;

/// Bonus de série : 5 par jour de série, jusqu'à 50.
int bonusSerie(int jours) => math.min(5 * jours, 50);

/// Une ligne du détail des points (« Papiers : +25 »).
typedef GainJeu = ({String texte, int points});

/// Le bilan du jeu à un instant donné.
class BilanJeu {
  final int total;
  final int duJour;

  /// Le détail des points d'aujourd'hui.
  final List<GainJeu> gainsDuJour;

  /// Synchro d'aujourd'hui (part faite de ce qui était prévu), nulle sans
  /// rien de prévu.
  final double? synchroDuJour;

  /// Jours de série en cours.
  final int serie;

  const BilanJeu({
    required this.total,
    required this.duJour,
    required this.gainsDuJour,
    required this.synchroDuJour,
    required this.serie,
  });

  int get niveau => niveauPour(total).niveau;

  /// Points gagnés dans le niveau en cours, et ceux qu'il faut pour le
  /// suivant.
  int get dansNiveau => niveauPour(total).dans;
  int get pourNiveau => niveauPour(total).pour;
  String get stade => stadePour(niveau);
}

/// Points pour passer du niveau [n] au suivant : 100, puis 50 de plus à
/// chaque niveau.
int pointsPourNiveau(int n) => 100 + 50 * (n - 1);

/// Le niveau atteint avec [total] points, et où l'on en est dedans.
({int niveau, int dans, int pour}) niveauPour(int total) {
  var niveau = 1;
  var reste = total;
  while (reste >= pointsPourNiveau(niveau)) {
    reste -= pointsPourNiveau(niveau);
    niveau++;
  }
  return (niveau: niveau, dans: reste, pour: pointsPourNiveau(niveau));
}

/// Les cinq stades de l'histoire.
String stadePour(int niveau) => niveau >= 35
    ? 'Machine parfaite'
    : niveau >= 20
    ? 'Androïde'
    : niveau >= 10
    ? 'Cyborg'
    : niveau >= 5
    ? 'Augmenté'
    : 'Humain';

/// Calcule tout le jeu : [taches] (tout le planning), [reponses] (par
/// question), [plans] (jours, « 2026-10-22 », où le plan du lendemain a
/// été validé).
BilanJeu bilanJeu({
  required List<Tache> taches,
  required Map<int, Reponses> reponses,
  required Set<String> plans,
  required DateTime aujourdhui,
}) {
  final cleAujourdhui = cleJour(jourDe(aujourdhui));
  var total = 0;
  var duJour = 0;
  final gains = <GainJeu>[];
  void gagne(String jour, int points, String texte) {
    if (points <= 0) return;
    total += points;
    if (jour == cleAujourdhui) {
      duJour += points;
      gains.add((texte: texte, points: points));
    }
  }

  // Les choses faites, et la synchro de chaque journée.
  final parJour = <String, List<Tache>>{};
  for (final t in taches) {
    if (t.test) continue;
    parJour.putIfAbsent(cleJour(t.jour), () => []).add(t);
    if (t.etat == Tache.fait) gagne(cleJour(t.jour), pointsChose(t), t.texte);
  }
  double? synchroDuJour;
  for (final MapEntry(key: jour, value: ts) in parJour.entries) {
    final repondues = ts.where((t) => t.etat != null).toList();
    if (ts.isEmpty) continue;
    final part = ts.where((t) => t.etat == Tache.fait).length / ts.length;
    if (jour == cleAujourdhui) synchroDuJour = part;
    // La synchro compte quand toute la journée a une réponse (ou qu'elle
    // est passée).
    if (repondues.length == ts.length || jour.compareTo(cleAujourdhui) < 0) {
      final b = bonusSynchro(part);
      gagne(
        jour,
        b,
        part >= 1 ? 'Synchro parfaite' : 'Synchro ${(part * 100).round()} %',
      );
    }
  }

  // Les réponses aux questions.
  final reponduParJour = <String, int>{};
  for (final r in reponses.values) {
    for (final jour in r.keys) {
      reponduParJour[jour] = (reponduParJour[jour] ?? 0) + 1;
    }
  }
  for (final MapEntry(key: jour, value: n) in reponduParJour.entries) {
    gagne(
      jour,
      n * pointsReponse,
      '$n réponse${n > 1 ? 's' : ''} aux questions',
    );
  }

  // Les soirées planifiées.
  for (final jour in plans) {
    gagne(jour, pointsPlan, 'Plan de vol validé');
  }

  // Les séries : un jour compte s'il a au moins une réponse et une chose
  // faite.
  bool actif(String jour) =>
      (reponduParJour[jour] ?? 0) > 0 &&
      (parJour[jour]?.any((t) => t.etat == Tache.fait) ?? false);
  final jours = {...reponduParJour.keys, ...parJour.keys}.toList()..sort();
  var serie = 0;
  DateTime? precedent;
  for (final jour in jours) {
    if (jour.compareTo(cleAujourdhui) > 0) break;
    final d = jourDepuisCle(jour);
    if (!actif(jour)) {
      if (jour != cleAujourdhui) serie = 0;
      precedent = d;
      continue;
    }
    final suit = precedent != null && ecartJours(precedent, d) == 1;
    serie = suit ? serie + 1 : 1;
    precedent = d;
    if (serie >= 2) gagne(jour, bonusSerie(serie), 'Série : $serie jours');
  }
  // La série en cours : interrompue si hier n'était pas actif.
  final hier = cleJour(ajouteJours(jourDe(aujourdhui), -1));
  final enCours = actif(cleAujourdhui) || actif(hier) ? serie : 0;

  gains.sort((a, b) => b.points.compareTo(a.points));
  return BilanJeu(
    total: total,
    duJour: duJour,
    gainsDuJour: gains,
    synchroDuJour: synchroDuJour,
    serie: enCours,
  );
}
