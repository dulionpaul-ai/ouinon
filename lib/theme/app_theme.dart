import 'package:flutter/material.dart';

/// Style provisoire « Blanc net » (proposition A, en attendant le choix de
/// Paul) : fond blanc, texte noir, une couleur par réponse.
class AppTheme {
  static ThemeData clair() => _theme(Brightness.light);

  static ThemeData sombre() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness luminosite) {
    final sombre = luminosite == Brightness.dark;
    final fond = sombre ? const Color(0xFF121316) : Colors.white;
    final texte = sombre ? const Color(0xFFF4F4F5) : const Color(0xFF111111);
    final doux = sombre ? const Color(0xFFA1A1AA) : const Color(0xFF5F5F5F);
    final trait = sombre ? const Color(0xFF2A2B30) : const Color(0xFFE6E6E6);
    final carte = sombre ? const Color(0xFF1C1D21) : const Color(0xFFF6F6F6);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E8E4E),
          brightness: luminosite,
        ).copyWith(
          primary: texte,
          onPrimary: fond,
          surface: fond,
          onSurface: texte,
          onSurfaceVariant: doux,
          outlineVariant: trait,
          surfaceContainerLowest: fond,
          surfaceContainerLow: carte,
          surfaceContainer: carte,
          surfaceContainerHigh: carte,
          surfaceContainerHighest: carte,
          secondaryContainer: trait,
          onSecondaryContainer: texte,
        );
    final rond = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: fond,
      appBarTheme: AppBarTheme(
        backgroundColor: fond,
        foregroundColor: texte,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: texte,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: fond,
        surfaceTintColor: Colors.transparent,
        indicatorColor: trait,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 13,
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? texte : doux,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: trait, space: 1, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: rond,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: rond,
          foregroundColor: texte,
          side: BorderSide(color: trait, width: 1.5),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: carte,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: trait),
      ),
    );
  }

  /// Couleur d'une réponse : vert pour la meilleure, rouge pour la moins
  /// bonne, orange au milieu (3 réponses).
  static Color couleurReponse(BuildContext context, int choix, int nb) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    final rang = nb == 2 && choix == 1 ? 2 : choix;
    return switch (rang) {
      0 => sombre ? const Color(0xFF4ADE80) : const Color(0xFF1E8E4E),
      1 => sombre ? const Color(0xFFFBBF24) : const Color(0xFFE5A100),
      _ => sombre ? const Color(0xFFF87171) : const Color(0xFFC62828),
    };
  }

  /// Texte lisible sur la couleur d'une réponse.
  static Color texteSurReponse(BuildContext context, int choix, int nb) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    final rang = nb == 2 && choix == 1 ? 2 : choix;
    if (sombre) return const Color(0xFF111111);
    return rang == 1 ? const Color(0xFF111111) : Colors.white;
  }
}
