import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/data/base.dart';
import 'package:ouinon/data/donnees_test.dart';
import 'package:ouinon/data/notifications.dart';
import 'package:ouinon/main.dart';
import 'package:ouinon/models/tache.dart';
import 'package:ouinon/screens/accueil_screen.dart';
import 'package:ouinon/screens/aujourdhui_screen.dart';
import 'package:ouinon/screens/edition_question_screen.dart';
import 'package:ouinon/screens/edition_tache_screen.dart';
import 'package:ouinon/screens/planning_screen.dart';
import 'package:ouinon/screens/reglages_screen.dart';
import 'package:ouinon/screens/stats_screen.dart';
import 'package:ouinon/widgets/graphiques.dart';
import 'package:ouinon/widgets/rond.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils.dart';

void main() {
  late Base base;
  late FaussesNotifications notifs;
  // Jeudi 22 octobre 2026, 12 h.
  DateTime midi() => DateTime(2026, 10, 22, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    base = await ouvreBase();
    Base.remplace(base);
    notifs = FaussesNotifications();
    Notifications.instance = notifs;
  });

  Future<void> ouvre(WidgetTester tester, Widget ecran) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(OuinonApp(accueil: ecran));
    await attends(tester);
  }

  testWidgets('Aujourd\'hui : répondre, changer, effacer', (tester) async {
    final semantique = tester.ensureSemantics();
    await ouvre(tester, AujourdhuiScreen(base: base, maintenant: midi));
    expect(find.text('Aujourd\'hui'), findsOneWidget);
    expect(find.text('Jeu. 22 oct.'), findsOneWidget);
    expect(find.text('Sommeil ?'), findsOneWidget);
    expect(find.bySemanticsLabel('0 sur 4 répondue'), findsOneWidget);

    await tester.tap(find.text('6 à 8 h'));
    await attends(tester);
    final jour = DateTime(2026, 10, 22);
    expect(await tester.runAsync(() => base.reponsesDuJour(jour)), {1: 1});
    expect(find.bySemanticsLabel('1 sur 4 répondue'), findsOneWidget);
    expect(notifs.retirees, hasLength(1));

    // Toucher la réponse choisie l'efface.
    await tester.tap(find.text('6 à 8 h'));
    await attends(tester);
    expect(await tester.runAsync(() => base.reponsesDuJour(jour)), isEmpty);
    semantique.dispose();
  });

  testWidgets('Aujourd\'hui : revenir sur hier', (tester) async {
    final semantique = tester.ensureSemantics();
    await tester.runAsync(() => base.repond(3, DateTime(2026, 10, 21), 0));
    await ouvre(tester, AujourdhuiScreen(base: base, maintenant: midi));
    await tester.tap(find.byTooltip('Jour d\'avant'));
    await tester.pumpAndSettle();
    await attends(tester);
    expect(find.text('Hier'), findsOneWidget);
    expect(find.text('Mer. 21 oct.'), findsOneWidget);
    expect(find.bySemanticsLabel('1 sur 4 répondue'), findsOneWidget);
    semantique.dispose();
  });

  testWidgets('Aujourd\'hui : glisser vers la droite montre la veille', (
    tester,
  ) async {
    await ouvre(tester, AujourdhuiScreen(base: base, maintenant: midi));
    // Vers la gauche : rien après aujourd'hui.
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    await attends(tester);
    expect(find.text('Aujourd\'hui'), findsOneWidget);
    // Vers la droite : hier, puis avant-hier.
    await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    await attends(tester);
    expect(find.text('Hier'), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    await attends(tester);
    expect(find.text('Mardi'), findsOneWidget);
    expect(find.text('Mar. 20 oct.'), findsOneWidget);
  });

  testWidgets('modifier : passer de 3 à 2 réponses avec confirmation', (
    tester,
  ) async {
    final forme = (await tester.runAsync(() => base.question(2)))!;
    await tester.runAsync(() async {
      await base.repond(2, DateTime(2026, 10, 20), 1);
      await base.repond(2, DateTime(2026, 10, 21), 2);
    });
    await ouvre(tester, EditionQuestionScreen(base: base, question: forme));
    await tester.tap(find.text('2 réponses'));
    await tester.pump();
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await attends(tester);
    await tester.pumpAndSettle();
    expect(find.text('Passer à 2 réponses ?'), findsOneWidget);
    expect(
      find.textContaining('1 réponse « Moyen » sera effacée'),
      findsOneWidget,
    );
    await tester.tap(find.text('Changer'));
    await attends(tester);
    await tester.pumpAndSettle();
    final apres = (await tester.runAsync(() => base.question(2)))!;
    expect(apres.nbReponses, 2);
    expect(await tester.runAsync(() => base.reponsesDe(2)), {'2026-10-21': 1});
  });

  testWidgets('nouvelle question à 3 réponses, en semaine', (tester) async {
    await ouvre(tester, EditionQuestionScreen(base: base));
    await tester.enterText(find.byType(TextField).first, 'Stressé ?');
    await tester.tap(find.text('3 réponses'));
    await tester.pump();
    expect(find.text('Moyen'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('reponse0')),
      'Pas du tout',
    );
    await tester.enterText(find.byKey(const ValueKey('reponse1')), 'Un peu');
    await tester.enterText(find.byKey(const ValueKey('reponse2')), 'Beaucoup');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('jour6')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('jour5')));
    await tester.tap(find.byKey(const ValueKey('jour6')));
    await tester.pump();
    expect(
      tester
          .widget<PiluleChoix>(find.widgetWithText(PiluleChoix, 'Semaine'))
          .choisie,
      isTrue,
    );
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await attends(tester);
    final q = (await tester.runAsync(base.questions))!.last;
    expect(q.texte, 'Stressé ?');
    expect(q.reponses, ['Pas du tout', 'Un peu', 'Beaucoup']);
    expect(q.jours, 0x1F);
  });

  testWidgets('suggestions : créer « 1 / 2 / 3 », puis la supprimer', (
    tester,
  ) async {
    await ouvre(tester, EditionQuestionScreen(base: base));
    await tester.tap(find.text('3 réponses'));
    await attends(tester);
    expect(find.text('Bien / Moyen / Pas bien'), findsOneWidget);
    expect(find.text('Oui / Non'), findsNothing);

    await tester.tap(find.text('+ Autre'));
    await tester.pumpAndSettle();
    final champs = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(champs.at(0), '3');
    await tester.enterText(champs.at(1), '2');
    await tester.enterText(champs.at(2), '1');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Enregistrer'),
      ),
    );
    await attends(tester);
    await tester.pumpAndSettle();
    // Gardée, et appliquée aux réponses.
    expect(find.text('3 / 2 / 1'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('reponse0')))
          .controller!
          .text,
      '3',
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('suggestions_reponses'), contains('"3","2","1"'));

    await tester.longPress(find.text('3 / 2 / 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer').last);
    await attends(tester);
    await tester.pumpAndSettle();
    expect(find.text('3 / 2 / 1'), findsNothing);
  });

  testWidgets('heure : cadran sans clavier, Enregistrer caché', (tester) async {
    await ouvre(tester, EditionQuestionScreen(base: base));
    expect(find.text('Enregistrer'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('21 h'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('21 h'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(find.text('Enregistrer'), findsNothing);
    expect(find.byIcon(Icons.keyboard_outlined), findsNothing);
    // La police des tests, très large, pousse « OK » hors de l'écran
    // simulé : on ferme le cadran avec une heure, comme « OK ».
    Navigator.of(tester.element(find.byType(TimePickerDialog)))
        .pop(const TimeOfDay(hour: 22, minute: 30));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsNothing);
    expect(find.text('Enregistrer'), findsOneWidget);
    expect(find.text('22 h 30'), findsOneWidget);
  });

  testWidgets('question sans texte refusée', (tester) async {
    await ouvre(tester, EditionQuestionScreen(base: base));
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await attends(tester);
    await tester.scrollUntilVisible(
      find.text('Écris la question.'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Écris la question.'), findsOneWidget);
    expect(await tester.runAsync(base.questions), hasLength(4));
  });

  testWidgets('Stats : sans réponse, explication', (tester) async {
    await ouvre(tester, StatsScreen(base: base, maintenant: midi));
    expect(
      find.textContaining('Les premières découvertes arrivent'),
      findsOneWidget,
    );
    expect(
      find.text('Pas encore assez de jours en commun (14 au moins).'),
      findsOneWidget,
    );
  });

  testWidgets('Stats : découvertes et comparateur avec 6 mois de test', (
    tester,
  ) async {
    await tester.runAsync(
      () => ajouteDonneesTest(base, maintenant: DateTime(2026, 10, 22)),
    );
    await ouvre(tester, StatsScreen(base: base, maintenant: midi));
    await tester.pumpAndSettle();
    // Des découvertes trouvées toutes seules, avec leurs courbes.
    expect(find.textContaining('Même courbe'), findsWidgets);
    expect(find.byType(Courbes), findsWidgets);
    // Comparateur : ressemblance chiffrée, curseur de décalage.
    await tester.scrollUntilVisible(
      find.byType(Slider),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('de ressemblance'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('a-1')));
    await tester.tap(find.byKey(const ValueKey('b-2')));
    await tester.pumpAndSettle();
    final curseur = tester.widget<Slider>(find.byType(Slider));
    curseur.onChanged!(1);
    await tester.pumpAndSettle();
    expect(find.text('Courbe 2 décalée de 1 jour'), findsOneWidget);
    // Le nuage de points et la carte de chaleur sont là.
    expect(find.byType(Nuage), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(CarteChaleur),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(CarteChaleur), findsOneWidget);
  });

  testWidgets('premier lancement : bienvenue puis notifications', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await ouvre(tester, const AccueilScreen());
    expect(find.text('Bienvenue dans Ouinon'), findsOneWidget);
    await tester.tap(find.text('Autoriser les notifications'));
    await attends(tester);
    expect(find.text('Bienvenue dans Ouinon'), findsNothing);
    expect(notifs.replanifications, greaterThan(0));
    expect(find.text('Questions'), findsOneWidget);
  });

  testWidgets('heure précise non autorisée : demandée une seule fois', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'bienvenue_vue': true});
    notifs.precise = false;
    await ouvre(tester, const AccueilScreen());
    expect(find.text('Questions à l\'heure pile'), findsOneWidget);
    await tester.tap(find.text('Autoriser'));
    await attends(tester);
    expect(notifs.demandesHeurePrecise, 1);

    // Deuxième ouverture : plus de fenêtre.
    await tester.pumpWidget(const SizedBox());
    await ouvre(tester, const AccueilScreen());
    expect(find.text('Questions à l\'heure pile'), findsNothing);
  });

  testWidgets('Réglages : heure précise et prochaine question', (tester) async {
    notifs.precise = false;
    await ouvre(tester, ReglagesScreen(base: base));
    expect(find.textContaining('Heure précise non autorisée'), findsOneWidget);
    expect(find.text('Autoriser l\'heure précise'), findsOneWidget);
    expect(find.textContaining('Prochaine question :'), findsOneWidget);
    expect(
      find.text('27 notifications programmées sur le téléphone.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Autoriser l\'heure précise'));
    await attends(tester);
    expect(notifs.demandesHeurePrecise, 1);
  });

  testWidgets('Réglages : couper le bilan du dimanche', (tester) async {
    await ouvre(tester, ReglagesScreen(base: base));
    final interrupteur = find.byKey(const ValueKey('interrupteur-bilan'));
    await tester.scrollUntilVisible(
      interrupteur,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(interrupteur).value, isTrue);
    await tester.tap(interrupteur);
    await attends(tester);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('bilan_dimanche'), isFalse);
  });

  group('planning', () {
    final jeudi = DateTime(2026, 10, 22);
    final vendredi = DateTime(2026, 10, 23);

    testWidgets('demain vide, puis une chose prévue', (tester) async {
      await ouvre(tester, PlanningScreen(base: base, maintenant: midi));
      expect(find.text('Demain'), findsWidgets);
      expect(
        find.textContaining('Prépare ta journée de demain'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Prévoir quelque chose'));
      await tester.pumpAndSettle();
      await attends(tester);
      expect(find.byType(EditionTacheScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Garage');
      await tester.ensureVisible(find.byKey(const ValueKey('duree-90')));
      await tester.tap(find.byKey(const ValueKey('duree-90')));
      await tester.pump();
      expect(find.text('Demain, de 9 h à 10 h 30'), findsOneWidget);
      await tester.tap(find.text('Enregistrer'));
      await attends(tester);
      await tester.pumpAndSettle();
      final prevues = (await tester.runAsync(() => base.tachesDu(vendredi)))!;
      expect(prevues.single.texte, 'Garage');
      expect(prevues.single.debut, 9 * 60);
      expect(prevues.single.duree, 90);
      expect(find.text('Garage'), findsOneWidget);
      expect(find.textContaining('1 chose · 1 h 30'), findsOneWidget);
    });

    testWidgets('aujourd\'hui : répondre ; demain : remettre ce qui reste', (
      tester,
    ) async {
      final faite = (await tester.runAsync(
        () => base.enregistreTache(
          Tache(jour: jeudi, debut: 10 * 60, texte: 'Banque'),
        ),
      ))!;
      await tester.runAsync(
        () => base.enregistreTache(
          Tache(jour: jeudi, debut: 18 * 60, texte: 'Garage'),
        ),
      );
      await ouvre(tester, PlanningScreen(base: base, maintenant: midi));
      // 10 h est passée et sans réponse : à remettre demain.
      expect(find.text('Pas fait aujourd\'hui'), findsOneWidget);
      await tester.tap(find.text('Aujourd\'hui').last);
      await attends(tester);
      await tester.tap(find.text('Fait').first);
      await attends(tester);
      expect(
        (await tester.runAsync(() => base.tache(faite.id!)))!.etat,
        Tache.fait,
      );
      expect(notifs.retireesTaches, [faite.id]);
      // Plus rien à remettre (Garage est à 18 h).
      await tester.tap(find.text('Demain').last);
      await attends(tester);
      expect(find.text('Pas fait aujourd\'hui'), findsNothing);
      await tester.runAsync(() => base.repondTache(faite.id!, Tache.pasFait));
      await attends(tester);
      await tester.scrollUntilVisible(
        find.text('Remettre demain'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Remettre demain'));
      await attends(tester);
      final demain = (await tester.runAsync(() => base.tachesDu(vendredi)))!;
      expect(demain.single.texte, 'Banque');
      expect(demain.single.debut, 10 * 60);
      expect(find.text('Pas fait aujourd\'hui'), findsNothing);
    });

    testWidgets('horaires qui se croisent : signalés', (tester) async {
      await tester.runAsync(
        () => base.enregistreTache(
          Tache(jour: vendredi, debut: 9 * 60, texte: 'Courses'),
        ),
      );
      await ouvre(
        tester,
        EditionTacheScreen(base: base, jour: vendredi, maintenant: midi),
      );
      // Après Courses (9 h – 10 h) : 10 h proposé.
      expect(find.text('10 h'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Garage');
      await tester.ensureVisible(find.byKey(const ValueKey('duree-180')));
      await tester.tap(find.byKey(const ValueKey('duree-180')));
      await tester.pump();
      expect(find.textContaining('Croise'), findsNothing);
      // Raccourci : ce qu'on a déjà prévu revient.
      expect(find.widgetWithText(PiluleChoix, 'Courses'), findsOneWidget);
    });

    testWidgets('la page Jour montre ce qui était prévu', (tester) async {
      await tester.runAsync(
        () => base.enregistreTache(
          Tache(jour: jeudi, debut: 18 * 60, texte: 'Garage'),
        ),
      );
      await ouvre(tester, AujourdhuiScreen(base: base, maintenant: midi));
      await tester.scrollUntilVisible(
        find.text('Garage'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Prévu'), findsOneWidget);
      expect(find.text('18 h'), findsWidgets);
    });

    testWidgets('Stats : le planning et sa courbe', (tester) async {
      await tester.runAsync(
        () => ajouteDonneesTest(base, maintenant: DateTime(2026, 10, 22)),
      );
      await ouvre(tester, StatsScreen(base: base, maintenant: midi));
      await tester.pumpAndSettle();
      // Le planning se compare comme une question.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('a--1')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.scrollUntilVisible(
        find.text('Ton planning'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Ton planning'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Selon le moment'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Selon le moment'), findsOneWidget);
    });
  });
}
