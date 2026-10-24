import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/question.dart';
import '../models/tache.dart';
import '../utils/jour.dart';
import '../utils/stats.dart';

/// Les questions, les réponses et le planning, dans une base SQLite sur le téléphone
/// (`ouinon.sqlite`). Rien ne part sur internet.
///
/// La base est aussi ouverte par le moteur d'arrière-plan qui enregistre
/// les réponses données depuis une notification (appli fermée) : toujours
/// relire la base plutôt que garder une copie.
class Base {
  /// 2 : planning (24/10/2026).
  static const version = 2;

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
        onUpgrade: (db, ancienne, _) async {
          if (ancienne < 2) await _creePlanning(db);
        },
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
    await _creePlanning(db);
    if (avecDepart) {
      for (final q in questionsDeDepart) {
        await db.insert('questions', q.versLigne());
      }
    }
  }

  static Future<void> _creePlanning(Database db) async {
    await db.execute('''
      CREATE TABLE planning (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        jour TEXT NOT NULL,
        debut INTEGER NOT NULL,
        duree INTEGER NOT NULL,
        texte TEXT NOT NULL,
        etat INTEGER,
        reports INTEGER NOT NULL DEFAULT 0,
        test INTEGER NOT NULL DEFAULT 0
      )''');
    await db.execute('CREATE INDEX planning_jour ON planning (jour)');
  }

  // Questions

  /// Les questions dans l'ordre de la journée (demande de Paul du
  /// 23/10/2026) ; à heure égale, dans l'ordre de création.
  Future<List<Question>> questions() async {
    final lignes = await db.query('questions', orderBy: 'heure, ordre, id');
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

  /// Marque des réponses de test (dans `repondu_le`) : on peut les effacer
  /// toutes sans toucher aux vraies.
  static const marqueTest = 'test';

  /// Ajoute des réponses de test, sans remplacer une réponse existante.
  /// Rend le nombre de réponses ajoutées.
  Future<int> ajouteReponsesTest(
    List<({int questionId, DateTime jour, int choix})> reponses,
  ) => _ecrit(
    db.transaction((t) async {
      var ajoutees = 0;
      for (final r in reponses) {
        final id = await t.insert('reponses', {
          'question_id': r.questionId,
          'jour': cleJour(r.jour),
          'choix': r.choix,
          'repondu_le': marqueTest,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        if (id != 0) ajoutees++;
      }
      return ajoutees;
    }),
  );

  /// Ajoute des choses prévues de test, sur des jours qui n'ont encore
  /// rien de prévu (le vrai planning n'est jamais mélangé). Rend le
  /// nombre ajouté.
  Future<int> ajouteTachesTest(List<Tache> taches) => _ecrit(
    db.transaction((t) async {
      final occupes = {
        for (final l in await t.query('planning', columns: ['jour']))
          l['jour'] as String,
      };
      var ajoutees = 0;
      for (final tache in taches) {
        if (occupes.contains(cleJour(tache.jour))) continue;
        await t.insert('planning', tache.versLigne());
        ajoutees++;
      }
      return ajoutees;
    }),
  );

  /// Nombre de réponses et de choses prévues de test.
  Future<int> nombreReponsesTest() async =>
      (Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM reponses WHERE repondu_le = ?',
              [marqueTest],
            ),
          ) ??
          0) +
      (Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM planning WHERE test = 1'),
          ) ??
          0);

  /// Efface toutes les réponses et choses prévues de test (les vraies
  /// restent).
  Future<int> effaceReponsesTest() => _ecrit(
    db.transaction((t) async {
      final reponses = await t.delete(
        'reponses',
        where: 'repondu_le = ?',
        whereArgs: [marqueTest],
      );
      return reponses + await t.delete('planning', where: 'test = 1');
    }),
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

  // Planning

  /// Les choses prévues d'un jour, dans l'ordre de la journée.
  Future<List<Tache>> tachesDu(DateTime jour) async {
    final lignes = await db.query(
      'planning',
      where: 'jour = ?',
      whereArgs: [cleJour(jour)],
      orderBy: 'debut, id',
    );
    return [for (final l in lignes) Tache.depuisLigne(l)];
  }

  /// Les choses prévues à partir de `depuis` (toutes sans `depuis`).
  Future<List<Tache>> taches({DateTime? depuis}) async {
    final lignes = await db.query(
      'planning',
      where: depuis == null ? null : 'jour >= ?',
      whereArgs: depuis == null ? null : [cleJour(depuis)],
      orderBy: 'jour, debut, id',
    );
    return [for (final l in lignes) Tache.depuisLigne(l)];
  }

  Future<Tache?> tache(int id) async {
    final lignes = await db.query('planning', where: 'id = ?', whereArgs: [id]);
    return lignes.isEmpty ? null : Tache.depuisLigne(lignes.first);
  }

  /// Ajoute (sans id) ou met à jour une chose prévue.
  Future<Tache> enregistreTache(Tache tache) => _ecrit(() async {
    if (tache.id == null) {
      final id = await db.insert('planning', tache.versLigne());
      return tache.copie(id: id);
    }
    await db.update(
      'planning',
      tache.versLigne(),
      where: 'id = ?',
      whereArgs: [tache.id],
    );
    return tache;
  }());

  Future<void> supprimeTache(int id) =>
      _ecrit(db.delete('planning', where: 'id = ?', whereArgs: [id]));

  /// « Fait » (`Tache.fait`), « Pas fait » (`Tache.pasFait`) ou nul pour
  /// effacer la réponse.
  Future<void> repondTache(int id, int? etat) => _ecrit(
    db.update('planning', {'etat': etat}, where: 'id = ?', whereArgs: [id]),
  );

  /// « Reporter » : la chose revient une heure après `maintenant` (même
  /// durée), le même jour. Rend la chose reportée, ou nulle si l'heure
  /// dépasserait minuit (elle reste alors sans réponse, à remettre au
  /// lendemain).
  Future<Tache?> reporteTache(int id, DateTime maintenant) async {
    final tache = await this.tache(id);
    if (tache == null || tache.etat != null) return null;
    final base = jourDe(maintenant) == tache.jour
        ? maintenant.hour * 60 + maintenant.minute
        : tache.debut;
    final debut = base + 60;
    if (debut >= 24 * 60) return null;
    return enregistreTache(
      tache.copie(debut: debut, reports: tache.reports + 1),
    );
  }

  /// Ce qu'on prévoit le plus souvent (texte et durée la plus récente),
  /// pour l'ajouter d'un toucher.
  Future<List<({String texte, int duree})>> habitudes({int nombre = 6}) async {
    final lignes = await db.rawQuery(
      'SELECT texte, duree, COUNT(*) AS fois, MAX(jour) AS dernier '
      'FROM planning WHERE test = 0 GROUP BY texte '
      'ORDER BY fois DESC, dernier DESC LIMIT ?',
      [nombre],
    );
    return [
      for (final l in lignes)
        (texte: l['texte'] as String, duree: l['duree'] as int),
    ];
  }
}
