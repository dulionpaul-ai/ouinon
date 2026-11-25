import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ouinon/data/base.dart';
import 'package:ouinon/data/notifications.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Base en mémoire, neuve à chaque appel.
Future<Base> ouvreBase() async {
  sqfliteFfiInit();
  return Base(
    await Base.ouvrirAvec(
      databaseFactoryFfi,
      inMemoryDatabasePath,
      instanceUnique: false,
    ),
  );
}

/// Notifications sans appel au système : on note ce qui est demandé.
class FaussesNotifications extends Notifications {
  int replanifications = 0;
  final retirees = <String>[];
  bool precise = true;

  @override
  Future<void> prepare() async {}

  @override
  Future<void> demandeAutorisation() async {}

  @override
  Future<bool> heurePrecise() async => precise;

  @override
  Future<void> replanifie(Base base) async => replanifications++;

  @override
  Future<void> retire(int questionId, DateTime jour) async =>
      retirees.add('$questionId|${jour.toIso8601String()}');
}

/// Une réponse donnée par un bouton de notification.
NotificationResponse bouton(String action, String contenu) =>
    NotificationResponse(
      notificationResponseType:
          NotificationResponseType.selectedNotificationAction,
      actionId: action,
      payload: contenu,
    );
