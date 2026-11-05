import 'package:shared_preferences/shared_preferences.dart';

import '../models/question.dart';
import '../utils/date_fr.dart';
import '../utils/jour.dart';
import '../utils/planning.dart';
import '../utils/stats.dart';
import 'base.dart';
import 'preferences.dart';

/// Le coaching de vie de Paul avec Claude (démarré le 5/11/2026,
/// `docs/coaching/carnet.md`). Étape 1 : Ouinon ne garde que les
/// questions ; le coach crée les suivis, et un bilan se copie pour être
/// collé dans la conversation.

/// Texte de la question du coucher : la cible avance chaque semaine.
const texteCoucher = 'Couché à l\'heure ?';

/// Lundi où la cible du coucher est 0 h 30 ; elle avance ensuite de
/// 30 minutes chaque lundi, jusqu'à 23 h (règle du coaching).
final _premierLundi = DateTime(2026, 11, 2);

/// L'heure cible du coucher le soir de [jour], en minutes depuis minuit
/// la veille (0 h 30 = 24 h 30 = 1470).
int cibleCoucher(DateTime jour) {
  final lundi = ajouteJours(jourDe(jour), -(jour.weekday - 1));
  final semaines = (ecartJours(_premierLundi, lundi) ~/ 7).clamp(0, 3);
  return 24 * 60 + 30 - 30 * semaines;
}

/// « 0 h 30 », « 23 h 30 ».
String cibleFr(DateTime jour) => heureFr(cibleCoucher(jour) % (24 * 60));

/// Le texte d'une notification de question : pour le coucher (posée le
/// matin, sur la nuit passée), la cible de la veille au soir.
String? detailNotification(Question q, DateTime jour) => q.texte == texteCoucher
    ? 'Cible : ${cibleFr(ajouteJours(jour, -1))}'
    : null;

const _semaine = 0x1F;
const _matin = 7 * 60 + 45;

/// Les suivis du coaching, créés par le coach (étape 1). Oui/Non : la
/// meilleure réponse d'abord. Jamais redemandés le lendemain : une
/// séance ou une nuit ratée ne se rattrape pas.
const questionsCoaching = [
  Question(
    texte: 'Écrans coupés à minuit ?',
    reponses: ['Oui', 'Non'],
    heure: _matin,
    famille: 'Sommeil',
    redemande: false,
    ordre: 0,
  ),
  Question(
    texte: texteCoucher,
    reponses: ['Oui', 'Non'],
    heure: _matin,
    famille: 'Sommeil',
    redemande: false,
    ordre: 1,
  ),
  Question(
    texte: 'Levé avant 7 h 30 ?',
    reponses: ['Oui', 'Non'],
    heure: _matin,
    famille: 'Sommeil',
    redemande: false,
    ordre: 2,
  ),
  Question(
    texte: 'Assez dormi ?',
    reponses: ['Oui', 'Bof', 'Non'],
    heure: _matin,
    famille: 'Sommeil',
    redemande: false,
    ordre: 3,
  ),
  Question(
    texte: 'Hyrox ?',
    reponses: ['Fait', 'Pas fait'],
    heure: 12 * 60,
    jours: 0x01,
    famille: 'Sport',
    redemande: false,
    ordre: 4,
  ),
  Question(
    texte: 'Ultimate ?',
    reponses: ['Fait', 'Pas fait'],
    heure: 23 * 60,
    jours: 0x0A,
    famille: 'Sport',
    redemande: false,
    ordre: 5,
  ),
  Question(
    texte: 'Bodycombat ?',
    reponses: ['Fait', 'Pas fait'],
    heure: 14 * 60,
    jours: 0x10,
    famille: 'Sport',
    redemande: false,
    ordre: 6,
  ),
  Question(
    texte: 'Cuisine maison ?',
    reponses: ['Fait', 'Pas fait'],
    heure: 18 * 60,
    jours: 0x04,
    redemande: false,
    ordre: 7,
  ),
  Question(
    texte: 'Bloc recherche d\'emploi ?',
    reponses: ['Fait', 'Pas fait'],
    heure: 16 * 60 + 30,
    jours: _semaine,
    redemande: false,
    ordre: 8,
  ),
];

const _cleInstalle = 'coaching_v1';

/// Une seule fois : les anciennes questions passent en pause (leur
/// historique est gardé), les suivis du coaching sont créés, le rappel
/// du soir pour la to-do est coupé.
Future<void> installeCoaching(Base base) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_cleInstalle) ?? false) return;
  final anciennes = await base.questions();
  for (final q in anciennes) {
    if (q.active) await base.enregistre(q.copie(active: false));
  }
  for (final q in questionsCoaching) {
    await base.enregistre(q);
  }
  await Preferences.activeRappelPlanning(false);
  await prefs.setBool(_cleInstalle, true);
}

