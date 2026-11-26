import 'package:flutter/material.dart';

import '../models/apparence.dart';

/// Le style de Ouinon, thème HUD (choisi par Paul le 26/11/2026) : noir,
/// bleu glacier pour la meilleure réponse et l'accent, rouge-orange pour
/// la moins bonne, lignes fines. Oxanium pour le texte, JetBrains Mono
/// pour les chiffres et les étiquettes. Les couleurs viennent de
/// l'apparence en cours (`Apparence.actuelle`), réglable sans APK.
abstract final class AppTheme {
  static const police = 'Oxanium';
  static const mono = 'JetBrainsMono';

  static Apparence get a => Apparence.actuelle;
  static Color get fond => a.fond;
  static Color get surface => a.surface;
  static Color get trait => a.trait;
  static Color get texte => a.texte;
  static Color get doux => a.doux;
  static Color get meilleure => a.meilleure;
  static Color get moinsBonne => a.moinsBonne;
  static Color get milieu => a.milieu;

  /// Couleur d'une réponse : la meilleure (indice 0), la moins bonne, ou
  /// celle du milieu.
  static Color couleurReponse(int indice, int nombre) => indice == 0
      ? meilleure
      : indice == nombre - 1
      ? moinsBonne
      : milieu;

  /// Une étiquette du HUD : petite, en capitales espacées.
  static TextStyle etiquette({Color? couleur, double taille = 11}) => TextStyle(
    fontFamily: mono,
    fontSize: taille,
    letterSpacing: 2,
    fontWeight: FontWeight.w500,
    color: couleur ?? doux,
  );

  static ThemeData sombre() {
    final schema =
        ColorScheme.fromSeed(
          seedColor: meilleure,
          brightness: Brightness.dark,
        ).copyWith(
          primary: meilleure,
          onPrimary: fond,
          secondary: moinsBonne,
          surface: fond,
          onSurface: texte,
          onSurfaceVariant: doux,
          outline: trait,
          error: moinsBonne,
          surfaceContainerHigh: surface,
          surfaceContainerHighest: surface,
        );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: schema,
      fontFamily: police,
      // Les symboles (▸, ◆…) absents d'Oxanium viennent de JetBrains Mono.
      fontFamilyFallback: const [mono],
      scaffoldBackgroundColor: fond,
    );
    final carre = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(2),
    );
    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: fond,
        surfaceTintColor: Colors.transparent,
        foregroundColor: texte,
        centerTitle: false,
        titleTextStyle: etiquette(couleur: meilleure, taille: 13),
      ),
      dividerTheme: DividerThemeData(color: trait, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: UnderlineInputBorder(borderSide: BorderSide(color: trait)),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: trait),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: meilleure),
        ),
        hintStyle: TextStyle(color: doux),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: meilleure,
        selectionColor: meilleure.withValues(alpha: 0.3),
        selectionHandleColor: meilleure,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: TextStyle(fontFamily: police, color: texte),
        actionTextColor: meilleure,
        behavior: SnackBarBehavior.floating,
        shape: carre,
      ),
      dialogTheme: DialogThemeData(backgroundColor: surface, shape: carre),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: surface,
        shape: carre,
      ),
    );
  }
}
