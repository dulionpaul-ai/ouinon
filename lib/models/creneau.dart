/// Un créneau fixe qui revient chaque semaine (« Enfants 17 h – 23 h »,
/// demande de Paul du 24/10/2026, comme le bloc noir de son tableau
/// blanc) : pas une chose à faire, une contrainte. Il apparaît grisé
/// dans la journée, « Remplir ma journée » le contourne, et il n'envoie
/// aucune notification.
class Creneau {
  final int? id;
  final String texte;

  /// Début et fin, en minutes depuis minuit.
  final int debut;
  final int fin;

  /// Jours où il revient : bit 0 = lundi … bit 6 = dimanche.
  final int jours;

  static const tousLesJours = 0x7F;

  const Creneau({
    this.id,
    required this.texte,
    required this.debut,
    required this.fin,
    this.jours = tousLesJours,
  });

  bool revientLe(int weekday) => jours & (1 << (weekday - 1)) != 0;

  int get duree => fin - debut;

  Creneau copie({String? texte, int? debut, int? fin, int? jours}) => Creneau(
    id: id,
    texte: texte ?? this.texte,
    debut: debut ?? this.debut,
    fin: fin ?? this.fin,
    jours: jours ?? this.jours,
  );

  Map<String, Object?> versLigne() => {
    if (id != null) 'id': id,
    'texte': texte,
    'debut': debut,
    'fin': fin,
    'jours': jours,
  };

  factory Creneau.depuisLigne(Map<String, Object?> l) => Creneau(
    id: l['id'] as int,
    texte: l['texte'] as String,
    debut: l['debut'] as int,
    fin: l['fin'] as int,
    jours: l['jours'] as int,
  );
}
