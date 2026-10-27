import 'package:shared_preferences/shared_preferences.dart';

import '../utils/deux_moi.dart';

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

/// Les deux toi (idée de Paul du 26/10/2026) : deux rôles séparés, le
/// Décideur (To-do, Planifier, Stats) et l'Exécutant (Ma journée) ; on
/// passe de l'un à l'autre par l'ascenseur.
abstract final class DeuxMoi {
  static const _cleIntro = 'intro_deux_moi_vue';
  static const _cleRole = 'role_actif';

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

  /// Le rôle actif (Décideur par défaut), gardé d'une ouverture à
  /// l'autre ; on en change par l'ascenseur (26/10/2026).
  static Future<Moi> role() async =>
      (await SharedPreferences.getInstance()).getString(_cleRole) ==
          Moi.executant.name
      ? Moi.executant
      : Moi.decideur;

  static Future<void> changeRole(Moi role) async =>
      (await SharedPreferences.getInstance()).setString(_cleRole, role.name);
}

/// Au début : rappel (« C'est l'heure »), avec « Reporter ». À la fin :
/// « C'est fait ? », avec « Pas fait · Reporter · Fait ». Avec une seule
/// notification, elle porte les trois boutons.
enum NotifsPlanning { debutEtFin, debut, fin }

/// Le jeu « Synchro » (docs/jeu.md) : ce qu'il faut garder en plus de
/// l'historique pour calculer les points.
abstract final class PrefsJeu {
  static const _clePlans = 'jeu_plans';
  static const _cleNiveauVu = 'jeu_niveau_vu';

  /// Les soirs (« 2026-10-27 ») où le plan du lendemain a été validé.
  static Future<Set<String>> plans() async =>
      ((await SharedPreferences.getInstance()).getStringList(_clePlans) ??
              const [])
          .toSet();

  static Future<void> ajoutePlan(DateTime soir) async {
    final p = await SharedPreferences.getInstance();
    final plans = (p.getStringList(_clePlans) ?? const []).toSet()
      ..add(cleJour(soir));
    await p.setStringList(_clePlans, plans.toList()..sort());
  }

  /// Le dernier niveau fêté par l'animation (nul : jamais ouvert).
  static Future<int?> niveauVu() async =>
      (await SharedPreferences.getInstance()).getInt(_cleNiveauVu);

  static Future<void> changeNiveauVu(int niveau) async =>
      (await SharedPreferences.getInstance()).setInt(_cleNiveauVu, niveau);
}
