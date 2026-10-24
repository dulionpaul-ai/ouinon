import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/data/base.dart';
import 'package:ouinon/data/donnees_test.dart';
import 'package:ouinon/utils/courbes.dart';
import 'package:ouinon/data/notifications.dart';
import 'package:ouinon/models/a_faire.dart';
import 'package:ouinon/models/creneau.dart';
import 'package:ouinon/models/question.dart';
import 'package:ouinon/models/tache.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'dart:io';

import 'outils.dart';

void main() {
  test('premier lancement : les 4 questions de départ', () async {
    final base = await ouvreBase();
    final qs = await base.questions();
    expect(qs.map((q) => q.texte), [
      'Sommeil ?',
      'En forme ?',
      'Sport ?',
      'Sorti dehors ?',
    ]);
    expect(qs.first.reponses, ['8 h et +', '6 à 8 h', 'Moins de 6 h']);
    expect(qs.first.heure, 9 * 60);
    expect(qs.every((q) => q.active && q.jours == 0x7F), isTrue);
  });

  test('ajout, modification, et ordre de la journée', () async {
    final base = await ouvreBase(depart: false);
    final a = await base.enregistre(
      const Question(texte: 'Eau ?', reponses: ['Oui', 'Non'], heure: 600),
    );
    final b = await base.enregistre(
      const Question(texte: 'Lu ?', reponses: ['Oui', 'Non'], heure: 1200),
    );
    expect(a.ordre, 0);
    expect(b.ordre, 1);
    expect((await base.questions()).map((q) => q.texte), ['Eau ?', 'Lu ?']);
    // Passée à 21 h, « Eau ? » vient après « Lu ? » (20 h).
    await base.enregistre(
      a.copie(texte: 'Bu de l\'eau ?', jours: 0x1F, heure: 21 * 60),
    );
    var qs = await base.questions();
    expect(qs.map((q) => q.texte), ['Lu ?', 'Bu de l\'eau ?']);
    expect(qs.last.jours, 0x1F);
    // Une question du matin, créée en dernier, passe en tête.
    await base.enregistre(
      const Question(texte: 'Réveil ?', reponses: ['Oui', 'Non'], heure: 421),
    );
    qs = await base.questions();
    expect(qs.first.texte, 'Réveil ?');
  });

  test('une réponse par question et par jour, effaçable', () async {
    final base = await ouvreBase();
    final jour = DateTime(2026, 10, 22);
    await base.repond(1, jour, 0);
    await base.repond(1, jour, 2);
    await base.repond(3, jour, 1);
    expect(await base.reponsesDuJour(jour), {1: 2, 3: 1});
    expect(await base.reponduesDepuis(jour), {'1|2026-10-22', '3|2026-10-22'});
    expect(await base.reponduesDepuis(DateTime(2026, 10, 23)), isEmpty);
    await base.efface(1, jour);
    expect(await base.reponsesDuJour(jour), {3: 1});
    expect((await base.toutesLesReponses())[3], {'2026-10-22': 1});
  });

  test('passer de 2 à 3 réponses, puis de 3 à 2', () async {
    final base = await ouvreBase();
    // Sport ? (id 3) : Oui / Non.
    final sport = (await base.question(3))!;
    final lundi = DateTime(2026, 10, 19);
    await base.repond(3, lundi, 0);
    await base.repond(3, DateTime(2026, 10, 20), 1);
    await base.enregistreAvecNombre(
      sport.copie(reponses: ['Beaucoup', 'Un peu', 'Pas du tout']),
      2,
    );
    expect(await base.reponsesDe(3), {'2026-10-19': 0, '2026-10-20': 2});
    expect((await base.question(3))!.nbReponses, 3);

    await base.repond(3, DateTime(2026, 10, 21), 1);
    final trois = (await base.question(3))!;
    await base.enregistreAvecNombre(trois.copie(reponses: ['Oui', 'Non']), 3);
    // Le « milieu » est effacé, la moins bonne passe en 1.
    expect(await base.reponsesDe(3), {'2026-10-19': 0, '2026-10-20': 1});
    expect((await base.question(3))!.reponses, ['Oui', 'Non']);
  });

  test(
    'réponses de test : ajoutées sans toucher aux vraies, effaçables',
    () async {
      final base = await ouvreBase();
      final aujourdhui = DateTime(2026, 10, 22);
      await base.repond(3, DateTime(2026, 10, 20), 1); // vraie réponse
      final ajoutees = await ajouteDonneesTest(base, maintenant: aujourdhui);
      // 4 questions × 182 jours, moins ~7 % d'oublis, moins la vraie.
      expect(ajoutees, greaterThan(600));
      expect(await base.nombreReponsesTest(), ajoutees);
      expect((await base.reponsesDe(3))['2026-10-20'], 1);
      // Deuxième fois : rien de nouveau (pas de doublons).
      expect(await ajouteDonneesTest(base, maintenant: aujourdhui), 0);
      // Les découvertes trouvent quelque chose.
      final d = decouvertes(
        await base.questions(),
        await base.toutesLesReponses(),
      );
      expect(d, isNotEmpty);
      expect(await base.effaceReponsesTest(), ajoutees);
      expect(await base.toutesLesReponses(), {
        3: {'2026-10-20': 1},
      });
    },
  );

  test('supprimer une question efface ses réponses', () async {
    final base = await ouvreBase();
    await base.repond(1, DateTime(2026, 10, 22), 0);
    await base.supprime(1);
    expect(await base.question(1), isNull);
    expect(await base.toutesLesReponses(), isEmpty);
  });

  group('réponse depuis une notification', () {
    late Base base;
    late FaussesNotifications notifs;

    setUp(() async {
      base = await ouvreBase();
      Base.remplace(base);
      notifs = FaussesNotifications();
    });

    test(
      'le bouton enregistre la réponse du jour de la notification',
      () async {
        await notifs.traiteReponse(reponseBouton('r1', '3|2026-10-21'));
        expect(await base.reponsesDuJour(DateTime(2026, 10, 21)), {3: 1});
        expect(notifs.replanifications, 1);
      },
    );

    test('réponses impossibles ignorées', () async {
      // Sport n'a que 2 réponses ; question inconnue ; appui sur le texte.
      await notifs.traiteReponse(reponseBouton('r2', '3|2026-10-21'));
      await notifs.traiteReponse(reponseBouton('r0', '99|2026-10-21'));
      await notifs.traiteReponse(reponseBouton('ouvrir', '3|2026-10-21'));
      expect(await base.toutesLesReponses(), isEmpty);
      expect(notifs.replanifications, 0);
    });
  });

  test(
    'le gestionnaire d\'arrière-plan est une fonction de premier niveau',
    () {
      expect(reponseNotifArrierePlan, isA<Function>());
    },
  );

  group('planning', () {
    final jeudi = DateTime(2026, 10, 22);
    final vendredi = DateTime(2026, 10, 23);

    test('ajouter, ranger par heure, répondre, retirer', () async {
      final base = await ouvreBase();
      final garage = await base.enregistreTache(
        Tache(jour: vendredi, debut: 18 * 60, texte: 'Garage'),
      );
      await base.enregistreTache(
        Tache(jour: vendredi, debut: 9 * 60, duree: 30, texte: 'Mails'),
      );
      await base.enregistreTache(
        Tache(jour: jeudi, debut: 10 * 60, texte: 'Courses'),
      );
      final demain = await base.tachesDu(vendredi);
      expect([for (final t in demain) t.texte], ['Mails', 'Garage']);
      expect(demain.first.duree, 30);
      await base.repondTache(garage.id!, Tache.fait);
      expect((await base.tache(garage.id!))!.etat, Tache.fait);
      await base.repondTache(garage.id!, null);
      expect((await base.tache(garage.id!))!.etat, isNull);
      expect(await base.taches(depuis: vendredi), hasLength(2));
      await base.supprimeTache(garage.id!);
      expect(await base.tachesDu(vendredi), hasLength(1));
      // Ce qu'on prévoit souvent revient en raccourci.
      expect((await base.habitudes()).map((h) => h.texte), contains('Mails'));
    });

    test('reporter : une heure plus tard, jamais après minuit', () async {
      final base = await ouvreBase();
      final t = await base.enregistreTache(
        Tache(jour: jeudi, debut: 18 * 60, duree: 60, texte: 'Garage'),
      );
      final reportee = await base.reporteTache(
        t.id!,
        DateTime(2026, 10, 22, 18, 20),
      );
      expect(reportee!.debut, 19 * 60 + 20);
      expect(reportee.duree, 60);
      expect(reportee.reports, 1);
      expect(
        await base.reporteTache(t.id!, DateTime(2026, 10, 22, 23, 10)),
        isNull,
      );
      expect((await base.tache(t.id!))!.debut, 19 * 60 + 20);
    });

    test('données de test : jamais sur un jour déjà planifié', () async {
      final base = await ouvreBase();
      final hier = DateTime(2026, 10, 21);
      await base.enregistreTache(Tache(jour: hier, debut: 600, texte: 'Vrai'));
      await ajouteDonneesTest(base, maintenant: jeudi);
      expect([for (final t in await base.tachesDu(hier)) t.texte], ['Vrai']);
      expect(await base.taches(), hasLength(greaterThan(400)));
      await base.effaceReponsesTest();
      expect([for (final t in await base.taches()) t.texte], ['Vrai']);
    });

    test('une base de la version 1 gagne le planning', () async {
      sqfliteFfiInit();
      final dossier = await Directory.systemTemp.createTemp('ouinon');
      addTearDown(() => dossier.delete(recursive: true));
      final chemin = p.join(dossier.path, 'v1.sqlite');
      final v1 = await databaseFactoryFfi.openDatabase(
        chemin,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE questions (id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'texte TEXT NOT NULL, reponses TEXT NOT NULL, heure INTEGER '
              'NOT NULL, jours INTEGER NOT NULL, active INTEGER NOT NULL '
              'DEFAULT 1, ordre INTEGER NOT NULL DEFAULT 0)',
            );
            await db.execute(
              'CREATE TABLE reponses (question_id INTEGER NOT NULL, jour TEXT '
              'NOT NULL, choix INTEGER NOT NULL, repondu_le TEXT NOT NULL, '
              'PRIMARY KEY (question_id, jour))',
            );
            await db.insert('questions', questionsDeDepart.first.versLigne());
          },
        ),
      );
      await v1.close();
      final base = Base(
        await Base.ouvrirAvec(
          databaseFactoryFfi,
          chemin,
          instanceUnique: false,
        ),
      );
      expect(await base.questions(), hasLength(1));
      await base.enregistreTache(Tache(jour: jeudi, debut: 600, texte: 'A'));
      expect(await base.tachesDu(jeudi), hasLength(1));
      expect(await base.liste(), isEmpty);
      await base.db.close();
    });

    test('une base de la version 2 gagne la liste', () async {
      sqfliteFfiInit();
      final dossier = await Directory.systemTemp.createTemp('ouinon');
      addTearDown(() => dossier.delete(recursive: true));
      final chemin = p.join(dossier.path, 'v2.sqlite');
      final v2 = await databaseFactoryFfi.openDatabase(
        chemin,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE questions (id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'texte TEXT NOT NULL, reponses TEXT NOT NULL, heure INTEGER '
              'NOT NULL, jours INTEGER NOT NULL, active INTEGER NOT NULL '
              'DEFAULT 1, ordre INTEGER NOT NULL DEFAULT 0)',
            );
            await db.execute(
              'CREATE TABLE reponses (question_id INTEGER NOT NULL, jour TEXT '
              'NOT NULL, choix INTEGER NOT NULL, repondu_le TEXT NOT NULL, '
              'PRIMARY KEY (question_id, jour))',
            );
            await db.execute(
              'CREATE TABLE planning (id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'jour TEXT NOT NULL, debut INTEGER NOT NULL, duree INTEGER NOT '
              'NULL, texte TEXT NOT NULL, etat INTEGER, reports INTEGER NOT '
              'NULL DEFAULT 0, test INTEGER NOT NULL DEFAULT 0)',
            );
            await db.insert('planning', {
              'jour': '2026-10-22',
              'debut': 600,
              'duree': 60,
              'texte': 'Ancien',
            });
          },
        ),
      );
      await v2.close();
      final base = Base(
        await Base.ouvrirAvec(
          databaseFactoryFfi,
          chemin,
          instanceUnique: false,
        ),
      );
      final anciennes = await base.tachesDu(jeudi);
      expect(anciennes.single.texte, 'Ancien');
      expect(anciennes.single.imperatif, isTrue);
      await base.enregistreAFaire(AFaire(texte: 'Nouveau', creeLe: jeudi));
      expect(await base.liste(), hasLength(1));
      expect(await base.creneaux(), isEmpty);
      await base.db.close();
    });

    test('liste : faite par le planning, de retour si pas faite', () async {
      final base = await ouvreBase();
      final papiers = await base.enregistreAFaire(
        AFaire(texte: 'Papiers', duree: 60, important: true, creeLe: jeudi),
      );
      final t = await base.enregistreTache(
        Tache(
          jour: vendredi,
          debut: 14 * 60,
          texte: 'Papiers',
          listeId: papiers.id,
          quadrant: Case.aPlanifier.index,
        ),
      );
      expect((await base.placees(jeudi)).keys, [papiers.id]);
      await base.repondTache(t.id!, Tache.pasFait);
      expect(await base.placees(jeudi), isEmpty);
      expect(await base.liste(), hasLength(1));
      await base.repondTache(t.id!, Tache.fait);
      expect(await base.liste(), isEmpty);
      expect((await base.aFaire(papiers.id!))!.faiteLe, vendredi);
      await base.repondTache(t.id!, null);
      expect(await base.liste(), hasLength(1));
      // Changer la liste change ce qui est prévu sans réponse.
      await base.enregistreAFaire(papiers.copie(texte: 'Impôts', duree: 90));
      expect((await base.tache(t.id!))!.texte, 'Impôts');
      expect((await base.tache(t.id!))!.duree, 90);
      // Faite sans le planning : ses passages sans réponse partent.
      await base.marqueFaite(papiers.id!, jeudi);
      expect(await base.tache(t.id!), isNull);
      expect(await base.liste(), isEmpty);
      expect(await base.liste(avecFaites: true), hasLength(1));
      await base.supprimeAFaire(papiers.id!);
      expect(await base.liste(avecFaites: true), isEmpty);
    });

    test('choisie pour un jour, créneaux fixes', () async {
      final base = await ouvreBase();
      final a = await base.enregistreAFaire(
        AFaire(texte: 'Papiers', creeLe: jeudi),
      );
      await base.choisitPour(a.id!, vendredi);
      expect((await base.aFaire(a.id!))!.choisiePour, vendredi);
      await base.choisitPour(a.id!, null);
      expect((await base.aFaire(a.id!))!.choisiePour, isNull);
      final enfants = await base.enregistreCreneau(
        const Creneau(
          texte: 'Enfants',
          debut: 17 * 60,
          fin: 23 * 60,
          jours: 0x1F,
        ),
      );
      expect(await base.creneauxDu(vendredi), hasLength(1));
      expect(await base.creneauxDu(DateTime(2026, 10, 24)), isEmpty);
      await base.enregistreCreneau(enfants.copie(fin: 22 * 60));
      expect((await base.creneaux()).single.fin, 22 * 60);
      await base.supprimeCreneau(enfants.id!);
      expect(await base.creneaux(), isEmpty);
    });

    test('liste de test : une seule fois, effaçable', () async {
      final base = await ouvreBase();
      await base.enregistreAFaire(AFaire(texte: 'Vrai', creeLe: jeudi));
      await ajouteDonneesTest(base, maintenant: jeudi);
      expect((await base.liste()).length, greaterThan(5));
      expect(await ajouteDonneesTest(base, maintenant: jeudi), 0);
      await base.effaceReponsesTest();
      expect([for (final a in await base.liste()) a.texte], ['Vrai']);
    });

    group('réponse depuis une notification', () {
      late Base base;
      late FaussesNotifications notifs;
      late Tache garage;

      setUp(() async {
        base = await ouvreBase();
        Base.remplace(base);
        notifs = FaussesNotifications()
          ..horloge = () => DateTime(2026, 10, 22, 18, 5);
        garage = await base.enregistreTache(
          Tache(jour: jeudi, debut: 18 * 60, texte: 'Garage'),
        );
      });

      test('Fait, Pas fait', () async {
        await notifs.traiteReponse(reponseBouton('tf', 't|${garage.id}'));
        expect((await base.tache(garage.id!))!.etat, Tache.fait);
        await notifs.traiteReponse(reponseBouton('tp', 't|${garage.id}'));
        expect((await base.tache(garage.id!))!.etat, Tache.pasFait);
        expect(notifs.replanifications, 2);
      });

      test('Reporter : revient une heure après', () async {
        await notifs.traiteReponse(reponseBouton('tr', 't|${garage.id}'));
        final t = (await base.tache(garage.id!))!;
        expect(t.debut, 19 * 60 + 5);
        expect(t.etat, isNull);
        expect(t.reports, 1);
        expect(notifs.replanifications, 1);
      });

      test('chose inconnue ou appui sur le texte : rien', () async {
        await notifs.traiteReponse(reponseBouton('tf', 't|999'));
        await notifs.traiteReponse(reponseBouton('ouvrir', 't|${garage.id}'));
        expect((await base.tache(garage.id!))!.etat, isNull);
        expect(notifs.replanifications, 0);
      });
    });
  });
}
