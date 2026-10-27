import 'recherche.dart';

/// Lecture d'une chose dictée (demande de Paul du 27/10/2026) : « me
/// couper les ongles et ça prendra environ 15 minutes » donne le titre
/// « Me couper les ongles » et la durée 15 min. La durée est cherchée en
/// fin de phrase (chiffres ou mots : « une heure et demie », « un quart
/// d'heure ») ; les mots qui l'annoncent (« et ça prendra environ ») sont
/// retirés du titre. Sans durée reconnue, tout devient le titre.
({String texte, int? duree}) lisDictee(String dictee) {
  final brut = dictee.trim();
  final bas = brut.toLowerCase();
  ({int debut, int minutes})? trouvee;
  void garde(int debut, int minutes) {
    if (minutes <= 0 || minutes > 12 * 60) return;
    if (trouvee == null || debut > trouvee!.debut) {
      trouvee = (debut: debut, minutes: minutes);
    }
  }

  // « 1 h 30 », « 2 heures », « 1 heure et demie », « 1h », « 1 heure 15 ».
  for (final m in RegExp(
    r"(\d+)\s*(?:h\b|heures?\b)(?:\s*(?:et\s*)?(\d+)\s*(?:min(?:utes?)?\b)?|\s*et\s*demie?\b)?",
  ).allMatches(bas)) {
    final h = int.parse(m.group(1)!);
    final reste = m.group(0)!;
    final min = m.group(2) != null
        ? int.parse(m.group(2)!)
        : reste.contains('demi')
        ? 30
        : 0;
    garde(m.start, h * 60 + min);
  }
  // « 15 minutes », « 30 min », « 20 mn ».
  for (final m in RegExp(r"(\d+)\s*(?:minutes?|min|mn)\b").allMatches(bas)) {
    // Pas la fin d'un « 1 h 30 min » déjà lu.
    garde(m.start, int.parse(m.group(1)!));
  }
  // En toutes lettres.
  const nombres = {
    'un': 1,
    'une': 1,
    'deux': 2,
    'trois': 3,
    'quatre': 4,
    'cinq': 5,
    'dix': 10,
    'quinze': 15,
    'vingt': 20,
    'vingt-cinq': 25,
    'trente': 30,
    'quarante': 40,
    'quarante-cinq': 45,
    'cinquante': 50,
  };
  for (final m in RegExp(
    r"\b(une|un|deux|trois|quatre)\s+heures?(\s+et\s+demie?)?",
  ).allMatches(bas)) {
    garde(m.start, nombres[m.group(1)!]! * 60 + (m.group(2) != null ? 30 : 0));
  }
  for (final m in RegExp(
    r"\b(cinq|dix|quinze|vingt-cinq|vingt|trente|quarante-cinq|quarante|cinquante)\s+minutes?",
  ).allMatches(bas)) {
    garde(m.start, nombres[m.group(1)!]!);
  }
  for (final m in RegExp(r"\b(?:une\s+)?demi[\s-]heure").allMatches(bas)) {
    garde(m.start, 30);
  }
  for (final m in RegExp(r"\btrois\s+quarts?\s+d'?\s*heure").allMatches(bas)) {
    garde(m.start, 45);
  }
  for (final m in RegExp(r"\b(?:un\s+)?quart\s+d'?\s*heure").allMatches(bas)) {
    // Pas le « quart d'heure » de « trois quarts d'heure ».
    if (!bas.substring(0, m.start).trimRight().endsWith('trois')) {
      garde(m.start, 15);
    }
  }
  final t = trouvee;
  if (t == null) return (texte: _propre(brut), duree: null);
  // Retire, en fin de titre, les mots qui annoncent la durée (« et ça
  // prendra environ »), sans tenir compte des accents.
  final mots = brut.substring(0, t.debut).split(RegExp(r'\s+'));
  while (mots.isNotEmpty &&
      (_annonce.contains(normalise(mots.last)) ||
          normalise(mots.last).isEmpty)) {
    mots.removeLast();
  }
  final titre = mots.join(' ').replaceFirst(RegExp(r'[\s,;:.-]+$'), '');
  return (texte: _propre(titre.isEmpty ? brut : titre), duree: t.minutes);
}

const _annonce = {
  'et',
  'ca',
  'cela',
  'va',
  'me',
  'prendra',
  'prend',
  'prendre',
  'dure',
  'durera',
  'pendant',
  'environ',
  'a',
  'peu',
  'pres',
  'en',
  'de',
  'pour',
  'duree',
  'gros',
  'il',
  'faut',
  'faudra',
  'compter',
  'sur',
};

/// Majuscule en tête, espaces nets.
String _propre(String s) {
  final t = s.trim().replaceAll(RegExp(r'\s+'), ' ');
  return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
}
