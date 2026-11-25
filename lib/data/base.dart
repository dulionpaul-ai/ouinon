import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/question.dart';
import '../utils/jour.dart';

/// Réponses d'une question : « 2026-10-22 » → indice de la réponse.
typedef Reponses = Map<String, int>;

/// Les questions et les réponses, dans une base SQLite sur le téléphone
/// (`ouinon.sqlite`). Rien ne part sur internet.
///
/// La base est aussi ouverte par le moteur d'arrière-plan qui enregistre
/// les réponses données depuis une notification (appli fermée) : toujours
/// la relire plutôt que garder une copie.
class Base {
  /// 8 : nouvelle Ouinon, repartie de zéro (25/11/2026). Les tables de
  /// l'ancienne appli (planning, liste, créneaux) restent dans le fichier,
  /// inutilisées.
  static const version = 8;

  final Database db;

  Base(this.db);

  /// Incrémenté à chaque modification : l'écran l'écoute.
  final changements = ValueNotifier<int>(0);

  void signaleChangement() => changements.value++;

  Future<T> _ecrit<T>(Future<T> ecriture) async {
    final resultat = await ecriture;
    changements.value++;
    return resultat;
  }

  static Future<Base>? _ouverture;

  /// Ouvre (et crée au premier lancement) la base du téléphone.
  static Future<Base> ouvrir() =>
      _ouverture ??= _ouvre().catchError((Object e) {
        _ouverture = null;
        throw e;
      });

  /// Remplace la base (tests).
  static void remplace(Base base) => _ouverture = Future.value(base);

  static Future<Base> _ouvre() async {
    final chemin = p.join(await getDatabasesPath(), 'ouinon.sqlite');
    return Base(await ouvrirAvec(databaseFactory, chemin));
  }

  /// Ouverture avec une fabrique donnée (tests : base en mémoire, neuve à
  /// chaque fois avec `instanceUnique: false`).
  static Future<Database> ouvrirAvec(
    DatabaseFactory fabrique,
    String chemin, {
    bool instanceUnique = true,
  }) => fabrique.openDatabase(
    chemin,
    options: OpenDatabaseOptions(
      version: version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE questions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            texte TEXT NOT NULL,
            reponses TEXT NOT NULL,
            heure INTEGER NOT NULL,
            jours INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE reponses (
            question_id INTEGER NOT NULL
              REFERENCES questions(id) ON DELETE CASCADE,
            jour TEXT NOT NULL,
            choix INTEGER NOT NULL,
            repondu_le TEXT NOT NULL,
            PRIMARY KEY (question_id, jour)
          )''');
      },
      onUpgrade: (db, ancienne, _) async {
        if (ancienne < 8) {
          // Une question en pause n'a plus de jours (la colonne « active »
          // de l'ancienne appli n'est plus lue).
          await db.execute('UPDATE questions SET jours = 0 WHERE active = 0');
          // Les fausses réponses ajoutées pour essayer les stats.
          await db.delete('reponses', where: "repondu_le = 'test'");
        }
      },
      singleInstance: instanceUnique,
    ),
  );

  // Questions

  /// Les questions dans l'ordre de la journée ; à heure égale, dans
  /// l'ordre de création.
  Future<List<Question>> questions() async {
    final lignes = await db.query('questions', orderBy: 'heure, id');
    return [for (final l in lignes) Question.depuisLigne(l)];
  }

  Future<Question?> question(int id) async {
    final lignes = await db.query(
      'questions',
      where: 'id = ?',
      whereArgs: [id],
    );
    return lignes.isEmpty ? null : Question.depuisLigne(lignes.first);
  }

  /// Ajoute (sans id) ou met à jour une question.
  Future<Question> enregistre(Question q) => _ecrit(() async {
    if (q.id == null) {
      return q.copie(id: await db.insert('questions', q.versLigne()));
    }
    await db.update(
      'questions',
      q.versLigne(),
      where: 'id = ?',
      whereArgs: [q.id],
    );
    return q;
  }());

  /// Met à jour une question dont le nombre de réponses change, et
  /// convertit ses réponses passées : de 2 à 3, la moins bonne (indice 1)
  /// passe en 2 ; de 3 à 2, celles du milieu sont effacées et la moins
  /// bonne passe en 1. La meilleure reste toujours 0.
  Future<void> enregistreAvecNombre(Question q, int ancienNombre) => _ecrit(
    db.transaction((t) async {
      if (ancienNombre == 2 && q.nbReponses == 3) {
        await t.rawUpdate(
          'UPDATE reponses SET choix = 2 WHERE question_id = ? AND choix = 1',
          [q.id],
        );
      } else if (ancienNombre == 3 && q.nbReponses == 2) {
        await t.delete(
          'reponses',
          where: 'question_id = ? AND choix = 1',
          whereArgs: [q.id],
        );
        await t.rawUpdate(
          'UPDATE reponses SET choix = 1 WHERE question_id = ? AND choix = 2',
          [q.id],
        );
      }
      await t.update(
        'questions',
        q.versLigne(),
        where: 'id = ?',
        whereArgs: [q.id],
      );
    }),
  );

  /// Supprime une question et toutes ses réponses.
  Future<void> supprime(int id) =>
      _ecrit(db.delete('questions', where: 'id = ?', whereArgs: [id]));

  // Réponses

  /// Enregistre (ou remplace) la réponse d'une question pour un jour.
  Future<void> repond(
    int questionId,
    DateTime jour,
    int choix, {
    DateTime? maintenant,
  }) => _ecrit(
    db.insert('reponses', {
      'question_id': questionId,
      'jour': cleJour(jour),
      'choix': choix,
      'repondu_le': (maintenant ?? DateTime.now()).toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace),
  );

  /// Efface la réponse d'une question pour un jour.
  Future<void> efface(int questionId, DateTime jour) => _ecrit(
    db.delete(
      'reponses',
      where: 'question_id = ? AND jour = ?',
      whereArgs: [questionId, cleJour(jour)],
    ),
  );

  /// Toutes les réponses, par question.
  Future<Map<int, Reponses>> toutesLesReponses() async {
    final lignes = await db.query('reponses');
    final resultat = <int, Reponses>{};
    for (final l in lignes) {
      (resultat[l['question_id'] as int] ??= {})[l['jour'] as String] =
          l['choix'] as int;
    }
    return resultat;
  }
}
