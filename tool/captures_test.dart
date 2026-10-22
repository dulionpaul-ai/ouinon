// Captures d'écran de l'appli (polices réelles), pour montrer le style.
// Lancement : flutter test tool/captures_test.dart --update-goldens
// Images écrites dans tool/captures/ (non commitées).
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/data/base.dart';
import 'package:ouinon/data/notifications.dart';
import 'package:ouinon/main.dart';
import 'package:ouinon/screens/accueil_screen.dart';
import 'package:ouinon/screens/edition_question_screen.dart';
import 'package:ouinon/screens/fiche_question_screen.dart';
import 'package:ouinon/screens/questions_screen.dart';
import 'package:ouinon/screens/reglages_screen.dart';
import 'package:ouinon/screens/stats_screen.dart';
import 'package:ouinon/utils/jour.dart';
import 'package:ouinon/widgets/rond.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/outils.dart';

Future<void> _police(String famille, List<String> fichiers) async {
  final chargeur = FontLoader(famille);
  for (final f in fichiers) {
    final octets = File(f).readAsBytesSync();
    chargeur.addFont(Future.value(ByteData.view(octets.buffer)));
  }
  await chargeur.load();
}

void main() {
  setUpAll(() async {
    await _police('Unbounded', [
      'assets/fonts/Unbounded-500.ttf',
      'assets/fonts/Unbounded-700.ttf',
    ]);
    await _police('Figtree', [
      for (final w in [500, 600, 700, 800]) 'assets/fonts/Figtree-$w.ttf',
    ]);
    final sdk = File(Platform.resolvedExecutable).parent.parent.parent.path;
    await _police('MaterialIcons', [
      '$sdk/material_fonts/MaterialIcons-Regular.otf',
    ]);
  });

  late Base base;
  final maintenant = DateTime(2026, 10, 22, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({'bienvenue_vue': true});
    base = await ouvreBase();
    Base.remplace(base);
    Notifications.instance = FaussesNotifications();
  });

  Future<void> remplit(WidgetTester tester) => tester.runAsync(() async {
    // 30 jours de réponses inventées, avec un lien sport → forme.
    for (var n = 1; n <= 30; n++) {
      final jour = ajouteJours(DateTime(2026, 10, 22), -n);
      final sport = n % 3 == 0 ? 1 : 0;
      await base.repond(3, jour, sport);
      await base.repond(2, jour, sport == 0 ? (n % 5 == 0 ? 1 : 0) : 2);
      await base.repond(1, jour, n % 4 == 0 ? 2 : (n % 3 == 0 ? 1 : 0));
      await base.repond(4, jour, n % 2);
    }
    await base.repond(1, DateTime(2026, 10, 22), 0);
    await base.repond(2, DateTime(2026, 10, 22), 1);
  });

  Future<void> capture(
    WidgetTester tester,
    String nom,
    Widget ecran,
    ThemeMode mode, {
    double hauteur = 844,
    double largeur = 390,
    double texte = 1,
    Future<void> Function(WidgetTester)? avant,
  }) async {
    tester.view.physicalSize = Size(largeur * 2, hauteur * 2);
    tester.platformDispatcher.textScaleFactorTestValue = texte;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(OuinonApp(accueil: ecran));
    await attends(tester, 15);
    if (avant != null) await avant(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('captures/$nom.png'),
    );
  }

  for (final mode in [ThemeMode.dark]) {
    final suffixe = mode == ThemeMode.light ? 'clair' : 'sombre';

    testWidgets('jour $suffixe', (tester) async {
      await remplit(tester);
      await capture(tester, '1-jour-$suffixe', const AccueilScreen(), mode);
    });

    testWidgets('stats $suffixe', (tester) async {
      await remplit(tester);
      await capture(
        tester,
        '2-stats-$suffixe',
        Scaffold(
          body: StatsScreen(base: base, maintenant: () => maintenant),
          extendBody: true,
          bottomNavigationBar: BarreOnglets(
            index: 1,
            libelles: const ['Jour', 'Stats', 'Questions'],
            onChoix: (_) {},
          ),
        ),
        mode,
      );
    });

    testWidgets('fiche $suffixe', (tester) async {
      await remplit(tester);
      final q = (await tester.runAsync(() => base.question(2)))!;
      await capture(
        tester,
        '3-fiche-$suffixe',
        FicheQuestionScreen(
          base: base,
          question: q,
          maintenant: () => maintenant,
        ),
        mode,
      );
    });

    testWidgets('nouvelle question $suffixe', (tester) async {
      await capture(
        tester,
        '5-nouvelle-$suffixe',
        EditionQuestionScreen(base: base),
        mode,
        hauteur: 1250,
      );
    });

    testWidgets('choix heure $suffixe', (tester) async {
      await capture(
        tester,
        '5b-heure-$suffixe',
        EditionQuestionScreen(base: base),
        mode,
        avant: (tester) async {
          await tester.scrollUntilVisible(
            find.text('21 h'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.text('21 h'));
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('modifier $suffixe', (tester) async {
      final q = (await tester.runAsync(() => base.question(1)))!;
      await capture(
        tester,
        '6-modifier-$suffixe',
        EditionQuestionScreen(base: base, question: q),
        mode,
        hauteur: 1400,
      );
    });

    testWidgets('réglages $suffixe', (tester) async {
      (Notifications.instance as FaussesNotifications).precise = false;
      await capture(
        tester,
        '11-reglages-$suffixe',
        ReglagesScreen(base: base),
        mode,
        hauteur: 1100,
      );
    });

    testWidgets('questions $suffixe', (tester) async {
      await capture(
        tester,
        '4-questions-$suffixe',
        Scaffold(
          body: QuestionsScreen(base: base),
          extendBody: true,
          bottomNavigationBar: BarreOnglets(
            index: 2,
            libelles: const ['Jour', 'Stats', 'Questions'],
            onChoix: (_) {},
          ),
        ),
        mode,
      );
    });
  }

  // Petit téléphone (360 de large) et gros texte (1,3) : rien ne déborde.
  testWidgets('petit écran, gros texte', (tester) async {
    await remplit(tester);
    await capture(
      tester,
      '7-petit-jour',
      const AccueilScreen(),
      ThemeMode.dark,
      largeur: 360,
      hauteur: 760,
      texte: 1.3,
    );
  });

  testWidgets('petit écran, gros texte, questions', (tester) async {
    await capture(
      tester,
      '8-petit-questions',
      Scaffold(body: QuestionsScreen(base: base)),
      ThemeMode.dark,
      largeur: 360,
      hauteur: 760,
      texte: 1.3,
    );
  });

  testWidgets('petit écran, gros texte, nouvelle question', (tester) async {
    await capture(
      tester,
      '9-petit-nouvelle',
      EditionQuestionScreen(base: base),
      ThemeMode.dark,
      largeur: 360,
      hauteur: 1400,
      texte: 1.3,
    );
  });

  testWidgets('petit écran, gros texte, fiche', (tester) async {
    await remplit(tester);
    final q = (await tester.runAsync(() => base.question(1)))!;
    await capture(
      tester,
      '10-petit-fiche',
      FicheQuestionScreen(
        base: base,
        question: q,
        maintenant: () => maintenant,
      ),
      ThemeMode.light,
      largeur: 360,
      hauteur: 1600,
      texte: 1.3,
    );
  });
}
