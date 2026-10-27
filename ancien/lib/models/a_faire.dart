import '../utils/jour.dart';

/// Une chose de la liste « À faire » (demande de Paul du 24/10/2026) :
/// ce qu'il y a à faire, le temps que ça prend, rangé dans une des 4
/// cases d'Eisenhower : la matrice, que Paul appelle « en fond » (comme la
/// colonne de son tableau blanc). Chaque soir, il y pioche ce qu'il fera
/// le lendemain (`choisiePour`) : ces choses attendent dans le bac « À
/// placer », puis il les glisse dans les heures de la journée ; placée,
/// elle devient une chose prévue (`Tache.listeId`). Pas faite, elle
/// revient d'elle-même en fond.
class AFaire {
  final int? id;
  final String texte;

  /// Durée, en minutes.
  final int duree;
  final bool important;

  /// Coché à la main ; une date limite proche rend aussi urgent
  /// (`urgentLe`).
  final bool urgent;

  /// Date limite (facultative).
  final DateTime? echeance;
  final DateTime creeLe;

  /// Faite le (nulle tant qu'elle est à faire).
  final DateTime? faiteLe;

  /// Choisie pour ce jour-là (dans le bac « À placer » de ce jour).
  final DateTime? choisiePour;

  /// Heure imposée (minutes depuis minuit), facultative : posée dans la
  /// journée, elle va à cette heure-là (formulaire du 26/10/2026).
  final int? heure;

  /// Inventée par « Ajouter 6 mois de test » (effaçable d'un coup).
  final bool test;

  /// À moins de 2 jours de sa date limite, une chose devient urgente.
  static const joursUrgence = 2;

  const AFaire({
    this.id,
    required this.texte,
    this.duree = 30,
    this.important = false,
    this.urgent = false,
    this.echeance,
    required this.creeLe,
    this.faiteLe,
    this.choisiePour,
    this.heure,
    this.test = false,
  });

  bool get faite => faiteLe != null;

  /// Urgente ce jour-là : cochée, ou date limite dans moins de
  /// `joursUrgence` jours (ou dépassée).
  bool urgentLe(DateTime jour) =>
      urgent ||
      (echeance != null && ecartJours(jourDe(jour), echeance!) <= joursUrgence);

  /// La case d'Eisenhower ce jour-là.
  Case caseLe(DateTime jour) => Case.de(important, urgentLe(jour));

  AFaire copie({
    int? id,
    String? texte,
    int? duree,
    bool? important,
    bool? urgent,
    DateTime? Function()? echeance,
    DateTime? Function()? faiteLe,
    DateTime? Function()? choisiePour,
    int? Function()? heure,
  }) => AFaire(
    id: id ?? this.id,
    texte: texte ?? this.texte,
    duree: duree ?? this.duree,
    important: important ?? this.important,
    urgent: urgent ?? this.urgent,
    echeance: echeance == null ? this.echeance : echeance(),
    creeLe: creeLe,
    faiteLe: faiteLe == null ? this.faiteLe : faiteLe(),
    choisiePour: choisiePour == null ? this.choisiePour : choisiePour(),
    heure: heure == null ? this.heure : heure(),
    test: test,
  );

  Map<String, Object?> versLigne() => {
    if (id != null) 'id': id,
    'texte': texte,
    'duree': duree,
    'important': important ? 1 : 0,
    'urgent': urgent ? 1 : 0,
    'echeance': echeance == null ? null : cleJour(echeance!),
    'cree_le': cleJour(creeLe),
    'faite_le': faiteLe == null ? null : cleJour(faiteLe!),
    'choisie_pour': choisiePour == null ? null : cleJour(choisiePour!),
    'heure': heure,
    'test': test ? 1 : 0,
  };

  factory AFaire.depuisLigne(Map<String, Object?> l) => AFaire(
    id: l['id'] as int,
    texte: l['texte'] as String,
    duree: l['duree'] as int,
    important: (l['important'] as int) == 1,
    urgent: (l['urgent'] as int) == 1,
    echeance: switch (l['echeance']) {
      final String c => jourDepuisCle(c),
      _ => null,
    },
    creeLe: jourDepuisCle(l['cree_le'] as String),
    faiteLe: switch (l['faite_le']) {
      final String c => jourDepuisCle(c),
      _ => null,
    },
    choisiePour: switch (l['choisie_pour']) {
      final String c => jourDepuisCle(c),
      _ => null,
    },
    heure: l['heure'] as int?,
    test: (l['test'] as int) == 1,
  );
}

/// Les 4 cases d'Eisenhower, avec des noms parlants pour la vie perso
/// (« déléguer » est rarement possible). Dans l'ordre où on les place.
enum Case {
  dabord('D\'abord', 'Urgent et important'),
  aPlanifier('À planifier', 'Important, pas urgent'),
  viteFait('Vite fait', 'Urgent, pas important'),
  peutEtreJamais('Peut-être jamais', 'Ni urgent ni important');

  final String nom;
  final String detail;

  const Case(this.nom, this.detail);

  static Case de(bool important, bool urgent) => important
      ? (urgent ? dabord : aPlanifier)
      : (urgent ? viteFait : peutEtreJamais);
}
