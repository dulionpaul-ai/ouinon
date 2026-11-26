import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ouinon/data/base.dart';
import 'package:ouinon/data/notifications.dart';
import 'package:ouinon/models/question.dart';
import 'package:ouinon/utils/jour.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Base en mémoire, neuve à chaque appel.
Future<Base> ouvreBase({Miroir? miroir}) async {
  sqfliteFfiInit();
  return Base(
    await Base.ouvrirAvec(
      databaseFactoryFfi,
      inMemoryDatabasePath,
      instanceUnique: false,
    ),
    miroir: miroir,
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

/// Copie en ligne en mémoire : on note ce qui est envoyé.
class FauxMiroir implements Miroir {
  final questions = <int, Question>{};
  final reponses = <int, Reponses>{};
  final reglages = <String, String>{};
  bool horsLigne = false;

  void _reseau() {
    if (horsLigne) throw StateError('hors ligne');
  }

  @override
  Future<void> envoieQuestion(Question q) async {
    _reseau();
    questions[q.id!] = q;
  }

  @override
  Future<void> supprimeQuestion(int id) async {
    _reseau();
    questions.remove(id);
    reponses.remove(id);
  }

  @override
  Future<void> envoieReponse(int questionId, DateTime jour, int choix) async {
    _reseau();
    (reponses[questionId] ??= {})[cleJour(jour)] = choix;
  }

  @override
  Future<void> effaceReponse(int questionId, DateTime jour) async {
    _reseau();
    reponses[questionId]?.remove(cleJour(jour));
  }

  @override
  Future<void> remplaceReponsesDe(int questionId, Reponses r) async {
    _reseau();
    reponses[questionId] = {...r};
  }

  @override
  Future<void> envoieReglage(String cle, String valeur) async {
    _reseau();
    reglages[cle] = valeur;
  }

  @override
  Future<void> envoieTout(Copie copie) async {
    _reseau();
    for (final q in copie.questions) {
      questions[q.id!] = q;
    }
    for (final e in copie.reponses.entries) {
      (reponses[e.key] ??= {}).addAll(e.value);
    }
    reglages.addAll(copie.reglages);
  }

  @override
  Future<Copie> telecharge() async {
    _reseau();
    return (
      questions: questions.values.toList(),
      reponses: reponses,
      reglages: reglages,
    );
  }
}
