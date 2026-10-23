import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/question.dart';
import '../utils/jour.dart';
import '../utils/planification.dart';
import '../utils/stats.dart';
import 'base.dart';
import 'preferences.dart';

/// Le moment où une notification doit partir, en temps universel.
///
/// L'heure locale est d'abord calculée avec l'horloge du téléphone
/// (`DateTime` local : fuseau et heure d'été du téléphone), puis envoyée à
/// Android en temps universel, qui ne dépend d'aucun fuseau. Avant, on
/// passait par un fuseau détecté par l'appli : le 23/10/2026, une question
/// de 7 h 01 est arrivée à 8 h 01 chez Paul.
tz.TZDateTime instantProgramme(DateTime local) =>
    tz.TZDateTime.from(local, tz.UTC);

/// Réponse donnée avec un bouton de notification, appli fermée : Android
/// (ou iOS) lance un petit moteur d'arrière-plan qui appelle cette
/// fonction. Elle enregistre la réponse et reprogramme les notifications.
@pragma('vm:entry-point')
Future<void> reponseNotifArrierePlan(NotificationResponse reponse) =>
    Notifications.instance.traiteReponse(reponse);

/// Les notifications des questions, programmées sur le téléphone (rien ne
/// part sur internet). Le titre est la question, sans autre texte (la
/// date ne servait à rien, avis de Paul du 23/10/2026) ; ses boutons sont
/// les réponses. Le jour dont elle parle est dans son contenu caché
/// (`payload`).
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

  /// Au démarrage (appli ou moteur d'arrière-plan) : module de
  /// notifications.
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
                  // La moins bonne à gauche, la meilleure à droite
                  // (choix de Paul) ; « r0 » reste la meilleure.
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

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

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

  /// Nombre de notifications en attente sur le téléphone.
  Future<int> enAttente() async {
    await prepare();
    return (await _plugin.pendingNotificationRequests()).length;
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
      // iPhone : 64 notifications programmées au plus (deux gardées pour
      // le rappel « continuer » et le bilan). Android : 500 alarmes.
      maxNotifs: defaultTargetPlatform == TargetPlatform.iOS ? 62 : 400,
    );
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _initialise(questions);
    }
    // Heure précise si « Alarmes et rappels » est autorisé. Sinon, heure
    // approximative : Android peut alors décaler la notification d'autant
    // plus qu'elle est programmée longtemps à l'avance (plusieurs heures
    // de retard possibles : le soir du 22/10/2026, Paul n'a rien reçu).
    final mode = await heurePrecise()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    await _plugin.cancelAllPendingNotifications();
    for (final n in plan.notifs) {
      await _plugin.zonedSchedule(
        id: n.id,
        title: n.question.texte,
        scheduledDate: _tz(n.quand),
        notificationDetails: _details(n.question),
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
        scheduledDate: _tz(rappel),
        notificationDetails: _detailsSimples,
        androidScheduleMode: mode,
      );
    }
    await _programmeBilan(base, questions, now, mode);
  }

  /// Bilan du dimanche soir (si activé) : la semaine en quelques lignes.
  /// Son texte est recalculé à chaque reprogrammation, donc après chaque
  /// réponse : il est à jour de la dernière réponse donnée.
  Future<void> _programmeBilan(
    Base base,
    List<Question> questions,
    DateTime maintenant,
    AndroidScheduleMode mode,
  ) async {
    if (!await Preferences.bilanDimanche()) return;
    final quand = prochainBilan(maintenant);
    final idPrincipale = await Preferences.questionPrincipale();
    Question? principale;
    for (final q in questions) {
      if (q.id == idPrincipale) principale = q;
    }
    final lignes = bilanSemaine(
      questions,
      await base.toutesLesReponses(),
      quand,
      principale: principale,
    );
    if (lignes == null) return;
    final texte = lignes.join('\n');
    await _plugin.zonedSchedule(
      id: idBilanDimanche,
      title: 'Ta semaine',
      body: texte,
      scheduledDate: _tz(quand),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'bilan',
          'Bilan de la semaine',
          channelDescription:
              'Le dimanche soir, ta semaine en quelques lignes.',
          icon: '@drawable/ic_stat_ouinon',
          styleInformation: BigTextStyleInformation(texte),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: mode,
    );
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
      notificationDetails: _details(q),
      payload: '${q.id}|${cleJour(jour)}',
    );
  }

  tz.TZDateTime _tz(DateTime local) => instantProgramme(local);

  NotificationDetails _details(Question q) => NotificationDetails(
    android: AndroidNotificationDetails(
      _canal,
      'Questions',
      channelDescription: 'Les questions du jour, avec leurs réponses.',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      // Pas de couleur : Samsung assombrissait le citron en vert olive ;
      // rond neutre du système, logo blanc.
      icon: '@drawable/ic_stat_ouinon',
      // La moins bonne à gauche, la meilleure à droite (choix de Paul) ;
      // « r0 » reste la meilleure.
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
      channelDescription: 'Les questions du jour, avec leurs réponses.',
      icon: '@drawable/ic_stat_ouinon',
    ),
    iOS: DarwinNotificationDetails(),
  );
}
