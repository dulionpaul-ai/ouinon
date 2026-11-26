import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/data/base.dart';
import 'package:ouinon/data/notifications.dart';
import 'package:ouinon/models/question.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'outils.dart';

const _sport = Question(
  texte: 'Sport ?',
  reponses: ['Oui', 'Non'],
  heure: 21 * 60,
  jours: Question.tousLesJours,
);

void main() {
  final lundi = DateTime(2026, 11, 23);
  final mardi = DateTime(2026, 11, 24);

  test('une nouvelle base est vide', () async {
    final base = await ouvreBase();
    expect(await base.questions(), isEmpty);
  });

  test('créer, modifier, répondre, supprimer', () async {
    final base = await ouvreBase();
    final q = await base.enregistre(_sport);
    expect(q.id, isNotNull);
    await base.enregistre(q.copie(texte: 'Muscu ?', jours: 0));
    final relue = await base.question(q.id!);
    expect(relue!.texte, 'Muscu ?');
    expect(relue.enPause, isTrue);

    await base.repond(q.id!, lundi, 1);
    await base.repond(q.id!, lundi, 0);
    expect((await base.toutesLesReponses())[q.id], {'2026-11-23': 0});
    await base.efface(q.id!, lundi);
    expect(await base.toutesLesReponses(), isEmpty);

    await base.repond(q.id!, lundi, 0);
    await base.supprime(q.id!);
    expect(await base.questions(), isEmpty);
    expect(await base.toutesLesReponses(), isEmpty);
  });

  test('de 2 à 3 réponses, la moins bonne passe en 2', () async {
    final base = await ouvreBase();
    final q = await base.enregistre(_sport);
    await base.repond(q.id!, lundi, 0);
    await base.repond(q.id!, mardi, 1);
    await base.enregistreAvecNombre(
      q.copie(reponses: ['Oui', 'Un peu', 'Non']),
      2,
    );
    expect((await base.toutesLesReponses())[q.id], {
      '2026-11-23': 0,
      '2026-11-24': 2,
    });
  });

  test('de 3 à 2 réponses, le milieu est effacé', () async {
    final base = await ouvreBase();
    final q = await base.enregistre(
      _sport.copie(reponses: ['Oui', 'Un peu', 'Non']),
    );
    await base.repond(q.id!, lundi, 1);
    await base.repond(q.id!, mardi, 2);
    await base.enregistreAvecNombre(q.copie(reponses: ['Oui', 'Non']), 3);
    expect((await base.toutesLesReponses())[q.id], {'2026-11-24': 1});
  });

  test(
    'la base de l\'ancienne appli (version 7) est reprise (version 9)',
    () async {
      sqfliteFfiInit();
      final dossier = await Directory.systemTemp.createTemp('ouinon');
      final chemin = p.join(dossier.path, 'ouinon.sqlite');
      final ancienne = await databaseFactoryFfi.openDatabase(
        chemin,
        options: OpenDatabaseOptions(
          version: 7,
          onCreate: (db, _) async {
            await db.execute('''
            CREATE TABLE questions (
              id INTEGER PRIMARY KEY AUTOINCREMENT, texte TEXT NOT NULL,
              reponses TEXT NOT NULL, heure INTEGER NOT NULL,
              jours INTEGER NOT NULL, active INTEGER NOT NULL DEFAULT 1,
              ordre INTEGER NOT NULL DEFAULT 0, famille TEXT,
              redemande INTEGER)''');
            await db.execute('''
            CREATE TABLE reponses (
              question_id INTEGER NOT NULL, jour TEXT NOT NULL,
              choix INTEGER NOT NULL, repondu_le TEXT NOT NULL,
              PRIMARY KEY (question_id, jour))''');
            await db.execute('CREATE TABLE planning (id INTEGER PRIMARY KEY)');
          },
        ),
      );
      await ancienne.insert('questions', {
        'texte': 'Hyrox ?',
        'reponses': 'Fait\nPas fait',
        'heure': 720,
        'jours': 1,
      });
      await ancienne.insert('questions', {
        'texte': 'Sommeil ?',
        'reponses': '8 h\n6 h\nMoins',
        'heure': 540,
        'jours': 0x7F,
        'active': 0,
      });
      await ancienne.insert('reponses', {
        'question_id': 1,
        'jour': '2026-11-23',
        'choix': 0,
        'repondu_le': '2026-11-23T12:00:00',
      });
      await ancienne.insert('reponses', {
        'question_id': 1,
        'jour': '2026-09-01',
        'choix': 1,
        'repondu_le': 'test',
      });
      await ancienne.close();

      final base = Base(
        await Base.ouvrirAvec(
          databaseFactoryFfi,
          chemin,
          instanceUnique: false,
        ),
      );
      final questions = await base.questions();
      expect(questions.map((q) => q.texte), ['Sommeil ?', 'Hyrox ?']);
      expect(questions.first.enPause, isTrue);
      expect(questions.last.jours, 1);
      expect(await base.toutesLesReponses(), {
        1: {'2026-11-23': 0},
      });
      // Version 9 : pourquoi et intervalle vides, la phrase à écrire.
      expect(questions.last.pourquoi, '');
      expect(questions.last.intervalle, 0);
      expect(await base.phrase(), '');
      await base.changePhrase(' dort bien. ');
      expect(await base.phrase(), 'dort bien.');
      // Une nouvelle question s'ajoute sans les anciennes colonnes.
      await base.enregistre(
        _sport.copie(pourquoi: 'Pour la forme.', intervalle: 3),
      );
      final toutes = await base.questions();
      expect(toutes, hasLength(3));
      expect(toutes.last.pourquoi, 'Pour la forme.');
      expect(toutes.last.intervalle, 3);
      await base.db.close();
      await dossier.delete(recursive: true);
    },
  );

  test('un bouton de notification enregistre la réponse', () async {
    final base = await ouvreBase();
    Base.remplace(base);
    final q = await base.enregistre(_sport);
    final notifs = FaussesNotifications();
    await notifs.traiteReponse(bouton('r1', '${q.id}|2026-11-23'));
    expect((await base.toutesLesReponses())[q.id], {'2026-11-23': 1});
    expect(notifs.replanifications, 1);
    // Réponse hors limites ou contenu abîmé : rien.
    await notifs.traiteReponse(bouton('r5', '${q.id}|2026-11-24'));
    await notifs.traiteReponse(bouton('r0', 'abîmé'));
    await notifs.traiteReponse(bouton('tf', 't|3'));
    expect((await base.toutesLesReponses())[q.id], hasLength(1));
  });

  test('l\'heure part en temps universel', () {
    final local = DateTime(2026, 11, 23, 7, 1);
    expect(instantProgramme(local).toUtc(), local.toUtc());
  });
}
