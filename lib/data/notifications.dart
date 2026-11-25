import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/question.dart';
import '../utils/jour.dart';
import '../utils/planification.dart';
import 'base.dart';

/// Le moment où une notification doit partir, envoyé à Android en temps
/// universel : l'heure locale est calculée avec l'horloge du téléphone
/// (une question de 7 h 01 arrivait à 8 h 01 en passant par un fuseau,
/// 23/10/2026).
tz.TZDateTime instantProgramme(DateTime local) =>
    tz.TZDateTime.from(local, tz.UTC);

/// Réponse donnée avec un bouton de notification, appli fermée : Android
/// lance un petit moteur d'arrière-plan qui appelle cette fonction.
@pragma('vm:entry-point')
Future<void> reponseNotifArrierePlan(NotificationResponse reponse) =>
    Notifications.instance.traiteReponse(reponse);

/// Les notifications des questions, programmées sur le téléphone. Le titre
/// est la question ; ses boutons sont les réponses, la moins bonne à
/// gauche, la meilleure à droite (bouton « r0 » = la meilleure). Le jour
/// dont elle parle est dans son contenu caché (« id|2026-10-22 »).
///
/// Tout est reprogrammé à chaque ouverture de l'appli, à chaque
/// modification et à chaque réponse : les jours déjà répondus sont sautés.
class Notifications {
  /// Remplacé dans les tests (aucun appel au système).
  static Notifications instance = Notifications();

  static const _canal = 'questions';

  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _pret;

  /// Au démarrage (appli ou moteur d'arrière-plan).
  Future<void> prepare() => _pret ??= _initialise(const []);

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

  /// Demande l'autorisation d'envoyer des notifications (rien ne s'affiche
  /// si elle est déjà donnée).
  Future<void> demandeAutorisation() async {
    await prepare();
    await _android?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, sound: true);
  }

  /// L'heure précise est-elle autorisée (Android : « Alarmes et
  /// rappels ») ? Sans elle, Android peut décaler les notifications de
  /// plusieurs heures.
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
    final morceaux = reponse.payload?.split('|');
    if (action == null || !action.startsWith('r')) return;
    if (morceaux == null || morceaux.length != 2) return;
    final id = int.tryParse(morceaux[0]);
    final choix = int.tryParse(action.substring(1));
    if (id == null || choix == null) return;
    final base = await Base.ouvrir();
    final question = await base.question(id);
    if (question == null || choix < 0 || choix >= question.nbReponses) return;
    await base.repond(id, jourDepuisCle(morceaux[1]), choix);
    await replanifie(base);
  }

  /// Reprogramme toutes les notifications.
  Future<void> replanifie(Base base) async {
    await prepare();
    final questions = await base.questions();
    final plan = planifie(
      questions: questions,
      reponses: await base.toutesLesReponses(),
      maintenant: DateTime.now(),
      // iPhone : 64 notifications programmées au plus. Android : 500.
      maxNotifs: defaultTargetPlatform == TargetPlatform.iOS ? 63 : 400,
    );
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _initialise(questions);
    }
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
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _canal,
            'Questions',
            icon: '@drawable/ic_stat_ouinon',
          ),
          iOS: DarwinNotificationDetails(),
        ),
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

  /// [duree] : temps d'affichage, jusqu'à la suivante de la même question.
  NotificationDetails _details(Question q, Duration duree) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          _canal,
          'Questions',
          channelDescription: 'Les questions du jour, avec leurs réponses.',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          icon: '@drawable/ic_stat_ouinon',
          timeoutAfter: duree.inMilliseconds,
          actions: [
            for (var i = q.nbReponses - 1; i >= 0; i--)
              AndroidNotificationAction('r$i', q.reponses[i]),
          ],
        ),
        iOS: DarwinNotificationDetails(categoryIdentifier: 'q${q.id}'),
      );
}
