import '../utils/jour.dart';

/// Une chose prévue dans le planning (demande de Paul du 24/10/2026 :
/// « chaque jour, je planifie ma journée de demain, et les rappels se
/// font en accord avec ça ») : un jour, une heure de début, une durée.
///
/// À l'heure pile, une notification demande « Pas fait · Reporter ·
/// Fait ». Comme pour les questions, « pas répondu » n'est pas une
/// réponse : `etat` reste nul.
class Tache {
  final int? id;
  final DateTime jour;

  /// Début, en minutes depuis minuit (18 h = 1080).
  final int debut;

  /// Durée, en minutes.
  final int duree;
  final String texte;

  /// `fait` (0, la meilleure, comme l'indice 0 des réponses), `pasFait`
  /// (1), ou nul sans réponse.
  final int? etat;

  /// Nombre de fois où elle a été reportée.
  final int reports;

  /// Inventée par « Ajouter 6 mois de test » (effaçable d'un coup).
  final bool test;

  static const fait = 0;
  static const pasFait = 1;
  static const longueurMax = 40;

  /// Durées proposées, en minutes.
  static const durees = [15, 30, 60, 90, 120, 180];

  const Tache({
    this.id,
    required this.jour,
    required this.debut,
    this.duree = 60,
    required this.texte,
    this.etat,
    this.reports = 0,
    this.test = false,
  });

  int get fin => debut + duree;

  /// Moment du rappel : l'heure de début, ce jour-là.
  DateTime get quand =>
      DateTime(jour.year, jour.month, jour.day, debut ~/ 60, debut % 60);

  Tache copie({
    int? id,
    DateTime? jour,
    int? debut,
    int? duree,
    String? texte,
    int? Function()? etat,
    int? reports,
  }) => Tache(
    id: id ?? this.id,
    jour: jour ?? this.jour,
    debut: debut ?? this.debut,
    duree: duree ?? this.duree,
    texte: texte ?? this.texte,
    etat: etat == null ? this.etat : etat(),
    reports: reports ?? this.reports,
    test: test,
  );

  Map<String, Object?> versLigne() => {
    if (id != null) 'id': id,
    'jour': cleJour(jour),
    'debut': debut,
    'duree': duree,
    'texte': texte,
    'etat': etat,
    'reports': reports,
    'test': test ? 1 : 0,
  };

  factory Tache.depuisLigne(Map<String, Object?> l) => Tache(
    id: l['id'] as int,
    jour: jourDepuisCle(l['jour'] as String),
    debut: l['debut'] as int,
    duree: l['duree'] as int,
    texte: l['texte'] as String,
    etat: l['etat'] as int?,
    reports: l['reports'] as int,
    test: (l['test'] as int) == 1,
  );
}
