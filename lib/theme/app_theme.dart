import 'package:flutter/material.dart';

/// Le style de Ouinon : toujours sombre, une seule police (Oxanium), deux
/// couleurs : orange (la moins bonne réponse) et vert (la meilleure),
/// gris pour celle du milieu.
abstract final class AppTheme {
  static const police = 'Oxanium';

  static const fond = Color(0xFF07090C);
  static const surface = Color(0xFF12151A);
  static const trait = Color(0xFF22262E);
  static const texte = Color(0xFFE8E6E1);
  static const doux = Color(0xFF8B9099);

  static const orange = Color(0xFFFF8A2A);
  static const vert = Color(0xFF34E0B0);
  static const gris = Color(0xFFB5B8BF);

  /// Couleur d'une réponse : la meilleure (indice 0) en vert, la moins
  /// bonne en orange, celle du milieu en gris.
  static Color couleurReponse(int indice, int nombre) => indice == 0
      ? vert
      : indice == nombre - 1
      ? orange
      : gris;

  static ThemeData sombre() {
    final schema =
        ColorScheme.fromSeed(
          seedColor: vert,
          brightness: Brightness.dark,
        ).copyWith(
          primary: vert,
          onPrimary: fond,
          secondary: orange,
          surface: fond,
          onSurface: texte,
          onSurfaceVariant: doux,
          outline: trait,
          error: orange,
        );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: schema,
      fontFamily: police,
      scaffoldBackgroundColor: fond,
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: fond,
        surfaceTintColor: Colors.transparent,
        foregroundColor: texte,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: police,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: texte,
          letterSpacing: 0.5,
        ),
      ),
      dividerTheme: const DividerThemeData(color: trait, space: 1),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: vert.withValues(alpha: 0.18),
        foregroundColor: vert,
        elevation: 0,
        shape: const CircleBorder(side: BorderSide(color: vert)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderSide: BorderSide(color: trait)),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: trait)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: vert)),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: TextStyle(fontFamily: police, color: texte),
        actionTextColor: vert,
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: const DialogThemeData(backgroundColor: surface),
    );
  }
}
