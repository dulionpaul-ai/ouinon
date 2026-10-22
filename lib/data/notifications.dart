import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/question.dart';
import '../utils/date_fr.dart';
import '../utils/jour.dart';
import '../utils/planification.dart';
import 'base.dart';

/// Réponse donnée avec un bouton de notification, appli fermée : Android
/// (ou iOS) lance un petit moteur d'arrière-plan qui appelle cette
/// fonction. Elle enregistre la réponse et reprogramme les notifications.
@pragma('vm:entry-point')
Future<void> reponseNotifArrierePlan(NotificationResponse reponse) =>
    Notifications.instance.traiteReponse(reponse);

/// Les notifications des questions, programmées sur le téléphone (rien ne
/// part sur internet). Chaque notification porte la question et le jour
/// dont elle parle ; ses boutons sont les réponses de la question.
///
/// Programmation une par une pour les jours à venir (`planifie`), refaite
/// à chaque ouverture de l'appli, à chaque modification et à chaque
/// réponse : les jours déjà répondus sont sautés.
class Notifications {
  /// Remplacé dans les tests (aucun appel au système).
  static Notifications instance = Notifications();

  static const _canal = 'questions';

  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _pret;

  /// Au démarrage (appli ou moteur d'arrière-plan) : fuseau horaire et
  /// module de notifications.
  Future<void> prepare() => _pret ??= () async {
    tzdata.initializeTimeZones();
    try {
      final fuseau = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(fuseau.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Paris'));
    }
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
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
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
                    for (var i = 0; i < q.nbReponses; i++)
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

  /// Les notifications sont-elles autorisées (Android) ? Nul si on ne sait
  /// pas (iPhone).
  Future<bool?> autorisees() async {
    await prepare();
    return _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.areNotificationsEnabled();
  }

  /// Demande l'autorisation d'envoyer des notifications.
  Future<bool> demandeAutorisation() async {
    await prepare();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ??
        await ios?.requestPermissions(alert: true, badge: false, sound: true) ??
        false;
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
  /// réponses déjà données.
  Future<void> replanifie(Base base, {DateTime? maintenant}) async {
    await prepare();
    final now = maintenant ?? DateTime.now();
    final questions = await base.questions();
    final plan = planifie(
      questions: questions,
      repondues: await base.reponduesDepuis(jourDe(now)),
      maintenant: now,
      // iPhone : 64 notifications programmées au plus (une gardée pour le
      // rappel « continuer »). Android : 500 alarmes par appli.
      maxNotifs: defaultTargetPlatform == TargetPlatform.iOS ? 63 : 400,
    );
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _initialise(questions);
    }
    await _plugin.cancelAllPendingNotifications();
    for (final n in plan.notifs) {
      await _plugin.zonedSchedule(
        id: n.id,
        title: n.question.texte,
        body: majuscule(jourEtDate(n.jour)),
        scheduledDate: _tz(n.quand),
        notificationDetails: _details(n.question),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '${n.question.id}|${cleJour(n.jour)}',
      );
    }
    final rappel = plan.rappelContinuer;
    if (rappel != null) {
      await _plugin.zonedSchedule(
        id: idRappelContinuer,
        title: 'Ouinon',
        body: 'Ouvre l\'appli pour continuer à recevoir tes questions.',
        scheduledDate: _tz(rappel),
        notificationDetails: _detailsSimples,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  /// Retire la notification affichée d'une question pour un jour (réponse
  /// donnée dans l'appli).
  Future<void> retire(int questionId, DateTime jour) async {
    await prepare();
    await _plugin.cancel(id: idNotification(questionId, jour));
  }

  /// Envoie tout de suite la notification d'une question pour aujourd'hui
  /// (Réglages : « Essayer »).
  Future<void> essaie(Question q) async {
    await prepare();
    final jour = jourDe(DateTime.now());
    await _plugin.show(
      id: idNotification(q.id!, jour),
      title: q.texte,
      body: majuscule(jourEtDate(jour)),
      notificationDetails: _details(q),
      payload: '${q.id}|${cleJour(jour)}',
    );
  }

  tz.TZDateTime _tz(DateTime local) => tz.TZDateTime(
    tz.local,
    local.year,
    local.month,
    local.day,
    local.hour,
    local.minute,
  );

  NotificationDetails _details(Question q) => NotificationDetails(
    android: AndroidNotificationDetails(
      _canal,
      'Questions',
      channelDescription: 'Les questions du jour, avec leurs réponses.',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      actions: [
        for (var i = 0; i < q.nbReponses; i++)
          AndroidNotificationAction('r$i', q.reponses[i]),
      ],
    ),
    iOS: DarwinNotificationDetails(categoryIdentifier: 'q${q.id}'),
  );

  static const _detailsSimples = NotificationDetails(
    android: AndroidNotificationDetails(
      _canal,
      'Questions',
      channelDescription: 'Les questions du jour, avec leurs réponses.',
    ),
    iOS: DarwinNotificationDetails(),
  );
}
