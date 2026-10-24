import 'package:shared_preferences/shared_preferences.dart';

/// Les choix de la personne gardés sur le téléphone : bilan du dimanche
/// soir, rappel du soir pour préparer le lendemain, heures de la journée
/// (pour « Remplir ma journée »), notifications du planning.
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

  static const _cleDebutJournee = 'debut_journee';
  static const _cleFinJournee = 'fin_journee';
  static const _cleNotifsPlanning = 'notifs_planning';

  /// La journée où « Remplir ma journée » place la liste : 9 h – 19 h par
  /// défaut.
  static const debutJourneeParDefaut = 9 * 60;
  static const finJourneeParDefaut = 19 * 60;

  static Future<({int debut, int fin})> journee() async {
    final p = await SharedPreferences.getInstance();
    return (
      debut: p.getInt(_cleDebutJournee) ?? debutJourneeParDefaut,
      fin: p.getInt(_cleFinJournee) ?? finJourneeParDefaut,
    );
  }

  static Future<void> changeJournee({int? debut, int? fin}) async {
    final p = await SharedPreferences.getInstance();
    if (debut != null) await p.setInt(_cleDebutJournee, debut);
    if (fin != null) await p.setInt(_cleFinJournee, fin);
  }

  /// Notifications d'une chose prévue : au début et à la fin (par
  /// défaut, choix de Paul du 24/10/2026), ou une seule.
  static Future<NotifsPlanning> notifsPlanning() async {
    final nom = (await SharedPreferences.getInstance()).getString(
      _cleNotifsPlanning,
    );
    return NotifsPlanning.values.firstWhere(
      (m) => m.name == nom,
      orElse: () => NotifsPlanning.debutEtFin,
    );
  }

  static Future<void> changeNotifsPlanning(NotifsPlanning mode) async =>
      (await SharedPreferences.getInstance()).setString(
        _cleNotifsPlanning,
        mode.name,
      );
}

/// Au début : rappel (« C'est l'heure »), avec « Reporter ». À la fin :
/// « C'est fait ? », avec « Pas fait · Reporter · Fait ». Avec une seule
/// notification, elle porte les trois boutons.
enum NotifsPlanning { debutEtFin, debut, fin }
