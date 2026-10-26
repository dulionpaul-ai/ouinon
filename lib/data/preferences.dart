import 'package:shared_preferences/shared_preferences.dart';

import '../utils/jour.dart';

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

  /// La journée (plage de l'Exécutant, où « Caser pour moi » place la
  /// liste) : 8 h – 20 h par défaut (Paul, 26/10/2026).
  static const debutJourneeParDefaut = 8 * 60;
  static const finJourneeParDefaut = 20 * 60;

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

/// Les deux toi (idée de Paul du 26/10/2026) : le toi suit l'onglet
/// (To-do et Stats : celui qui décide ; Aujourd'hui : celui qui exécute).
abstract final class DeuxMoi {
  static const _cleIntro = 'intro_deux_moi_vue';
  static const _cleReveil = 'reveil_vu';
  static const _cleRetour = 'retour_vu';

  /// L'intro des deux toi a été vue : les deux modes sont actifs.
  static Future<bool> actifs() async =>
      (await SharedPreferences.getInstance()).getBool(_cleIntro) ?? false;

  static Future<void> active(bool oui) async =>
      (await SharedPreferences.getInstance()).setBool(_cleIntro, oui);

  /// Le mot laissé le soir pour le toi qui exécute `jour`.
  static Future<String?> motPour(DateTime jour) async =>
      (await SharedPreferences.getInstance()).getString('mot_${cleJour(jour)}');

  /// Le mot laissé en fin de journée `jour` pour le toi du soir.
  static Future<String?> motDuJour(DateTime jour) async =>
      (await SharedPreferences.getInstance()).getString(
        'mot_soir_${cleJour(jour)}',
      );

  static Future<void> changeMotPour(DateTime jour, String? mot) =>
      _ecrit('mot_${cleJour(jour)}', mot);

  static Future<void> changeMotDuJour(DateTime jour, String? mot) =>
      _ecrit('mot_soir_${cleJour(jour)}', mot);

  static Future<void> _ecrit(String cle, String? mot) async {
    final p = await SharedPreferences.getInstance();
    final texte = mot?.trim() ?? '';
    if (texte.isEmpty) {
      await p.remove(cle);
    } else {
      await p.setString(cle, texte);
    }
  }

  /// L'ascenseur a déjà été joué ce jour-là dans ce sens (vers
  /// l'Exécutant : « le réveil » ; vers le Décideur : « le retour »).
  static Future<bool> passageVu(
    DateTime jour, {
    required bool versLeSoir,
  }) async =>
      (await SharedPreferences.getInstance()).getString(
        versLeSoir ? _cleRetour : _cleReveil,
      ) ==
      cleJour(jour);

  static Future<void> marquePassage(
    DateTime jour, {
    required bool versLeSoir,
  }) async => (await SharedPreferences.getInstance()).setString(
    versLeSoir ? _cleRetour : _cleReveil,
    cleJour(jour),
  );
}

/// Au début : rappel (« C'est l'heure »), avec « Reporter ». À la fin :
/// « C'est fait ? », avec « Pas fait · Reporter · Fait ». Avec une seule
/// notification, elle porte les trois boutons.
enum NotifsPlanning { debutEtFin, debut, fin }
