import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/data/base.dart';
import 'package:ouinon/data/notifications.dart';
import 'package:ouinon/main.dart';
import 'package:ouinon/screens/accueil_screen.dart';
import 'package:ouinon/screens/aujourdhui_screen.dart';
import 'package:ouinon/screens/edition_question_screen.dart';
import 'package:ouinon/screens/stats_screen.dart';
import 'package:ouinon/utils/jour.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils.dart';

void main() {
  late Base base;
  late FaussesNotifications notifs;
  // Jeudi 22 octobre 2026, 12 h.
  DateTime midi() => DateTime(2026, 10, 22, 12);

  setUp(() async {
    base = await ouvreBase();
    Base.remplace(base);
    notifs = FaussesNotifications();
    Notifications.instance = notifs;
  });

  Future<void> ouvre(WidgetTester tester, Widget ecran) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(OuiNonApp(accueil: ecran));
    await attends(tester);
  }

  testWidgets('Aujourd\'hui : répondre, changer, effacer', (tester) async {
    await ouvre(tester, AujourdhuiScreen(base: base, maintenant: midi));
    expect(find.text('Aujourd\'hui'), findsOneWidget);
    expect(find.text('Jeudi 22 octobre'), findsOneWidget);
    expect(find.text('Sommeil ?'), findsOneWidget);
    expect(find.text('0 sur 4 répondue'), findsOneWidget);

    await tester.tap(find.text('6 à 8 h'));
    await attends(tester);
    final jour = DateTime(2026, 10, 22);
    expect(await tester.runAsync(() => base.reponsesDuJour(jour)), {1: 1});
    expect(find.text('1 sur 4 répondue'), findsOneWidget);
    expect(notifs.retirees, hasLength(1));

    // Toucher la réponse choisie l'efface.
    await tester.tap(find.text('6 à 8 h'));
    await attends(tester);
    expect(await tester.runAsync(() => base.reponsesDuJour(jour)), isEmpty);
  });

  testWidgets('Aujourd\'hui : revenir sur hier', (tester) async {
    await tester.runAsync(() => base.repond(3, DateTime(2026, 10, 21), 0));
    await ouvre(tester, AujourdhuiScreen(base: base, maintenant: midi));
    await tester.tap(find.byTooltip('Jour d\'avant'));
    await attends(tester);
    expect(find.text('Hier'), findsOneWidget);
    expect(find.text('Mercredi 21 octobre'), findsOneWidget);
    expect(find.text('1 sur 4 répondue'), findsOneWidget);
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
    await tester.tap(find.text('sam.'));
    await tester.tap(find.text('dim.'));
    await tester.pump();
    expect(find.text('En semaine'), findsOneWidget);
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await attends(tester);
    final q = (await tester.runAsync(base.questions))!.last;
    expect(q.texte, 'Stressé ?');
    expect(q.reponses, ['Pas du tout', 'Un peu', 'Beaucoup']);
    expect(q.jours, 0x1F);
  });

  testWidgets('question sans texte refusée', (tester) async {
    await ouvre(tester, EditionQuestionScreen(base: base));
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await attends(tester);
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
    expect(find.textContaining('« Sport ? Oui »'), findsWidgets);
    expect(find.textContaining('10 fois sur 10'), findsWidgets);
    expect(find.text('Sur 10 jours.'), findsWidgets);
  });

  testWidgets('Stats : sans réponse, explication', (tester) async {
    await ouvre(tester, StatsScreen(base: base, maintenant: midi));
    expect(
      find.textContaining('apparaîtront après au moins 7 jours'),
      findsOneWidget,
    );
    expect(find.text('Pas encore de réponse.'), findsNWidgets(4));
  });

  testWidgets('premier lancement : bienvenue puis notifications', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await ouvre(tester, const AccueilScreen());
    expect(find.text('Bienvenue dans Oui-Non'), findsOneWidget);
    await tester.tap(find.text('Autoriser les notifications'));
    await attends(tester);
    expect(find.text('Bienvenue dans Oui-Non'), findsNothing);
    expect(notifs.replanifications, greaterThan(0));
    expect(find.text('Questions'), findsOneWidget);
  });
}
