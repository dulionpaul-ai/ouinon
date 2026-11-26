/// Une question à suivre : son texte, son « pourquoi », ses 2 ou 3
/// réponses, l'heure de sa notification, ses jours et, pour les tâches
/// (arroser les plantes, changer les draps), un intervalle en jours.
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

  /// Jours où elle revient : bit 0 = lundi … bit 6 = dimanche. Aucun jour =
  /// en pause : elle ne sonne jamais, son historique est gardé.
  final int jours;

  /// 0 : posée chaque jour coché. N (2 ou plus) : une tâche à refaire tous
  /// les N jours ; elle revient N jours après la dernière meilleure
  /// réponse (« Fait »), puis chaque jour coché tant qu'elle n'est pas
  /// faite (`utils/frequence.dart`).
  final int intervalle;

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
  });

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
  }) => Question(
    id: id ?? this.id,
    texte: texte ?? this.texte,
    pourquoi: pourquoi ?? this.pourquoi,
    reponses: reponses ?? this.reponses,
    heure: heure ?? this.heure,
    jours: jours ?? this.jours,
    intervalle: intervalle ?? this.intervalle,
  );

  Map<String, Object?> versLigne() => {
    if (id != null) 'id': id,
    'texte': texte,
    'pourquoi': pourquoi,
    'reponses': reponses.join('\n'),
    'heure': heure,
    'jours': jours,
    'intervalle': intervalle,
  };

  factory Question.depuisLigne(Map<String, Object?> l) => Question(
    id: l['id'] as int,
    texte: l['texte'] as String,
    pourquoi: l['pourquoi'] as String? ?? '',
    reponses: (l['reponses'] as String).split('\n'),
    heure: l['heure'] as int,
    jours: l['jours'] as int,
    intervalle: l['intervalle'] as int? ?? 0,
  );
}
