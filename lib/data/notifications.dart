import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:sqflite/sqflite.dart' show getDatabasesPath;

import '../models/apparence.dart';
import '../theme/app_theme.dart';
import '../models/question.dart';
import '../utils/frequence.dart';
import '../utils/jour.dart';
import '../utils/planification.dart';
import 'apparence_distante.dart';
import 'base.dart';
import 'images_notif.dart';

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
/// est la question, le texte son « pourquoi » ; ses boutons sont les
/// réponses, la moins bonne à
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

  /// Reprogramme toutes les notifications, au style de l'apparence en
  /// cours (HUD, 26/11/2026) : couleur d'accent, symbole et majuscules
  /// dans le titre, le « pourquoi » dessous, et sur Android deux images
  /// dessinées par l'appli (la série à droite, les 7 derniers jours quand
  /// on déplie).
  Future<void> replanifie(Base base) async {
    await prepare();
    await ApparenceDistante.charge(base);
    final a = Apparence.actuelle;
    final questions = await base.questions();
    final reponses = await base.toutesLesReponses();
    final maintenant = DateTime.now();
    final plan = planifie(
      questions: questions,
      reponses: reponses,
      maintenant: maintenant,
      // iPhone : 64 notifications programmées au plus. Android : 500.
      maxNotifs: defaultTargetPlatform == TargetPlatform.iOS ? 63 : 400,
    );
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _initialise(questions);
    }
    final mode = await heurePrecise()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    // Les images, une paire par question programmée.
    final images = <int, ({String icone, String grande})>{};
    if (a.images && defaultTargetPlatform == TargetPlatform.android) {
      final dossier = await getDatabasesPath();
      for (final q in {
        for (final n in plan.notifs) n.question.id: n.question,
      }.values) {
        final r = reponses[q.id] ?? const {};
        final i = await ImagesNotif.ecris(
          q: q,
          serie: serie(q, maintenant, r),
          jours: septJours(q, maintenant, r),
          a: a,
          dossier: dossier,
        );
        if (i != null) images[q.id!] = i;
      }
    }
    await _plugin.cancelAllPendingNotifications();
    for (final n in plan.notifs) {
      final q = n.question;
      final titre = titreNotif(q, a);
      final corps = texteNotif(q, n.jour, reponses[q.id] ?? const {});
      await _plugin.zonedSchedule(
        id: n.id,
        title: titre,
        body: corps,
        scheduledDate: instantProgramme(n.quand),
        notificationDetails: _details(
          q,
          n.duree,
          a,
          titre,
          corps,
          images[q.id],
        ),
        androidScheduleMode: mode,
        payload: '${q.id}|${cleJour(n.jour)}',
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
  NotificationDetails _details(
    Question q,
    Duration duree,
    Apparence a,
    String titre,
    String? corps,
    ({String icone, String grande})? images,
  ) => NotificationDetails(
    android: AndroidNotificationDetails(
      _canal,
      'Questions',
      channelDescription: 'Les questions du jour, avec leurs réponses.',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      icon: '@drawable/ic_stat_ouinon',
      color: a.couleurNotif ? a.meilleure : null,
      timeoutAfter: duree.inMilliseconds,
      largeIcon: images == null ? null : FilePathAndroidBitmap(images.icone),
      styleInformation: images == null
          ? (corps == null ? null : BigTextStyleInformation(corps))
          : BigPictureStyleInformation(
              FilePathAndroidBitmap(images.grande),
              hideExpandedLargeIcon: true,
              contentTitle: titre,
              summaryText: corps,
            ),
      actions: [
        for (var i = q.nbReponses - 1; i >= 0; i--)
          AndroidNotificationAction(
            'r$i',
            a.majuscules ? q.reponses[i].toUpperCase() : q.reponses[i],
            titleColor: a.couleurNotif
                ? AppTheme.couleurReponse(i, q.nbReponses)
                : null,
          ),
      ],
    ),
    iOS: DarwinNotificationDetails(categoryIdentifier: 'q${q.id}'),
  );
}

/// Le titre d'une notification : le symbole, puis la question (en
/// capitales si l'apparence le demande).
String titreNotif(Question q, Apparence a) {
  final texte = a.majuscules ? q.texte.toUpperCase() : q.texte;
  return a.symbole.isEmpty ? texte : '${a.symbole} $texte';
}
