import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/data/base.dart';
import 'package:ouinon/data/notifications.dart';
import 'package:ouinon/main.dart';
import 'package:ouinon/screens/accueil_screen.dart';
import 'package:ouinon/screens/aujourdhui_screen.dart';
import 'package:ouinon/screens/edition_question_screen.dart';
import 'package:ouinon/screens/reglages_screen.dart';
import 'package:ouinon/screens/stats_screen.dart';
import 'package:ouinon/utils/jour.dart';
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

  testWidgets('Stats : lien affiché après assez de jours', (tester) async {
    await tester.runAsync(() async {
      final debut = DateTime(2026, 10, 10);
      for (var n = 0; n < 10; n++) {
        final jour = ajouteJours(debut, n);
        await base.repond(3, jour, n.isEven ? 0 : 1); // Sport
        await base.repond(2, jour, n.isEven ? 0 : 2); // En forme
      }
    });
    await ouvre(tester, StatsScreen(base: base, maintenant: midi));
    // Croiseur : quand Sport, regarder En forme, le même jour.
    await tester.tap(find.byKey(const ValueKey('a-3')));
    await tester.tap(find.byKey(const ValueKey('b-2')));
    await tester.tap(find.text('Le même jour'));
    await tester.pump();
    expect(find.text('Sur 10 jours.'), findsOneWidget);
    expect(find.text('100 % « Bien »'), findsOneWidget);
    expect(find.text('0 % « Bien »'), findsOneWidget);
    // Le lien, en pastilles et en barres « avec » / « sans ».
    await tester.scrollUntilVisible(
      find.text('Sport ? Oui'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Sport ? Oui'), findsWidgets);
    expect(find.text('100 %'), findsWidgets);
    expect(find.text('0 %'), findsWidgets);
  });

  testWidgets('Stats : croiser deux questions au choix', (tester) async {
    await tester.runAsync(() async {
      await base.repond(1, DateTime(2026, 10, 20), 0); // Sommeil 8 h et +
      await base.repond(3, DateTime(2026, 10, 20), 0); // Sport Oui
      await base.repond(1, DateTime(2026, 10, 21), 2);
      await base.repond(3, DateTime(2026, 10, 21), 1);
    });
    await ouvre(tester, StatsScreen(base: base, maintenant: midi));
    // Par défaut : Sommeil et En forme (pas de jour commun).
    expect(
      find.text('Pas encore de jours où les deux ont une réponse.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('b-3'))); // Regarder : Sport
    await tester.pump();
    expect(find.text('Sur 2 jours.'), findsOneWidget);
    expect(find.text('100 % « Oui »'), findsOneWidget);
    expect(find.text('0 % « Oui »'), findsOneWidget);
  });

  testWidgets('Stats : sans réponse, explication', (tester) async {
    await ouvre(tester, StatsScreen(base: base, maintenant: midi));
    expect(
      find.textContaining('apparaissent après 7 jours de réponses'),
      findsOneWidget,
    );
    expect(
      find.text('Pas encore de jours où les deux ont une réponse.'),
      findsOneWidget,
    );
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
}
