import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/question.dart';
import '../models/tache.dart';
import '../utils/courbes.dart';
import '../utils/jour.dart';
import '../utils/planification.dart';
import '../utils/planning.dart';
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
///
/// Planning : chaque chose prévue sans réponse a deux notifications
/// (choix de Paul du 24/10/2026) : au début, « C'est l'heure » avec
/// « Reporter » ; à la fin, « C'est fait ? » avec « Pas fait · Reporter ·
/// Fait » (contenu caché « t|id »). « Reporter » la reprogramme une heure
/// plus tard. Le soir, un rappel invite à préparer le lendemain.
class Notifications {
  /// Remplacé dans les tests (aucun appel au système).
  static Notifications instance = Notifications();

  static const _canal = 'questions';

  /// Boutons des choses prévues, de gauche à droite : la moins bonne
  /// réponse à gauche, la meilleure à droite (choix de Paul).
  static const _actionsTache = [
    ('tp', 'Pas fait'),
    ('tr', 'Reporter'),
    ('tf', 'Fait'),
  ];

  final _plugin = FlutterLocalNotificationsPlugin();

  /// L'heure qu'il est (remplacée dans les tests).
  DateTime Function() horloge = DateTime.now;
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
            DarwinNotificationCategory(
              'tache',
              actions: [
                for (final (id, texte) in _actionsTache)
                  DarwinNotificationAction.plain(id, texte),
              ],
            ),
            DarwinNotificationCategory(
              'tacheDebut',
              actions: [DarwinNotificationAction.plain('tr', 'Reporter')],
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
    if (contenu != null && contenu.startsWith('t|')) {
      return _traiteTache(action, contenu);
    }
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

  /// Bouton d'une chose prévue : fait, pas fait, ou reportée d'une heure.
  Future<void> _traiteTache(String? action, String contenu) async {
    final id = int.tryParse(contenu.substring(2));
    if (id == null || action == null) return;
    final base = await Base.ouvrir();
    if (await base.tache(id) == null) return;
    switch (action) {
      case 'tf':
        await base.repondTache(id, Tache.fait);
      case 'tp':
        await base.repondTache(id, Tache.pasFait);
      case 'tr':
        await base.reporteTache(id, horloge());
      default:
        return;
    }
    await replanifie(base);
  }

  /// Reprogramme toutes les notifications d'après les questions et les
  /// réponses déjà données.
  Future<void> replanifie(Base base, {DateTime? maintenant}) async {
    await prepare();
    final now = maintenant ?? DateTime.now();
    final questions = await base.questions();
    final taches = rappelsAProgrammer(
      await base.taches(depuis: jourDe(now)),
      now,
      mode: await Preferences.notifsPlanning(),
    );
    final plan = planifie(
      questions: questions,
      repondues: await base.reponduesDepuis(jourDe(now)),
      maintenant: now,
      // iPhone : 64 notifications programmées au plus (trois gardées pour
      // le rappel « continuer », le bilan et le rappel du soir, plus le
      // planning). Android : 500 alarmes.
      maxNotifs:
          (defaultTargetPlatform == TargetPlatform.iOS ? 61 : 400) -
          taches.length,
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
    for (final r in taches) {
      final t = r.tache;
      await _plugin.zonedSchedule(
        id: r.fin ? idNotifFin(t.id!) : idNotifDebut(t.id!),
        title: r.fin ? '${t.texte}, c\'est fait ?' : t.texte,
        body: r.fin ? plageFr(t) : 'C\'est l\'heure · ${plageFr(t)}',
        scheduledDate: _tz(r.quand),
        notificationDetails: r.question ? _detailsTache : _detailsDebut,
        androidScheduleMode: mode,
        payload: 't|${t.id}',
      );
    }
    await _programmeRappelPlanning(base, now, mode);
    await _programmeBilan(base, questions, now, mode);
  }

  /// Rappel du soir (si activé) : « Prépare ta journée de demain », avec
  /// le point sur la journée et ce qui est déjà prévu.
  Future<void> _programmeRappelPlanning(
    Base base,
    DateTime maintenant,
    AndroidScheduleMode mode,
  ) async {
    if (!await Preferences.rappelPlanning()) return;
    final quand = prochainRappelPlanning(
      maintenant,
      await Preferences.heureRappelPlanning(),
    );
    final jour = jourDe(quand);
    final lendemain = ajouteJours(jour, 1);
    final placees = await base.placees(lendemain);
    final texte = texteRappelPlanning(
      await base.tachesDu(jour),
      await base.tachesDu(lendemain),
      aPlacer: [
        for (final a in await base.liste())
          if (!placees.containsKey(a.id)) a,
      ].length,
    );
    await _plugin.zonedSchedule(
      id: idRappelPlanning,
      title: 'Prépare ta journée de demain',
      body: texte,
      scheduledDate: _tz(quand),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'rappel_planning',
          'Préparer demain',
          channelDescription: 'Le soir, un rappel pour préparer le lendemain.',
          icon: '@drawable/ic_stat_ouinon',
          styleInformation: BigTextStyleInformation(texte),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: mode,
    );
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
    final reponses = await base.toutesLesReponses();
    final trouvees = decouvertes(questions, reponses);
    final planning = ligneBilanPlanning(await base.taches(), quand);
    final lignes = [
      ...?bilanSemaine(
        questions,
        reponses,
        quand,
        enPlus: trouvees.isEmpty ? null : ligneBilan(trouvees.first),
      ),
      ?planning,
    ];
    if (lignes.isEmpty) return;
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

  /// Retire la notification affichée d'une chose prévue (réponse donnée
  /// dans l'appli).
  Future<void> retireTache(int id) async {
    await prepare();
    await _plugin.cancel(id: idNotifDebut(id));
    await _plugin.cancel(id: idNotifFin(id));
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

  static final _detailsTache = NotificationDetails(
    android: AndroidNotificationDetails(
      'planning',
      'Planning',
      channelDescription: 'Les choses prévues, à leur heure.',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      icon: '@drawable/ic_stat_ouinon',
      actions: [
        for (final (id, texte) in _actionsTache)
          AndroidNotificationAction(id, texte),
      ],
    ),
    iOS: const DarwinNotificationDetails(categoryIdentifier: 'tache'),
  );

  static const _detailsDebut = NotificationDetails(
    android: AndroidNotificationDetails(
      'planning',
      'Planning',
      channelDescription: 'Les choses prévues, à leur heure.',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      icon: '@drawable/ic_stat_ouinon',
      actions: [AndroidNotificationAction('tr', 'Reporter')],
    ),
    iOS: DarwinNotificationDetails(categoryIdentifier: 'tacheDebut'),
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
