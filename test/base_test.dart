import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/data/base.dart';
import 'package:ouinon/data/donnees_test.dart';
import 'package:ouinon/utils/courbes.dart';
import 'package:ouinon/data/notifications.dart';
import 'package:ouinon/models/question.dart';

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
}
