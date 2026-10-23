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

  /// Jours de réponses communes qui manquent encore pour juger.
  int get joursManquants => [
    minJoursCommuns - jours,
    minJoursParCote - joursAvec,
    minJoursParCote - joursSans,
    0,
  ].reduce((a, b) => a > b ? a : b);

  bool get assezDeJours => joursManquants == 0;

  /// Assez de jours et un écart net : un lien qu'on peut montrer.
  bool get net => assezDeJours && ecart >= ecartMin;
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
  final lien = relation(a, b, decalage, ra, rb);
  return lien.net ? lien : null;
}

/// Le lien de A vers B, sans seuil : quand A a sa meilleure réponse, part
/// de la meilleure réponse de B (le même jour, ou le lendemain avec
/// `decalage` = 1), contre les autres jours.
Lien relation(Question a, Question b, int decalage, Reponses ra, Reponses rb) {
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
  return Lien(
    a: a,
    b: b,
    decalage: decalage,
    avec: joursAvec == 0 ? 0 : meilleurAvec / joursAvec,
    joursAvec: joursAvec,
    sans: joursSans == 0 ? 0 : meilleurSans / joursSans,
    joursSans: joursSans,
  );
}

/// Ce qui va avec la question principale `p` : chaque autre question, le
/// même jour ou la veille (le plus net des deux), du lien le plus net au
/// moins net ; puis celles sans lien net ; puis celles qui manquent de
/// jours (les plus avancées d'abord).
List<Lien> classement(
  Question p,
  List<Question> questions,
  Map<int, Reponses> reponses,
) {
  final rp = reponses[p.id] ?? const {};
  final liste = <Lien>[];
  for (final q in questions) {
    if (q.id == null || q.id == p.id) continue;
    final rq = reponses[q.id] ?? const {};
    final memeJour = relation(q, p, 0, rq, rp);
    final veille = relation(q, p, 1, rq, rp);
    final prendVeille =
        veille.net && (!memeJour.net || veille.ecart > memeJour.ecart);
    liste.add(prendVeille ? veille : memeJour);
  }
  int rang(Lien l) => l.net ? 0 : (l.assezDeJours ? 1 : 2);
  liste.sort((x, y) {
    final r = rang(x).compareTo(rang(y));
    if (r != 0) return r;
    if (rang(x) == 2) return x.joursManquants.compareTo(y.joursManquants);
    return y.ecart.compareTo(x.ecart);
  });
  return liste;
}

/// Une série : jours d'affilée avec la meilleure réponse.
class Serie {
  final int actuelle;
  final int record;

  const Serie(this.actuelle, this.record);
}

/// Série en cours et record d'une question. Seuls comptent les jours où
/// la question revient ; aujourd'hui sans réponse ne casse pas la série
/// (la journée n'est pas finie).
Serie serie(Question q, Reponses reponses, DateTime aujourdhui) {
  if (reponses.isEmpty) return const Serie(0, 0);
  final premier = reponses.keys.reduce((a, b) => a.compareTo(b) < 0 ? a : b);
  final debut = jourDepuisCle(premier);
  final auj = jourDe(aujourdhui);
  var enCours = 0, record = 0;
  for (var j = debut; !j.isAfter(auj); j = ajouteJours(j, 1)) {
    if (!q.revientLe(j.weekday)) continue;
    final choix = reponses[cleJour(j)];
    if (choix == 0) {
      enCours++;
      if (enCours > record) record = enCours;
    } else if (!(choix == null && j == auj)) {
      enCours = 0;
    }
  }
  return Serie(enCours, record);
}

/// Les lignes du bilan de la semaine (du lundi au dimanche `dimanche`),
/// pour la notification du dimanche soir ; nul sans aucune réponse.
List<String>? bilanSemaine(
  List<Question> questions,
  Map<int, Reponses> reponses,
  DateTime dimanche, {
  Question? principale,
}) {
  final fin = jourDe(dimanche);
  final lundi = lundiDe(fin);
  final lignes = <String>[];
  Question? meilleureSerie;
  var longueur = 0;
  for (final q in questions) {
    if (!q.active || q.id == null) continue;
    final r = reponses[q.id] ?? const {};
    final b = bilan(q, r, debut: lundi, fin: fin);
    if (b.total == 0) continue;
    lignes.add(
      '${q.texte} ${q.reponses[0]} : ${b.comptes[0]} '
      'jour${b.comptes[0] > 1 ? 's' : ''} sur ${b.total}',
    );
    final s = serie(q, r, fin).actuelle;
    if (s > longueur) {
      longueur = s;
      meilleureSerie = q;
    }
  }
  if (lignes.isEmpty) return null;
  if (meilleureSerie != null && longueur >= 3) {
    lignes.add(
      'Série : ${meilleureSerie.texte} ${meilleureSerie.reponses[0]}, '
      '$longueur jours d\'affilée',
    );
  }
  if (principale != null) {
    final nets = classement(
      principale,
      questions,
      reponses,
    ).where((l) => l.net);
    if (nets.isNotEmpty) {
      final l = nets.first;
      lignes.add(
        '${l.a.texte} ${l.a.reponses[0]} va avec '
        '${l.b.texte} ${l.b.reponses[0]} : '
        '${(l.avec * 100).round()} % contre ${(l.sans * 100).round()} %',
      );
    }
  }
  return lignes;
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

/// Croisement libre de deux questions : pour chaque réponse de A, combien
/// de fois chaque réponse de B (le même jour, ou le lendemain avec
/// `decalage` = 1). Une ligne par réponse de A (la meilleure d'abord),
/// des bilans de B.
List<Bilan> croisement(
  Question a,
  Question b,
  int decalage,
  Reponses ra,
  Reponses rb,
) {
  final comptes = List.generate(
    a.nbReponses,
    (_) => List.filled(b.nbReponses, 0),
  );
  ra.forEach((cle, choixA) {
    if (choixA < 0 || choixA >= a.nbReponses) return;
    final cleB = decalage == 0
        ? cle
        : cleJour(ajouteJours(jourDepuisCle(cle), decalage));
    final choixB = rb[cleB];
    if (choixB == null || choixB < 0 || choixB >= b.nbReponses) return;
    comptes[choixA][choixB]++;
  });
  return [for (final c in comptes) Bilan(c)];
}
