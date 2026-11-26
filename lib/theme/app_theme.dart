import 'package:flutter/material.dart';

import '../models/apparence.dart';

/// Le style de Ouinon : toujours sombre, une seule police (Oxanium), deux
/// couleurs : orange (la moins bonne réponse) et vert (la meilleure),
/// gris pour celle du milieu (version minimaliste validée le 26/11/2026,
/// préférée par Paul au thème HUD). Les couleurs viennent de l'apparence
/// en cours (`Apparence.actuelle`), réglable sans APK.
abstract final class AppTheme {
  static const police = 'Oxanium';

  /// Pour les chiffres des images de notification.
  static const mono = 'JetBrainsMono';

  static Apparence get _a => Apparence.actuelle;
  static Color get fond => _a.fond;
  static Color get surface => _a.surface;
  static Color get trait => _a.trait;
  static Color get texte => _a.texte;
  static Color get doux => _a.doux;

  static Color get orange => _a.moinsBonne;
  static Color get vert => _a.meilleure;
  static Color get gris => _a.milieu;

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
      appBarTheme: AppBarTheme(
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
      dividerTheme: DividerThemeData(color: trait, space: 1),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: vert.withValues(alpha: 0.18),
        foregroundColor: vert,
        elevation: 0,
        shape: CircleBorder(side: BorderSide(color: vert)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderSide: BorderSide(color: trait)),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: trait)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: vert)),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: TextStyle(fontFamily: police, color: texte),
        actionTextColor: vert,
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(backgroundColor: surface),
    );
  }
}
