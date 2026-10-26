import 'package:flutter/material.dart';

/// Style « Nuit ronde » (propositions D et F, 22/10/2026), toujours sombre
/// (choix de Paul) : tout est rond, cartes sombres, réponses en pilules
/// colorées (citron, abricot, corail), titres en Unbounded, texte en
/// Figtree. Polices embarquées, licence OFL (`assets/fonts/OFL-*.txt`).
class AppTheme {
  static const policeTitre = 'Unbounded';

  /// Couleur de la seconde courbe quand on en compare deux (lilas, bien
  /// distinct du citron et du corail).
  static const courbeB = Color(0xFFA594FF);
  static const policeTexte = 'Figtree';

  /// Écran rétro du toi qui exécute (vieux terminal, 26/10/2026) : VT323
  /// pour les titres, IBM Plex Mono pour le texte (licence OFL).
  static const policeRetro = 'VT323';
  static const policeMono = 'IBMPlexMono';

  /// Couleurs des deux toi : ambre le soir, bleu-vert le jour.
  static const ambre = Color(0xFFF2A541);
  static const bleuVert = Color(0xFF5FE0C9);

  static ThemeData sombre() => _theme(Teintes.sombre, Brightness.dark);

  /// Le soir, celui qui décide : accent ambre.
  static ThemeData soir() => _theme(Teintes.soir, Brightness.dark);

  /// Le jour, celui qui exécute : vieux terminal bleu-vert sur noir.
  static ThemeData retro() => _theme(
    Teintes.retro,
    Brightness.dark,
    texte: policeMono,
    titre: policeRetro,
    tailleTitre: 1.4,
  );

