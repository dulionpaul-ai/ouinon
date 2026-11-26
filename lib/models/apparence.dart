import 'dart:convert';

import 'package:flutter/painting.dart';

/// Tout ce qui se règle sans nouvel APK (accord de Paul du 26/11/2026) :
/// couleurs, textes, tailles, ce qui s'affiche, le style des
/// notifications. Lu dans un fichier public (`reglages.json`, voir
/// `data/apparence_distante.dart`) ; chaque valeur absente ou fausse
/// garde sa valeur par défaut, le thème HUD.
class Apparence {
  final Color fond;
  final Color surface;
  final Color trait;
  final Color texte;
  final Color doux;

  /// La meilleure réponse (bleu glacier), aussi la couleur d'accent.
  final Color meilleure;

  /// La moins bonne réponse (rouge-orange).
  final Color moinsBonne;

  /// La réponse du milieu.
  final Color milieu;

  /// Quadrillage fin en fond d'écran.
  final bool grille;

  /// Notifications : symbole devant la question, question en majuscules,
  /// images dessinées par l'appli (série et 7 derniers jours).
  final String symbole;
  final bool majuscules;
  final bool images;

  /// Tailles : la question dans le formulaire, la phrase, une ligne de la
  /// liste.
  final double tailleQuestion;
  final double taillePhrase;
  final double tailleLigne;

  /// Ce qui s'affiche dans l'appli.
  final bool voirPhrase;
  final bool voirSemaine;
  final bool voirBarres;
  final bool voirApercu;

  /// Les textes des boutons et titres.
  final Map<String, String> textes;

  const Apparence({
    this.fond = const Color(0xFF05070A),
    this.surface = const Color(0xFF0A1016),
    this.trait = const Color(0xFF13202A),
    this.texte = const Color(0xFFE6F1F5),
    this.doux = const Color(0xFF6F808A),
    this.meilleure = const Color(0xFF3EE6FF),
    this.moinsBonne = const Color(0xFFFF5A36),
    this.milieu = const Color(0xFF8FA3AD),
    this.grille = true,
    this.symbole = '▸',
    this.majuscules = true,
    this.images = true,
    this.tailleQuestion = 24,
    this.taillePhrase = 22,
    this.tailleLigne = 17,
    this.voirPhrase = true,
    this.voirSemaine = true,
    this.voirBarres = true,
    this.voirApercu = true,
    this.textes = textesParDefaut,
  });

  static const defaut = Apparence();

  /// L'apparence en cours (lue par `AppTheme`).
  static Apparence actuelle = defaut;

  static const textesParDefaut = {
    'titre': 'OUINON',
    'phrase': 'Je deviens quelqu\'un qui',
    'nouvelle': '+ NOUVELLE HABITUDE',
    'enregistrer': 'ENREGISTRER',
    'retour': '‹ RETOUR',
    'supprimer': 'SUPPR',
    'apercu': 'APERÇU DE LA NOTIFICATION',
    'question': 'QUESTION',
    'pourquoi': 'POURQUOI',
    'reponses': 'RÉPONSES',
    'heure': 'HEURE',
    'jours': 'JOURS',
    'repeter': 'RÉPÉTER',
    'vide': 'Aucune habitude.\nTouche le bouton du bas pour en créer une.',
  };

  /// Un texte réglable (sa valeur par défaut s'il manque).
  String t(String cle) => textes[cle] ?? textesParDefaut[cle] ?? cle;

  /// Lit le fichier de réglages ; nul s'il n'est pas lisible.
  static Apparence? depuisJson(String texte) {
    final Object? brut;
    try {
      brut = jsonDecode(texte);
    } catch (_) {
      return null;
    }
    if (brut is! Map<String, Object?>) return null;
    final racine = brut;
    Map<String, Object?> partie(String cle) {
      final v = racine[cle];
      return v is Map<String, Object?> ? v : const {};
    }

    final c = partie('couleurs');
    final n = partie('notification');
    final ta = partie('tailles');
    final af = partie('afficher');
    final tx = partie('textes');
    Color couleur(String cle, Color defaut) => _couleur(c[cle]) ?? defaut;
    double taille(String cle, double defaut) {
      final v = ta[cle];
      return v is num && v >= 8 && v <= 80 ? v.toDouble() : defaut;
    }

    bool oui(Map<String, Object?> m, String cle, bool defaut) {
      final v = m[cle];
      return v is bool ? v : defaut;
    }

    const d = defaut;
    final symbole = n['symbole'];
    return Apparence(
      fond: couleur('fond', d.fond),
      surface: couleur('surface', d.surface),
      trait: couleur('trait', d.trait),
      texte: couleur('texte', d.texte),
      doux: couleur('doux', d.doux),
      meilleure: couleur('meilleure', d.meilleure),
      moinsBonne: couleur('moinsBonne', d.moinsBonne),
      milieu: couleur('milieu', d.milieu),
      grille: oui(racine, 'grille', d.grille),
      symbole: symbole is String && symbole.length <= 4 ? symbole : d.symbole,
      majuscules: oui(n, 'majuscules', d.majuscules),
      images: oui(n, 'images', d.images),
      tailleQuestion: taille('question', d.tailleQuestion),
      taillePhrase: taille('phrase', d.taillePhrase),
      tailleLigne: taille('ligne', d.tailleLigne),
      voirPhrase: oui(af, 'phrase', d.voirPhrase),
      voirSemaine: oui(af, 'semaine', d.voirSemaine),
      voirBarres: oui(af, 'barres', d.voirBarres),
      voirApercu: oui(af, 'apercu', d.voirApercu),
      textes: {
        ...textesParDefaut,
        for (final e in tx.entries)
          if (e.value is String && (e.value as String).length <= 120)
            e.key: e.value as String,
      },
    );
  }

  /// « #3EE6FF » ou « #FF3EE6FF » ; nul sinon.
  static Color? _couleur(Object? v) {
    if (v is! String) return null;
    final hex = v.startsWith('#') ? v.substring(1) : v;
    if (hex.length != 6 && hex.length != 8) return null;
    final n = int.tryParse(hex, radix: 16);
    if (n == null) return null;
    return Color(hex.length == 6 ? 0xFF000000 | n : n);
  }
}
