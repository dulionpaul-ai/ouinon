import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/question.dart';
import '../utils/jour.dart';
import 'supabase.dart';

/// Réponses d'une question : « 2026-10-22 » → indice de la réponse.
typedef Reponses = Map<String, int>;

/// Toutes les questions et réponses.
typedef Copie = ({
  List<Question> questions,
  Map<int, Reponses> reponses,
  Map<String, String> reglages,
});

/// La copie en ligne (Supabase), tenue à jour à chaque changement.
abstract interface class Miroir {
  Future<void> envoieQuestion(Question q);
  Future<void> supprimeQuestion(int id);
  Future<void> envoieReponse(int questionId, DateTime jour, int choix);
  Future<void> effaceReponse(int questionId, DateTime jour);
  Future<void> remplaceReponsesDe(int questionId, Reponses reponses);
  Future<void> envoieReglage(String cle, String valeur);
  Future<void> envoieTout(Copie copie);
  Future<Copie> telecharge();
}

/// Les questions et les réponses, dans une base SQLite sur le téléphone
/// (`ouinon.sqlite`). Rien ne part sur internet.
///
/// La base est aussi ouverte par le moteur d'arrière-plan qui enregistre
/// les réponses données depuis une notification (appli fermée) : toujours
/// la relire plutôt que garder une copie.
class Base {
  /// 8 : nouvelle Ouinon, repartie de zéro (25/11/2026). Les tables de
  /// l'ancienne appli (planning, liste, créneaux) restent dans le fichier,
  /// inutilisées. 9 (26/11/2026) : le « pourquoi » et l'intervalle des
  /// questions, la table `reglages` (la phrase « Je deviens… »). 10
  /// (27/11/2026) : « Prochaine fois » d'une tâche (`depart`), et une
  /// tâche n'a plus de jours fixes.
  static const version = 10;

  final Database db;

  /// La copie en ligne ; nulle dans les tests.
  final Miroir? miroir;

  Base(this.db, {this.miroir});

  final _envois = <Future<void>>{};

  /// Envoie un changement à la copie en ligne, sans faire attendre
  /// l'écran. Sans réseau, tant pis : tout est renvoyé à la prochaine
  /// ouverture de l'appli ([synchronise]).
  void _envoie(Future<void> Function(Miroir m) envoi) {
    final m = miroir;
    if (m == null) return;
    late final Future<void> f;
    f = Future(() => envoi(m))
        .catchError((Object _) {})
        .whenComplete(() => _envois.remove(f));
    _envois.add(f);
  }

  /// Attend la fin des envois en cours (moteur d'arrière-plan, avant
  /// qu'Android ne l'arrête).
  Future<void> envoisTermines() => Future.wait([..._envois]);

  /// À l'ouverture de l'appli : téléphone vide (nouveau téléphone,
  /// appli réinstallée) → tout revient de la copie en ligne ; sinon, tout
  /// y est renvoyé. Rend vrai si des données sont revenues. Ne supprime
  /// jamais rien en ligne.
  Future<bool> synchronise() async {
    final m = miroir;
    if (m == null) return false;
    try {
      final locales = await questions();
      if (locales.isEmpty) {
        final copie = await m.telecharge();
        if (copie.questions.isEmpty) return false;
        await _ecrit(
          db.transaction((t) async {
            for (final MapEntry(key: cle, value: valeur)
                in copie.reglages.entries) {
              await t.insert('reglages', {
                'cle': cle,
                'valeur': valeur,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
            for (final q in copie.questions) {
              await t.insert('questions', q.versLigne());
            }
            for (final MapEntry(key: id, value: r) in copie.reponses.entries) {
              for (final e in r.entries) {
                await t.insert('reponses', {
                  'question_id': id,
                  'jour': e.key,
                  'choix': e.value,
                  'repondu_le': DateTime.now().toIso8601String(),
                });
              }
            }
          }),
        );
        return true;
      }
      await m.envoieTout((
        questions: locales,
        reponses: await toutesLesReponses(),
        reglages: {
          for (final l in await db.query('reglages'))
            l['cle'] as String: l['valeur'] as String,
        },
      ));
    } catch (_) {
      // Sans réseau : on réessaiera à la prochaine ouverture.
    }
    return false;
  }

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
    return Base(
      await ouvrirAvec(databaseFactory, chemin),
      miroir: Supabase.disponible ? Supabase() : null,
    );
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
            jours INTEGER NOT NULL,
            pourquoi TEXT NOT NULL DEFAULT '',
            intervalle INTEGER NOT NULL DEFAULT 0,
            depart TEXT
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
        await _creeReglages(db);
      },
      onUpgrade: (db, ancienne, _) async {
        if (ancienne < 8) {
          // Une question en pause n'a plus de jours (la colonne « active »
          // de l'ancienne appli n'est plus lue).
          await db.execute('UPDATE questions SET jours = 0 WHERE active = 0');
          // Les fausses réponses ajoutées pour essayer les stats.
          await db.delete('reponses', where: "repondu_le = 'test'");
        }
        if (ancienne < 9) {
          final colonnes = {
            for (final c in await db.rawQuery('PRAGMA table_info(questions)'))
              c['name'] as String,
          };
          if (!colonnes.contains('pourquoi')) {
            await db.execute(
              "ALTER TABLE questions ADD COLUMN pourquoi TEXT NOT NULL "
              "DEFAULT ''",
            );
          }
          if (!colonnes.contains('intervalle')) {
            await db.execute(
              'ALTER TABLE questions ADD COLUMN intervalle INTEGER NOT NULL '
              'DEFAULT 0',
            );
          }
          await _creeReglages(db);
        }
        if (ancienne < 10) await _versTaches(db, DateTime.now());
      },
      singleInstance: instanceUnique,
    ),
  );

