import 'package:shared_preferences/shared_preferences.dart';

/// Les choix de la personne gardés sur le téléphone : bilan du dimanche
/// soir.
class Preferences {
  static const _cleBilan = 'bilan_dimanche';

  /// Bilan du dimanche soir : activé par défaut.
  static Future<bool> bilanDimanche() async =>
      (await SharedPreferences.getInstance()).getBool(_cleBilan) ?? true;

  static Future<void> activeBilan(bool oui) async =>
      (await SharedPreferences.getInstance()).setBool(_cleBilan, oui);
}
