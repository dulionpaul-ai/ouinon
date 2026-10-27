import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Les suggestions de réponses proposées à la création d'une question
/// (« Oui / Non », « Bien / Moyen / Pas bien »…). Modifiables par la
/// personne, gardées sur le téléphone.
class Suggestions {
  static const _cle = 'suggestions_reponses';

  static const parDefaut = [
    ['Oui', 'Non'],
    ['Bien', 'Moyen', 'Pas bien'],
  ];

  static Future<List<List<String>>> charge() async {
    final prefs = await SharedPreferences.getInstance();
    final brut = prefs.getString(_cle);
    if (brut == null) return _copieParDefaut();
    try {
      return [
        for (final s in jsonDecode(brut) as List<dynamic>)
          [for (final r in s as List<dynamic>) r as String],
      ];
    } catch (_) {
      return _copieParDefaut();
    }
  }

  static List<List<String>> _copieParDefaut() => [
    for (final s in parDefaut) [...s],
  ];

  static Future<void> enregistre(List<List<String>> suggestions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cle, jsonEncode(suggestions));
  }
}