/// Le bilan des 7 derniers jours, à coller dans la conversation avec le
/// coach : pour chaque suivi, la réponse jour par jour.
String bilanCoaching(
  List<Question> questions,
  Map<int, Reponses> reponses,
  DateTime aujourdhui,
) {
  final fin = jourDe(aujourdhui);
  final debut = ajouteJours(fin, -6);
  final lignes = <String>[
    'Bilan Ouinon du ${dateCourte(debut).toLowerCase()} au '
        '${dateCourte(fin).toLowerCase()}',
    'Cible du coucher cette semaine : ${cibleFr(fin)}',
    '',
  ];
  for (final q in questions) {
    if (!q.active || q.jours == 0) continue;
    final r = reponses[q.id] ?? const {};
    final jours = <String>[];
    var oui = 0, total = 0;
    for (var n = 0; n < 7; n++) {
      final j = ajouteJours(debut, n);
      if (!q.revientLe(j.weekday)) continue;
      final c = r[cleJour(j)];
      total++;
      if (c == 0) oui++;
      jours.add(
        '${joursCourts[j.weekday - 1]} '
        '${c == null ? '–' : q.reponses[c]}',
      );
    }
    if (total == 0) continue;
    lignes.add('${q.texte} $oui/$total · ${jours.join(', ')}');
  }
  return lignes.join('\n');
}

/// Tout, d'un coup, pour le coach (5/11/2026) : chaque question (même en
/// pause) avec toutes ses réponses depuis le début, la to-do et le
/// planning. Les données de test sont laissées de côté.
Future<String> exportComplet(Base base, DateTime maintenant) async {
  final questions = await base.questions();
  final reponses = await base.toutesLesReponses();
  final liste = await base.liste(avecFaites: true);
  final taches = await base.taches();
  String d(DateTime j) => '${j.day}/${j.month}/${j.year % 100}';
  final lignes = <String>['EXPORT OUINON du ${d(maintenant)}', '', 'QUESTIONS'];
  for (final q in questions) {
    final r = reponses[q.id] ?? const {};
    final jours = r.keys.toList()..sort();
    lignes.add(
      '- ${q.texte} [${q.reponses.join(' / ')}] '
      '${heureFr(q.heure)} · ${q.jours == 0 ? 'aucun jour' : joursFr(q.jours)}'
      '${q.active ? '' : ' · en pause'} · ${jours.length} réponses',
    );
    if (jours.isNotEmpty) {
      lignes.add(
        '  ${[for (final j in jours) '${d(jourDepuisCle(j))} ${q.reponses[r[j]!]}'].join(', ')}',
      );
    }
  }
  lignes
    ..add('')
    ..add('TO-DO');
  for (final a in liste) {
    if (a.test) continue;
    lignes.add(
      '- ${a.texte} · ${dureeFr(a.duree)}'
      ' · ${a.caseLe(maintenant).nom} · créée le ${d(a.creeLe)}'
      '${a.faiteLe != null ? ' · faite le ${d(a.faiteLe!)}' : ''}'
      '${a.choisiePour != null ? ' · choisie pour le ${d(a.choisiePour!)}' : ''}',
    );
  }
  lignes
    ..add('')
    ..add('PLANNING');
  for (final t in taches) {
    if (t.test) continue;
    lignes.add(
      '- ${d(t.jour)} ${heureFr(t.debut)} ${t.texte} (${t.duree} min) : '
      '${switch (t.etat) {
        0 => 'fait',
        1 => 'pas fait',
        _ => 'sans réponse',
      }}',
    );
  }
  return lignes.join('\n');
}

/// Un créneau du programme envoyé par le coach.
typedef Creneau2 = ({int debut, int fin, String texte});

/// Lit le programme collé depuis la conversation (5/11/2026) : une ligne
/// par créneau, « 9 h 45 – 10 h 45 Rangement », « 13:15-13:40 Sieste »,
/// ou une ligne de tableau « | 15 h – 16 h | Entretien |». Les lignes
/// sans plage horaire sont ignorées.
List<Creneau2> lisProgramme(String texte) {
  final plage = RegExp(
    r'(\d{1,2})\s*(?:h|:)\s*(\d{2})?\s*[–—-]\s*(\d{1,2})\s*(?:h|:)\s*(\d{2})?\s*(.*)',
  );
  final creneaux = <Creneau2>[];
  for (final brute in texte.split('\n')) {
    final ligne = brute.replaceAll('|', ' ').replaceAll('*', ' ').trim();
    final m = plage.firstMatch(ligne);
    if (m == null) continue;
    final h1 = int.parse(m.group(1)!), h2 = int.parse(m.group(3)!);
    final debut = h1 * 60 + int.parse(m.group(2) ?? '0');
    var fin = h2 * 60 + int.parse(m.group(4) ?? '0');
    if (h1 > 23 || h2 > 24 || debut >= 24 * 60) continue;
    // « 23 h 30 – 0 h 30 » : jusqu'à minuit.
    if (fin <= debut) fin = 24 * 60;
    final nom = m
        .group(5)!
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceFirst(RegExp(r'^[\s:·,.-]+'), '')
        .trim();
    if (nom.isEmpty) continue;
    creneaux.add((debut: debut, fin: fin, texte: nom));
  }
  return creneaux;
}
