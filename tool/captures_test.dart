// Captures d'écran de l'appli (polices réelles), pour montrer le style.
// Lancement : flutter test tool/captures_test.dart --update-goldens
// Images écrites dans tool/captures/ (non commitées).
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/data/base.dart';
import 'package:ouinon/data/donnees_test.dart';
import 'package:ouinon/data/notifications.dart';
import 'package:ouinon/main.dart';
import 'package:ouinon/models/creneau.dart';
import 'package:ouinon/models/tache.dart';
import 'package:ouinon/screens/accueil_screen.dart';
import 'package:ouinon/screens/aujourdhui_screen.dart';
import 'package:ouinon/screens/edition_a_faire_screen.dart';
import 'package:ouinon/screens/edition_tache_screen.dart';
import 'package:ouinon/screens/edition_question_screen.dart';
import 'package:ouinon/screens/fiche_question_screen.dart';
import 'package:ouinon/screens/planning_screen.dart';
import 'package:ouinon/screens/questions_screen.dart';
import 'package:ouinon/screens/reglages_screen.dart';
import 'package:ouinon/screens/stats_screen.dart';
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
    // Six mois de réponses de test (comme le bouton des Réglages).
    await ajouteDonneesTest(base, maintenant: maintenant);
    await base.repond(1, DateTime(2026, 10, 22), 0);
    await base.repond(2, DateTime(2026, 10, 22), 1);
    // Le planning du jour et du lendemain.
    final jeudi = DateTime(2026, 10, 22), vendredi = DateTime(2026, 10, 23);
    for (final t in [
      Tache(jour: jeudi, debut: 540, duree: 30, texte: 'Mails', etat: 0),
      Tache(jour: jeudi, debut: 630, duree: 30, texte: 'Banque', etat: 1),
      Tache(jour: jeudi, debut: 750, duree: 15, texte: 'Appeler maman'),
      Tache(jour: jeudi, debut: 1080, texte: 'Garage', reports: 1),
      Tache(jour: jeudi, debut: 1290, duree: 30, texte: 'Lire'),
      Tache(jour: vendredi, debut: 540, texte: 'Garage C3'),
    ]) {
      await base.enregistreTache(t);
    }
    await base.enregistreCreneau(
      const Creneau(texte: 'Enfants', debut: 17 * 60, fin: 23 * 60),
    );
  });

  Widget avecOnglets(Widget ecran, int index) => Scaffold(
    body: ecran,
    extendBody: true,
    bottomNavigationBar: BarreOnglets(
      index: index,
      libelles: const ['Jour', 'À faire', 'Stats', 'Questions'],
      onChoix: (_) {},
    ),
  );

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
    // Laisse les animations des graphiques aller au bout.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
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
        avecOnglets(StatsScreen(base: base, maintenant: () => maintenant), 2),
        mode,
        hauteur: 6200,
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
        hauteur: 1700,
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
        avecOnglets(QuestionsScreen(base: base), 3),
        mode,
      );
    });

    testWidgets('demain $suffixe', (tester) async {
      await remplit(tester);
      await capture(
        tester,
        '12-demain-$suffixe',
        avecOnglets(
          PlanningScreen(base: base, maintenant: () => maintenant),
          1,
        ),
        mode,
        hauteur: 2300,
      );
    });

    testWidgets('planning du jour $suffixe', (tester) async {
      await remplit(tester);
      await capture(
        tester,
        '13-aujourdhui-planning-$suffixe',
        avecOnglets(
          PlanningScreen(
            base: base,
            maintenant: () => maintenant,
            vue: VuePlanning.aujourdhui,
          ),
          1,
        ),
        mode,
        hauteur: 1700,
      );
    });

    testWidgets('liste $suffixe', (tester) async {
      await remplit(tester);
      await capture(
        tester,
        '17-liste-$suffixe',
        avecOnglets(
          PlanningScreen(
            base: base,
            maintenant: () => maintenant,
            vue: VuePlanning.enFond,
          ),
          1,
        ),
        mode,
        hauteur: 2000,
      );
    });

    testWidgets('à faire $suffixe', (tester) async {
      await capture(
        tester,
        '18-a-faire-$suffixe',
        EditionAFaireScreen(base: base, maintenant: () => maintenant),
        mode,
        hauteur: 1250,
        avant: (tester) async {
          await tester.enterText(find.byType(TextField).first, 'Papiers');
          await tester.tap(find.byKey(const ValueKey('duree-60')));
          await tester.tap(
            find.descendant(
              of: find.byKey(const ValueKey('important')),
              matching: find.text('Oui'),
            ),
          );
          await tester.tap(find.text('Cette semaine'));
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('remplir $suffixe', (tester) async {
      await remplit(tester);
      await capture(
        tester,
        '19-remplir-$suffixe',
        avecOnglets(
          PlanningScreen(base: base, maintenant: () => maintenant),
          1,
        ),
        mode,
        hauteur: 900,
        avant: (tester) async {
          await tester.tap(find.text('Remplir'));
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('prévoir $suffixe', (tester) async {
      await remplit(tester);
      await capture(
        tester,
        '14-prevoir-$suffixe',
        EditionTacheScreen(
          base: base,
          jour: DateTime(2026, 10, 23),
          maintenant: () => maintenant,
        ),
        mode,
        hauteur: 1100,
        avant: (tester) async {
          await tester.enterText(find.byType(TextField).first, 'Garage');
          await tester.pump();
        },
      );
    });

    testWidgets('jour avec planning $suffixe', (tester) async {
      await remplit(tester);
      await capture(
        tester,
        '16-jour-prevu-$suffixe',
        avecOnglets(
          AujourdhuiScreen(base: base, maintenant: () => maintenant),
          0,
        ),
        mode,
        hauteur: 1700,
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

  testWidgets('petit écran, gros texte, demain', (tester) async {
    await remplit(tester);
    await capture(
      tester,
      '15-petit-demain',
      avecOnglets(PlanningScreen(base: base, maintenant: () => maintenant), 1),
      ThemeMode.dark,
      largeur: 360,
      hauteur: 900,
      texte: 1.3,
    );
  });
}
