import '../models/a_faire.dart';

/// Recherche de doublons dans la to-do (demande de Paul du 27/10/2026) :
/// en tapant une nouvelle chose, on voit ce qui existe déjà avec les mêmes
/// mots. Sans majuscules ni accents ; les petits mots (« le », « de »…)
/// ne comptent pas ; un mot tapé à moitié suffit (« ongl » trouve
/// « ongles »).

const _petitsMots = {
  'le',
  'la',
  'les',
  'l',
  'un',
  'une',
  'des',
  'de',
  'du',
  'd',
  'et',
  'ou',
  'a',
  'au',
  'aux',
  'en',
  'pour',
  'par',
  'sur',
  'avec',
  'mon',
  'ma',
  'mes',
  'ton',
  'ta',
  'tes',
  'son',
  'sa',
  'ses',
  'me',
  'te',
  'se',
  'm',
  't',
  's',
  'faire',
  'chez',
  'dans',
};

const _accents = {
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'á': 'a',
  'ç': 'c',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'î': 'i',
  'ï': 'i',
  'í': 'i',
  'ô': 'o',
  'ö': 'o',
  'ó': 'o',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ú': 'u',
  'ÿ': 'y',
  'œ': 'oe',
  'æ': 'ae',
};

/// « Rappeler l'Électricien » → « rappeler l electricien ».
String normalise(String texte) {
  final b = StringBuffer();
  for (final c in texte.toLowerCase().split('')) {
    b.write(_accents[c] ?? c);
  }
  return b.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

/// Les mots qui comptent : deux lettres au moins, hors petits mots.
List<String> motsCles(String texte) => [
  for (final m in normalise(texte).split(' '))
    if (m.length >= 2 && !_petitsMots.contains(m)) m,
];

/// Les choses de [liste] qui ressemblent à [saisie] (au moins un mot en
/// commun, ou commencé), les plus proches d'abord. [sauf] : la chose qu'on
/// est en train de modifier.
List<AFaire> ressemblantes(String saisie, List<AFaire> liste, {int? sauf}) {
  final cherches = motsCles(saisie);
  if (cherches.isEmpty) return const [];
  final scores = <(AFaire, int)>[];
  for (final a in liste) {
    if (a.id != null && a.id == sauf) continue;
    final mots = motsCles(a.texte);
    var score = 0;
    for (final c in cherches) {
      if (mots.any(
        (m) =>
            m == c ||
            (c.length >= 3 &&
                (m.startsWith(c) || c.startsWith(m) && m.length >= 4)),
      )) {
        score++;
      }
    }
    if (score > 0) scores.add((a, score));
  }
  scores.sort((x, y) => y.$2.compareTo(x.$2));
  return [for (final (a, _) in scores) a];
}
