/// Une question à suivre : son texte, ses 2 ou 3 réponses, l'heure de sa
/// notification et ses jours.
class Question {
  final int? id;
  final String texte;

  /// 2 ou 3 réponses, la meilleure d'abord (indice 0). Changer leur nombre
  /// passe par `Base.enregistreAvecNombre`, qui convertit l'historique.
  final List<String> reponses;

  /// Heure de la notification, en minutes depuis minuit (21 h = 1260).
  final int heure;

  /// Jours où elle revient : bit 0 = lundi … bit 6 = dimanche. Aucun jour =
  /// en pause : elle ne sonne jamais, son historique est gardé.
  final int jours;

  static const tousLesJours = 0x7F;
  static const longueurMaxReponse = 16;

  const Question({
    this.id,
    required this.texte,
    required this.reponses,
    required this.heure,
    this.jours = 0,
  });

  bool get enPause => jours == 0;

  int get nbReponses => reponses.length;

  /// Revient-elle ce jour-là (1 = lundi … 7 = dimanche) ?
  bool revientLe(int weekday) => jours & (1 << (weekday - 1)) != 0;

  Question copie({
    int? id,
    String? texte,
    List<String>? reponses,
    int? heure,
    int? jours,
  }) => Question(
    id: id ?? this.id,
    texte: texte ?? this.texte,
    reponses: reponses ?? this.reponses,
    heure: heure ?? this.heure,
    jours: jours ?? this.jours,
  );

  Map<String, Object?> versLigne() => {
    if (id != null) 'id': id,
    'texte': texte,
    'reponses': reponses.join('\n'),
    'heure': heure,
    'jours': jours,
  };

  factory Question.depuisLigne(Map<String, Object?> l) => Question(
    id: l['id'] as int,
    texte: l['texte'] as String,
    reponses: (l['reponses'] as String).split('\n'),
    heure: l['heure'] as int,
    jours: l['jours'] as int,
  );
}