  static ThemeData _theme(
    Teintes t,
    Brightness luminosite, {
    String texte = policeTexte,
    String titre = policeTitre,
    double tailleTitre = 1,
  }) {
    final policeTexte = texte;
    final policeTitre = titre;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: t.accent,
          brightness: luminosite,
        ).copyWith(
          primary: t.texte,
          onPrimary: t.fond,
          secondary: t.accent,
          onSecondary: t.surAccent,
          surface: t.fond,
          onSurface: t.texte,
          onSurfaceVariant: t.doux,
          outline: t.doux,
          outlineVariant: t.trait,
          surfaceContainerLowest: t.carte,
          surfaceContainerLow: t.carte,
          surfaceContainer: t.carte,
          surfaceContainerHigh: t.carte,
          surfaceContainerHighest: t.puce,
          secondaryContainer: t.accent,
          onSecondaryContainer: t.surAccent,
          error: luminosite == Brightness.dark
              ? const Color(0xFFFF8A80)
              : const Color(0xFFC0392B),
        );
    final base = ThemeData(brightness: luminosite).textTheme;
    final styles = base
        .apply(
          fontFamily: policeTexte,
          bodyColor: t.texte,
          displayColor: t.texte,
        )
        .copyWith(
          titleLarge: TextStyle(
            fontFamily: policeTitre,
            fontSize: 20 * tailleTitre,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: t.texte,
          ),
          titleMedium: TextStyle(
            fontFamily: policeTexte,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: t.texte,
          ),
          bodyLarge: TextStyle(
            fontFamily: policeTexte,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: t.texte,
          ),
          bodyMedium: TextStyle(
            fontFamily: policeTexte,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: t.texte,
          ),
        );
    final pilule = const StadiumBorder();
    return ThemeData(
      colorScheme: scheme,
      extensions: [t],
      fontFamily: policeTexte,
      textTheme: styles,
      scaffoldBackgroundColor: t.fond,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: t.fond,
        foregroundColor: t.texte,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: policeTitre,
          fontSize: 20 * tailleTitre,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: t.texte,
        ),
      ),
      cardTheme: CardThemeData(
        color: t.carte,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      ),
      dividerTheme: DividerThemeData(color: t.trait, space: 1, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 56),
          shape: pilule,
          backgroundColor: t.texte,
          foregroundColor: t.fond,
          textStyle: TextStyle(
            fontFamily: policeTexte,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 56),
          shape: pilule,
          foregroundColor: t.texte,
          backgroundColor: t.carte,
          side: BorderSide.none,
          textStyle: TextStyle(
            fontFamily: policeTexte,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.texte,
          shape: pilule,
          textStyle: TextStyle(
            fontFamily: policeTexte,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: t.carte,
          selectedBackgroundColor: t.texte,
          selectedForegroundColor: t.fond,
          foregroundColor: t.texte,
          side: BorderSide.none,
          shape: pilule,
          minimumSize: const Size(0, 48),
          textStyle: TextStyle(
            fontFamily: policeTexte,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.accent,
        foregroundColor: t.surAccent,
        elevation: 0,
        highlightElevation: 0,
        shape: pilule,
        extendedTextStyle: TextStyle(
          fontFamily: policeTexte,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.carte,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 22,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor: t.puce,
        selectedColor: t.accent,
        labelStyle: WidgetStateTextStyle.resolveWith(
          (etats) => TextStyle(
            fontFamily: policeTexte,
            fontWeight: FontWeight.w700,
            color: etats.contains(WidgetState.selected) ? t.surAccent : t.texte,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.carte,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        titleTextStyle: TextStyle(
          fontFamily: policeTitre,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: t.texte,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.carte,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.texte,
        contentTextStyle: TextStyle(
          fontFamily: policeTexte,
          fontWeight: FontWeight.w600,
          color: t.fond,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: t.carte,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      ),
    );
  }

  /// Couleur d'une réponse : citron pour la meilleure, corail pour la
  /// moins bonne, abricot au milieu (3 réponses).
  static Color couleurReponse(BuildContext context, int choix, int nb) {
    final t = Teintes.de(context);
    final rang = nb == 2 && choix == 1 ? 2 : choix;
    return switch (rang) {
      0 => t.meilleure,
      1 => t.moyenne,
      _ => t.moinsBonne,
    };
  }

  /// Texte sur la couleur d'une réponse : toujours foncé (couleurs vives
  /// et claires).
  static Color texteSurReponse(BuildContext context, int choix, int nb) =>
      const Color(0xFF111114);
}

/// Les couleurs du style.
class Teintes extends ThemeExtension<Teintes> {
  final Color fond;
  final Color carte;

  /// Fond d'une réponse non choisie, des pastilles.
  final Color puce;
  final Color texte;
  final Color doux;
  final Color trait;

  /// Citron : onglet choisi, bouton Ajouter.
  final Color accent;
  final Color surAccent;

  /// Barre d'onglets flottante.
  final Color barre;
  final Color texteBarre;
  final Color meilleure;
  final Color moyenne;
  final Color moinsBonne;

  /// Écran rétro (le toi qui exécute).
  final bool estRetro;

  const Teintes({
    required this.fond,
    required this.carte,
    required this.puce,
    required this.texte,
    required this.doux,
    required this.trait,
    required this.accent,
    required this.surAccent,
    required this.barre,
    required this.texteBarre,
    required this.meilleure,
    required this.moyenne,
    required this.moinsBonne,
    this.estRetro = false,
  });

  static const sombre = Teintes(
    fond: Color(0xFF0F0F12),
    carte: Color(0xFF1A1A1F),
    puce: Color(0xFF26262C),
    texte: Color(0xFFF5F5F2),
    doux: Color(0xFFA3A3AD),
    trait: Color(0xFF26262C),
    accent: Color(0xFFD4FF3A),
    surAccent: Color(0xFF0F0F12),
    barre: Color(0xFF2E2E36),
    texteBarre: Color(0xFFC4C4CC),
    meilleure: Color(0xFFD4FF3A),
    moyenne: Color(0xFFFFB547),
    moinsBonne: Color(0xFFFF6B5E),
  );

  /// Le soir : accent ambre (celui qui décide).
  static const soir = Teintes(
    fond: Color(0xFF0F0F12),
    carte: Color(0xFF1A1A1F),
    puce: Color(0xFF26262C),
    texte: Color(0xFFF5F5F2),
    doux: Color(0xFFA3A3AD),
    trait: Color(0xFF26262C),
    accent: AppTheme.ambre,
    surAccent: Color(0xFF0F0F12),
    barre: Color(0xFF2E2E36),
    texteBarre: Color(0xFFC4C4CC),
    meilleure: Color(0xFFD4FF3A),
    moyenne: Color(0xFFFFB547),
    moinsBonne: Color(0xFFFF6B5E),
  );

  /// Le jour : vieux terminal, bleu-vert phosphore sur noir (celui qui
  /// exécute). Réponses : bleu-vert, sable, corail.
  static const retro = Teintes(
    fond: Color(0xFF050807),
    carte: Color(0xFF0B1412),
    puce: Color(0xFF12302B),
    texte: AppTheme.bleuVert,
    doux: Color(0xFF3FA593),
    trait: Color(0xFF12302B),
    accent: AppTheme.bleuVert,
    surAccent: Color(0xFF050807),
    barre: Color(0xFF0B1412),
    texteBarre: Color(0xFF3FA593),
    meilleure: AppTheme.bleuVert,
    moyenne: Color(0xFFE8D7B0),
    moinsBonne: Color(0xFFFF7A6B),
    estRetro: true,
  );

  static Teintes de(BuildContext context) =>
      Theme.of(context).extension<Teintes>() ?? sombre;

  @override
  Teintes copyWith() => this;

  @override
  Teintes lerp(Teintes? autre, double t) => t < 0.5 ? this : (autre ?? this);
}
