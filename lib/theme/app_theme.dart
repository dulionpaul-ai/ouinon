import 'package:flutter/material.dart';

/// Style « Nuit ronde » (propositions D et F, 22/10/2026), toujours sombre
/// (choix de Paul) : tout est rond, cartes sombres, réponses en pilules
/// colorées (citron, abricot, corail), titres en Unbounded, texte en
/// Figtree. Polices embarquées, licence OFL (`assets/fonts/OFL-*.txt`).
class AppTheme {
  static const policeTitre = 'Unbounded';
  static const policeTexte = 'Figtree';

  static ThemeData sombre() => _theme(Teintes.sombre, Brightness.dark);

  static ThemeData _theme(Teintes t, Brightness luminosite) {
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
    final texte = base
        .apply(
          fontFamily: policeTexte,
          bodyColor: t.texte,
          displayColor: t.texte,
        )
        .copyWith(
          titleLarge: TextStyle(
            fontFamily: policeTitre,
            fontSize: 20,
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
      textTheme: texte,
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
          fontSize: 20,
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
          textStyle: const TextStyle(
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
          textStyle: const TextStyle(
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
          textStyle: const TextStyle(
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
          textStyle: const TextStyle(
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
        extendedTextStyle: const TextStyle(
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

  static Teintes de(BuildContext context) =>
      Theme.of(context).extension<Teintes>() ?? sombre;

  @override
  Teintes copyWith() => this;

  @override
  Teintes lerp(Teintes? autre, double t) => t < 0.5 ? this : (autre ?? this);
}
