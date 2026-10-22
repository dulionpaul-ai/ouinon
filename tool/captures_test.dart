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
import 'package:ouinon/screens/fiche_question_screen.dart';
import 'package:ouinon/screens/questions_screen.dart';
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
    ThemeMode mode,
  ) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(OuinonApp(accueil: ecran, themeMode: mode));
    await attends(tester, 15);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('captures/$nom.png'),
    );
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
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
}
