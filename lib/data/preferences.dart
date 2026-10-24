import 'package:shared_preferences/shared_preferences.dart';

/// Les choix de la personne gardés sur le téléphone : bilan du dimanche
/// soir, rappel du soir pour préparer le lendemain.
class Preferences {
  static const _cleBilan = 'bilan_dimanche';
  static const _cleRappelPlanning = 'rappel_planning';
  static const _cleHeureRappelPlanning = 'heure_rappel_planning';

  /// Heure du rappel du soir par défaut : 21 h 30 (après les questions
  /// de 21 h).
  static const heureRappelPlanningParDefaut = 21 * 60 + 30;

  /// Bilan du dimanche soir : activé par défaut.
  static Future<bool> bilanDimanche() async =>
      (await SharedPreferences.getInstance()).getBool(_cleBilan) ?? true;

  static Future<void> activeBilan(bool oui) async =>
      (await SharedPreferences.getInstance()).setBool(_cleBilan, oui);

  /// Rappel du soir « Prépare ta journée de demain » : activé par défaut.
  static Future<bool> rappelPlanning() async =>
      (await SharedPreferences.getInstance()).getBool(_cleRappelPlanning) ??
      true;

  static Future<void> activeRappelPlanning(bool oui) async =>
      (await SharedPreferences.getInstance()).setBool(_cleRappelPlanning, oui);

  /// Heure du rappel du soir, en minutes depuis minuit.
  static Future<int> heureRappelPlanning() async =>
      (await SharedPreferences.getInstance()).getInt(_cleHeureRappelPlanning) ??
      heureRappelPlanningParDefaut;

  static Future<void> changeHeureRappelPlanning(int minutes) async =>
      (await SharedPreferences.getInstance()).setInt(
        _cleHeureRappelPlanning,
        minutes,
      );
}
