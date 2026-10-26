import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/a_faire.dart';
import '../models/creneau.dart';
import '../models/question.dart';
import '../models/tache.dart';
import '../utils/jour.dart';
import '../utils/stats.dart';

/// Les questions, les réponses, la liste « À faire » et le planning, dans
/// une base SQLite sur le téléphone
/// (`ouinon.sqlite`). Rien ne part sur internet.
///
/// La base est aussi ouverte par le moteur d'arrière-plan qui enregistre
/// les réponses données depuis une notification (appli fermée) : toujours
/// relire la base plutôt que garder une copie.
class Base {
  /// 2 : planning ; 3 : liste « À faire » ; 4 : choisies pour un jour et
  /// créneaux fixes (24/10/2026).
  static const version = 5;

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
          if (ancienne < 2) {
            await _creePlanning(db);
          } else if (ancienne < 3) {
            await db.execute(
              'ALTER TABLE planning ADD COLUMN liste_id INTEGER',
            );
            await db.execute(
              'ALTER TABLE planning ADD COLUMN quadrant INTEGER',
            );
          }
          if (ancienne < 3) {
            await _creeListe(db);
          } else if (ancienne < 4) {
            await db.execute('ALTER TABLE liste ADD COLUMN choisie_pour TEXT');
          }
          if (ancienne < 4) await _creeCreneaux(db);
          if (ancienne >= 3 && ancienne < 5) {
            await db.execute('ALTER TABLE liste ADD COLUMN heure INTEGER');
          }
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
    await _creeListe(db);
    await _creeCreneaux(db);
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
        test INTEGER NOT NULL DEFAULT 0,
        liste_id INTEGER,
        quadrant INTEGER
      )''');
    await db.execute('CREATE INDEX planning_jour ON planning (jour)');
  }

  static Future<void> _creeListe(Database db) async {
    await db.execute('''
      CREATE TABLE liste (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        texte TEXT NOT NULL,
        duree INTEGER NOT NULL,
        important INTEGER NOT NULL DEFAULT 0,
        urgent INTEGER NOT NULL DEFAULT 0,
        echeance TEXT,
        cree_le TEXT NOT NULL,
        faite_le TEXT,
        test INTEGER NOT NULL DEFAULT 0,
        choisie_pour TEXT,
        heure INTEGER
      )''');
  }

  static Future<void> _creeCreneaux(Database db) async {
    await db.execute('''
      CREATE TABLE creneaux (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        texte TEXT NOT NULL,
        debut INTEGER NOT NULL,
        fin INTEGER NOT NULL,
        jours INTEGER NOT NULL
      )''');
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

  /// Ajoute des choses à faire de test, une seule fois (la vraie liste
  /// n'est jamais touchée). Rend le nombre ajouté.
  Future<int> ajouteListeTest(List<AFaire> liste) => _ecrit(
    db.transaction((t) async {
      final deja = Sqflite.firstIntValue(
        await t.rawQuery('SELECT COUNT(*) FROM liste WHERE test = 1'),
      );
      if ((deja ?? 0) > 0) return 0;
      for (final a in liste) {
        await t.insert('liste', a.versLigne());
      }
      return liste.length;
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
          0) +
      (Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM liste WHERE test = 1'),
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
      return reponses +
          await t.delete('planning', where: 'test = 1') +
          await t.delete('liste', where: 'test = 1');
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
  /// effacer la réponse. Tirée de la liste : « Fait » la sort de la
  /// liste, sinon elle y reste (à placer à nouveau).
  Future<void> repondTache(int id, int? etat) => _ecrit(
    db.transaction((t) async {
      await t.update(
        'planning',
        {'etat': etat},
        where: 'id = ?',
        whereArgs: [id],
      );
      final lignes = await t.query(
        'planning',
        columns: ['liste_id', 'jour'],
        where: 'id = ?',
        whereArgs: [id],
      );
      final listeId = lignes.isEmpty ? null : lignes.first['liste_id'];
      if (listeId == null) return;
      await t.update(
        'liste',
        {'faite_le': etat == Tache.fait ? lignes.first['jour'] : null},
        where: 'id = ?',
        whereArgs: [listeId],
      );
    }),
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

  // Liste « À faire »

  /// Les choses à faire (sans les faites, sauf `avecFaites`), des plus
  /// anciennes aux plus récentes.
  Future<List<AFaire>> liste({bool avecFaites = false}) async {
    final lignes = await db.query(
      'liste',
      where: avecFaites ? null : 'faite_le IS NULL',
      orderBy: 'cree_le, id',
    );
    return [for (final l in lignes) AFaire.depuisLigne(l)];
  }

  Future<AFaire?> aFaire(int id) async {
    final lignes = await db.query('liste', where: 'id = ?', whereArgs: [id]);
    return lignes.isEmpty ? null : AFaire.depuisLigne(lignes.first);
  }

  /// Ajoute (sans id) ou met à jour une chose à faire ; ses passages
  /// prévus à venir suivent son nouveau texte et sa nouvelle durée.
  Future<AFaire> enregistreAFaire(AFaire a) => _ecrit(() async {
    if (a.id == null) {
      final id = await db.insert('liste', a.versLigne());
      return a.copie(id: id);
    }
    await db.transaction((t) async {
      await t.update(
        'liste',
        a.versLigne(),
        where: 'id = ?',
        whereArgs: [a.id],
      );
      await t.update(
        'planning',
        {'texte': a.texte, 'duree': a.duree},
        where: 'liste_id = ? AND etat IS NULL',
        whereArgs: [a.id],
      );
    });
    return a;
  }());

  /// Supprime une chose de la liste, et ses passages prévus sans réponse.
  Future<void> supprimeAFaire(int id) => _ecrit(
    db.transaction((t) async {
      await t.delete(
        'planning',
        where: 'liste_id = ? AND etat IS NULL',
        whereArgs: [id],
      );
      await t.delete('liste', where: 'id = ?', whereArgs: [id]);
    }),
  );

  /// Marque une chose faite (ou à faire de nouveau) sans passer par le
  /// planning ; ses passages prévus sans réponse sont retirés.
  Future<void> marqueFaite(int id, DateTime? le) => _ecrit(
    db.transaction((t) async {
      await t.update(
        'liste',
        {'faite_le': le == null ? null : cleJour(le)},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (le != null) {
        await t.delete(
          'planning',
          where: 'liste_id = ? AND etat IS NULL',
          whereArgs: [id],
        );
      }
    }),
  );

  /// Les choses de la liste déjà placées à partir de `depuis` (un
  /// passage prévu qui n'est pas « pas fait ») : id → passage.
  Future<Map<int, Tache>> placees(DateTime depuis) async {
    final lignes = await db.query(
      'planning',
      where:
          'liste_id IS NOT NULL AND jour >= ? AND '
          '(etat IS NULL OR etat = ?)',
      whereArgs: [cleJour(depuis), Tache.fait],
      orderBy: 'jour, debut',
    );
    // Le plus proche d'abord s'il y en a plusieurs.
    final placees = <int, Tache>{};
    for (final l in lignes) {
      placees.putIfAbsent(l['liste_id'] as int, () => Tache.depuisLigne(l));
    }
    return placees;
  }

  /// Choisit une chose de la liste pour un jour (dans son bac « À
  /// placer »), ou la remet en fond (`jour` nul).
  Future<void> choisitPour(int id, DateTime? jour) => _ecrit(
    db.update(
      'liste',
      {'choisie_pour': jour == null ? null : cleJour(jour)},
      where: 'id = ?',
      whereArgs: [id],
    ),
  );

  // Créneaux fixes

  Future<List<Creneau>> creneaux() async {
    final lignes = await db.query('creneaux', orderBy: 'debut, id');
    return [for (final l in lignes) Creneau.depuisLigne(l)];
  }

  /// Les créneaux fixes d'un jour.
  Future<List<Creneau>> creneauxDu(DateTime jour) async => [
    for (final c in await creneaux())
      if (c.revientLe(jour.weekday)) c,
  ];

  Future<Creneau> enregistreCreneau(Creneau c) => _ecrit(() async {
    if (c.id == null) {
      final id = await db.insert('creneaux', c.versLigne());
      return Creneau(
        id: id,
        texte: c.texte,
        debut: c.debut,
        fin: c.fin,
        jours: c.jours,
      );
    }
    await db.update(
      'creneaux',
      c.versLigne(),
      where: 'id = ?',
      whereArgs: [c.id],
    );
    return c;
  }());

  Future<void> supprimeCreneau(int id) =>
      _ecrit(db.delete('creneaux', where: 'id = ?', whereArgs: [id]));
}
