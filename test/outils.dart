import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/data/base.dart';
import 'package:ouinon/data/notifications.dart';
import 'package:ouinon/models/question.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Base en mémoire, neuve à chaque appel (avec ou sans les questions de
/// départ).
Future<Base> ouvreBase({bool depart = true}) async {
  sqfliteFfiInit();
  return Base(
    await Base.ouvrirAvec(
      databaseFactoryFfi,
      inMemoryDatabasePath,
      instanceUnique: false,
      questionsDeDepart: depart,
    ),
  );
}

/// Notifications sans appel au système : on note ce qui est demandé.
class FaussesNotifications extends Notifications {
  int replanifications = 0;
  final retirees = <String>[];
  final retireesTaches = <int>[];
  bool precise = true;
  int demandesHeurePrecise = 0;

  @override
  Future<void> prepare() async {}

  @override
  Future<void> replanifie(Base base, {DateTime? maintenant}) async {
    replanifications++;
  }

  @override
  Future<void> retire(int questionId, DateTime jour) async {
    retirees.add('$questionId|${jour.toIso8601String()}');
  }

  @override
  Future<void> retireTache(int id) async => retireesTaches.add(id);

  @override
  Future<bool?> autorisees() async => true;

  @override
  Future<bool> demandeAutorisation() async => true;

  @override
  Future<bool> heurePrecise() async => precise;

  @override
  Future<void> demandeHeurePrecise() async => demandesHeurePrecise++;

  @override
  Future<int> enAttente() async => 27;

  @override
  Future<void> essaie(Question q) async {}
}

NotificationResponse reponseBouton(String action, String contenu) =>
    NotificationResponse(
      notificationResponseType:
          NotificationResponseType.selectedNotificationAction,
      actionId: action,
      payload: contenu,
    );

/// Laisse tourner les requêtes SQLite (hors du temps simulé des tests).
Future<void> attends(WidgetTester tester, [int tours = 10]) async {
  for (var i = 0; i < tours; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }
}
