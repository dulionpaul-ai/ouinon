import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/question.dart';
import '../utils/jour.dart';
import '../utils/planification.dart';
import 'base.dart';

/// Le moment où une notification doit partir, en temps universel.
///
/// L'heure locale est d'abord calculée avec l'horloge du téléphone, puis
/// envoyée à Android en temps universel, qui ne dépend d'aucun fuseau (le
/// 23/10/2026, un fuseau détecté par l'appli avait décalé une question
/// d'une heure).
tz.TZDateTime instantProgramme(DateTime local) =>
    tz.TZDateTime.from(local, tz.UTC);

/// Réponse donnée avec un bouton de notification, appli fermée : le
/// téléphone lance un petit moteur d'arrière-plan qui appelle cette
/// fonction. Elle enregistre la réponse et reprogramme les notifications.
@pragma('vm:entry-point')
Future<void> reponseNotifArrierePlan(NotificationResponse reponse) =>
    Notifications.instance.traiteReponse(reponse);

/// Les notifications des questions (cahier, écran 1, 27/10/2026),
/// programmées sur le téléphone : rien ne part sur internet. Le titre est
/// la question ; ses boutons sont les réponses, la moins bonne à gauche.
/// Le jour dont elle parle est dans son contenu caché (`payload`).
///
/// Une notification ratée reste affichée jusqu'à la suivante de la même
/// question, qui la remplace (sur Android, elle s'efface d'elle-même à ce
/// moment-là) ; sans réponse, le jour compte comme « pas de réponse ».
///
/// Programmation jour par jour pour les deux semaines à venir
/// (`planifie`), refaite à chaque ouverture, modification et réponse.
class Notifications {
  /// Remplacé dans les tests (aucun appel au système).
  static Notifications instance = Notifications();

  static const _canal = 'questions';

  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _pret;

  /// Au démarrage (appli ou moteur d'arrière-plan).
  Future<void> prepare() => _pret ??= () async {
    await _initialise(await _questionsSansErreur());
  }();

  Future<List<Question>> _questionsSansErreur() async {
    try {
      return await (await Base.ouvrir()).questions();
    } catch (_) {
      return const [];
    }
  }

  /// Sur iPhone, les boutons sont déclarés d'avance, une « catégorie » par
  /// question : à refaire quand les questions changent.
  Future<void> _initialise(List<Question> questions) async {
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings(
          '@drawable/ic_stat_ouinon',
        ),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            for (final q in questions)
              if (q.id != null)
                DarwinNotificationCategory(
                  'q${q.id}',
                  actions: [
                    for (var i = q.nbReponses - 1; i >= 0; i--)
                      DarwinNotificationAction.plain('r$i', q.reponses[i]),
                  ],
                ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: traiteReponse,
      onDidReceiveBackgroundNotificationResponse: reponseNotifArrierePlan,
    );
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Les notifications sont-elles autorisées (Android) ? Nul si on ne sait
  /// pas (iPhone).
  Future<bool?> autorisees() async {
    await prepare();
    return _android?.areNotificationsEnabled();
  }

  /// Demande l'autorisation d'envoyer des notifications.
  Future<bool> demandeAutorisation() async {
    await prepare();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await _android?.requestNotificationsPermission() ??
        await ios?.requestPermissions(alert: true, badge: false, sound: true) ??
        false;
  }

  /// L'heure précise est-elle autorisée (Android : « Alarmes et
  /// rappels ») ? Toujours vrai ailleurs.
  Future<bool> heurePrecise() async {
    await prepare();
    final android = _android;
    if (android == null) return true;
    return await android.canScheduleExactNotifications() ?? false;
  }

  /// Ouvre le réglage Android « Alarmes et rappels » de l'appli.
  Future<void> demandeHeurePrecise() async {
    await prepare();
    await _android?.requestExactAlarmsPermission();
  }

  /// Réponse à une notification (bouton), appli ouverte ou non.
  Future<void> traiteReponse(NotificationResponse reponse) async {
    final action = reponse.actionId;
    final contenu = reponse.payload;
    if (action == null || !action.startsWith('r') || contenu == null) return;
    final morceaux = contenu.split('|');
    if (morceaux.length != 2) return;
    final id = int.tryParse(morceaux[0]);
    final choix = int.tryParse(action.substring(1));
    if (id == null || choix == null) return;
    final base = await Base.ouvrir();
    final question = await base.question(id);
    if (question == null || choix < 0 || choix >= question.nbReponses) return;
    await base.repond(id, jourDepuisCle(morceaux[1]), choix);
    await replanifie(base);
  }

  /// Reprogramme toutes les notifications d'après les questions et les
  /// réponses déjà données. Les notifications déjà affichées restent.
  Future<void> replanifie(Base base, {DateTime? maintenant}) async {
    await prepare();
    final now = maintenant ?? DateTime.now();
    final questions = await base.questions();
    final plan = planifie(
      questions: questions,
      repondues: await base.reponduesDepuis(jourDe(now)),
      maintenant: now,
      // iPhone : 64 notifications programmées au plus. Android : 500.
      maxNotifs: defaultTargetPlatform == TargetPlatform.iOS ? 62 : 400,
    );
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _initialise(questions);
    }
    // Heure précise si « Alarmes et rappels » est autorisé ; sinon Android
    // peut retarder la notification de plusieurs heures.
    final mode = await heurePrecise()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    await _plugin.cancelAllPendingNotifications();
    for (final n in plan.notifs) {
      await _plugin.zonedSchedule(
        id: n.id,
        title: n.question.texte,
        scheduledDate: instantProgramme(n.quand),
        notificationDetails: _details(n.question, n.duree),
        androidScheduleMode: mode,
        payload: '${n.question.id}|${cleJour(n.jour)}',
      );
    }
    final rappel = plan.rappelContinuer;
    if (rappel != null) {
      await _plugin.zonedSchedule(
        id: idRappelContinuer,
        title: 'Ouinon',
        body: 'Ouvre l\'appli pour continuer à recevoir tes questions.',
        scheduledDate: instantProgramme(rappel),
        notificationDetails: _detailsSimples,
        androidScheduleMode: mode,
      );
    }
  }

  /// Retire la notification affichée d'une question pour un jour (réponse
  /// donnée dans l'appli).
  Future<void> retire(int questionId, DateTime jour) async {
    await prepare();
    await _plugin.cancel(id: idNotification(questionId, jour));
  }

  /// [duree] : temps d'affichage, jusqu'à la suivante de la même question
  /// (nul : pas de limite).
  NotificationDetails _details(Question q, Duration? duree) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          _canal,
          'Questions',
          channelDescription: 'Les questions, avec leurs réponses.',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          icon: '@drawable/ic_stat_ouinon',
          timeoutAfter: duree?.inMilliseconds,
          actions: [
            for (var i = q.nbReponses - 1; i >= 0; i--)
              AndroidNotificationAction('r$i', q.reponses[i]),
          ],
        ),
        iOS: DarwinNotificationDetails(categoryIdentifier: 'q${q.id}'),
      );

  static const _detailsSimples = NotificationDetails(
    android: AndroidNotificationDetails(
      _canal,
      'Questions',
      channelDescription: 'Les questions, avec leurs réponses.',
      icon: '@drawable/ic_stat_ouinon',
    ),
    iOS: DarwinNotificationDetails(),
  );
}
