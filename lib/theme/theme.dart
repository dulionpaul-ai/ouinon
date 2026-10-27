import 'package:flutter/material.dart';

/// Le thème de l'appli de zéro (27/10/2026). Paul ne voulait pas d'un
/// thème « qui fasse IA » : ni fond noir à néons, ni dégradés, ni lueurs.
/// Papier clair, encre noire, un seul bleu d'encre pour ce qu'on touche,
/// la police du téléphone, des lignes séparées par des traits fins.
abstract final class Couleurs {
  static const papier = Color(0xFFF7F6F2);
  static const encre = Color(0xFF1C1B19);
  static const gris = Color(0xFF6B6862);
  static const trait = Color(0xFFDEDBD3);
  static const bleu = Color(0xFF1F4E8C);
  static const rouge = Color(0xFFB3261E);
}

ThemeData themeOuinon() {
  final schema =
      ColorScheme.fromSeed(
        seedColor: Couleurs.bleu,
        brightness: Brightness.light,
      ).copyWith(
        primary: Couleurs.bleu,
        onPrimary: Colors.white,
        surface: Couleurs.papier,
        onSurface: Couleurs.encre,
        error: Couleurs.rouge,
        outline: Couleurs.trait,
      );
  return ThemeData(
    // La police du téléphone (Roboto sur Android).
    fontFamily: 'Roboto',
    colorScheme: schema,
    scaffoldBackgroundColor: Couleurs.papier,
    dividerTheme: const DividerThemeData(
      color: Couleurs.trait,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Couleurs.papier,
      foregroundColor: Couleurs.encre,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        color: Couleurs.encre,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Couleurs.bleu,
      foregroundColor: Colors.white,
      elevation: 1,
      shape: CircleBorder(),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: false,
      border: UnderlineInputBorder(),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Couleurs.trait),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Couleurs.bleu,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Couleurs.bleu),
    ),
  );
}
