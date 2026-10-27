/// Une chose à suivre : son texte, ses 2 ou 3 réponses (rangées de la
/// meilleure à la moins bonne), l'heure de sa notification et ses jours.
class Question {
  final int? id;
  final String texte;

  /// 2 ou 3 libellés, la meilleure réponse d'abord (indice 0). Changer leur
  /// nombre passe par `Base.enregistreAvecNombre`, qui convertit
  /// l'historique.
  final List<String> reponses;

  /// Heure de la notification, en minutes depuis minuit (21 h = 1260).
  final int heure;

  /// Jours où la question revient : bit 0 = lundi … bit 6 = dimanche.
  final int jours;

  /// En pause : plus de notification, historique gardé.
  final bool active;

  /// Place dans la liste.
  final int ordre;

  static const tousLesJours = 0x7F;
  static const longueurMaxReponse = 16;

  const Question({
    this.id,
    required this.texte,
    required this.reponses,
    required this.heure,
    this.jours = tousLesJours,
    this.active = true,
    this.ordre = 0,
  });

  /// La question revient-elle ce jour-là (1 = lundi … 7 = dimanche) ?
  bool revientLe(int weekday) => jours & (1 << (weekday - 1)) != 0;

  int get nbReponses => reponses.length;

  Question copie({
    int? id,
    String? texte,
    List<String>? reponses,
    int? heure,
    int? jours,
    bool? active,
    int? ordre,
  }) => Question(
    id: id ?? this.id,
    texte: texte ?? this.texte,
    reponses: reponses ?? this.reponses,
    heure: heure ?? this.heure,
    jours: jours ?? this.jours,
    active: active ?? this.active,
    ordre: ordre ?? this.ordre,
  );

  Map<String, Object?> versLigne() => {
    if (id != null) 'id': id,
    'texte': texte,
    'reponses': reponses.join('\n'),
    'heure': heure,
    'jours': jours,
    'active': active ? 1 : 0,
    'ordre': ordre,
  };

  factory Question.depuisLigne(Map<String, Object?> l) => Question(
    id: l['id'] as int,
    texte: l['texte'] as String,
    reponses: (l['reponses'] as String).split('\n'),
    heure: l['heure'] as int,
    jours: l['jours'] as int,
    active: (l['active'] as int) == 1,
    ordre: l['ordre'] as int,
  );
}

/// Questions proposées au premier lancement (modifiables).
const questionsDeDepart = [
  Question(
    texte: 'Sommeil ?',
    reponses: ['8 h et +', '6 à 8 h', 'Moins de 6 h'],
    heure: 9 * 60,
    ordre: 0,
  ),
  Question(
    texte: 'En forme ?',
    reponses: ['Bien', 'Moyen', 'Pas bien'],
    heure: 21 * 60,
    ordre: 1,
  ),
  Question(
    texte: 'Sport ?',
    reponses: ['Oui', 'Non'],
    heure: 21 * 60,
    ordre: 2,
  ),
  Question(
    texte: 'Sorti dehors ?',
    reponses: ['Oui', 'Non'],
    heure: 21 * 60,
    ordre: 3,
  ),
];
