import '../utils/jour.dart';

/// Une question à suivre : son texte, son « pourquoi », ses 2 ou 3
/// réponses, l'heure de sa notification, et quand elle revient, d'une
/// seule des deux façons (Paul, 27/11/2026) : certains jours fixes
/// (« Hyrox ? » le lundi), ou tous les N jours pour une tâche (arroser
/// les plantes), qui se recale sur le jour où elle a été faite.
class Question {
  final int? id;
  final String texte;

  /// Pourquoi je le fais, écrit par Paul : affiché sous la question dans la
  /// notification (vide : rien).
  final String pourquoi;

  /// 2 ou 3 réponses, la meilleure d'abord (indice 0). Changer leur nombre
  /// passe par `Base.enregistreAvecNombre`, qui convertit l'historique.
  final List<String> reponses;

  /// Heure de la notification, en minutes depuis minuit (21 h = 1260).
  final int heure;

  /// Certains jours : bit 0 = lundi … bit 6 = dimanche. Aucun jour = en
  /// pause : elle ne sonne jamais, son historique est gardé. Une tâche a
  /// tous les jours (ou aucun, en pause).
  final int jours;

  /// 0 : certains jours fixes. N (2 ou plus) : une tâche tous les N
  /// jours ; elle revient N jours après la dernière meilleure réponse
  /// (« Fait »), donnée n'importe quel jour, puis chaque jour tant qu'elle
  /// n'est pas faite (`utils/frequence.dart`).
  final int intervalle;

  /// Pour une tâche : « Prochaine fois », choisi dans le formulaire. Les
  /// réponses d'avant ce jour ne comptent plus pour la suite.
  final DateTime? depart;

  static const tousLesJours = 0x7F;
  static const longueurMaxPourquoi = 80;
  static const longueurMaxReponse = 16;

  const Question({
    this.id,
    required this.texte,
    this.pourquoi = '',
    required this.reponses,
    required this.heure,
    this.jours = 0,
    this.intervalle = 0,
    this.depart,
  });

  /// Tous les N jours (sinon : certains jours fixes).
  bool get tache => intervalle >= 2;

  bool get enPause => jours == 0;

  int get nbReponses => reponses.length;

  /// Revient-elle ce jour-là (1 = lundi … 7 = dimanche) ?
  bool revientLe(int weekday) => jours & (1 << (weekday - 1)) != 0;

  Question copie({
    int? id,
    String? texte,
    String? pourquoi,
    List<String>? reponses,
    int? heure,
    int? jours,
    int? intervalle,
    DateTime? Function()? depart,
  }) => Question(
    id: id ?? this.id,
    texte: texte ?? this.texte,
    pourquoi: pourquoi ?? this.pourquoi,
    reponses: reponses ?? this.reponses,
    heure: heure ?? this.heure,
    jours: jours ?? this.jours,
    intervalle: intervalle ?? this.intervalle,
    depart: depart == null ? this.depart : depart(),
  );

  Map<String, Object?> versLigne() => {
    if (id != null) 'id': id,
    'texte': texte,
    'pourquoi': pourquoi,
    'reponses': reponses.join('\n'),
    'heure': heure,
    'jours': jours,
    'intervalle': intervalle,
    'depart': depart == null ? null : cleJour(depart!),
  };

  factory Question.depuisLigne(Map<String, Object?> l) => Question(
    id: l['id'] as int,
    texte: l['texte'] as String,
    pourquoi: l['pourquoi'] as String? ?? '',
    reponses: (l['reponses'] as String).split('\n'),
    heure: l['heure'] as int,
    jours: l['jours'] as int,
    intervalle: l['intervalle'] as int? ?? 0,
    depart: switch (l['depart']) {
      final String d => jourDepuisCle(d),
      _ => null,
    },
  );
}
