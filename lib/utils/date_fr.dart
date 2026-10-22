const _mois = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

const _jours = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];

/// Initiales des jours, lundi d'abord.
const initialesJours = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

/// « lun. », « mar. »…
const joursCourts = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];

/// « lundi » (1 = lundi … 7 = dimanche).
String nomJour(int weekday) => _jours[weekday - 1];

/// « jeudi 9 octobre », « mercredi 1er avril ».
String jourEtDate(DateTime date) =>
    '${_jours[date.weekday - 1]} ${date.day == 1 ? '1er' : date.day} '
    '${_mois[date.month - 1]}';

/// « octobre 2026 ».
String moisEtAnnee(DateTime date) => '${_mois[date.month - 1]} ${date.year}';

/// « 9 h », « 21 h 30 » (minutes depuis minuit).
String heureFr(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
}

/// « Tous les jours », « En semaine », « Le week-end », « lun., mer., ven. ».
String joursFr(int masque) {
  if (masque == 0x7F) return 'Tous les jours';
  if (masque == 0x1F) return 'En semaine';
  if (masque == 0x60) return 'Le week-end';
  return [
    for (var i = 0; i < 7; i++)
      if (masque & (1 << i) != 0) joursCourts[i],
  ].join(', ');
}

/// Majuscule en tête.
String majuscule(String texte) =>
    texte.isEmpty ? texte : texte[0].toUpperCase() + texte.substring(1);