  /// Version 10 : une tâche (tous les N jours) qui avait aussi des jours
  /// cochés (« dimanche, tous les 7 jours ») garde seulement
  /// l'intervalle ; sa prochaine fois est le prochain de ces jours.
  static Future<void> _versTaches(Database db, DateTime maintenant) async {
    await db.execute('ALTER TABLE questions ADD COLUMN depart TEXT');
    await _rangeTaches(db, maintenant);
  }

  static Future<void> _rangeTaches(Database db, DateTime maintenant) async {
    final lignes = await db.query(
      'questions',
      where: 'intervalle >= 2 AND jours != 0 AND jours != ?',
      whereArgs: [Question.tousLesJours],
    );
    for (final l in lignes) {
      final jours = l['jours'] as int;
      var depart = jourDe(maintenant);
      while (jours & (1 << (depart.weekday - 1)) == 0) {
        depart = ajouteJours(depart, 1);
      }
      await db.update(
        'questions',
        {'jours': Question.tousLesJours, 'depart': cleJour(depart)},
        where: 'id = ?',
        whereArgs: [l['id']],
      );
    }
  }

  /// Pour les tests : la conversion de la version 10 à un moment donné
  /// (la colonne existe déjà).
  @visibleForTesting
  static Future<void> versTachesSansColonne(Database db, DateTime maintenant) =>
      _rangeTaches(db, maintenant);

  static Future<void> _creeReglages(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS reglages (
      cle TEXT PRIMARY KEY,
      valeur TEXT NOT NULL
    )''');

  // Réglages

  /// Un réglage gardé sur le téléphone (nul s'il n'existe pas).
  Future<String?> reglage(String cle) async {
    final lignes = await db.query(
      'reglages',
      where: 'cle = ?',
      whereArgs: [cle],
    );
    return lignes.isEmpty ? null : lignes.first['valeur'] as String;
  }

  Future<void> changeReglage(String cle, String valeur) async {
    await _ecrit(
      db.insert('reglages', {
        'cle': cle,
        'valeur': valeur,
      }, conflictAlgorithm: ConflictAlgorithm.replace),
    );
    _envoie((m) => m.envoieReglage(cle, valeur));
  }

  /// La phrase du haut : « Je deviens quelqu'un qui… » (vide : pas encore
  /// écrite).
  Future<String> phrase() async => await reglage('phrase') ?? '';

  Future<void> changePhrase(String phrase) =>
      changeReglage('phrase', phrase.trim());

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
    final enregistree = q.id == null
        ? q.copie(id: await db.insert('questions', q.versLigne()))
        : q;
    if (q.id != null) {
      await db.update(
        'questions',
        q.versLigne(),
        where: 'id = ?',
        whereArgs: [q.id],
      );
    }
    _envoie((m) => m.envoieQuestion(enregistree));
    return enregistree;
  }());

  /// Met à jour une question dont le nombre de réponses change, et
  /// convertit ses réponses passées : de 2 à 3, la moins bonne (indice 1)
  /// passe en 2 ; de 3 à 2, celles du milieu sont effacées et la moins
  /// bonne passe en 1. La meilleure reste toujours 0.
  Future<void> enregistreAvecNombre(Question q, int ancienNombre) async {
    await _convertit(q, ancienNombre);
    final reponses = (await toutesLesReponses())[q.id] ?? {};
    _envoie((m) async {
      await m.envoieQuestion(q);
      await m.remplaceReponsesDe(q.id!, reponses);
    });
  }

  Future<void> _convertit(Question q, int ancienNombre) => _ecrit(
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
  Future<void> supprime(int id) async {
    await _ecrit(db.delete('questions', where: 'id = ?', whereArgs: [id]));
    _envoie((m) => m.supprimeQuestion(id));
  }

  // Réponses

  /// Enregistre (ou remplace) la réponse d'une question pour un jour.
  Future<void> repond(
    int questionId,
    DateTime jour,
    int choix, {
    DateTime? maintenant,
  }) async {
    await _ecrit(
      db.insert('reponses', {
        'question_id': questionId,
        'jour': cleJour(jour),
        'choix': choix,
        'repondu_le': (maintenant ?? DateTime.now()).toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace),
    );
    _envoie((m) => m.envoieReponse(questionId, jour, choix));
  }

  /// Efface la réponse d'une question pour un jour.
  Future<void> efface(int questionId, DateTime jour) async {
    await _ecrit(
      db.delete(
        'reponses',
        where: 'question_id = ? AND jour = ?',
        whereArgs: [questionId, cleJour(jour)],
      ),
    );
    _envoie((m) => m.effaceReponse(questionId, jour));
  }

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
