import 'package:shared_preferences/shared_preferences.dart';

/// Les choix de la personne gardés sur le téléphone : question principale
/// (celle qui compte le plus, base du classement des stats) et bilan du
/// dimanche soir.
class Preferences {
  static const _clePrincipale = 'question_principale';
  static const _cleBilan = 'bilan_dimanche';

  static Future<int?> questionPrincipale() async =>
      (await SharedPreferences.getInstance()).getInt(_clePrincipale);

  static Future<void> choisitPrincipale(int? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_clePrincipale);
    } else {
      await prefs.setInt(_clePrincipale, id);
    }
  }

  /// Bilan du dimanche soir : activé par défaut.
  static Future<bool> bilanDimanche() async =>
      (await SharedPreferences.getInstance()).getBool(_cleBilan) ?? true;

  static Future<void> activeBilan(bool oui) async =>
      (await SharedPreferences.getInstance()).setBool(_cleBilan, oui);
}
