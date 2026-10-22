import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/question.dart';
import '../utils/jour.dart';
import '../utils/stats.dart';

/// Les questions et les réponses, dans une base SQLite sur le téléphone
/// (`ouinon.sqlite`). Rien ne part sur internet.
///
/// La base est aussi ouverte par le moteur d'arrière-plan qui enregistre
/// les réponses données depuis une notification (appli fermée) : toujours
/// relire la base plutôt que garder une copie.
class Base {
  static const version = 1;

  final Database db;

  Base(this.db);

  /// Incrémenté à chaque modification : les écrans l'écoutent pour se
  /// mettre à jour (aussi au retour dans l'appli, pour les réponses
  /// données depuis les notifications).
  final changements = ValueNotifier<int>(0);

  void signaleChangement() => changements.value++;

  Future<T> _ecrit<T>(Future<T> ecriture) async {
    final resultat = await ecriture;
    changements.value++;
    return resultat;
  }

  static Future<Base>? _ouverture;

  /// Ouvre (et crée au premier lancement, avec les questions de départ) la
  /// base du téléphone.
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

  /// Ouverture avec une fabrique donnée (tests : base en mémoire, une
  /// nouvelle à chaque fois avec `instanceUnique: false`).
  static Future<Database> ouvrirAvec(
    DatabaseFactory fabrique,
    String chemin, {
    bool instanceUnique = true,
    bool questionsDeDepart = true,
  }) {
    return fabrique.openDatabase(
      chemin,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) => _cree(db, questionsDeDepart),
        singleInstance: instanceUnique,
      ),
    );
  }

  static Future<void> _cree(Database db, bool avecDepart) async {
    await db.execute('''
      CREATE TABLE questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        texte TEXT NOT NULL,
        reponses TEXT NOT NULL,
        heure INTEGER NOT NULL,
        jours INTEGER NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        ordre INTEGER NOT NULL DEFAULT 0
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
    if (avecDepart) {
      for (final q in questionsDeDepart) {
        await db.insert('questions', q.versLigne());
      }
    }
  }

  // Questions

  Future<List<Question>> questions() async {
    final lignes = await db.query('questions', orderBy: 'ordre, id');
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

  /// Ajoute (sans id, en fin de liste) ou met à jour une question.
  Future<Question> enregistre(Question q) => _ecrit(() async {
    if (q.id == null) {
      final fin = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COALESCE(MAX(ordre) + 1, 0) FROM questions'),
      );
      final nouvelle = q.copie(ordre: fin ?? 0);
      final id = await db.insert('questions', nouvelle.versLigne());
      return nouvelle.copie(id: id);
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
  /// passe en 2 ; de 3 à 2, les réponses du milieu sont effacées et la
  /// moins bonne passe en 1. La meilleure reste toujours 0.
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

  /// Nouvel ordre de la liste (ids dans l'ordre voulu).
  Future<void> reordonne(List<int> ids) => _ecrit(
    db.transaction((t) async {
      for (var i = 0; i < ids.length; i++) {
        await t.update(
          'questions',
          {'ordre': i},
          where: 'id = ?',
          whereArgs: [ids[i]],
        );
      }
    }),
  );

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

  /// Réponses d'un jour : id de la question → indice de la réponse.
  Future<Map<int, int>> reponsesDuJour(DateTime jour) async {
    final lignes = await db.query(
      'reponses',
      columns: ['question_id', 'choix'],
      where: 'jour = ?',
      whereArgs: [cleJour(jour)],
    );
    return {for (final l in lignes) l['question_id'] as int: l['choix'] as int};
  }

  /// Toutes les réponses, par question.
  Future<Map<int, Reponses>> toutesLesReponses() async {
    final lignes = await db.query(
      'reponses',
      columns: ['question_id', 'jour', 'choix'],
    );
    final parQuestion = <int, Reponses>{};
    for (final l in lignes) {
      (parQuestion[l['question_id'] as int] ??= {})[l['jour'] as String] =
          l['choix'] as int;
    }
    return parQuestion;
  }

  /// Réponses d'une question : jour → indice.
  Future<Reponses> reponsesDe(int questionId) async {
    final lignes = await db.query(
      'reponses',
      columns: ['jour', 'choix'],
      where: 'question_id = ?',
      whereArgs: [questionId],
    );
    return {for (final l in lignes) l['jour'] as String: l['choix'] as int};
  }

  /// Les couples « id|jour » déjà répondus à partir de `depuis` (pour ne
  /// pas reposer une question déjà répondue).
  Future<Set<String>> reponduesDepuis(DateTime depuis) async {
    final lignes = await db.query(
      'reponses',
      columns: ['question_id', 'jour'],
      where: 'jour >= ?',
      whereArgs: [cleJour(depuis)],
    );
    return {for (final l in lignes) '${l['question_id']}|${l['jour']}'};
  }
}
